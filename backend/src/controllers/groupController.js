import ExcelJS from 'exceljs';

import { query } from '../config/database.js';
import Group from '../models/Group.js';
import Settlement from '../models/Settlement.js';
import GroupService from '../services/groupService.js';
import ActivityService from '../services/activityService.js';
import { NotificationService } from '../services/notificationService.js';
import WatiService from '../services/watiService.js';
import EmailService from '../services/emailService.js';
import User from '../models/User.js';

/**
 * Get user's groups
 * GET /api/v1/groups?userId=:id&page=1&limit=20
 */
const getGroups = async (req, res, next) => {
  try {
    const { userId, page = 1, limit = 20 } = req.query;

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId query parameter is required',
      });
    }

    const offset = (page - 1) * limit;
    const groups = await Group.findByUserId(userId, parseInt(limit), offset);

    // Batch fetch members for ALL groups in a single query (eliminates N+1)
    const groupIds = groups.map(g => g.id);
    const membersByGroup = await Group.getMembersByGroupIds(groupIds);

    // Pair-level breakdown of the requesting user's position in each group.
    //
    // For each group we compute three numbers:
    //   myBalance         = signed per-group net (positive = others owe me net,
    //                       negative = I owe net). Used by the group card.
    //   youAreOwedInGroup = sum of positive pair-nets (per other user)
    //                       within this group. What "I'm owed" totals up to,
    //                       independent of debts to other people.
    //   youOweInGroup     = sum of |negative pair-nets| within this group.
    //                       What "I owe" totals up to.
    //
    // Why both: home-screen detail screens ("You're owed" / "You owe") need
    // pair-level totals so users see Group X even when their per-group net is
    // positive but they owe one specific member there. The group card and
    // simplify-debt math still want the net.
    const balancesByGroup = {};
    if (groupIds.length > 0) {
      const placeholders = groupIds.map((_, i) => `$${i + 2}`).join(', ');
      const balanceResult = await query(
        `WITH pair_deltas AS (
           -- I paid → each other split row means that user owes me
           SELECT e.group_id, es.user_id AS other_user_id, es.amount AS delta
           FROM expenses e
           JOIN expense_splits es ON es.expense_id = e.id
           WHERE e.deleted_at IS NULL
             AND e.paid_by = $1
             AND es.user_id != $1
             AND e.group_id IN (${placeholders})
           UNION ALL
           -- Other paid → I owe them my split
           SELECT e.group_id, e.paid_by AS other_user_id, -es.amount AS delta
           FROM expenses e
           JOIN expense_splits es ON es.expense_id = e.id
           WHERE e.deleted_at IS NULL
             AND e.paid_by != $1
             AND es.user_id = $1
             AND e.group_id IN (${placeholders})
           UNION ALL
           SELECT s.group_id, s.to_user_id AS other_user_id, s.amount AS delta
           FROM settlements s
           WHERE s.deleted_at IS NULL
             AND s.status = 'paid'
             AND s.from_user_id = $1
             AND s.group_id IN (${placeholders})
           UNION ALL
           SELECT s.group_id, s.from_user_id AS other_user_id, -s.amount AS delta
           FROM settlements s
           WHERE s.deleted_at IS NULL
             AND s.status = 'paid'
             AND s.to_user_id = $1
             AND s.group_id IN (${placeholders})
         ),
         pair_net AS (
           SELECT group_id, other_user_id, SUM(delta) AS net
           FROM pair_deltas
           GROUP BY group_id, other_user_id
         )
         SELECT group_id,
                COALESCE(SUM(net), 0)                  AS my_balance,
                COALESCE(SUM(GREATEST(net, 0)), 0)     AS you_are_owed_in_group,
                COALESCE(SUM(GREATEST(-net, 0)), 0)    AS you_owe_in_group
         FROM pair_net
         GROUP BY group_id`,
        [userId, ...groupIds]
      );
      for (const row of balanceResult.rows) {
        balancesByGroup[row.group_id] = {
          myBalance: parseFloat(row.my_balance),
          youAreOwedInGroup: parseFloat(row.you_are_owed_in_group),
          youOweInGroup: parseFloat(row.you_owe_in_group),
        };
      }
    }

    const groupsWithMembers = groups.map(group => {
      const members = membersByGroup[group.id] || [];
      const transformedMembers = members.map(member => ({
        userId: member.user_id,
        name: member.name,
        phoneNumber: member.phone_number,
        email: member.email,
        profileImageBase64: member.profile_image_base64 || null,
        role: member.role,
        joinedAt: member.joined_at,
        addedBy: member.added_by,
        isPlaceholder: member.is_placeholder || false,
      }));

      const bal = balancesByGroup[group.id] || {
        myBalance: 0,
        youAreOwedInGroup: 0,
        youOweInGroup: 0,
      };
      return {
        id: group.id,
        name: group.name,
        description: group.description,
        currency: group.currency,
        coverImageBase64: group.cover_image_base64 || null,
        createdBy: group.created_by,
        createdAt: group.created_at,
        updatedAt: group.updated_at,
        isArchived: !!group.is_archived,
        memberCount: parseInt(group.member_count) || 0,
        expenseCount: parseInt(group.expense_count) || 0,
        totalExpenses: parseFloat(group.total_expenses) || 0,
        myBalance: bal.myBalance,
        // Pair-level aggregates so the "You're owed" / "You owe" detail
        // screens can list this group even when myBalance net is positive.
        youAreOwedInGroup: bal.youAreOwedInGroup,
        youOweInGroup: bal.youOweInGroup,
        members: transformedMembers,
      };
    });

    res.json({
      success: true,
      data: groupsWithMembers,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        hasMore: groups.length === parseInt(limit),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get single group with details
 * GET /api/v1/groups/:id
 */
const getGroup = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user has access
    await GroupService.validateGroupAccess(id, req.user.id);

    // Fetch group (with cover image), members, and balances in parallel
    const [group, members, balances] = await Promise.all([
      Group.findByIdFull(id),
      Group.getMembers(id),
      GroupService.calculateBalances(id),
    ]);

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      });
    }

    // Transform members to camelCase format for frontend compatibility
    const transformedMembers = members.map(member => ({
      userId: member.user_id,
      name: member.name,
      phoneNumber: member.phone_number,
      email: member.email,
      profileImageBase64: member.profile_image_base64 || null,
      role: member.role,
      joinedAt: member.joined_at,
      addedBy: member.added_by,
      isPlaceholder: member.is_placeholder || false,
    }));

    res.json({
      success: true,
      data: {
        id: group.id,
        name: group.name,
        description: group.description,
        currency: group.currency,
        createdBy: group.created_by,
        coverImageBase64: group.cover_image_base64,
        createdAt: group.created_at,
        updatedAt: group.updated_at,
        isArchived: !!group.is_archived,
        memberCount: parseInt(group.member_count) || 0,
        expenseCount: parseInt(group.expense_count) || 0,
        totalExpenses: parseFloat(group.total_expenses) || 0,
        members: transformedMembers,
        balances,
      },
    });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Create new group
 * POST /api/v1/groups
 */
