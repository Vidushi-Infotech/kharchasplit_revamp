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
    const balancesResult = await query(
      `SELECT COALESCE(SUM(GREATEST(net, 0)), 0) AS you_are_owed,
              COALESCE(SUM(GREATEST(-net, 0)), 0) AS you_owe,
              COALESCE(SUM(net), 0) AS total
       FROM (
         SELECT e.group_id,
                SUM(CASE
                  WHEN e.paid_by = $1 AND es.user_id != $1 THEN es.amount
                  WHEN e.paid_by != $1 AND es.user_id = $1 THEN -es.amount
                  ELSE 0
                END) AS net
         FROM expenses e
         JOIN expense_splits es ON es.expense_id = e.id
         WHERE e.deleted_at IS NULL
           AND e.group_id IN (
             SELECT group_id FROM group_members
             WHERE user_id = $1 AND deleted_at IS NULL
           )
         GROUP BY e.group_id
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
};
