/**
 * Notification Service
 * Push notifications via Firebase Cloud Messaging.
 *
 * Token lookup uses the user_devices table (multi-device per user).
 * Every send is filtered through notification_prefs so server-stored
 * user preferences are honored consistently across devices.
 */

import admin from 'firebase-admin';
import { query } from '../config/database.js';
import { isFirebaseReady } from '../config/firebaseAdmin.js';
import { logger } from '../utils/logger.js';

/**
 * Notification types. `prefKey` maps each type to the column in
 * notification_prefs that gates whether it gets delivered. Types whose
 * prefKey is `null` are always sent if push is enabled globally.
 */
const NOTIFICATION_TYPES = {
  SETTLEMENT_CREATED: {
    title: 'Payment initiated',
    getBody: (data) => `${data.fromUserName} marked payment of ${data.currency}${data.amount} to ${data.toUserName}`,
    channelId: 'payments',
    prefKey: 'payment_received',
  },
  SETTLEMENT_CONFIRMED: {
    title: 'Payment confirmed',
    getBody: (data) => `${data.toUserName} confirmed receiving ${data.currency}${data.amount} from ${data.fromUserName}`,
    channelId: 'payments',
    prefKey: 'payment_received',
  },
  SETTLEMENT_REMINDER: {
    title: 'Time to settle up',
    getBody: (data) => `You owe ${data.currency}${data.amount} in ${data.groupName}`,
    channelId: 'payments',
    prefKey: 'settlement_reminder',
  },

  GROUP_INVITE: {
    title: 'New group invite',
    getBody: (data) => `${data.inviterName} invited you to ${data.groupName}`,
    channelId: 'groups',
    prefKey: 'group_invite',
  },
  GROUP_ARCHIVED: {
    title: 'Group archived',
    getBody: (data) => `"${data.groupName}" has been archived`,
    channelId: 'groups',
    prefKey: null,
  },
  GROUP_COMPLETED: {
    title: 'Group closed',
    getBody: (data) => `"${data.groupName}" has been marked as complete`,
    channelId: 'groups',
    prefKey: null,
  },
  GROUP_DELETED: {
    title: 'Group deleted',
    getBody: (data) => `"${data.groupName}" has been deleted`,
    channelId: 'groups',
    prefKey: null,
  },

  MEMBER_REMOVED: {
    title: 'Member removed',
    getBody: (data) => `${data.memberName} was removed from "${data.groupName}"`,
    channelId: 'groups',
    prefKey: null,
  },
  MEMBER_LEFT: {
    title: 'Member left',
    getBody: (data) => `${data.memberName} left "${data.groupName}"`,
    channelId: 'groups',
    prefKey: null,
  },
  MEMBER_ADDED: {
    title: 'New member',
    getBody: (data) => `${data.memberName} joined "${data.groupName}"`,
    channelId: 'groups',
    prefKey: null,
  },

  EXPENSE_ADDED: {
    title: 'New expense',
    getBody: (data) => `${data.paidByName} added "${data.description}" (${data.currency}${data.amount}) in "${data.groupName}"`,
    channelId: 'expenses',
    prefKey: 'new_expense',
  },
  EXPENSE_UPDATED: {
    title: 'Expense updated',
    getBody: (data) => `"${data.description}" was updated in "${data.groupName}"`,
    channelId: 'expenses',
    prefKey: 'new_expense',
  },
  EXPENSE_DELETED: {
    title: 'Expense deleted',
    getBody: (data) => `"${data.description}" was deleted from "${data.groupName}"`,
    channelId: 'expenses',
    prefKey: 'new_expense',
  },
};

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

