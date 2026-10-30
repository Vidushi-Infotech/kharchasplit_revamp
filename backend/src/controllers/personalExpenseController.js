import PersonalExpense from '../models/PersonalExpense.js';
import {
  buildPersonalSummary,
  parseMonthQuery,
  shiftMonth,
  TREND_MONTHS,
} from '../utils/personalSummary.js';
import { todayIST } from '../utils/recurrence.js';

/**
 * Get personal expenses for a user
 * GET /api/v1/personal-expenses?userId=:id&page=1&limit=50
 */
const getPersonalExpenses = async (req, res, next) => {
  try {
    const { userId, page = 1, limit = 50 } = req.query;
    // Apps that know about income ask for it; older ones only get expenses.
    const includeIncome = req.query.includeIncome === '1';

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId query parameter is required',
      });
    }

    // Users can only view their own personal expenses
    if (userId !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only view your own personal expenses',
      });
    }

    const offset = (page - 1) * limit;
    const expenses = await PersonalExpense.findByUserId(userId, parseInt(limit), offset, includeIncome);
    const total = await PersonalExpense.countByUserId(userId, includeIncome);

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
    next(error);
  }
};

/**
 * The Insights tab: one month's spending by category and by day, compared
 * with the month before, plus a six-month trend.
 * GET /api/v1/personal-expenses/summary?month=YYYY-MM&tzOffset=330
 * (tzOffset: the phone's minutes east of UTC, so days split at its midnight)
 */
const getPersonalSummary = async (req, res, next) => {
  try {
    const { month, tzOffset } = parseMonthQuery(req.query, todayIST());
    const rows = await PersonalExpense.dailyTotals(
      req.user.id,
      shiftMonth(month, -(TREND_MONTHS - 1)),
      month,
      tzOffset,
    );
    res.json({ success: true, data: buildPersonalSummary(rows, month) });
  } catch (error) {
    next(error);
  }
};

/**
 * Get single personal expense
 * GET /api/v1/personal-expenses/:id
 */
const getPersonalExpense = async (req, res, next) => {
  try {
    const { id } = req.params;

    const expense = await PersonalExpense.findById(id);

    if (!expense) {
      return res.status(404).json({
        success: false,
        error: 'Personal expense not found',
      });
    }

    // Users can only view their own personal expenses
    if (expense.user_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only view your own personal expenses',
      });
    }

    res.json({
      success: true,
      data: expense,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Create new personal expense
 * POST /api/v1/personal-expenses
 */
const createPersonalExpense = async (req, res, next) => {
  try {
    const { kind, description, amount, currency, category, receiptBase64, notes, expenseDate } = req.body;

    const expense = await PersonalExpense.create({
      userId: req.user.id,
      kind,
      description,
      amount,
      currency,
      category,
      receiptBase64,
      notes,
      expenseDate,
    });

    res.status(201).json({
      success: true,
      message: 'Personal expense created successfully',
      data: expense,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update personal expense
 * PUT /api/v1/personal-expenses/:id
 */
const updatePersonalExpense = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { kind, description, amount, currency, category, receiptBase64, notes, expenseDate } = req.body;

    // Get expense to verify ownership
    const existingExpense = await PersonalExpense.findById(id);

    if (!existingExpense) {
      return res.status(404).json({
        success: false,
        error: 'Personal expense not found',
      });
    }

    // Users can only edit their own personal expenses
    if (existingExpense.user_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only edit your own personal expenses',
      });
    }

    const expense = await PersonalExpense.update(id, {
      kind,
      description,
      amount,
      currency,
      category,
      receiptBase64,
      notes,
      expenseDate,
    });

    res.json({
      success: true,
      message: 'Personal expense updated successfully',
      data: expense,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete personal expense
 * DELETE /api/v1/personal-expenses/:id
 */
const deletePersonalExpense = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Get expense to verify ownership
    const expense = await PersonalExpense.findById(id);

    if (!expense) {
      return res.status(404).json({
        success: false,
        error: 'Personal expense not found',
      });
    }

    // Users can only delete their own personal expenses
    if (expense.user_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only delete your own personal expenses',
      });
    }

    const deleted = await PersonalExpense.delete(id);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Personal expense not found',
      });
    }

    res.json({
      success: true,
      message: 'Personal expense deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

export default {
  getPersonalExpenses,
  getPersonalSummary,
  getPersonalExpense,
  createPersonalExpense,
  updatePersonalExpense,
  deletePersonalExpense,
};