const createGroup = async (req, res, next) => {
  try {
    const { name, description, coverImageBase64, currency, members } = req.body;

    const group = await Group.create(
      {
        name,
        description,
        coverImageBase64,
        currency,
        createdBy: req.user.id,
      },
      members
    );

    // Log activity
    await ActivityService.logGroupCreated(group.id, req.user.id, name);

    // Push notify each added (registered) member that they were added to a new
    // group. Mirrors addGroupMember — placeholder / phone-only members (no
    // userId) and the creator are skipped. Non-fatal: a notification failure
    // must not fail group creation.
    if (Array.isArray(members) && members.length > 0) {
      try {
        const inviter = await User.findById(req.user.id);
        const inviterName = inviter?.name || 'Someone';
        await Promise.all(
          members
            .filter(m => m.userId && m.userId !== req.user.id)
            .map(m =>
              NotificationService.notifyGroupInvite(
                m.userId,
                group.id,
                name,
                inviterName,
              ).catch(err =>
                console.error('[GroupController] create-notify failed:', err)
              )
            )
        );
      } catch (notifError) {
        console.error('[GroupController] create-notify failed:', notifError);
      }
    }

    res.status(201).json({
      success: true,
      message: 'Group created successfully',
      data: group,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update group
 * PUT /api/v1/groups/:id
 */
const updateGroup = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name, description, coverImageBase64, currency } = req.body;

    // Verify user is admin
    await GroupService.validateAdminAccess(id, req.user.id);

    const group = await Group.update(id, {
      name,
      description,
      coverImageBase64,
      currency,
    });

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      });
    }

    // Log activity
    const changes = { name, description };
    await ActivityService.logGroupUpdated(id, req.user.id, group.name, changes);

    res.json({
      success: true,
      message: 'Group updated successfully',
      data: group,
    });
  } catch (error) {
    if (error.message === 'User is not an admin of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Delete group
 * DELETE /api/v1/groups/:id
 */
const deleteGroup = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user is admin
    await GroupService.validateAdminAccess(id, req.user.id);

    // Get group details before deletion for activity log
    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      });
    }

    // Block delete unless every pair is settled.
    const outstanding = await GroupService.calculateBalances(id);
    if (outstanding && outstanding.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Cannot delete group with unsettled balances. Settle all dues first.',
      });
    }

    const deleted = await Group.delete(id);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      });
    }

    // Log activity
    await ActivityService.logGroupDeleted(id, req.user.id, group.name);

    res.json({
      success: true,
      message: 'Group deleted successfully',
    });
  } catch (error) {
    if (error.message === 'User is not an admin of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Get group members
 * GET /api/v1/groups/:id/members
 */
const getGroupMembers = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user has access
    await GroupService.validateGroupAccess(id, req.user.id);

    const members = await Group.getMembers(id);

    res.json({
      success: true,
      data: members,
    });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Add member to group
 * POST /api/v1/groups/:id/members
 */
const addGroupMember = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { userId, name, phoneNumber, email } = req.body;

    // Verify user is member (members can invite others)
    await GroupService.validateGroupAccess(id, req.user.id);

    // Get group name for activity log
    const group = await Group.findById(id);

    const member = await Group.addMember(id, {
      userId,
      name,
      phoneNumber,
      email,
      addedBy: req.user.id,
    });

    // Log activity
    await ActivityService.logMemberAdded(id, req.user.id, group.name, name);

    // Push notify the newly-added user that they've been invited.
    // Only fires when we have a userId (i.e. a real registered user, not
    // a placeholder added by phone/email alone).
    if (userId && userId !== req.user.id) {
      try {
        const inviter = await User.findById(req.user.id);
        await NotificationService.notifyGroupInvite(
          userId,
          id,
          group.name,
          inviter?.name || 'Someone',
        );
      } catch (notifError) {
        console.error('[GroupController] notify failed:', notifError);
      }
    }

    res.status(201).json({
      success: true,
      message: 'Member added successfully',
      data: member,
    });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Add pending member to group (non-registered user)
 * Creates a placeholder user and adds them to the group as a member
 * Sends WhatsApp invite via WATI
 * POST /api/v1/groups/:id/pending-members
 */
const addPendingMember = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name, phoneNumber, email } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        error: 'Phone number is required',
      });
    }

    if (!name) {
      return res.status(400).json({
        success: false,
        error: 'Name is required',
      });
    }

    // Verify user is member (members can invite others)
    await GroupService.validateGroupAccess(id, req.user.id);

    // Fetch group and inviter in parallel (was 2 sequential queries)
    const [group, inviter] = await Promise.all([
      Group.findById(id),
      User.findById(req.user.id),
    ]);
    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      });
    }
    const inviterName = inviter?.name || 'A friend';

    // Normalize phone number
    const normalizedPhone = phoneNumber.replace(/\D/g, '');
    const formattedPhone = normalizedPhone.length === 10 ? `+91${normalizedPhone}` : phoneNumber;

    // Check if user is already registered (non-placeholder)
    const existingUser = await User.findByPhone(formattedPhone);
    if (existingUser && !existingUser.is_placeholder) {
      // User is registered, add them directly
      try {
        const member = await Group.addMember(id, {
          userId: existingUser.id,
          name: existingUser.name,
          phoneNumber: existingUser.phone_number,
          email: existingUser.email,
          addedBy: req.user.id,
        });

        // Log activity
        await ActivityService.logMemberAdded(id, req.user.id, group.name, existingUser.name);

        return res.status(201).json({
          success: true,
          message: 'Member added successfully (user was already registered)',
          data: {
            type: 'registered',
            member,
          },
        });
      } catch (memberError) {
        if (memberError.message === 'User is already a member of this group') {
          return res.status(400).json({
            success: false,
            error: 'User is already a member of this group',
          });
        }
        throw memberError;
      }
    }

    // Check if already has pending invite
    const hasPending = await Group.hasPendingInvite(id, formattedPhone);

    // Create or get placeholder user
    let placeholderUser;
    if (existingUser && existingUser.is_placeholder) {
      // Use existing placeholder user
      placeholderUser = existingUser;
    } else {
      // Create new placeholder user
      placeholderUser = await User.createPlaceholder({
        phoneNumber: formattedPhone,
        name,
        email: email || null,
      });
      console.log(`[GroupController] Created placeholder user: ${placeholderUser.id} for ${formattedPhone}`);
    }

    // Add placeholder user to group as a member (if not already a member)
    let memberAdded = false;
    try {
      await Group.addMember(id, {
        userId: placeholderUser.id,
        name: placeholderUser.name,
        phoneNumber: placeholderUser.phone_number,
        email: placeholderUser.email,
        addedBy: req.user.id,
      });
      memberAdded = true;
      console.log(`[GroupController] Added placeholder user ${placeholderUser.id} to group ${id}`);
    } catch (memberError) {
      if (memberError.message === 'User is already a member of this group') {
        console.log(`[GroupController] Placeholder user ${placeholderUser.id} already in group ${id}`);
      } else {
        throw memberError;
      }
    }

    // Send WATI WhatsApp invite
    let watiResult = { success: false, error: 'WATI not configured' };
    if (WatiService.isConfigured()) {
      console.log(`[GroupController] Sending WATI invite to ${formattedPhone} for group ${group.name}`);
      watiResult = await WatiService.sendInviteMessage(
        formattedPhone,
        name,
        inviterName,
        group.name
      );
      console.log('[GroupController] WATI result:', watiResult);
    } else {
      console.warn('[GroupController] WATI not configured, skipping WhatsApp invite');
    }

    // Create pending invite record (for tracking and resend capability)
    const pendingInvite = await Group.addPendingInvite(id, {
      phoneNumber: formattedPhone,
      name,
      email: email || null,
      invitedBy: req.user.id,
      watiMessageId: watiResult.messageId || null,
      watiStatus: watiResult.success ? 'sent' : 'failed',
    });

    // Log activity
    await ActivityService.logMemberAdded(id, req.user.id, group.name, `${name} (pending)`);

    // The pending member is in the group either way — but be honest about
    // whether WhatsApp delivery actually went out, so the UI doesn't claim
    // success when WATI silently dropped the message.
    const inviteMessage = watiResult.success
      ? (hasPending
          ? 'Invite resent via WhatsApp'
          : 'Member added and WhatsApp invite sent')
      : (hasPending
          ? `Member kept in group, but WhatsApp resend failed: ${watiResult.error || 'unknown error'}`
          : `Member added, but WhatsApp invite failed: ${watiResult.error || 'unknown error'}`);
    res.status(201).json({
      success: true,
      message: inviteMessage,
      data: {
        type: 'placeholder',
        member: {
          userId: placeholderUser.id,
          name: placeholderUser.name,
          phoneNumber: placeholderUser.phone_number,
          email: placeholderUser.email,
          isPlaceholder: true,
        },
        pendingInvite: {
          id: pendingInvite.id,
          phoneNumber: pendingInvite.phone_number,
          name: pendingInvite.name,
          email: pendingInvite.email,
          inviteCount: pendingInvite.invite_count,
          watiStatus: pendingInvite.wati_status,
          createdAt: pendingInvite.created_at,
        },
        watiResult: {
          success: watiResult.success,
          error: watiResult.error || null,
        },
      },
    });
  } catch (error) {
    console.error('[GroupController] Error adding pending member:', error);
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Get pending invites for a group
 * GET /api/v1/groups/:id/pending-members
 */
const getPendingMembers = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user has access
    await GroupService.validateGroupAccess(id, req.user.id);

    const pendingInvites = await Group.getPendingInvites(id);

    // Transform to camelCase
    const transformedInvites = pendingInvites.map(invite => ({
      id: invite.id,
      phoneNumber: invite.phone_number,
      name: invite.name,
      email: invite.email,
      invitedBy: invite.invited_by,
      inviterName: invite.inviter_name,
      watiStatus: invite.wati_status,
      watiError: invite.wati_error,
      inviteCount: invite.invite_count,
      lastInvitedAt: invite.last_invited_at,
      createdAt: invite.created_at,
    }));

    res.json({
      success: true,
      data: transformedInvites,
    });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Resend WATI invite to pending member
 * POST /api/v1/groups/:id/pending-members/:phoneNumber/resend
 */
const resendPendingInvite = async (req, res, next) => {
  try {
    const { id, phoneNumber } = req.params;

    // Verify user has access
    await GroupService.validateGroupAccess(id, req.user.id);

    // Fetch group, inviter, and pending invites in parallel (was 3 sequential queries)
    const [group, inviter, pendingInvites] = await Promise.all([
      Group.findById(id),
      User.findById(req.user.id),
      Group.getPendingInvites(id),
    ]);
    const inviterName = inviter?.name || 'A friend';
    const pendingInvite = pendingInvites.find(
      p => p.phone_number === phoneNumber || p.phone_number === `+91${phoneNumber.replace(/\D/g, '')}`
    );

    if (!pendingInvite) {
      return res.status(404).json({
        success: false,
        error: 'Pending invite not found',
      });
    }

    // Resend WATI invite
    let watiResult = { success: false, error: 'WATI not configured' };
    if (WatiService.isConfigured()) {
      watiResult = await WatiService.sendInviteMessage(
        pendingInvite.phone_number,
        pendingInvite.name,
        inviterName,
        group.name
      );
    }

    // Update pending invite
    await Group.addPendingInvite(id, {
      phoneNumber: pendingInvite.phone_number,
      name: pendingInvite.name,
      email: pendingInvite.email,
      invitedBy: req.user.id,
      watiMessageId: watiResult.messageId || null,
      watiStatus: watiResult.success ? 'sent' : 'failed',
    });

    res.json({
      success: true,
      message: 'Invite resent successfully',
      data: {
        watiResult: {
          success: watiResult.success,
          error: watiResult.error || null,
        },
      },
    });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Remove pending member from group
 * DELETE /api/v1/groups/:id/pending-members/:phoneNumber
 */
const removePendingMember = async (req, res, next) => {
  try {
    const { id, phoneNumber } = req.params;

    // Verify user has access
    await GroupService.validateGroupAccess(id, req.user.id);

    // Format phone number
    const formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : `+91${phoneNumber.replace(/\D/g, '')}`;

    const deleted = await Group.deletePendingInviteByPhone(id, formattedPhone);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Pending invite not found',
      });
    }

    res.json({
      success: true,
      message: 'Pending invite removed successfully',
    });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Remove member from group
 * DELETE /api/v1/groups/:id/members/:userId
 */
const removeGroupMember = async (req, res, next) => {
  try {
    const { id, userId } = req.params;

    // Allow users to remove themselves (leave group) without being admin
    // For removing others, require admin access
    const isRemovingSelf = req.user.id === userId;

    if (!isRemovingSelf) {
      // Verify user is admin to remove others
      await GroupService.validateAdminAccess(id, req.user.id);
    } else {
      // For leaving, just verify user is a member
      await GroupService.validateGroupAccess(id, req.user.id);

      // Block leave unless all pairwise debts with other members are settled.
      const pair = await GroupService.getUserPairwiseDebts(id, req.user.id);
      const unsettled = [...pair.values()].some(v => Math.abs(v) > 0.005);
      if (unsettled) {
        return res.status(409).json({
          success: false,
          error: 'You must settle all balances before leaving the group.',
        });
      }
    }

    // Fetch group and members in parallel (was 2 sequential queries)
    const [group, members] = await Promise.all([
      Group.findById(id),
      Group.getMembers(id),
    ]);
    const member = members.find(m => m.user_id === userId);

    // Admin-removing-another path: data-integrity gate. Soft-deleting a
    // member with unsettled splits would leave phantom debt in the
    // balance computation (the split rows still reference them, but the
    // member list filters them out — UI can never settle the debt).
    //
    // Two-step protocol:
    //   1. First call → if unsettled, return 409 with structured debt
    //      list so the client can show a "write off and remove" prompt.
    //   2. Second call sets acknowledgeUnsettledDebt:true → we create
    //      completed write-off settlements for each pair, zeroing the
    //      member's balance, before soft-deleting the membership.
    let writeOffPairs = [];
    if (!isRemovingSelf) {
      const pair = await GroupService.getUserPairwiseDebts(id, userId);
      writeOffPairs = [...pair.entries()]
        .filter(([, amt]) => Math.abs(amt) > 0.005)
        .map(([otherUserId, amount]) => ({ otherUserId, amount }));

      const acknowledged = req.body?.acknowledgeUnsettledDebt === true;
      if (writeOffPairs.length > 0 && !acknowledged) {
        // Resolve names for the UI so it doesn't have to re-fetch.
        const named = writeOffPairs.map(p => {
          const other = members.find(m => m.user_id === p.otherUserId);
          return {
            userId: p.otherUserId,
            userName: other?.name || 'Unknown',
            // Sign convention matches getUserPairwiseDebts:
            // amount > 0 → the member being removed owes that party.
            // amount < 0 → that party owes the member being removed.
            amount: Number(p.amount.toFixed(2)),
          };
        });
        return res.status(409).json({
          success: false,
          error: 'Member has unsettled balances',
          code: 'UNSETTLED_BALANCES',
          data: {
            memberId: userId,
            memberName: member?.name || 'Member',
            pairwise: named,
            currency: group?.currency_code || 'INR',
          },
        });
      }

      // Acknowledged path — create write-off settlements before delete.
      // Status is 'completed' so the balance compute treats them as
      // already settled; notes carry an audit trail.
      for (const p of writeOffPairs) {
        const amount = Math.abs(p.amount);
        const fromUserId = p.amount > 0 ? userId : p.otherUserId;
        const toUserId = p.amount > 0 ? p.otherUserId : userId;
        await Settlement.create({
          groupId: id,
          fromUserId,
          toUserId,
          amount,
          currency: group?.currency_code || 'INR',
          status: 'completed',
          notes: `Written off — ${member?.name || 'member'} removed by admin`,
        });
      }
    }

    const removed = await Group.removeMember(id, userId);

    if (!removed) {
      return res.status(404).json({
        success: false,
        error: 'Member not found',
      });
    }

    // Log activity
    if (member) {
      await ActivityService.logMemberRemoved(id, req.user.id, group.name, member.name);
    }

    // Send push notification
    try {
      if (isRemovingSelf) {
        // User left the group - notify other members
        await NotificationService.notifyMemberLeft(id, group.name, userId, member?.name || 'A member');
      } else {
        // User was removed - notify the removed user and other members
        await NotificationService.notifyMemberRemoved(id, group.name, userId, member?.name || 'A member', req.user.id);
      }
    } catch (notifError) {
      console.error('[GroupController] Error sending member removal notification:', notifError);
      // Don't fail the request if notification fails
    }

    res.json({
      success: true,
      message: isRemovingSelf ? 'Successfully left the group' : 'Member removed successfully',
    });
  } catch (error) {
    if (error.message === 'User is not an admin of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Update member role
 * PUT /api/v1/groups/:id/members/:userId
 */
const updateMemberRole = async (req, res, next) => {
  try {
    const { id, userId } = req.params;
    const { role } = req.body;

    // Verify user is admin
    await GroupService.validateAdminAccess(id, req.user.id);

    if (!['admin', 'member'].includes(role)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid role. Must be "admin" or "member"',
      });
    }

    const member = await Group.updateMemberRole(id, userId, role);

    if (!member) {
      return res.status(404).json({
        success: false,
        error: 'Member not found',
      });
    }

    res.json({
      success: true,
      message: 'Member role updated successfully',
      data: member,
    });
  } catch (error) {
    if (error.message === 'User is not an admin of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Archive group
 * PUT /api/v1/groups/:id/archive
 */
const archiveGroup = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user is admin
    await GroupService.validateAdminAccess(id, req.user.id);

    // Get group details before archiving for activity log
    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      });
    }

    const archived = await Group.archive(id);

    if (!archived) {
      return res.status(404).json({
        success: false,
        error: 'Group not found or already archived',
      });
    }

    // Log activity
    await ActivityService.logGroupArchived(id, req.user.id, group.name);

    // Send push notification to group members
    try {
      await NotificationService.notifyGroupArchived(id, group.name, req.user.id);
    } catch (notifError) {
      console.error('[GroupController] Error sending archive notification:', notifError);
    }

    res.json({
      success: true,
      message: 'Group archived successfully',
    });
  } catch (error) {
    if (error.message === 'User is not an admin of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Unarchive group
 * PUT /api/v1/groups/:id/unarchive
 */
const unarchiveGroup = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user is admin
    await GroupService.validateAdminAccess(id, req.user.id);

    const unarchived = await Group.unarchive(id);

    if (!unarchived) {
      return res.status(404).json({
        success: false,
        error: 'Group not found or not archived',
      });
    }

    res.json({
      success: true,
      message: 'Group unarchived successfully',
    });
  } catch (error) {
    if (error.message === 'User is not an admin of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Complete group (archive with completion status)
 * PUT /api/v1/groups/:id/complete
 */
const completeGroup = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user is admin
    await GroupService.validateAdminAccess(id, req.user.id);

    // Get group details before completing for activity log
    const group = await Group.findById(id);

    if (!group) {
      return res.status(404).json({
        success: false,
        error: 'Group not found',
      });
    }

    const completed = await Group.archive(id);

    if (!completed) {
      return res.status(404).json({
        success: false,
        error: 'Group not found or already completed',
      });
    }

    // Log activity
    await ActivityService.logGroupArchived(id, req.user.id, group.name);

    // Send push notification to group members
    try {
      await NotificationService.notifyGroupCompleted(id, group.name, req.user.id);
    } catch (notifError) {
      console.error('[GroupController] Error sending complete notification:', notifError);
    }

    res.json({
      success: true,
      message: 'Group completed successfully',
    });
  } catch (error) {
    if (error.message === 'User is not an admin of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Send a settlement reminder push to a member who owes the caller money in
 * this group.
 *
 * POST /api/v1/groups/:groupId/remind/:userId
 *
 * Rules:
 *   - Caller must be a member of the group.
 *   - Target must be a different member of the group.
 *   - Target must currently owe the caller > 0.01 in the group's pairwise
 *     debt math. Self-reminders + reminders for settled debts are 400.
 *   - Soft rate limit — at most one reminder per (caller, target, group)
 *     every 6 hours, to keep this from being a nag-spam vector.
 *
 * Side effects:
 *   - SETTLEMENT_REMINDER push sent to target (gated by their notif prefs).
 *   - One row inserted into `notifications` (the persistent inbox).
 */
const remindForBalance = async (req, res, next) => {
  try {
    const { id: groupId, userId: targetId } = req.params;
    const callerId = req.user.id;

    if (callerId === targetId) {
      return res.status(400).json({
        success: false,
        error: "You can't remind yourself.",
      });
    }

    // Caller must be in the group.
    await GroupService.validateGroupAccess(groupId, callerId);

    // Target must also be a member — silently 404 if not (avoids leaking
    // group membership to outsiders by error-message inference).
    const targetIsMember = await Group.isMember(groupId, targetId);
    if (!targetIsMember) {
      return res.status(404).json({
        success: false,
        error: 'Member not found in this group',
      });
    }

    // Pairwise from caller's perspective:
    //   pair[targetId] > 0  → caller owes target (don't remind)
    //   pair[targetId] < 0  → target owes caller |that much|
    const pair = await GroupService.getUserPairwiseDebts(groupId, callerId);
    const owedToCaller = -(pair.get(targetId) || 0);
    if (owedToCaller <= 0.01) {
      return res.status(400).json({
        success: false,
        error: 'No outstanding balance to remind about.',
      });
    }

    // Soft rate limit — last reminder for this exact (caller, target, group)
    // must be older than 6 hours.
    const recent = await query(
      `SELECT created_at FROM notifications
       WHERE user_id = $1
         AND type = 'SETTLEMENT_REMINDER'
         AND data->>'fromUserId' = $2
         AND data->>'groupId' = $3
         AND created_at > NOW() - INTERVAL '6 hours'
       ORDER BY created_at DESC
       LIMIT 1`,
      [targetId, callerId, groupId],
    );
    if (recent.rows.length > 0) {
      return res.status(429).json({
        success: false,
        error: "You've already reminded this person in the last 6 hours.",
      });
    }

    const group = await Group.findById(groupId);
    const caller = await User.findById(callerId);

    // Pre-rounded amount so the body string + activity log agree.
    const amount = owedToCaller.toFixed(2);
    const currency = group?.currency || 'INR';

    await NotificationService.sendToUser(targetId, 'SETTLEMENT_REMINDER', {
      amount,
      currency,
      groupName: group?.name || 'this group',
    }, {
      groupId,
      fromUserId: callerId,
      fromUserName: caller?.name || 'A group member',
    });

    res.json({
      success: true,
      message: `Reminder sent to ${targetId}`,
    });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({
        success: false,
        error: error.message,
      });
    }
    next(error);
  }
};

/**
 * Email-invite fallback (used when WhatsApp / WATI delivery isn't viable —
 * e.g. WABA billing or BSP issues). Sends a "you were added to <group> by
 * <inviter>" email via SMTP with install links to the Play Store / App Store.
 *
 * This intentionally does NOT add anyone to the group, because most early
 * recipients are pre-registration. The caller can still use the existing
 * /pending-members WATI flow when they know the recipient's phone.
 *
 * POST /api/v1/groups/:id/invite-email
 * Body: { email: string, name?: string }
 */
const inviteByEmail = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { email, name } = req.body || {};

    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return res.status(400).json({
        success: false,
        error: 'A valid email address is required',
      });
    }

    // Caller must be in the group (matches the WATI invite flow's gating).
    await GroupService.validateGroupAccess(id, req.user.id);

    const [group, inviter] = await Promise.all([
      Group.findById(id),
      User.findById(req.user.id),
    ]);
    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' });
    }

    if (!EmailService.isConfigured()) {
      return res.status(503).json({
        success: false,
        error: 'Email service not configured on the server (SMTP env vars missing).',
      });
    }

    const result = await EmailService.sendInviteEmail({
      toEmail: email.trim(),
      recipientName: (name || '').trim() || email.split('@')[0],
      inviterName: inviter?.name || 'A friend',
      groupName: group.name || 'a KharchaSplit group',
    });

    if (!result.success) {
      return res.status(502).json({
        success: false,
        error: result.error || 'Email could not be sent',
      });
    }

    return res.status(200).json({
      success: true,
      message: `Invite email sent to ${email.trim()}`,
      data: { messageId: result.messageId },
    });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({ success: false, error: error.message });
    }
    next(error);
  }
};


