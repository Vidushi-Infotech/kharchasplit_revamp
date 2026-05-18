import { query } from '../config/database.js';
import User from '../models/User.js';
import { NotificationService } from '../services/notificationService.js';

/**
 * Get user by ID
 * GET /api/v1/users/:id
 */
const getUser = async (req, res, next) => {
  try {
    const { id } = req.params;

    const user = await User.findById(id);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    res.json({
      success: true,
      data: {
        id: user.id,
        phoneNumber: user.phone_number,
        name: user.name,
        email: user.email,
        profileImage: user.profile_image_base64,
        preferredCurrency: user.preferred_currency,
        createdAt: user.created_at,
        updatedAt: user.updated_at,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update user profile
 * PUT /api/v1/users/:id
 */
const updateUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name, email, profileImageBase64, preferredCurrency } = req.body;

    // Verify user owns this account
    if (req.user.id !== id) {
      return res.status(403).json({
        success: false,
        error: 'You can only update your own profile',
      });
    }

    const user = await User.update(id, {
      name,
      email,
      profileImageBase64,
      preferredCurrency,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        id: user.id,
        phoneNumber: user.phone_number,
        name: user.name,
        email: user.email,
        profileImage: user.profile_image_base64,
        preferredCurrency: user.preferred_currency,
        updatedAt: user.updated_at,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete user account
 * DELETE /api/v1/users/:id
 */
const deleteUser = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user owns this account
    if (req.user.id !== id) {
      return res.status(403).json({
        success: false,
        error: 'You can only delete your own account',
      });
    }

    const deleted = await User.delete(id);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    res.json({
      success: true,
      message: 'Account deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get user by phone number
 * GET /api/v1/users/by-phone/:phoneNumber
 */
const getUserByPhone = async (req, res, next) => {
  try {
    const { phoneNumber } = req.params;

    const user = await User.findByPhoneNumber(phoneNumber);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    res.json({
      success: true,
      data: {
        id: user.id,
        phoneNumber: user.phone_number,
        name: user.name,
        email: user.email,
        profileImage: user.profile_image_base64,
        preferredCurrency: user.preferred_currency,
        createdAt: user.created_at,
        updatedAt: user.updated_at,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Check if users are registered by phone numbers
 * POST /api/v1/users/check-registration
 *
 * Optimized: Uses a single database query with WHERE IN clause
 * instead of N sequential queries for better performance
 */
const checkRegisteredUsers = async (req, res, next) => {
  try {
    const { phoneNumbers } = req.body;

    if (!phoneNumbers || !Array.isArray(phoneNumbers) || phoneNumbers.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Phone numbers array is required',
      });
    }

    // Use a single bulk query instead of N queries
    const users = await User.findByPhoneNumbers(phoneNumbers);

    const registered = users.map(user => ({
      phoneNumber: user.phone_number,
      userId: user.id,
      name: user.name,
      email: user.email,
      profileImage: user.profile_image_base64 || null,
    }));

    // Find unregistered numbers
    const registeredPhoneSet = new Set(users.map(u => u.phone_number));
    const unregistered = phoneNumbers.filter(phone => !registeredPhoneSet.has(phone));

    res.json({
      success: true,
      data: {
        registered,
        unregistered,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Deactivate user account
 * DELETE /api/v1/users/:id/deactivate
 */
const deactivateUser = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user owns this account
    if (req.user.id !== id) {
      return res.status(403).json({
        success: false,
        error: 'You can only deactivate your own account',
      });
    }

    const user = await User.findById(id);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    // Deactivate user (soft delete with is_active flag)
    const deactivated = await User.delete(id);

    if (!deactivated) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    res.json({
      success: true,
      message: 'Account deactivated successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update FCM token for push notifications
 * PUT /api/v1/users/:id/fcm-token
 */
const updateFcmToken = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { fcmToken } = req.body;

    // Verify user owns this account
    if (req.user.id !== id) {
      return res.status(403).json({
        success: false,
        error: 'You can only update your own FCM token',
      });
    }

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        error: 'FCM token is required',
      });
    }

    // Update the token
    const result = await NotificationService.updateUserToken(id, fcmToken);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: 'Failed to update FCM token',
      });
    }

    res.json({
      success: true,
      message: 'FCM token updated successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Remove FCM token (logout/disable notifications)
 * DELETE /api/v1/users/:id/fcm-token
 */
const removeFcmToken = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Verify user owns this account
    if (req.user.id !== id) {
      return res.status(403).json({
        success: false,
        error: 'You can only remove your own FCM token',
      });
    }

    // Remove the token by setting it to null
    const result = await NotificationService.updateUserToken(id, null);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: 'Failed to remove FCM token',
      });
    }

    res.json({
      success: true,
      message: 'FCM token removed successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Aggregate dashboard data for a user across every group they belong to.
 * GET /api/v1/users/:id/dashboard?recentLimit=10
 *
 * Returns:
 *   {
 *     youAreOwed:    sum of positive net balances (other people owe you)
 *     youOwe:        sum of |negative net balances| (you owe other people)
 *     totalBalance:  youAreOwed - youOwe
 *     recentExpenses: latest N expenses across all the user's groups
 *   }
 */
const getDashboard = async (req, res, next) => {
  try {
    const { id } = req.params;
    const recentLimit = Math.min(parseInt(req.query.recentLimit) || 10, 50);

    if (id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only fetch your own dashboard',
      });
    }

    // Per-group net position for this user, in one query.
    // Positive amount = others owe me, negative = I owe others.
    // Combines expenses (someone paying for someone else) AND settlements
    // (a payment that reduces the underlying debt).
    // The user's "active" group set: membership row alive AND group itself
    // not soft-deleted. Aligning this with Group.findByUserId so the
    // dashboard summary cards match the sum of per-group myBalance values
    // shown in the "You're owed" / "You owe" detail screens. (Without the
    // groups.deleted_at filter, leftover expenses in soft-deleted groups
    // still counted into the dashboard total but vanished from the
    // breakdown — root cause of the ₹X mismatch.)
    const balancesResult = await query(
      `WITH active_groups AS (
         SELECT g.id AS group_id
         FROM groups g
         JOIN group_members gm ON gm.group_id = g.id
         WHERE gm.user_id = $1
           AND gm.deleted_at IS NULL
           AND g.deleted_at IS NULL
       )
       SELECT COALESCE(SUM(GREATEST(net, 0)), 0) AS you_are_owed,
              COALESCE(SUM(GREATEST(-net, 0)), 0) AS you_owe,
              COALESCE(SUM(net), 0) AS total
       FROM (
         SELECT group_id, SUM(contribution) AS net FROM (
           SELECT e.group_id,
                  SUM(CASE
                    WHEN e.paid_by = $1 AND es.user_id != $1 THEN es.amount
                    WHEN e.paid_by != $1 AND es.user_id = $1 THEN -es.amount
                    ELSE 0
                  END) AS contribution
           FROM expenses e
           JOIN expense_splits es ON es.expense_id = e.id
           WHERE e.deleted_at IS NULL
             AND e.group_id IN (SELECT group_id FROM active_groups)
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
             AND s.group_id IN (SELECT group_id FROM active_groups)
           GROUP BY s.group_id
         ) all_contributions
         GROUP BY group_id
       ) per_group`,
      [id]
    );

    const balances = balancesResult.rows[0] || {};

    // Latest expenses across the user's groups, with the group name + paid-by user.
    // One query, with all splits batch-fetched separately.
    const expensesResult = await query(
      `SELECT e.id, e.group_id, e.description, e.amount, e.currency, e.category,
              e.paid_by, e.split_type, e.notes, e.expense_date, e.created_at,
              g.name AS group_name,
              u.name AS paid_by_name, u.phone_number AS paid_by_phone,
              u.profile_image_base64 AS paid_by_image
       FROM expenses e
       JOIN groups g ON g.id = e.group_id
       LEFT JOIN users u ON u.id = e.paid_by
       WHERE e.deleted_at IS NULL
         AND e.group_id IN (
           SELECT group_id FROM group_members
           WHERE user_id = $1 AND deleted_at IS NULL
         )
       ORDER BY e.created_at DESC
       LIMIT $2`,
      [id, recentLimit]
    );

    const expenseIds = expensesResult.rows.map(r => r.id);
    let splitsByExpense = {};
    if (expenseIds.length > 0) {
      const splitsResult = await query(
        `SELECT es.expense_id, es.user_id, es.amount, es.percentage, es.shares,
                u.name AS user_name
         FROM expense_splits es
         LEFT JOIN users u ON u.id = es.user_id
         WHERE es.expense_id = ANY($1::uuid[])
           AND es.deleted_at IS NULL`,
        [expenseIds]
      );
      for (const s of splitsResult.rows) {
        if (!splitsByExpense[s.expense_id]) splitsByExpense[s.expense_id] = [];
        splitsByExpense[s.expense_id].push({
          userId: s.user_id,
          userName: s.user_name,
          owedShare: parseFloat(s.amount),
          percentage: s.percentage != null ? parseFloat(s.percentage) : null,
          shares: s.shares,
        });
      }
    }

    const recentExpenses = expensesResult.rows.map(e => ({
      id: e.id,
      groupId: e.group_id,
      groupName: e.group_name,
      description: e.description,
      amount: parseFloat(e.amount),
      currency: e.currency,
      category: e.category,
      paidBy: e.paid_by
        ? {
            id: e.paid_by,
            name: e.paid_by_name,
            phoneNumber: e.paid_by_phone,
            profileImage: e.paid_by_image,
          }
        : null,
      splitType: e.split_type,
      notes: e.notes,
      expenseDate: e.expense_date,
      createdAt: e.created_at,
      splits: splitsByExpense[e.id] || [],
    }));

    res.json({
      success: true,
      data: {
        youAreOwed: parseFloat(balances.you_are_owed) || 0,
        youOwe: parseFloat(balances.you_owe) || 0,
        totalBalance: parseFloat(balances.total) || 0,
        recentExpenses,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/v1/users/:id/export
 * Returns the user's data as a single JSON blob — profile, groups, expenses,
 * personal expenses, and settlements. Lets the client save a copy locally.
 */
const exportUserData = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({
        success: false,
        error: 'You can only export your own data',
      });
    }

    const profileRes = await query(
      `SELECT id, phone_number, name, email, profile_image_base64,
              preferred_currency, created_at, updated_at
       FROM users WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    if (profileRes.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    const u = profileRes.rows[0];
    const profile = {
      id: u.id,
      phoneNumber: u.phone_number,
      name: u.name,
      email: u.email,
      preferredCurrency: u.preferred_currency,
      hasProfilePhoto: !!u.profile_image_base64,
      createdAt: u.created_at,
      updatedAt: u.updated_at,
    };

    const groupsRes = await query(
      `SELECT g.id, g.name, g.description, g.currency, g.created_at,
              gm.role, gm.joined_at
       FROM groups g
       JOIN group_members gm ON gm.group_id = g.id
       WHERE gm.user_id = $1 AND g.deleted_at IS NULL
       ORDER BY gm.joined_at DESC`,
      [id]
    );
    const groups = groupsRes.rows.map((r) => ({
      id: r.id,
      name: r.name,
      description: r.description,
      currency: r.currency,
      role: r.role,
      joinedAt: r.joined_at,
      groupCreatedAt: r.created_at,
    }));

    const expensesRes = await query(
      `SELECT e.id, e.group_id, e.description, e.amount, e.currency, e.category,
              e.paid_by, e.split_type, e.notes, e.expense_date, e.created_at,
              es.amount AS my_share, es.percentage AS my_percentage,
              es.shares AS my_shares
       FROM expenses e
       LEFT JOIN expense_splits es ON es.expense_id = e.id AND es.user_id = $1
       JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = $1
       WHERE e.deleted_at IS NULL
       ORDER BY e.expense_date DESC
       LIMIT 5000`,
      [id]
    );
    const expenses = expensesRes.rows.map((r) => ({
      id: r.id,
      groupId: r.group_id,
      description: r.description,
      amount: r.amount,
      currency: r.currency,
      category: r.category,
      paidBy: r.paid_by,
      paidByMe: r.paid_by === id,
      splitType: r.split_type,
      myShare: r.my_share,
      myPercentage: r.my_percentage,
      myShares: r.my_shares,
      notes: r.notes,
      expenseDate: r.expense_date,
      createdAt: r.created_at,
    }));

    const personalRes = await query(
      `SELECT id, description, amount, currency, category, expense_date,
              notes, created_at
       FROM personal_expenses
       WHERE user_id = $1 AND is_deleted = FALSE
       ORDER BY expense_date DESC
       LIMIT 5000`,
      [id]
    );
    const personalExpenses = personalRes.rows.map((r) => ({
      id: r.id,
      title: r.description,
      amount: r.amount,
      currency: r.currency,
      category: r.category,
      expenseDate: r.expense_date,
      notes: r.notes,
      createdAt: r.created_at,
    }));

    let settlements = [];
    try {
      const settlementsRes = await query(
        `SELECT id, group_id, amount, currency, payer_id, payee_id, notes,
                created_at
         FROM settlements
         WHERE (payer_id = $1 OR payee_id = $1)
         ORDER BY created_at DESC
         LIMIT 5000`,
        [id]
      );
      settlements = settlementsRes.rows.map((r) => ({
        id: r.id,
        groupId: r.group_id,
        amount: r.amount,
        currency: r.currency,
        payerId: r.payer_id,
        payeeId: r.payee_id,
        direction: r.payer_id === id ? 'paid' : 'received',
        notes: r.notes,
        createdAt: r.created_at,
      }));
    } catch (_) {
      // settlements table may not exist in all environments — skip silently
    }

    const payload = {
      exportVersion: 1,
      exportedAt: new Date().toISOString(),
      profile,
      counts: {
        groups: groups.length,
        expenses: expenses.length,
        personalExpenses: personalExpenses.length,
        settlements: settlements.length,
      },
      groups,
      expenses,
      personalExpenses,
      settlements,
    };

    res.json({ success: true, data: payload });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/v1/users/:id/reports?period=month|quarter|year
 *
 * Aggregated spending breakdown for the Reports screen. All money figures
 * are in the user's preferred currency (the dashboard already mixes
 * currencies, this endpoint follows the same convention — sums are taken
 * raw, no FX conversion).
 *
 * Window semantics (all relative to NOW):
 *   month   → from start of the *current* calendar month
 *   quarter → from start of (current month - 2)  (covers 3 months)
 *   year    → from start of (current month - 11) (covers 12 months)
 *
 * Returns:
 *   totalSpending    — Σ (es.amount) for splits belonging to the caller,
 *                      within the window, across active groups.
 *   youOwe / owedToYou — current pairwise *balances* (NOT period-windowed —
 *                      these are point-in-time snapshots of what's outstanding
 *                      right now, same definition the dashboard uses).
 *   categorySpending — { categoryId: amount } for the caller's splits, window.
 *   monthlySpending  — { 'YYYY-MM': amount } per calendar month in the window.
 *   topCategories    — categorySpending sorted desc, top 5, with categoryId.
 */
const getReports = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'You can only fetch your own reports',
      });
    }

    const period = (req.query.period || 'month').toString().toLowerCase();
    let windowStartSql;
    switch (period) {
      case 'year':
        windowStartSql = "date_trunc('month', NOW()) - INTERVAL '11 months'";
        break;
      case 'quarter':
        windowStartSql = "date_trunc('month', NOW()) - INTERVAL '2 months'";
        break;
      case 'month':
      default:
        windowStartSql = "date_trunc('month', NOW())";
        break;
    }

    // Snapshot of current outstanding balances — same shape as dashboard's
    // you_owe / you_are_owed numbers. We intentionally do NOT period-window
    // these (debts don't have a "this month" — they're either outstanding
    // now or settled).
    const balancesResult = await query(
      `WITH active_groups AS (
         SELECT g.id AS group_id
         FROM groups g
         JOIN group_members gm ON gm.group_id = g.id
         WHERE gm.user_id = $1
           AND gm.deleted_at IS NULL
           AND g.deleted_at IS NULL
       )
       SELECT COALESCE(SUM(GREATEST(net, 0)), 0) AS you_are_owed,
              COALESCE(SUM(GREATEST(-net, 0)), 0) AS you_owe
       FROM (
         SELECT group_id, SUM(contribution) AS net FROM (
           SELECT e.group_id,
                  SUM(CASE
                    WHEN e.paid_by = $1 AND es.user_id != $1 THEN es.amount
                    WHEN e.paid_by != $1 AND es.user_id = $1 THEN -es.amount
                    ELSE 0
                  END) AS contribution
           FROM expenses e
           JOIN expense_splits es ON es.expense_id = e.id
           WHERE e.deleted_at IS NULL
             AND e.group_id IN (SELECT group_id FROM active_groups)
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
             AND s.group_id IN (SELECT group_id FROM active_groups)
           GROUP BY s.group_id
         ) all_contributions
         GROUP BY group_id
       ) per_group`,
      [id]
    );
    const balances = balancesResult.rows[0] || {};

    // Per-category spend = amount the caller *consumed* (their own split row)
    // within the window. Counts the caller's portion of every expense in
    // every group they're a member of.
    const categoryResult = await query(
      `SELECT COALESCE(NULLIF(e.category, ''), 'other') AS category,
              COALESCE(SUM(es.amount), 0) AS amount
         FROM expense_splits es
         JOIN expenses e ON e.id = es.expense_id
         JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = $1 AND gm.deleted_at IS NULL
         JOIN groups g ON g.id = e.group_id AND g.deleted_at IS NULL
        WHERE es.user_id = $1
          AND es.deleted_at IS NULL
          AND e.deleted_at IS NULL
          AND e.expense_date >= ${windowStartSql}
        GROUP BY COALESCE(NULLIF(e.category, ''), 'other')
        ORDER BY amount DESC`,
      [id]
    );

    const categorySpending = {};
    for (const row of categoryResult.rows) {
      categorySpending[row.category] = parseFloat(row.amount);
    }
    const totalSpending = Object.values(categorySpending)
      .reduce((sum, v) => sum + v, 0);
    const topCategories = Object.entries(categorySpending)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([category, amount]) => ({ category, amount }));

    // Monthly spend series — bucketed by calendar month so the bar chart's
    // X axis has stable labels regardless of timezone. Months in the window
    // with zero spend are filled in client-side.
    const monthlyResult = await query(
      `SELECT to_char(date_trunc('month', e.expense_date), 'YYYY-MM') AS month,
              COALESCE(SUM(es.amount), 0) AS amount
         FROM expense_splits es
         JOIN expenses e ON e.id = es.expense_id
         JOIN group_members gm ON gm.group_id = e.group_id AND gm.user_id = $1 AND gm.deleted_at IS NULL
         JOIN groups g ON g.id = e.group_id AND g.deleted_at IS NULL
        WHERE es.user_id = $1
          AND es.deleted_at IS NULL
          AND e.deleted_at IS NULL
          AND e.expense_date >= ${windowStartSql}
        GROUP BY date_trunc('month', e.expense_date)
        ORDER BY date_trunc('month', e.expense_date)`,
      [id]
    );
    const monthlySpending = {};
    for (const row of monthlyResult.rows) {
      monthlySpending[row.month] = parseFloat(row.amount);
    }

    res.json({
      success: true,
      data: {
        period,
        totalSpending,
        youOwe: parseFloat(balances.you_owe || 0),
        owedToYou: parseFloat(balances.you_are_owed || 0),
        categorySpending,
        monthlySpending,
        topCategories,
      },
    });
  } catch (error) {
    next(error);
  }
};

export default {
  getUser,
  getUserByPhone,
  updateUser,
  deleteUser,
  checkRegisteredUsers,
  deactivateUser,
  updateFcmToken,
  removeFcmToken,
  getDashboard,
  exportUserData,
  getReports,
};