class NotificationService {
  /**
   * Fetch notification_prefs for a set of users in a single query.
   * Returns { [userId]: prefsObject }, falling back to defaults for users
   * with no row (so every user gets sensible defaults until they touch
   * the settings screen).
   */
  static async getPrefsForUsers(userIds) {
    if (!userIds || userIds.length === 0) return {};

    // ANY-array form is one parameter regardless of array size and lets the
    // planner reuse a prepared plan across different group sizes. Explicit
    // columns avoid hauling the auto-increment id + created_at over the
    // wire on a hot fan-out path (every group push fires this).
    const result = await query(
      `SELECT user_id, push_enabled, email_enabled, new_expense, group_invite,
              payment_received, settlement_reminder, comment_mention,
              weekly_summary, product_updates
         FROM notification_prefs
        WHERE user_id = ANY($1::uuid[])`,
      [userIds],
    );

    const byUser = {};
    for (const id of userIds) byUser[id] = { ...DEFAULT_PREFS };
    for (const row of result.rows) {
      byUser[row.user_id] = {
        push_enabled: row.push_enabled,
        email_enabled: row.email_enabled,
        new_expense: row.new_expense,
        group_invite: row.group_invite,
        payment_received: row.payment_received,
        settlement_reminder: row.settlement_reminder,
        comment_mention: row.comment_mention,
        weekly_summary: row.weekly_summary,
        product_updates: row.product_updates,
      };
    }
    return byUser;
  }

  /**
   * Filter a list of userIds by their notification prefs. Returns the
   * subset who should receive the given notification type.
   */
  static async _filterByPrefs(userIds, type) {
    if (!userIds || userIds.length === 0) return [];
    const config = NOTIFICATION_TYPES[type];
    const prefs = await this.getPrefsForUsers(userIds);
    return userIds.filter((uid) => {
      const p = prefs[uid] || DEFAULT_PREFS;
      if (!p.push_enabled) return false;
      if (config?.prefKey && p[config.prefKey] === false) return false;
      return true;
    });
  }

  /**
   * Fetch all device tokens for a set of users.
   */
  static async _fetchTokens(userIds) {
    if (userIds.length === 0) return [];
    const placeholders = userIds.map((_, i) => `$${i + 1}`).join(', ');
    const result = await query(
      `SELECT d.user_id, d.fcm_token, d.id AS device_id
         FROM user_devices d
         INNER JOIN users u ON u.id = d.user_id
        WHERE d.user_id IN (${placeholders})
          AND u.deleted_at IS NULL`,
      userIds,
    );
    return result.rows.map((row) => ({
      userId: row.user_id,
      token: row.fcm_token,
      deviceId: row.device_id,
    }));
  }

  /**
   * Insert one inbox row per recipient. Called before the FCM send so
   * users without a registered device still see the notification when
   * they open the app.
   */
  static async _logInbox(userIds, type, data, additionalData) {
    if (userIds.length === 0) return;
    const config = NOTIFICATION_TYPES[type];
    if (!config) return;
    const title = config.title;
    const body = config.getBody(data);
    // Merge `data` + `additionalData` into a single JSON payload so the
    // app can route on tap without extra lookups.
    const payload = { ...data, ...additionalData };

    const values = [];
    const tuples = [];
    userIds.forEach((uid, i) => {
      const base = i * 5;
      tuples.push(
        `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5})`,
      );
      values.push(uid, type, title, body, JSON.stringify(payload));
    });

    await query(
      `INSERT INTO notifications (user_id, type, title, body, data)
       VALUES ${tuples.join(', ')}`,
      values,
    );
  }

  /**
   * Resolve all member IDs of a group (minus excluded users).
   */
  static async _groupMemberIds(groupId, excludeUserIds = []) {
    const params = [groupId];
    let excludeClause = '';
    if (excludeUserIds.length > 0) {
      const ph = excludeUserIds.map((_, i) => `$${i + 2}`).join(', ');
      excludeClause = `AND gm.user_id NOT IN (${ph})`;
      params.push(...excludeUserIds);
    }
    const result = await query(
      `SELECT DISTINCT gm.user_id
         FROM group_members gm
        WHERE gm.group_id = $1
          AND gm.deleted_at IS NULL
          ${excludeClause}`,
      params,
    );
    return result.rows.map((r) => r.user_id);
  }

