/**
 * Notification Service — the single dispatcher for user notifications.
 *
 * One call (sendToUser / sendToUsers / sendToGroup) fans out to every
 * channel the type is configured for:
 *   - inbox: in-app notifications feed (unless the type sets inbox: false)
 *   - push:  Firebase Cloud Messaging via user_devices (multi-device)
 *   - email: rendered from emailTemplates.js and queued in EmailOutbox
 *
 * Channel rules (see _resolveChannels):
 *   - The type's category toggle (prefKey) gates every channel.
 *   - push_enabled only gates push; the inbox stays populated.
 *   - email_enabled gates email, and only verified addresses get mail.
 *   - `security: true` types ignore prefs and email verification — those
 *     mails always go out.
 *   - `allowUnverified: true` types still respect prefs but may reach an
 *     unverified address (welcome mail — nothing sensitive in it).
 *
 * additionalData keys that never reach the device or inbox:
 *   dedupeId      entity id for email de-duplication
 *   emailContext  { [userId]: {...} } extra per-recipient template data
 */

import admin from 'firebase-admin';
import { query } from '../config/database.js';
import { isFirebaseReady } from '../config/firebaseAdmin.js';
import { logger } from '../utils/logger.js';
import { currencySymbol } from '../utils/currency.js';
import * as EmailTemplates from './emailTemplates.js';
import { enqueue as enqueueEmail } from './emailOutbox.js';
import GroupService from './groupService.js';

/**
 * Notification types.
 *   prefKey   column in notification_prefs gating this type (null = no toggle)
 *   email     template (data, recipient) => { subject, text, html }
 *   security  always deliver email, regardless of prefs / verification
 *   allowUnverified  email may go to an unverified address (prefs still apply)
 *   inbox     false to skip the in-app feed
 *   push      false to skip FCM
 */
