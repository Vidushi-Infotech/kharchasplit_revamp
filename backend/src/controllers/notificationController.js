import { query } from '../config/database.js';
import { NotificationService } from '../services/notificationService.js';

const PREF_COLUMNS = [
  'push_enabled',
  'email_enabled',
  'new_expense',
  'group_invite',
  'payment_received',
  'settlement_reminder',
  'comment_mention',
  'weekly_summary',
  'product_updates',
];

const DEFAULT_PREFS = {
  push_enabled: true,
  email_enabled: false,
  new_expense: true,
  group_invite: true,
  payment_received: true,
  settlement_reminder: true,
  comment_mention: true,
  weekly_summary: false,
  product_updates: false,
};

function rowToPrefs(row) {
  return {
    pushEnabled: row.push_enabled,
    emailEnabled: row.email_enabled,
    newExpense: row.new_expense,
    groupInvite: row.group_invite,
    paymentReceived: row.payment_received,
    settlementReminder: row.settlement_reminder,
    commentMention: row.comment_mention,
    weeklySummary: row.weekly_summary,
    productUpdates: row.product_updates,
    updatedAt: row.updated_at,
  };
}

function defaultsAsResponse() {
  return {
    pushEnabled: true,
    emailEnabled: false,
    newExpense: true,
    groupInvite: true,
    paymentReceived: true,
    settlementReminder: true,
    commentMention: true,
    weeklySummary: false,
    productUpdates: false,
    updatedAt: null,
  };
}

/**
 * GET /api/v1/users/:id/notification-prefs
 * Returns the user's notification preferences. If no row exists yet,
 * returns the defaults (no DB write — we lazily insert on first PUT).
 */
const getPrefs = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }

    const result = await query(
      `SELECT * FROM notification_prefs WHERE user_id = $1`,
      [id],
    );
    if (result.rows.length === 0) {
      return res.json({ success: true, data: defaultsAsResponse() });
    }
    res.json({ success: true, data: rowToPrefs(result.rows[0]) });
  } catch (err) {
    next(err);
  }
};

/**
 * PUT /api/v1/users/:id/notification-prefs
 * Body: any subset of pref keys (camelCase or snake_case accepted).
 * Upserts the row.
 */
const updatePrefs = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }

    // Build a partial-update map. Accept camelCase from clients but write
    // snake_case to the DB.
    const camelToSnake = {
      pushEnabled: 'push_enabled',
      emailEnabled: 'email_enabled',
      newExpense: 'new_expense',
      groupInvite: 'group_invite',
      paymentReceived: 'payment_received',
      settlementReminder: 'settlement_reminder',
      commentMention: 'comment_mention',
      weeklySummary: 'weekly_summary',
      productUpdates: 'product_updates',
    };

    const updates = {};
    for (const [k, v] of Object.entries(req.body || {})) {
      const col = camelToSnake[k] || (PREF_COLUMNS.includes(k) ? k : null);
      if (!col) continue;
      if (typeof v !== 'boolean') continue;
      updates[col] = v;
    }

    // INSERT … ON CONFLICT to upsert. Columns not in `updates` keep their
    // existing value (or fall back to the DEFAULT_PREFS on insert).
    const allCols = ['user_id', ...PREF_COLUMNS];
    const insertValues = allCols.map((col) =>
      col === 'user_id' ? id : (updates[col] ?? DEFAULT_PREFS[col]),
    );
    const placeholders = allCols.map((_, i) => `$${i + 1}`).join(', ');

    const setClauses = [];
    const setValues = [];
    for (const [col, val] of Object.entries(updates)) {
      setValues.push(val);
      setClauses.push(`${col} = $${allCols.length + setValues.length}`);
    }
    setClauses.push(`updated_at = NOW()`);

    const sql = `
      INSERT INTO notification_prefs (${allCols.join(', ')})
      VALUES (${placeholders})
      ON CONFLICT (user_id) DO UPDATE SET ${setClauses.join(', ')}
      RETURNING *
    `;

    const result = await query(sql, [...insertValues, ...setValues]);
    res.json({ success: true, data: rowToPrefs(result.rows[0]) });
  } catch (err) {
    next(err);
  }
};

/**
 * POST /api/v1/users/:id/devices
 * Body: { fcmToken, platform, deviceName, osVersion, appVersion }
 * Registers (or refreshes) a device's FCM token. Idempotent on token.
 */
const registerDevice = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }

    const { fcmToken, platform, deviceName, osVersion, appVersion } = req.body || {};
    if (!fcmToken) {
      return res.status(400).json({ success: false, error: 'fcmToken is required' });
    }

    const result = await NotificationService.registerDevice(id, fcmToken, {
      platform,
      deviceName,
      osVersion,
      appVersion,
    });

    if (!result.success) {
      return res.status(500).json({ success: false, error: result.error });
    }
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
};

/**
 * DELETE /api/v1/users/:id/devices
 * Body: { fcmToken } — unregisters a single device (e.g. on logout).
 */
const unregisterDevice = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }

    const { fcmToken } = req.body || {};
    if (!fcmToken) {
      return res.status(400).json({ success: false, error: 'fcmToken is required' });
    }

    await NotificationService.unregisterDevice(id, fcmToken);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
};

// ============================================================
// Inbox (notifications history) endpoints
// ============================================================

function rowToNotification(row) {
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    body: row.body,
    data: row.data || {},
    isRead: row.is_read,
    readAt: row.read_at,
    createdAt: row.created_at,
  };
}

/**
 * GET /api/v1/users/:id/notifications?limit=30&before=<iso>
 * Returns a paginated reverse-chronological list of inbox rows.
 */
const listNotifications = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }

    const limit = Math.min(parseInt(req.query.limit) || 30, 100);
    const before = req.query.before;
    const params = [id];
    let cursorClause = '';
    if (before) {
      params.push(before);
      cursorClause = `AND created_at < $${params.length}`;
    }
    params.push(limit);

    const result = await query(
      `SELECT id, type, title, body, data, is_read, read_at, created_at
         FROM notifications
        WHERE user_id = $1 ${cursorClause}
        ORDER BY created_at DESC
        LIMIT $${params.length}`,
      params,
    );

    res.json({
      success: true,
      data: result.rows.map(rowToNotification),
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/users/:id/notifications/unread-count
 * Returns just the count — used to drive the bell-icon badge.
 */
const unreadCount = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }
    const result = await query(
      `SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND is_read = FALSE`,
      [id],
    );
    res.json({ success: true, data: { count: result.rows[0].count } });
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH /api/v1/users/:id/notifications/:notifId/read
 * Marks a single notification as read.
 */
const markRead = async (req, res, next) => {
  try {
    const { id, notifId } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }
    await query(
      `UPDATE notifications SET is_read = TRUE, read_at = NOW()
        WHERE id = $1 AND user_id = $2 AND is_read = FALSE`,
      [notifId, id],
    );
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
};

/**
 * PATCH /api/v1/users/:id/notifications/read-all
 * Marks every unread notification for this user as read.
 */
const markAllRead = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (req.user.id !== id) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }
    await query(
      `UPDATE notifications SET is_read = TRUE, read_at = NOW()
        WHERE user_id = $1 AND is_read = FALSE`,
      [id],
    );
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
};

export default {
  getPrefs,
  updatePrefs,
  registerDevice,
  unregisterDevice,
  listNotifications,
  unreadCount,
  markRead,
  markAllRead,
};
