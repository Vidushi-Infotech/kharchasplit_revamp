import { query } from '../config/database.js';
import Group from '../models/Group.js';
import GroupService from '../services/groupService.js';
import ActivityService from '../services/activityService.js';
import { NotificationService } from '../services/notificationService.js';
import WatiService from '../services/watiService.js';
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

    // Net balance for the requesting user in each of these groups, in one query.
    // Positive = others owe me; negative = I owe others. Combines expense
    // contributions and settlement contributions so myBalance reflects
    // settled debts.
    const balancesByGroup = {};
    if (groupIds.length > 0) {
      const placeholders = groupIds.map((_, i) => `$${i + 2}`).join(', ');
      const balanceResult = await query(
        `SELECT group_id, COALESCE(SUM(contribution), 0) AS net FROM (
           SELECT e.group_id,
                  SUM(CASE
                    WHEN e.paid_by = $1 AND es.user_id != $1 THEN es.amount
                    WHEN e.paid_by != $1 AND es.user_id = $1 THEN -es.amount
                    ELSE 0
                  END) AS contribution
           FROM expenses e
           JOIN expense_splits es ON es.expense_id = e.id
           WHERE e.deleted_at IS NULL AND e.group_id IN (${placeholders})
           GROUP BY e.group_id
           UNION ALL
           SELECT s.group_id,
                  SUM(CASE
                    WHEN s.from_user_id = $1 THEN s.amount
                    WHEN s.to_user_id   = $1 THEN -s.amount
                    ELSE 0
                  END) AS contribution
           FROM settlements s
           WHERE s.deleted_at IS NULL
             AND (s.status IS NULL OR s.status NOT IN ('failed', 'cancelled'))
             AND s.group_id IN (${placeholders})
           GROUP BY s.group_id
         ) all_contributions
         GROUP BY group_id`,
        [userId, ...groupIds]
      );
      for (const row of balanceResult.rows) {
        balancesByGroup[row.group_id] = parseFloat(row.net);
      }
    }

    const groupsWithMembers = groups.map(group => {
      const members = membersByGroup[group.id] || [];
      const transformedMembers = members.map(member => ({
        userId: member.user_id,
        name: member.name,
        phoneNumber: member.phone_number,
        email: member.email,
        profileImage: member.profile_image_base64 || null,
        role: member.role,
        joinedAt: member.joined_at,
        addedBy: member.added_by,
        isPlaceholder: member.is_placeholder || false,
      }));

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
        myBalance: balancesByGroup[group.id] || 0,
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
      profileImage: member.profile_image_base64 || null,
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

    res.status(201).json({
      success: true,
      message: hasPending
        ? 'Invite resent successfully via WhatsApp'
        : 'Pending member added to group and WhatsApp invite sent',
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
};