const NOTIFICATION_TYPES = {
  SETTLEMENT_CREATED: {
    title: 'Payment received',
    getBody: (data) => `${data.fromUserName} paid you ${data.currency}${data.amount}`
      + (data.groupName ? ` in "${data.groupName}"` : ''),
    channelId: 'payments',
    prefKey: 'payment_received',
    email: EmailTemplates.settlementReceived,
  },
  SETTLE_ALL_RECEIVED: {
    title: 'Payment received',
    getBody: (data) => (data.groupCount === '1'
      ? `${data.fromUserName} paid you ${data.currency}${data.amount} in "${data.groupName}"`
      : `${data.fromUserName} paid you ${data.currency}${data.amount} and settled up across ${data.groupCount} groups`),
    channelId: 'payments',
    prefKey: 'payment_received',
    email: EmailTemplates.settlementReceived,
  },
  SETTLEMENT_DELETED: {
    title: 'Payment deleted',
    getBody: (data) => `${data.actorName} deleted the ${data.currency}${data.amount} payment from ${data.fromUserName} to ${data.toUserName} in "${data.groupName}"`,
    channelId: 'payments',
    prefKey: 'payment_received',
    email: EmailTemplates.settlementDeleted,
  },
  SETTLEMENT_CONFIRMED: {
    title: 'Payment confirmed',
    getBody: (data) => `${data.toUserName} confirmed receiving ${data.currency}${data.amount} from ${data.fromUserName}`,
    channelId: 'payments',
    prefKey: 'payment_received',
  },
  SETTLEMENT_REMINDER: {
    title: 'Time to settle up',
    getBody: (data) => (data.fromUserName
      ? `You owe ${data.fromUserName} ${data.currency}${data.amount} in "${data.groupName}"`
      : `You owe ${data.currency}${data.amount} in "${data.groupName}"`),
    channelId: 'payments',
    prefKey: 'settlement_reminder',
    email: EmailTemplates.settlementReminder,
  },

  UPI_ID_REQUESTED: {
    title: 'Add your UPI ID',
    getBody: (data) => `${data.requesterName} wants to pay you ${data.currency}${data.amount}. Add your UPI ID so they can pay in one tap`,
    channelId: 'payments',
    prefKey: 'payment_received',
  },
  PAYMENT_NOT_RECEIVED: {
    title: 'Payment not received',
    getBody: (data) => `${data.toUserName} says they didn't receive your ${data.currency}${data.amount} payment in "${data.groupName}". It was removed, so the balance is open again`,
    channelId: 'payments',
    prefKey: 'payment_received',
  },

  GROUP_INVITE: {
    title: 'New group invite',
    getBody: (data) => `${data.inviterName} invited you to ${data.groupName}`,
    channelId: 'groups',
    prefKey: 'group_invite',
    email: EmailTemplates.groupInvite,
  },
  GROUP_ARCHIVED: {
    title: 'Group archived',
    getBody: (data) => `"${data.groupName}" has been archived`,
    channelId: 'groups',
    prefKey: null,
    email: EmailTemplates.groupClosedSummary,
  },
  GROUP_COMPLETED: {
    title: 'Group completed',
    getBody: (data) => `"${data.groupName}" is all settled up and marked complete`,
    channelId: 'groups',
    prefKey: null,
    email: EmailTemplates.groupClosedSummary,
  },
  GROUP_DELETED: {
    title: 'Group deleted',
    getBody: (data) => `${data.actorName} deleted "${data.groupName}"`,
    channelId: 'groups',
    prefKey: null,
    email: EmailTemplates.groupDeleted,
  },

  MEMBER_REMOVED: {
    title: 'Member removed',
    getBody: (data) => `${data.memberName} was removed from "${data.groupName}"`,
    channelId: 'groups',
    prefKey: null,
  },
  REMOVED_FROM_GROUP: {
    title: 'Removed from group',
    getBody: (data) => `${data.actorName} removed you from "${data.groupName}"`,
    channelId: 'groups',
    prefKey: null,
    email: EmailTemplates.removedFromGroup,
  },
  BALANCE_WRITTEN_OFF: {
    title: 'Balance written off',
    getBody: (data) => (data.youOwed === 'true'
      ? `Your ${data.currency}${data.amount} owed to ${data.memberName} in "${data.groupName}" was cleared`
      : `${data.currency}${data.amount} owed to you by ${data.memberName} in "${data.groupName}" was written off`),
    channelId: 'payments',
    prefKey: 'payment_received',
    email: EmailTemplates.balanceWrittenOff,
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
    getBody: (data) => `${data.paidByName} added "${data.description}" (${data.currency}${data.amount}) in "${data.groupName}"`
      + (data.yourShare ? ` · you owe ${data.currency}${data.yourShare}` : ''),
    channelId: 'expenses',
    prefKey: 'new_expense',
  },
  EXPENSE_UPDATED: {
    title: 'Expense updated',
    getBody: (data) => `${data.actorName} updated "${data.description}" (${data.currency}${data.amount}) in "${data.groupName}"`,
    channelId: 'expenses',
    prefKey: 'new_expense',
  },
  EXPENSE_DELETED: {
    title: 'Expense deleted',
    getBody: (data) => `${data.actorName} deleted "${data.description}" (${data.currency}${data.amount}) from "${data.groupName}"`,
    channelId: 'expenses',
    prefKey: 'new_expense',
  },

  // Security — email always goes out; no category toggle.
  NEW_LOGIN: {
    title: 'New sign-in',
    getBody: (data) => `Your account was signed in on ${data.deviceName || data.platform || 'a new device'}`,
    channelId: 'account',
    prefKey: null,
    security: true,
    email: EmailTemplates.newLogin,
  },
  PASSWORD_CHANGED: {
    title: 'Password changed',
    getBody: () => 'Your KharchaSplit password was changed',
    channelId: 'account',
    prefKey: null,
    security: true,
    push: false,
    email: EmailTemplates.passwordChanged,
  },
  SESSIONS_REVOKED: {
    title: 'Signed out everywhere',
    getBody: (data) => `Your account was signed out of ${data.revokedCount} other session(s)`,
    channelId: 'account',
    prefKey: null,
    security: true,
    push: false,
    email: EmailTemplates.sessionsRevoked,
  },
  WEEKLY_SUMMARY: {
    title: 'Your week on KharchaSplit',
    getBody: () => 'Your weekly summary is in your inbox',
    channelId: 'account',
    prefKey: 'weekly_summary',
    inbox: false,
    push: false,
    email: EmailTemplates.weeklySummary,
  },
  WELCOME: {
    title: 'Welcome to KharchaSplit',
    getBody: () => 'Your account is ready',
    channelId: 'account',
    prefKey: null,
    allowUnverified: true,
    inbox: false,
    push: false,
    email: EmailTemplates.welcome,
  },
  ACCOUNT_DELETED: {
    title: 'Account deleted',
    getBody: () => 'Your KharchaSplit account was deleted',
    channelId: 'account',
    prefKey: null,
    security: true,
    inbox: false,
    push: false,
    email: EmailTemplates.accountDeleted,
  },
};

