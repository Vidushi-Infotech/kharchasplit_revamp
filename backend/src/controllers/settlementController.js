import Settlement from '../models/Settlement.js';
import Group from '../models/Group.js';
import User from '../models/User.js';
import GroupService from '../services/groupService.js';
import ActivityService from '../services/activityService.js';
import { NotificationService } from '../services/notificationService.js';
import { cache } from '../services/cacheService.js';
import { query, transaction } from '../config/database.js';
import { currencySymbol } from '../utils/currency.js';
import { userPairNets, toPaise, fromPaise } from '../services/ledger.js';
import crypto from 'crypto';

/**
 * Get settlements for a group
 * GET /api/v1/settlements?groupId=:id
 */
const getSettlements = async (req, res, next) => {
  try {
    const { groupId, page = 1, limit = 50 } = req.query;

    if (!groupId) {
      return res.status(400).json({
        success: false,
        error: 'groupId query parameter is required',
      });
    }

    // Verify user has access
    await GroupService.validateGroupAccess(groupId, req.user.id);

    const offset = (page - 1) * limit;
    const [settlements, total] = await Promise.all([
      Settlement.findByGroupId(groupId, parseInt(limit), offset),
      Settlement.countByGroupId(groupId),
    ]);

    res.json({
      success: true,
      data: settlements,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        hasMore: offset + settlements.length < total,
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
 * Create new settlement
 * POST /api/v1/settlements
 */
const createSettlement = async (req, res, next) => {
  try {
    const { groupId, fromUserId, toUserId, amount, currency, notes, method, paidAt } = req.body;

    // Verify user has access
    await GroupService.validateGroupAccess(groupId, req.user.id);

    // Verify the user creating the settlement is the payer
    if (fromUserId !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only create settlements for yourself',
      });
    }

    // Fetch group + both users in parallel (was 3 sequential queries)
    const [group, usersMap] = await Promise.all([
      Group.findById(groupId),
      User.findByIds([fromUserId, toUserId]),
    ]);
    const fromUser = usersMap[fromUserId];
    const toUser = usersMap[toUserId];

    // Settles immediately — no receiver confirmation step. The receiver is
    // informed via push + email below.
    const settlement = await Settlement.create({
      groupId,
      fromUserId,
      toUserId,
      amount,
      currency,
      notes,
      method,
      paidAt,
      status: 'paid',
    });

    // Invalidate settlement list cache + balance cache (settlements affect
    // the simplified-debt math).
    cache.invalidate(`group:${groupId}:settlements`);
    cache.invalidate(`group:${groupId}:balances`);
    // Bust every group member's dashboard cache — the settlement counts
    // towards balances right away.
    await GroupService.invalidateMemberDashboards(groupId);

    // Log activity - use group currency as default instead of USD
    const settlementCurrency = currency || group.currency || 'INR';
    await ActivityService.logSettlementCreated(
      settlement.id,
      groupId,
      fromUserId,
      toUserId,
      group.name,
      fromUser.name,
      toUser.name,
      amount,
      settlementCurrency
    );

    // Notify only the recipient (inbox + push + email, per their prefs).
    // Don't fail the request if notifying fails.
    try {
      await NotificationService.notifySettlementCreated(
        groupId,
        { ...settlement, currency: settlementCurrency },
        fromUser.name,
        toUser.name,
        { groupName: group.name },
      );
    } catch (notifError) {
      console.error('[SettlementController] notify failed:', notifError);
    }

    res.status(201).json({
      success: true,
      message: 'Settlement created successfully',
      data: settlement,
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
 * Confirm settlement (2-way confirmation)
 * PATCH /api/v1/settlements/:id/confirm
 */
const confirmSettlement = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Get settlement details
    const existingSettlement = await Settlement.findById(id);

    if (!existingSettlement) {
      return res.status(404).json({
        success: false,
        error: 'Settlement not found',
      });
    }

    // Verify user is the receiver
    if (existingSettlement.to_user_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'Only the receiver can confirm this settlement',
      });
    }

    // Fetch group + both users in parallel (was 3 sequential queries)
    const [group, usersMap] = await Promise.all([
      Group.findById(existingSettlement.group_id),
      User.findByIds([existingSettlement.from_user_id, existingSettlement.to_user_id]),
    ]);
    const fromUser = usersMap[existingSettlement.from_user_id];
    const toUser = usersMap[existingSettlement.to_user_id];

    const settlement = await Settlement.confirm(id);

    if (!settlement) {
      return res.status(400).json({
        success: false,
        error: 'Settlement already confirmed or not found',
      });
    }

    // Invalidate settlement + balance caches + every member's dashboard.
    // Confirmation flips status from 'pending' to 'paid' — which is now what
    // actually counts in balance math — so dashboard MUST refresh.
    cache.invalidate(`group:${existingSettlement.group_id}:settlements`);
    cache.invalidate(`group:${existingSettlement.group_id}:balances`);
    await GroupService.invalidateMemberDashboards(existingSettlement.group_id);

    // Log activity
    await ActivityService.logSettlementConfirmed(
      id,
      existingSettlement.group_id,
      existingSettlement.from_user_id,
      existingSettlement.to_user_id,
      group.name,
      fromUser.name,
      toUser.name,
      existingSettlement.amount,
      existingSettlement.currency
    );

    // Send push notification to group members
    try {
      await NotificationService.notifySettlementConfirmed(
        existingSettlement.group_id,
        existingSettlement,
        fromUser.name,
        toUser.name,
        req.user.id // Exclude the confirmer from notification
      );
    } catch (notifError) {
      console.error('[SettlementController] Error sending notification:', notifError);
      // Don't fail the request if notification fails
    }

    res.json({
      success: true,
      message: 'Settlement confirmed successfully',
      data: settlement,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete settlement
 * DELETE /api/v1/settlements/:id
 */
const deleteSettlement = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Get settlement to verify access
    const settlement = await Settlement.findById(id);

    if (!settlement) {
      return res.status(404).json({
        success: false,
        error: 'Settlement not found',
      });
    }

    // The payer, a group admin, or the receiver ("Not received" — they
    // never got the money) can delete. All three put the amount back on
    // the balance, so the other side is always told.
    const isAdmin = await Group.isAdmin(settlement.group_id, req.user.id);
    const isPayer = settlement.from_user_id === req.user.id;
    const isReceiver = settlement.to_user_id === req.user.id;

    if (!isAdmin && !isPayer && !isReceiver) {
      return res.status(403).json({
        success: false,
        error: 'Only the payer, the receiver or a group admin can delete this payment',
      });
    }

    // A "Settle all balances" batch is one real transfer split across
    // groups: removing one row removes the whole batch, otherwise the
    // remaining rows would claim money that never moved.
    const rows = settlement.batch_id
      ? (await query(
        `SELECT s.id, s.group_id, s.from_user_id, s.to_user_id, s.amount, s.currency, s.status,
                u1.name AS from_user_name, u2.name AS to_user_name
           FROM settlements s
           LEFT JOIN users u1 ON u1.id = s.from_user_id
           LEFT JOIN users u2 ON u2.id = s.to_user_id
          WHERE s.batch_id = $1 AND s.deleted_at IS NULL`,
        [settlement.batch_id],
      )).rows
      : [settlement];

    let deletedAny = false;
    for (const row of rows) {
      if (!(await Settlement.delete(row.id))) continue;
      deletedAny = true;
      // Invalidate settlement + balance caches + every member's dashboard.
      cache.invalidate(`group:${row.group_id}:settlements`);
      cache.invalidate(`group:${row.group_id}:balances`);
      await GroupService.invalidateMemberDashboards(row.group_id);
    }

    if (!deletedAny) {
      return res.status(404).json({
        success: false,
        error: 'Settlement not found',
      });
    }

    // Settlements count immediately, so removing one silently would put
    // money back on someone's balance without them knowing — tell them.
    // (Legacy 'pending' rows never counted, so cancelling one is silent.)
    const counted = rows.filter((r) => r.status !== 'pending');
    // Who actually paid: the row's payer, or for a batch the side the net
    // transfer came from (a batch has rows in both directions).
    let netPaise = 0;
    for (const r of counted) {
      netPaise += (r.from_user_id === settlement.from_user_id ? 1 : -1) * toPaise(r.amount);
    }
    const realPayer = netPaise >= 0 ? settlement.from_user_id : settlement.to_user_id;
    const realReceiver = realPayer === settlement.from_user_id ? settlement.to_user_id : settlement.from_user_id;
    const notReceived = counted.length > 0 && req.user.id === realReceiver;

    try {
      if (notReceived) {
        const names = await Promise.all(counted.map((r) => Group.findById(r.group_id)));
        const receiverName = (counted[0].from_user_id === realReceiver
          ? counted[0].from_user_name : counted[0].to_user_name) || 'The receiver';
        await NotificationService.sendToUser(realPayer, 'PAYMENT_NOT_RECEIVED', {
          groupId: counted[0].group_id,
          groupName: names.map((g) => g?.name || 'your group').join(', '),
          toUserName: receiverName,
          amount: fromPaise(Math.abs(netPaise)),
          currency: currencySymbol(settlement.currency),
        }, { groupId: counted[0].group_id, settlementId: settlement.id });
      } else {
        const actor = await User.findById(req.user.id);
        for (const row of counted) {
          const group = await Group.findById(row.group_id);
          await NotificationService.notifySettlementDeleted(
            row.group_id,
            group?.name || 'your group',
            row,
            req.user.id,
            actor?.name || 'A group member',
          );
        }
      }
    } catch (notifError) {
      console.error('[SettlementController] delete notify failed:', notifError);
    }

    res.json({
      success: true,
      message: 'Settlement deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Settle all balances with one friend, across every group you share in
 * one currency — Splitwise's "Settle all balances".
 * POST /api/v1/settlements/settle-all
 *   { friendId, currency, method?, notes?, expected: [{ groupId, amount }] }
 *   amount = what the app showed: > 0 the caller owes the friend in that
 *   group, < 0 the friend owes the caller.
 *
 * One real transfer (the net) is recorded as one 'paid' row per group so
 * every group's balance is right, all sharing a batch_id, all-or-nothing.
 * E.g. A owes B 500 in G1 and B owes A 200 in G2: A pays B 300, recorded
 * as A→B 500 (G1) + B→A 200 (G2).
 *
 * - Balances changed since the app loaded them (someone added an expense)
 *   → 409 BALANCES_CHANGED with the current amounts; nothing is recorded.
 * - Only the person who owes overall can settle all (the payer records).
 * - Per currency: groups in other currencies are never netted together.
 * - Serialised per pair with an advisory lock, so two concurrent requests
 *   can't both pay the same debt (retries are handled by Idempotency-Key).
 */
const settleAll = async (req, res, next) => {
  try {
    const callerId = req.user.id;
    const { friendId, currency, method, notes } = req.body;
    const expected = new Map(req.body.expected.map((e) => [e.groupId, toPaise(e.amount)]));
    if (friendId === callerId) {
      return res.status(400).json({ success: false, error: 'You can\'t settle up with yourself' });
    }
    const usersMap = await User.findByIds([callerId, friendId]);
    if (!usersMap[friendId]) return res.status(404).json({ success: false, error: 'User not found' });

    const [low, high] = [callerId, friendId].sort();
    const outcome = await transaction(async (client) => {
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [`settle-all:${low}:${high}`]);

      const { rows: groups } = await client.query(
        `SELECT g.id, g.name
           FROM groups g
           JOIN group_members a ON a.group_id = g.id AND a.user_id = $1 AND a.deleted_at IS NULL
           JOIN group_members b ON b.group_id = g.id AND b.user_id = $2 AND b.deleted_at IS NULL
          WHERE g.deleted_at IS NULL AND COALESCE(g.currency, 'INR') = $3`,
        [callerId, friendId, currency],
      );
      const nameOf = new Map(groups.map((g) => [g.id, g.name]));
      const current = new Map(); // groupId → paise, > 0 caller owes friend
      for (const r of await userPairNets(callerId, groups.map((g) => g.id))) {
        if (r.other_user_id === friendId) current.set(r.group_id, -toPaise(r.net));
      }

      const same = current.size === expected.size
        && [...current].every(([g, p]) => expected.get(g) === p);
      if (!same) {
        return {
          conflict: [...current].map(([groupId, p]) => ({
            groupId, groupName: nameOf.get(groupId), amount: Number(fromPaise(p)),
          })),
        };
      }
      const net = [...current.values()].reduce((a, b) => a + b, 0);
      if (net <= 0) return { notDebtor: true };

      const batchId = crypto.randomUUID();
      const inserted = [];
      for (const [groupId, p] of current) {
        const [from, to] = p > 0 ? [callerId, friendId] : [friendId, callerId];
        const { rows: [row] } = await client.query(
          `INSERT INTO settlements (group_id, from_user_id, to_user_id, amount, currency,
                                    status, notes, method, batch_id, confirmed_at)
           VALUES ($1, $2, $3, $4, $5, 'paid', $6, $7, $8, NOW())
           RETURNING id, group_id, from_user_id, to_user_id, amount, currency,
                     status, notes, method, batch_id, confirmed_at, settled_at, created_at`,
          [groupId, from, to, fromPaise(Math.abs(p)), currency, notes || null, method || null, batchId],
        );
        inserted.push({ ...row, group_name: nameOf.get(groupId) });
      }
      return { batchId, net, inserted };
    });

    if (outcome.conflict) {
      return res.status(409).json({
        success: false,
        code: 'BALANCES_CHANGED',
        error: 'Balances changed since you opened this screen. Check the new amounts and try again.',
        current: outcome.conflict,
      });
    }
    if (outcome.notDebtor) {
      return res.status(400).json({
        success: false,
        error: `You don't owe ${usersMap[friendId].name || 'them'} overall, so there is nothing for you to pay`,
      });
    }

    const caller = usersMap[callerId];
    const friend = usersMap[friendId];
    for (const row of outcome.inserted) {
      cache.invalidate(`group:${row.group_id}:settlements`);
      cache.invalidate(`group:${row.group_id}:balances`);
      await GroupService.invalidateMemberDashboards(row.group_id);
      const fromName = row.from_user_id === callerId ? caller.name : friend.name;
      const toName = row.to_user_id === callerId ? caller.name : friend.name;
      await ActivityService.logSettlementCreated(
        row.id, row.group_id, row.from_user_id, row.to_user_id, row.group_name,
        fromName, toName, row.amount, currency,
      );
    }

    // One notification for the one real transfer.
    try {
      await NotificationService.sendToUser(friendId, 'SETTLE_ALL_RECEIVED', {
        fromUserName: caller.name || 'Someone',
        toUserName: friend.name || '',
        amount: fromPaise(outcome.net),
        currency: currencySymbol(currency),
        currencyCode: currency,
        groupCount: String(outcome.inserted.length),
        groupName: outcome.inserted.map((r) => r.group_name).join(', '),
        notes: notes || '',
      }, { batchId: outcome.batchId });
    } catch (notifError) {
      console.error('[SettlementController] settle-all notify failed:', notifError);
    }

    res.status(201).json({
      success: true,
      message: 'All balances settled',
      data: {
        batchId: outcome.batchId,
        total: Number(fromPaise(outcome.net)),
        currency,
        settlements: outcome.inserted,
      },
    });
  } catch (error) {
    next(error);
  }
};

export default {
  getSettlements,
  createSettlement,
  confirmSettlement,
  deleteSettlement,
  settleAll,
};