  static async sendToUser(userId, type, data, additionalData = {}) {
    const allowedIds = await this._filterByPrefs([userId], type);
    await this._logInbox(allowedIds, type, data, additionalData);
    const tokens = await this._fetchTokens(allowedIds);
    return this._pushMany(tokens, type, data, additionalData);
  }

  static async sendToUsers(userIds, type, data, additionalData = {}) {
    const allowedIds = await this._filterByPrefs(userIds, type);
    await this._logInbox(allowedIds, type, data, additionalData);
    const tokens = await this._fetchTokens(allowedIds);
    return this._pushMany(tokens, type, data, additionalData);
  }

  static async sendToGroup(groupId, type, data, excludeUserIds = [], additionalData = {}) {
    const memberIds = await this._groupMemberIds(groupId, excludeUserIds);
    const allowedIds = await this._filterByPrefs(memberIds, type);
    await this._logInbox(allowedIds, type, data, additionalData);
    const tokens = await this._fetchTokens(allowedIds);
    return this._pushMany(tokens, type, data, additionalData);
  }

  static async _pushMany(tokens, type, data, additionalData) {
    if (!isFirebaseReady()) {
      logger.debug({ type }, '[NotificationService] Skipping — Firebase not initialized');
      return { success: false, reason: 'firebase_not_ready' };
    }
    if (tokens.length === 0) {
      return { success: true, sent: 0, failed: 0, reason: 'no_tokens' };
    }
    const config = NOTIFICATION_TYPES[type];
    if (!config) {
      logger.error({ type }, '[NotificationService] Unknown notification type');
      return { success: false, reason: 'unknown_type' };
    }

    // Build the multicast envelope once — only the token list varies
    // per chunk. The data payload must be all-strings (FCM rejects
    // mixed-type values silently in some SDK versions).
    const multicast = {
      notification: {
        title: config.title,
        body: config.getBody(data),
      },
      data: {
        type,
        ...additionalData,
        ...Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)]),
        ),
      },
      android: {
        notification: {
          channelId: config.channelId,
          priority: 'high',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    };

    // FCM caps multicast at 500 tokens per request. Chunk and dispatch
    // chunks in parallel — for a typical group expense (5-30 members)
    // we end up making exactly one upstream call.
    const CHUNK_SIZE = 500;
    const chunks = [];
    for (let i = 0; i < tokens.length; i += CHUNK_SIZE) {
      chunks.push(tokens.slice(i, i + CHUNK_SIZE));
    }

    const staleTokens = [];
    let sent = 0;
    let failed = 0;

    const chunkResults = await Promise.all(
      chunks.map((chunk) =>
        admin
          .messaging()
          .sendEachForMulticast({
            tokens: chunk.map((t) => t.token),
            ...multicast,
          })
          .then((batchResp) => ({ chunk, batchResp }))
          .catch((err) => ({ chunk, err })),
      ),
    );

    for (const r of chunkResults) {
      if (r.err) {
        // Whole chunk failed (network / quota / SDK error). Don't blame
        // individual tokens — log and count as failed; client refresh
        // will recover.
        logger.error(
          { err: r.err, type, batchSize: r.chunk.length },
          '[NotificationService] Multicast batch failed',
        );
        failed += r.chunk.length;
        continue;
      }
      const { batchResp, chunk } = r;
      batchResp.responses.forEach((resp, idx) => {
        if (resp.success) {
          sent += 1;
          return;
        }
        failed += 1;
        const code = resp.error?.code;
        const isInvalidToken =
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/invalid-argument';
        if (isInvalidToken) {
          staleTokens.push(chunk[idx].token);
        } else {
          logger.error(
            { err: resp.error, type },
            '[NotificationService] FCM send failed (per-token)',
          );
        }
      });
    }

    // Stale-token cleanup runs in parallel; do it after we've answered
    // the caller's count (already settled above) — but keep awaiting so
    // exceptions surface in logs.
    if (staleTokens.length > 0) {
      logger.warn(
        { count: staleTokens.length },
        '[NotificationService] Invalidating stale FCM tokens',
      );
      await Promise.all(staleTokens.map((tok) => this.invalidateToken(tok)));
    }

    return { success: true, sent, failed };
  }

  static async sendNotification(token, type, data, additionalData = {}) {
    try {
      const config = NOTIFICATION_TYPES[type];
      if (!config) {
        logger.error({ type }, '[NotificationService] Unknown notification type');
        return { success: false, reason: 'unknown_type' };
      }

      const message = {
        token,
        notification: {
          title: config.title,
          body: config.getBody(data),
        },
        data: {
          type,
          ...additionalData,
          ...Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)]),
          ),
        },
        android: {
          notification: {
            channelId: config.channelId,
            priority: 'high',
          },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      };

      const response = await admin.messaging().send(message);
      return { success: true, messageId: response };
    } catch (error) {
      // Token-invalidation paths are routine cleanup, not bugs — log at warn.
      // Any other FCM failure is a real bug worth surfacing.
      const isInvalidToken =
        error.code === 'messaging/registration-token-not-registered' ||
        error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/invalid-argument';
      if (isInvalidToken) {
        logger.warn({ code: error.code }, '[NotificationService] Stale FCM token — invalidating');
        await this.invalidateToken(token);
      } else {
        logger.error({ err: error, type }, '[NotificationService] FCM send failed');
      }
      return { success: false, error: error.message };
    }
  }

  /**
   * Remove a stale/invalid FCM token from user_devices. Also clears the
   * legacy users.fcm_token column if it still holds the same token.
   */
  static async invalidateToken(token) {
    try {
      await query(`DELETE FROM user_devices WHERE fcm_token = $1`, [token]);
      await query(
        `UPDATE users SET fcm_token = NULL, fcm_token_updated_at = NOW()
         WHERE fcm_token = $1`,
        [token],
      );
      logger.debug('[NotificationService] Invalidated stale token');
    } catch (error) {
      logger.error({ err: error }, '[NotificationService] Error invalidating token');
    }
  }

  /**
   * Register or refresh a device's FCM token. Upserts on the token itself
   * so re-registration from the same device collapses to one row.
   */
  static async registerDevice(userId, token, deviceInfo = {}) {
    try {
      await query(
        `INSERT INTO user_devices (user_id, fcm_token, platform, device_name, os_version, app_version, last_seen_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())
         ON CONFLICT (fcm_token) DO UPDATE
            SET user_id = EXCLUDED.user_id,
                platform = EXCLUDED.platform,
                device_name = EXCLUDED.device_name,
                os_version = EXCLUDED.os_version,
                app_version = EXCLUDED.app_version,
                last_seen_at = NOW()`,
        [
          userId,
          token,
          deviceInfo.platform || null,
          deviceInfo.deviceName || null,
          deviceInfo.osVersion || null,
          deviceInfo.appVersion || null,
        ],
      );
      return { success: true };
    } catch (error) {
      logger.error({ err: error, userId }, '[NotificationService] registerDevice failed');
      return { success: false, error: error.message };
    }
  }

  static async unregisterDevice(userId, token) {
    try {
      await query(
        `DELETE FROM user_devices WHERE user_id = $1 AND fcm_token = $2`,
        [userId, token],
      );
      return { success: true };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /** Legacy compat: keeps the existing PUT /users/:id/fcm-token endpoint working. */
  static async updateUserToken(userId, token, deviceInfo = {}) {
    await query(
      `UPDATE users SET fcm_token = $2, fcm_token_updated_at = NOW() WHERE id = $1`,
      [userId, token],
    );
    return this.registerDevice(userId, token, deviceInfo);
  }

  // =====================
  // Convenience methods (keep existing call sites working + add new ones)
  // =====================

  static async notifySettlementCreated(groupId, settlement, fromUserName, toUserName, excludeUserId) {
    const currencySymbols = { INR: '₹', USD: '$', EUR: '€', GBP: '£' };
    const currency = currencySymbols[settlement.currency] || settlement.currency;
    return this.sendToGroup(groupId, 'SETTLEMENT_CREATED', {
      fromUserName,
      toUserName,
      amount: settlement.amount,
      currency,
      groupId,
    }, [excludeUserId], { groupId, settlementId: settlement.id });
  }

  static async notifySettlementConfirmed(groupId, settlement, fromUserName, toUserName, excludeUserId) {
    const currencySymbols = { INR: '₹', USD: '$', EUR: '€', GBP: '£' };
    const currency = currencySymbols[settlement.currency] || settlement.currency;
    return this.sendToGroup(groupId, 'SETTLEMENT_CONFIRMED', {
      fromUserName,
      toUserName,
      amount: settlement.amount,
      currency,
      groupId,
    }, [excludeUserId], { groupId, settlementId: settlement.id });
  }

  static async notifyGroupArchived(groupId, groupName, excludeUserId) {
    return this.sendToGroup(groupId, 'GROUP_ARCHIVED', { groupName, groupId }, [excludeUserId], { groupId });
  }

  static async notifyGroupCompleted(groupId, groupName, excludeUserId) {
    return this.sendToGroup(groupId, 'GROUP_COMPLETED', { groupName, groupId }, [excludeUserId], { groupId });
  }

  static async notifyMemberRemoved(groupId, groupName, removedUserId, removedUserName, removedByUserId) {
    await this.sendToUser(removedUserId, 'MEMBER_REMOVED', {
      memberName: 'You',
      groupName,
      groupId,
    }, { groupId });
    return this.sendToGroup(groupId, 'MEMBER_REMOVED', {
      memberName: removedUserName,
      groupName,
      groupId,
    }, [removedUserId, removedByUserId], { groupId });
  }

  static async notifyMemberLeft(groupId, groupName, leftUserId, leftUserName) {
    return this.sendToGroup(groupId, 'MEMBER_LEFT', {
      memberName: leftUserName,
      groupName,
      groupId,
    }, [leftUserId], { groupId });
  }

  static async notifyMemberAdded(groupId, groupName, newMemberName, addedByUserId) {
    return this.sendToGroup(groupId, 'MEMBER_ADDED', {
      memberName: newMemberName,
      groupName,
      groupId,
    }, [addedByUserId], { groupId });
  }

  /**
   * Notify all group members (except the payer) that a new expense was added.
   */
  static async notifyExpenseAdded(groupId, expense, paidByName, groupName, currencyCode, excludeUserId) {
    const currencySymbols = { INR: '₹', USD: '$', EUR: '€', GBP: '£' };
    const currency = currencySymbols[currencyCode] || currencyCode || '';
    return this.sendToGroup(groupId, 'EXPENSE_ADDED', {
      paidByName,
      description: expense.description,
      amount: expense.amount,
      currency,
      groupName,
      groupId,
    }, [excludeUserId], { groupId, expenseId: expense.id });
  }

  /**
   * Notify a single user they've been invited to a group.
   */
  static async notifyGroupInvite(invitedUserId, groupId, groupName, inviterName) {
    return this.sendToUser(invitedUserId, 'GROUP_INVITE', {
      inviterName,
      groupName,
      groupId,
    }, { groupId });
  }

  /**
   * Notify a single user they have an unsettled balance reminder.
   */
  static async notifySettlementReminder(userId, groupId, groupName, amount, currencyCode) {
    const currencySymbols = { INR: '₹', USD: '$', EUR: '€', GBP: '£' };
    const currency = currencySymbols[currencyCode] || currencyCode || '';
    return this.sendToUser(userId, 'SETTLEMENT_REMINDER', {
      groupName,
      amount,
      currency,
      groupId,
    }, { groupId });
  }
}

export { NotificationService, NOTIFICATION_TYPES };
