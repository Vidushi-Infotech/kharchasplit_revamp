import Settlement from '../models/Settlement.js';
import Group from '../models/Group.js';
import User from '../models/User.js';
import GroupService from '../services/groupService.js';
import ActivityService from '../services/activityService.js';
import { NotificationService } from '../services/notificationService.js';
import { cache } from '../services/cacheService.js';

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
    const { groupId, fromUserId, toUserId, amount, currency, notes } = req.body;

    // Verify user has access
    await GroupService.validateGroupAccess(groupId, req.user.id);

    // Verify the user creating the settlement is the payer
    if (fromUserId !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only create settlements for yourself',
      });
    }

    // Check for existing pending settlement between same users in same group
    const existingPending = await Settlement.findPendingBetweenUsers(groupId, fromUserId, toUserId);
    if (existingPending) {
      return res.status(409).json({
        success: false,
        error: 'A pending settlement already exists between these users. Please wait for confirmation or cancel the existing one.',
        existingSettlement: existingPending,
      });
    }

    // Fetch group + both users in parallel (was 3 sequential queries)
    const [group, usersMap] = await Promise.all([
      Group.findById(groupId),
      User.findByIds([fromUserId, toUserId]),
    ]);
    const fromUser = usersMap[fromUserId];
    const toUser = usersMap[toUserId];

    const settlement = await Settlement.create({
      groupId,
      fromUserId,
      toUserId,
      amount,
      currency,
      notes,
    });

    // Invalidate settlement list cache + balance cache (settlements affect
    // the simplified-debt math).
    cache.invalidate(`group:${groupId}:settlements`);
    cache.invalidate(`group:${groupId}:balances`);

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

    // Push notify the recipient (and others in group) about the pending
    // settlement. Don't fail the request if push fails.
    try {
      await NotificationService.notifySettlementCreated(
        groupId,
        { ...settlement, currency: settlementCurrency },
        fromUser.name,
        toUser.name,
        req.user.id,
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

    // Invalidate settlement + balance caches
    cache.invalidate(`group:${existingSettlement.group_id}:settlements`);
    cache.invalidate(`group:${existingSettlement.group_id}:balances`);

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

    // Only the payer or group admin can delete
    const isAdmin = await Group.isAdmin(settlement.group_id, req.user.id);
    const isPayer = settlement.from_user_id === req.user.id;

    if (!isAdmin && !isPayer) {
      return res.status(403).json({
        success: false,
        error: 'Only group admins or the payer can delete this settlement',
      });
    }

    const deleted = await Settlement.delete(id);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Settlement not found',
      });
    }

    // Invalidate settlement + balance caches
    cache.invalidate(`group:${settlement.group_id}:settlements`);
    cache.invalidate(`group:${settlement.group_id}:balances`);

    res.json({
      success: true,
      message: 'Settlement deleted successfully',
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
};
