import Expense from '../models/Expense.js';
import Group from '../models/Group.js';
import User from '../models/User.js';
import GroupService from '../services/groupService.js';
import ActivityService from '../services/activityService.js';
import { NotificationService } from '../services/notificationService.js';
import { cache } from '../services/cacheService.js';
import { query } from '../config/database.js';

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
/**
 * Archived (and completed) groups are read-only for expenses. Payments
 * can still be recorded so open balances can be settled. Returns true
 * when it has sent the 409.
 */
const rejectIfArchived = (group, res) => {
  if (!group?.is_archived) return false;
  res.status(409).json({
    success: false,
    code: 'GROUP_ARCHIVED',
    error: 'This group is archived. Unarchive it to add or change expenses.',
  });
  return true;
};

/**
 * The payer and everyone in the split must be members of the group — a
 * member must not be able to put a debt on someone outside it (and a
 * non-group expense stays between its two friends). On an edit, people
 * already on the expense may stay even if they have since left
 * (`alreadyOn`). Returns true when it has sent the 400.
 */
const rejectNonMembers = async (groupId, userIds, res, alreadyOn = []) => {
  const ids = [...new Set(userIds.filter(Boolean))].filter((id) => !alreadyOn.includes(id));
  if (ids.length === 0) return false;
  const reject = () => {
    res.status(400).json({
      success: false,
      code: 'NOT_GROUP_MEMBER',
      error: 'Everyone on an expense must be a member of the group',
    });
    return true;
  };
  if (!ids.every((id) => UUID_RE.test(String(id)))) return reject();
  const { rows } = await query(
    `SELECT user_id FROM group_members
      WHERE group_id = $1 AND deleted_at IS NULL AND user_id = ANY($2::uuid[])`,
    [groupId, ids],
  );
  return rows.length === ids.length ? false : reject();
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
    if (rejectIfArchived(group, res)) return;
    if (await rejectNonMembers(
      groupId,
      [paidById || req.user.id, ...(participants || []).map((p) => p?.userId)],
      res,
    )) return;

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
        participants,
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
    if (rejectIfArchived(await Group.findById(existingExpense.group_id), res)) return;
    if (await rejectNonMembers(
      existingExpense.group_id,
      [paidById, ...(Array.isArray(participants) ? participants : []).map((p) => p?.userId)],
      res,
      [existingExpense.paid_by, ...(existingExpense.participants || []).map((p) => p.user_id)],
    )) return;

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

    // An edit changes what people owe — tell everyone whose share it touched,
    // before and after the edit.
    try {
      const [group, actor] = await Promise.all([
        Group.findById(existingExpense.group_id),
        User.findById(req.user.id),
      ]);
      await NotificationService.notifyExpenseChanged('EXPENSE_UPDATED', {
        groupId: existingExpense.group_id,
        groupName: group?.name || 'your group',
        expense: {
          id,
          description: expense?.description ?? existingExpense.description,
          amount: expense?.amount ?? existingExpense.amount,
          currency: expense?.currency || existingExpense.currency || group?.currency,
        },
        actorId: req.user.id,
        actorName: actor?.name || 'Someone',
        affectedUserIds: [
          existingExpense.paid_by,
          expense?.paid_by,
          ...existingExpense.participants.map((p) => p.user_id),
          ...(Array.isArray(participants) ? participants.map((p) => p.userId) : []),
        ],
      });
    } catch (notifError) {
      console.error('[ExpenseController] update notify failed:', notifError);
    }

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
    // NB: Expense.findById returns the column as `paid_by` (see the
    // SELECT in models/Expense.js) — `paid_by_id` was undefined here, so
    // this check rejected *every* delete with a 403, including the payer's.
    if (expense.paid_by !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'Only the person who added this expense can delete it.',
      });
    }
    if (rejectIfArchived(await Group.findById(expense.group_id), res)) return;

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

    try {
      const [group, actor] = await Promise.all([
        Group.findById(expense.group_id),
        User.findById(req.user.id),
      ]);
      await NotificationService.notifyExpenseChanged('EXPENSE_DELETED', {
        groupId: expense.group_id,
        groupName: group?.name || 'your group',
        expense: { ...expense, currency: expense.currency || group?.currency },
        actorId: req.user.id,
        actorName: actor?.name || 'Someone',
        affectedUserIds: [expense.paid_by, ...expense.participants.map((p) => p.user_id)],
      });
    } catch (notifError) {
      console.error('[ExpenseController] delete notify failed:', notifError);
    }

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