const DEFAULT_PREFS = {
  push_enabled: true,
  email_enabled: true,
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
   * Decide, per channel, which of `userIds` should receive `type`.
   * Returns { inboxIds, pushIds, emailRecipients: [{ id, name, email }] }.
   */
  static async _resolveChannels(userIds, type) {
    const empty = { inboxIds: [], pushIds: [], emailRecipients: [] };
    if (!userIds || userIds.length === 0) return empty;
    const config = NOTIFICATION_TYPES[type];
    if (!config) return empty;

    const prefs = await this.getPrefsForUsers(userIds);
    const categoryOn = (uid) => {
      if (config.security || !config.prefKey) return true;
      const p = prefs[uid] || DEFAULT_PREFS;
      return p[config.prefKey] !== false;
    };
    const allowed = userIds.filter(categoryOn);

    const inboxIds = config.inbox === false ? [] : allowed;
    const pushIds = config.push === false
      ? []
      : allowed.filter((uid) => (prefs[uid] || DEFAULT_PREFS).push_enabled);

    let emailRecipients = [];
    const emailIds = config.email
      ? allowed.filter((uid) => config.security || (prefs[uid] || DEFAULT_PREFS).email_enabled)
      : [];
    if (emailIds.length > 0) {
      // Security mail still reaches a just-deleted account, so no
      // deleted_at filter for those.
      const result = await query(
        `SELECT id, name, email, email_verified_at
           FROM users
          WHERE id = ANY($1::uuid[])
            ${config.security ? '' : 'AND deleted_at IS NULL'}`,
        [emailIds],
      );
      emailRecipients = result.rows
        .filter((u) => u.email && u.email.includes('@'))
        .filter((u) => config.security || config.allowUnverified || u.email_verified_at)
        .map((u) => ({ id: u.id, name: u.name, email: u.email }));
    }

    return { inboxIds, pushIds, emailRecipients };
  }

  /**
   * Render and queue one email per recipient. Never throws — email trouble
   * must not break the request that triggered it.
   */
  static async _queueEmails(recipients, type, data, additionalData) {
    const config = NOTIFICATION_TYPES[type];
    if (!config?.email || recipients.length === 0) return;
    await Promise.all(recipients.map(async (r) => {
      try {
        const { emailContext, ...rest } = additionalData;
        const perRecipient = emailContext?.[r.id] || {};
        const { subject, text, html } = config.email({ ...rest, ...data, ...perRecipient }, r);
        // One mail per (type, entity, recipient) — a retried request is a no-op.
        const entity = additionalData.dedupeId || additionalData.settlementId || additionalData.expenseId;
        const dedupeKey = entity ? `${type}:${entity}:${r.id}` : null;
        await enqueueEmail({ userId: r.id, toEmail: r.email, type, subject, text, html, dedupeKey });
      } catch (err) {
        logger.error({ err, type, userId: r.id }, '[NotificationService] email queue failed');
      }
    }));
  }

  /** Shared fan-out used by sendToUser / sendToUsers / sendToGroup. */
  static async _deliver(userIds, type, data, additionalData = {}) {
    const { inboxIds, pushIds, emailRecipients } = await this._resolveChannels(userIds, type);
    // Internal-only keys never go to the device payload.
    const { dedupeId, emailContext, ...pushExtra } = additionalData;
    await this._logInbox(inboxIds, type, data, pushExtra);
    await this._queueEmails(emailRecipients, type, data, additionalData);
    const tokens = await this._fetchTokens(pushIds);
    return this._pushMany(tokens, type, data, pushExtra);
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
    return this._deliver([userId], type, data, additionalData);
  }

  static async sendToUsers(userIds, type, data, additionalData = {}) {
    return this._deliver([...new Set(userIds)], type, data, additionalData);
  }

  static async sendToGroup(groupId, type, data, excludeUserIds = [], additionalData = {}) {
    const memberIds = await this._groupMemberIds(groupId, excludeUserIds);
    return this._deliver(memberIds, type, data, additionalData);
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

  /**
   * Settlements are final on creation — only the recipient is told
   * (inbox + push + email).
   */
  static async notifySettlementCreated(groupId, settlement, fromUserName, toUserName, extra = {}) {
    return this.sendToUser(settlement.to_user_id, 'SETTLEMENT_CREATED', {
      fromUserName,
      toUserName,
      amount: settlement.amount,
      currency: currencySymbol(settlement.currency),
      currencyCode: settlement.currency,
      groupName: extra.groupName || '',
      notes: settlement.notes || '',
      groupId,
    }, { groupId, settlementId: settlement.id });
  }

  static async notifySettlementConfirmed(groupId, settlement, fromUserName, toUserName, excludeUserId) {
    return this.sendToGroup(groupId, 'SETTLEMENT_CONFIRMED', {
      fromUserName,
      toUserName,
      amount: settlement.amount,
      currency: currencySymbol(settlement.currency),
      groupId,
    }, [excludeUserId], { groupId, settlementId: settlement.id });
  }

  /**
   * A settlement was removed, so the money counts as owed again. Tell both
   * parties except whoever removed it.
   */
  static async notifySettlementDeleted(groupId, groupName, settlement, actorId, actorName) {
    const recipients = [settlement.from_user_id, settlement.to_user_id].filter((id) => id && id !== actorId);
    return this.sendToUsers(recipients, 'SETTLEMENT_DELETED', {
      actorName,
      fromUserName: settlement.from_user_name || 'Someone',
      toUserName: settlement.to_user_name || 'someone',
      amount: settlement.amount,
      currency: currencySymbol(settlement.currency),
      currencyCode: settlement.currency,
      groupName,
      groupId,
    }, { groupId, settlementId: settlement.id });
  }

  /**
   * Archived / completed: push to everyone except the admin, plus a summary
   * email per member listing their own open balances.
   */
  static async _notifyGroupClosed(type, closeKind, groupId, groupName, actorId) {
    const [memberIds, actor, groupRow, totals] = await Promise.all([
      this._groupMemberIds(groupId, [actorId]),
      query('SELECT name FROM users WHERE id = $1', [actorId]),
      query('SELECT currency FROM groups WHERE id = $1', [groupId]),
      query(
        `SELECT COALESCE(SUM(amount), 0) AS total
           FROM expenses WHERE group_id = $1 AND deleted_at IS NULL`,
        [groupId],
      ),
    ]);
    const memberNames = await query(
      `SELECT gm.user_id, COALESCE(u.name, gm.name) AS name
         FROM group_members gm LEFT JOIN users u ON u.id = gm.user_id
        WHERE gm.group_id = $1`,
      [groupId],
    );
    const nameOf = Object.fromEntries(memberNames.rows.map((r) => [r.user_id, r.name || 'A member']));

    const emailContext = {};
    await Promise.all(memberIds.map(async (uid) => {
      const pair = await GroupService.getUserVisibleDebts(groupId, uid);
      emailContext[uid] = {
        balances: [...pair.entries()]
          .filter(([, amt]) => Math.abs(amt) > 0.005)
          .map(([otherId, amt]) => ({ otherName: nameOf[otherId] || 'A member', amount: Math.abs(amt), youOwe: amt > 0 })),
      };
    }));

    return this.sendToUsers(memberIds, type, {
      groupName,
      groupId,
      actorName: actor.rows[0]?.name || 'An admin',
      closeKind,
      totalSpent: totals.rows[0].total,
      currencyCode: groupRow.rows[0]?.currency || 'INR',
    }, { groupId, emailContext });
  }

  static async notifyGroupArchived(groupId, groupName, excludeUserId) {
    return this._notifyGroupClosed('GROUP_ARCHIVED', 'archived', groupId, groupName, excludeUserId);
  }

  static async notifyGroupCompleted(groupId, groupName, excludeUserId) {
    return this._notifyGroupClosed('GROUP_COMPLETED', 'completed', groupId, groupName, excludeUserId);
  }

  /**
   * Admin removed someone. The removed user gets their own notice (with any
   * written-off balances); the rest of the group gets MEMBER_REMOVED; anyone
   * whose balance with them was written off is told the amount.
   */
  static async notifyMemberRemoved(groupId, groupName, removedUserId, removedUserName, removedByUserId, extra = {}) {
    const { actorName = 'An admin', currencyCode = 'INR', writeOffs = [] } = extra;
    await this.sendToUser(removedUserId, 'REMOVED_FROM_GROUP', {
      actorName,
      groupName,
      groupId,
      currencyCode,
    }, {
      groupId,
      dedupeId: `removed-${groupId}-${Date.now()}`,
      emailContext: {
        [removedUserId]: {
          writeOffs: writeOffs.map((w) => ({ otherName: w.otherName, amount: w.amount, youOwed: w.removedOwed })),
        },
      },
    });
    // The admin doing the removal already knows about their own write-off.
    const othersWrittenOff = writeOffs.filter((w) => w.otherUserId !== removedByUserId);
    await Promise.all(othersWrittenOff.map((w) => this.sendToUser(w.otherUserId, 'BALANCE_WRITTEN_OFF', {
      actorName,
      memberName: removedUserName,
      groupName,
      groupId,
      amount: Number(w.amount).toFixed(2),
      currency: currencySymbol(currencyCode),
      currencyCode,
      // From the other party's side: they owed the removed member.
      youOwed: String(!w.removedOwed),
    }, { groupId })));
    return this.sendToGroup(groupId, 'MEMBER_REMOVED', {
      memberName: removedUserName,
      groupName,
      groupId,
    }, [removedUserId, removedByUserId, ...writeOffs.map((w) => w.otherUserId)], { groupId });
  }

  static async notifyMemberLeft(groupId, groupName, leftUserId, leftUserName) {
    return this.sendToGroup(groupId, 'MEMBER_LEFT', {
      memberName: leftUserName,
      groupName,
      groupId,
    }, [leftUserId], { groupId });
  }

  /**
   * Someone joined from a pending invite (registered after being invited by
   * phone). Tell the rest of the group, the inviter included.
   */
  static async notifyMemberJoined(groupId, groupName, newUserId, newMemberName) {
    return this.sendToGroup(groupId, 'MEMBER_ADDED', {
      memberName: newMemberName || 'A new member',
      groupName,
      groupId,
    }, [newUserId], { groupId });
  }

  static async notifyMemberAdded(groupId, groupName, newMemberName, addedByUserId) {
    return this.sendToGroup(groupId, 'MEMBER_ADDED', {
      memberName: newMemberName,
      groupName,
      groupId,
    }, [addedByUserId], { groupId });
  }

  /**
   * Notify all group members (except whoever added it) that a new expense
   * was added. Participants also see their own share in the message.
   *
   * @param {Array<{userId: string, amount: number}>} [participants]
   */
  static async notifyExpenseAdded(groupId, expense, paidByName, groupName, currencyCode, excludeUserId, participants = []) {
    const base = {
      paidByName,
      description: expense.description,
      amount: expense.amount,
      currency: currencySymbol(currencyCode),
      groupName,
      groupId,
    };
    const extra = { groupId, expenseId: expense.id };
    const shares = new Map(
      participants
        .filter((p) => p.userId && p.userId !== excludeUserId && Number(p.amount) > 0)
        .map((p) => [p.userId, Number(p.amount).toFixed(2)]),
    );
    const memberIds = await this._groupMemberIds(groupId, [excludeUserId]);
    const others = memberIds.filter((id) => !shares.has(id));
    await Promise.all([
      ...[...shares].filter(([id]) => memberIds.includes(id)).map(([id, share]) =>
        this.sendToUser(id, 'EXPENSE_ADDED', { ...base, yourShare: share }, extra)),
      others.length ? this.sendToUsers(others, 'EXPENSE_ADDED', base, extra) : null,
    ]);
  }

  /**
   * Expense edited or deleted — notify everyone whose share it touched
   * (participants before and after the change, plus the payer), except the
   * person who made the change.
   */
  static async notifyExpenseChanged(type, { groupId, groupName, expense, actorId, actorName, affectedUserIds }) {
    const recipients = [...new Set(affectedUserIds)].filter((id) => id && id !== actorId);
    return this.sendToUsers(recipients, type, {
      actorName,
      description: expense.description,
      amount: expense.amount,
      currency: currencySymbol(expense.currency),
      groupName,
      groupId,
    }, { groupId, expenseId: expense.id });
  }

  /**
   * Group deleted — every member except the admin who deleted it.
   */
  static async notifyGroupDeleted(groupId, groupName, actorId, actorName) {
    return this.sendToGroup(groupId, 'GROUP_DELETED', {
      groupName,
      actorName,
      groupId,
    }, [actorId], { groupId, dedupeId: `group-${groupId}` });
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
  static async notifySettlementReminder(userId, { groupId, groupName, amount, currencyCode, fromUserId, fromUserName, auto = false }) {
    return this.sendToUser(userId, 'SETTLEMENT_REMINDER', {
      groupName,
      amount,
      currency: currencySymbol(currencyCode),
      currencyCode,
      fromUserName: fromUserName || '',
      groupId,
    }, {
      groupId,
      fromUserId: fromUserId || '',
      // Scheduled (jobs/settlementReminderJob.js) rather than sent by a person.
      ...(auto ? { auto: 'true' } : {}),
    });
  }

  // =====================
  // Security notices — email always goes out (see `security: true`)
  // =====================

  static async notifyNewLogin(userId, device = {}) {
    return this.sendToUser(userId, 'NEW_LOGIN', {
      deviceName: device.deviceName || '',
      platform: device.platform || '',
      ipAddress: device.ipAddress || '',
      at: new Date().toISOString(),
    });
  }

  static async notifyPasswordChanged(userId) {
    return this.sendToUser(userId, 'PASSWORD_CHANGED', { at: new Date().toISOString() });
  }

  static async notifySessionsRevoked(userId, revokedCount) {
    return this.sendToUser(userId, 'SESSIONS_REVOKED', {
      revokedCount: String(revokedCount),
      at: new Date().toISOString(),
    });
  }

  static async notifyWelcome(userId) {
    return this.sendToUser(userId, 'WELCOME', {}, { dedupeId: `welcome-${userId}` });
  }

  static async notifyAccountDeleted(userId) {
    return this.sendToUser(userId, 'ACCOUNT_DELETED', { at: new Date().toISOString() });
  }
}

export { NotificationService, NOTIFICATION_TYPES };
