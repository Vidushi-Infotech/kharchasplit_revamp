import Expense from '../models/Expense.js';
import Group from '../models/Group.js';
import GroupService from '../services/groupService.js';
import ActivityService from '../services/activityService.js';
import { NotificationService } from '../services/notificationService.js';
import { cache } from '../services/cacheService.js';

/**
 * Get expenses for a group
 * GET /api/v1/expenses?groupId=:id&page=1&limit=50
 */
const getExpenses = async (req, res, next) => {
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
    const expenses = await Expense.findByGroupId(groupId, parseInt(limit), offset);
    const total = await Expense.countByGroupId(groupId);

    res.json({
      success: true,
      data: expenses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        hasMore: offset + expenses.length < total,
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
 * Get single expense with details
 * GET /api/v1/expenses/:id
 */
const getExpense = async (req, res, next) => {
  try {
    const { id } = req.params;

    const expense = await Expense.findById(id);

    if (!expense) {
      return res.status(404).json({
        success: false,
        error: 'Expense not found',
      });
    }

    // Verify user has access to the group
    await GroupService.validateGroupAccess(expense.group_id, req.user.id);

    res.json({
      success: true,
      data: expense,
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
 * Create new expense
 * POST /api/v1/expenses
 */
const createExpense = async (req, res, next) => {
  try {
    const {
      groupId,
      description,
      amount,
      currency,
      category,
      paidById,
      paidByName,
      splitType,
      receiptBase64,
      notes,
      expenseDate,
      participants,
    } = req.body;

    // Verify user has access
    await GroupService.validateGroupAccess(groupId, req.user.id);

    // Get group name for activity log
    const group = await Group.findById(groupId);

    const expense = await Expense.create(
      {
        groupId,
        description,
        amount,
        currency,
        category,
        paidById,
        paidByName,
        splitType,
        receiptBase64,
        notes,
        expenseDate,
      },
      participants
    );

    // Invalidate group expense/balance caches
    Expense.invalidateGroupExpenses(groupId);
    // Bust every group member's dashboard cache so "You owe / You're owed"
    // on the homescreen reflects this expense immediately (otherwise stale
    // until the 60s TTL on user:<id>:dashboard expires).
    await GroupService.invalidateMemberDashboards(groupId);

    // Log activity
    await ActivityService.logExpenseAdded(
      expense.id,
      groupId,
      req.user.id,
      group.name,
      description,
      amount,
      currency || 'USD'
    );

    // Push notify other group members (excluding the payer).
    // Wrapped in try/catch so a notification failure never breaks the
    // expense create response.
    try {
      await NotificationService.notifyExpenseAdded(
        groupId,
        expense,
        paidByName || 'Someone',
        group.name,
        currency || group.currency || 'INR',
        req.user.id,
      );
    } catch (notifError) {
      console.error('[ExpenseController] notify failed:', notifError);
    }

    res.status(201).json({
      success: true,
      message: 'Expense created successfully',
      data: expense,
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
 * Update expense
 * PUT /api/v1/expenses/:id
 */
const updateExpense = async (req, res, next) => {
  try {
    const { id } = req.params;
    const {
      description,
      amount,
      currency,
      category,
      receiptBase64,
      notes,
      expenseDate,
      paidById,
      splitType,
      participants,
    } = req.body;

    // Get expense to verify access
    const existingExpense = await Expense.findById(id);

    if (!existingExpense) {
      return res.status(404).json({
        success: false,
        error: 'Expense not found',
      });
    }

    // Verify user has access
    await GroupService.validateGroupAccess(existingExpense.group_id, req.user.id);

    // Only the *original* payer may edit. Payer can be reassigned via
    // `paidById` in the body, but the caller must currently be the payer.
    if (existingExpense.paid_by !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'Only the person who paid can edit this expense',
      });
    }

    const fields = {
      description,
      amount,
      currency,
      category,
      receiptBase64,
      notes,
      expenseDate,
      paidById,
      splitType,
    };

    // When the client sends a fresh participants array we re-write splits in
    // a transaction; otherwise we leave splits alone (legacy callers that
    // only patch description / notes / category).
    const expense = Array.isArray(participants)
      ? await Expense.updateWithSplits(id, fields, participants)
      : await Expense.update(id, fields);

    // Invalidate group expense/balance caches + every member's dashboard.
    Expense.invalidateGroupExpenses(existingExpense.group_id);
    await GroupService.invalidateMemberDashboards(existingExpense.group_id);

    res.json({
      success: true,
      message: 'Expense updated successfully',
      data: expense,
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
 * Delete expense
 * DELETE /api/v1/expenses/:id
 */
const deleteExpense = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Get expense to verify access
    const expense = await Expense.findById(id);

    if (!expense) {
      return res.status(404).json({
        success: false,
        error: 'Expense not found',
      });
    }

    // Only the person who added (paid for) the expense can delete it.
    if (expense.paid_by_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'Only the person who added this expense can delete it.',
      });
    }

    const deleted = await Expense.delete(id);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Expense not found',
      });
    }

    // Invalidate group expense/balance caches + every member's dashboard.
    Expense.invalidateGroupExpenses(expense.group_id);
    await GroupService.invalidateMemberDashboards(expense.group_id);

    res.json({
      success: true,
      message: 'Expense deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

export default {
  getExpenses,
  getExpense,
  createExpense,
  updateExpense,
  deleteExpense,
};