// ---------------------------------------------------------------------------
// Export group ledger as .xlsx
// ---------------------------------------------------------------------------

/**
 * GET /api/v1/groups/:id/export
 *
 * Builds a multi-sheet workbook (Summary, Members, Expenses, Pairwise debts,
 * Settlements) and streams it back as application/vnd.openxmlformats. Any
 * group member can export; the file represents the group ledger from their
 * perspective (member identity is included so the receiver can audit).
 *
 * The workbook is small (typically <100KB even for hundreds of expenses) so
 * we buffer it in memory before writing — no streaming complexity needed at
 * KharchaSplit's scale.
 */
const exportGroup = async (req, res, next) => {
  try {
    const { id } = req.params;
    await GroupService.validateGroupAccess(id, req.user.id);

    const group = await Group.findByIdFull(id);
    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' });
    }

    const members = await Group.getMembers(id);

    const expensesResult = await query(
      `SELECT e.id, e.description, e.amount, e.currency, e.category,
              e.paid_by, e.split_type, e.notes, e.expense_date, e.created_at,
              u.name AS paid_by_name
       FROM expenses e
       LEFT JOIN users u ON u.id = e.paid_by
       WHERE e.group_id = $1 AND e.deleted_at IS NULL
       ORDER BY e.expense_date DESC, e.created_at DESC`,
      [id]
    );
    const expenses = expensesResult.rows;
    const expenseIds = expenses.map(e => e.id);

    const splitsByExpense = {};
    if (expenseIds.length > 0) {
      const splitsResult = await query(
        `SELECT es.expense_id, es.user_id, es.amount, es.percentage, es.shares,
                u.name AS user_name
         FROM expense_splits es
         LEFT JOIN users u ON u.id = es.user_id
         WHERE es.expense_id = ANY($1::uuid[]) AND es.deleted_at IS NULL
         ORDER BY es.amount DESC`,
        [expenseIds]
      );
      for (const s of splitsResult.rows) {
        if (!splitsByExpense[s.expense_id]) splitsByExpense[s.expense_id] = [];
        splitsByExpense[s.expense_id].push(s);
      }
    }

    const settlementsResult = await query(
      `SELECT s.id, s.from_user_id, s.to_user_id, s.amount, s.currency,
              s.status, s.notes, s.settled_at, s.created_at, s.confirmed_at,
              fu.name AS from_name, tu.name AS to_name
       FROM settlements s
       LEFT JOIN users fu ON fu.id = s.from_user_id
       LEFT JOIN users tu ON tu.id = s.to_user_id
       WHERE s.group_id = $1 AND s.deleted_at IS NULL
       ORDER BY s.created_at DESC`,
      [id]
    );
    const settlements = settlementsResult.rows;

    // Per-member totals (paid + share) — derived from expense rows.
    const memberTotals = new Map();
    const ensureMember = (uid, name) => {
      if (!memberTotals.has(uid)) {
        memberTotals.set(uid, { name: name || 'Unknown', paid: 0, share: 0 });
      } else if (name && memberTotals.get(uid).name === 'Unknown') {
        memberTotals.get(uid).name = name;
      }
      return memberTotals.get(uid);
    };
    for (const m of members) ensureMember(m.user_id, m.name);
    for (const e of expenses) {
      const m = ensureMember(e.paid_by, e.paid_by_name);
      m.paid += parseFloat(e.amount);
      for (const s of splitsByExpense[e.id] || []) {
        const mm = ensureMember(s.user_id, s.user_name);
        mm.share += parseFloat(s.amount);
      }
    }

    // Pairwise net debts among all members (positive net = row owes column).
    // O(n*m) over expenses+splits — fine for any realistic group.
    const pairwise = new Map(); // key = `${ower}__${owed}`
    const addPair = (ower, owed, amount) => {
      if (!ower || !owed || ower === owed) return;
      const key = `${ower}__${owed}`;
      pairwise.set(key, (pairwise.get(key) || 0) + amount);
    };
    for (const e of expenses) {
      const payer = e.paid_by;
      for (const s of splitsByExpense[e.id] || []) {
        if (s.user_id !== payer) addPair(s.user_id, payer, parseFloat(s.amount));
      }
    }
    for (const st of settlements) {
      if (st.status !== 'paid') continue;
      // from_user paid to to_user → from owes less / to is owed less
      addPair(st.from_user_id, st.to_user_id, -parseFloat(st.amount));
    }
    // Collapse symmetric pairs into one net edge.
    const seen = new Set();
    const netDebts = [];
    for (const [key, amount] of pairwise.entries()) {
      const [a, b] = key.split('__');
      const reverseKey = `${b}__${a}`;
      if (seen.has(key) || seen.has(reverseKey)) continue;
      const reverse = pairwise.get(reverseKey) || 0;
      const net = amount - reverse;
      seen.add(key);
      seen.add(reverseKey);
      if (Math.abs(net) < 0.005) continue;
      const nameOf = (uid) => memberTotals.get(uid)?.name || 'Unknown';
      if (net > 0) {
        netDebts.push({ from: nameOf(a), to: nameOf(b), amount: net });
      } else {
        netDebts.push({ from: nameOf(b), to: nameOf(a), amount: -net });
      }
    }
    netDebts.sort((a, b) => b.amount - a.amount);

    // Build workbook ---------------------------------------------------------
    const wb = new ExcelJS.Workbook();
    wb.creator = 'KharchaSplit';
    wb.created = new Date();

    const headerStyle = {
      font: { bold: true, color: { argb: 'FFFFFFFF' } },
      fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E78' } },
      alignment: { vertical: 'middle', horizontal: 'left' },
    };
    const applyHeader = (row) => {
      row.eachCell((cell) => {
        cell.font = headerStyle.font;
        cell.fill = headerStyle.fill;
        cell.alignment = headerStyle.alignment;
        cell.border = {
          top: { style: 'thin', color: { argb: 'FFBFBFBF' } },
          bottom: { style: 'thin', color: { argb: 'FFBFBFBF' } },
          left: { style: 'thin', color: { argb: 'FFBFBFBF' } },
          right: { style: 'thin', color: { argb: 'FFBFBFBF' } },
        };
      });
      row.height = 22;
    };

    // ---------- Summary sheet ----------
    const summary = wb.addWorksheet('Summary');
    summary.columns = [
      { width: 28 },
      { width: 45 },
    ];
    summary.addRow(['KharchaSplit Group Export']).font = { bold: true, size: 16 };
    summary.addRow([]);
    const totalExpenseAmt = expenses.reduce((sum, e) => sum + parseFloat(e.amount), 0);
    const summaryRows = [
      ['Group Name', group.name],
      ['Description', group.description || '—'],
      ['Currency', group.currency || 'INR'],
      ['Created At', group.created_at],
      ['Total Members', members.length],
      ['Total Expenses', expenses.length],
      ['Total Expense Amount', totalExpenseAmt],
      ['Total Settlements', settlements.length],
      ['Exported By', req.user.name],
      ['Exported At', new Date()],
    ];
    for (const [k, v] of summaryRows) {
      const row = summary.addRow([k, v]);
      row.getCell(1).font = { bold: true };
      row.getCell(1).fill = {
        type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFDDEBF7' },
      };
    }

    // ---------- Members sheet ----------
    const memberSheet = wb.addWorksheet('Members');
    memberSheet.columns = [
      { header: 'Name', key: 'name', width: 28 },
      { header: 'Phone', key: 'phone', width: 20 },
      { header: 'Email', key: 'email', width: 30 },
      { header: 'Role', key: 'role', width: 14 },
      { header: 'Total Paid', key: 'paid', width: 16 },
      { header: 'Total Share', key: 'share', width: 16 },
      { header: 'Net Position', key: 'net', width: 16 },
    ];
    applyHeader(memberSheet.getRow(1));
    for (const m of members) {
      const totals = memberTotals.get(m.user_id) || { paid: 0, share: 0 };
      const net = totals.paid - totals.share;
      memberSheet.addRow({
        name: m.name,
        phone: m.phone_number || '—',
        email: m.email || '—',
        role: m.role,
        paid: +totals.paid.toFixed(2),
        share: +totals.share.toFixed(2),
        net: +net.toFixed(2),
      });
    }
    memberSheet.getColumn('paid').numFmt = '#,##0.00';
    memberSheet.getColumn('share').numFmt = '#,##0.00';
    memberSheet.getColumn('net').numFmt = '#,##0.00';

    // ---------- Expenses sheet ----------
    const expSheet = wb.addWorksheet('Expenses');
    expSheet.columns = [
      { header: 'Date', key: 'date', width: 12 },
      { header: 'Description', key: 'desc', width: 35 },
      { header: 'Category', key: 'cat', width: 14 },
      { header: 'Amount', key: 'amount', width: 12 },
      { header: 'Currency', key: 'curr', width: 10 },
      { header: 'Paid By', key: 'payer', width: 22 },
      { header: 'Split Type', key: 'splitType', width: 12 },
      { header: 'Participants & Shares', key: 'participants', width: 50 },
      { header: 'Notes', key: 'notes', width: 28 },
    ];
    applyHeader(expSheet.getRow(1));
    for (const e of expenses) {
      const parts = (splitsByExpense[e.id] || [])
        .map(s => `${s.user_name || 'Unknown'}: ${parseFloat(s.amount).toFixed(2)}`)
        .join('; ');
      const row = expSheet.addRow({
        date: e.expense_date ? new Date(e.expense_date) : null,
        desc: e.description,
        cat: e.category || '—',
        amount: parseFloat(e.amount),
        curr: e.currency || 'INR',
        payer: e.paid_by_name || 'Unknown',
        splitType: e.split_type || 'equal',
        participants: parts,
        notes: e.notes || '',
      });
      row.getCell('amount').numFmt = '#,##0.00';
      row.getCell('date').numFmt = 'yyyy-mm-dd';
      row.alignment = { wrapText: true, vertical: 'top' };
    }

    // ---------- Pairwise net debts ----------
    const debtSheet = wb.addWorksheet('Net Debts');
    debtSheet.columns = [
      { header: 'From (Owes)', key: 'from', width: 28 },
      { header: 'To (Receives)', key: 'to', width: 28 },
      { header: 'Amount', key: 'amount', width: 16 },
    ];
    applyHeader(debtSheet.getRow(1));
    if (netDebts.length === 0) {
      debtSheet.addRow({ from: 'All settled up — no outstanding debts', to: '', amount: '' });
    } else {
      for (const d of netDebts) {
        const r = debtSheet.addRow(d);
        r.getCell('amount').numFmt = '#,##0.00';
      }
    }

    // ---------- Settlements sheet ----------
    const setSheet = wb.addWorksheet('Settlements');
    setSheet.columns = [
      { header: 'Date', key: 'date', width: 12 },
      { header: 'From', key: 'from', width: 22 },
      { header: 'To', key: 'to', width: 22 },
      { header: 'Amount', key: 'amount', width: 14 },
      { header: 'Currency', key: 'curr', width: 10 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Confirmed At', key: 'confirmed', width: 18 },
      { header: 'Notes', key: 'notes', width: 28 },
    ];
    applyHeader(setSheet.getRow(1));
    if (settlements.length === 0) {
      setSheet.addRow({ from: 'No settlements yet' });
    } else {
      for (const s of settlements) {
        const r = setSheet.addRow({
          date: s.settled_at ? new Date(s.settled_at) : null,
          from: s.from_name || 'Unknown',
          to: s.to_name || 'Unknown',
          amount: parseFloat(s.amount),
          curr: s.currency || 'INR',
          status: s.status || 'pending',
          confirmed: s.confirmed_at ? new Date(s.confirmed_at) : null,
          notes: s.notes || '',
        });
        r.getCell('amount').numFmt = '#,##0.00';
        r.getCell('date').numFmt = 'yyyy-mm-dd';
        r.getCell('confirmed').numFmt = 'yyyy-mm-dd hh:mm';
      }
    }

    const buffer = await wb.xlsx.writeBuffer();

    const safeName = group.name.replace(/[^\w\-]+/g, '_').slice(0, 40) || 'group';
    const stamp = new Date().toISOString().slice(0, 10);
    const filename = `kharchasplit_${safeName}_${stamp}.xlsx`;

    res.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Length', buffer.byteLength);
    res.end(Buffer.from(buffer));
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({ success: false, error: error.message });
    }
    next(error);
  }
};

export default {
  getGroups,
  getGroup,
  createGroup,
  updateGroup,
  deleteGroup,
  getGroupMembers,
  addGroupMember,
  addPendingMember,
  getPendingMembers,
  resendPendingInvite,
  removePendingMember,
  removeGroupMember,
  updateMemberRole,
  archiveGroup,
  unarchiveGroup,
  completeGroup,
  remindForBalance,
  inviteByEmail,
  exportGroup,
};
