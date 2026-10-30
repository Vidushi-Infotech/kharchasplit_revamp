import PersonalBudget from '../models/PersonalBudget.js';
import { parseMonthQuery } from '../utils/personalSummary.js';
import { todayIST } from '../utils/recurrence.js';

/** The whole month's budget, as opposed to one category's. */
export const TOTAL = 'total';

/**
 * The caller's budgets with what's been spent against each this month.
 * GET /api/v1/personal-budgets?month=YYYY-MM&tzOffset=330
 * → { month, totalSpent, budgets: [{ category, amount, spent }],
 *     spent: [{ category, spent }] (every category with spending) }
 */
const getBudgets = async (req, res, next) => {
  try {
    const { month, tzOffset } = parseMonthQuery(req.query, todayIST());
    const [budgets, spentRows] = await Promise.all([
      PersonalBudget.listForUser(req.user.id),
      PersonalBudget.spentByCategory(req.user.id, month, tzOffset),
    ]);
    const spent = new Map(spentRows.map((r) => [r.category, Number(r.spent)]));
    const totalSpent = [...spent.values()].reduce((a, b) => a + b, 0);
    res.json({
      success: true,
      data: {
        month,
        totalSpent: Math.round(totalSpent * 100) / 100,
        budgets: budgets.map((b) => ({
          category: b.category,
          amount: Number(b.amount),
          spent: b.category === TOTAL ? totalSpent : spent.get(b.category) || 0,
        })),
        spent: [...spent.entries()]
          .map(([category, value]) => ({ category, spent: value }))
          .sort((a, b) => b.spent - a.spent),
      },
    });
  } catch (error) {
    next(error);
  }
};

/** PUT /api/v1/personal-budgets/:category { amount } — set or change. */
const setBudget = async (req, res, next) => {
  try {
    const budget = await PersonalBudget.upsert(
      req.user.id,
      req.params.category,
      req.body.amount,
    );
    res.json({
      success: true,
      data: { category: budget.category, amount: Number(budget.amount) },
    });
  } catch (error) {
    next(error);
  }
};

/** DELETE /api/v1/personal-budgets/:category */
const removeBudget = async (req, res, next) => {
  try {
    const removed = await PersonalBudget.remove(req.user.id, req.params.category);
    if (!removed) {
      return res.status(404).json({ success: false, error: 'Budget not found' });
    }
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
};

export default { getBudgets, setBudget, removeBudget };
