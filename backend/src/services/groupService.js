import Group from '../models/Group.js';
import User from '../models/User.js';
import { query } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';
import { flowsSql, groupNetPaise, simplify, userPairDebts } from './ledger.js';

class GroupService {
  /**
   * Simplified group balances (cached — 120s TTL): who should pay whom,
   * from the Ledger's per-member net positions.
   */
  static async calculateBalances(groupId) {
    return cache.getOrSet(`group:${groupId}:balances`, TTL.GROUP_BALANCES, () => this._computeBalances(groupId));
  }

  static async _computeBalances(groupId) {
    return simplify(await groupNetPaise(groupId));
  }

  /**
   * Validate group access
   */
  static async validateGroupAccess(groupId, userId) {
    const isMember = await Group.isMember(groupId, userId);
    if (!isMember) {
      throw new Error('User is not a member of this group');
    }
    return true;
  }

  /**
   * Validate admin access
   */
  static async validateAdminAccess(groupId, userId) {
    const isAdmin = await Group.isAdmin(groupId, userId);
    if (!isAdmin) {
      throw new Error('User is not an admin of this group');
    }
    return true;
  }

  /**
   * Pairwise debts for a single user in a group (see services/ledger.js).
   * Returns Map<otherUserId, amount> where positive = the user owes the
   * other party that much; negative = the other party owes them.
   */
  static async getUserPairwiseDebts(groupId, userId) {
    return userPairDebts(groupId, userId);
  }

  /**
   * Every open pairwise debt across groups, in one query — the Ledger's
   * flows netted per pair. Used by the reminder and weekly-summary jobs.
   *
   * Only live groups, current members and real (non-placeholder) accounts.
   *
   * @param {Object} [o]
   * @param {number}  [o.minAmount=0.01]  Ignore debts below this.
   * @param {boolean} [o.includeArchived=false]
   * @param {string}  [o.userId]          Only pairs involving this user.
   * @returns {Promise<Array<{groupId, groupName, currency, debtorId, debtorName, creditorId, creditorName, amount}>>}
   */
  static async getOpenPairwiseDebts({ minAmount = 0.01, includeArchived = false, userId = null } = {}) {
    const result = await query(
      `WITH flows AS (${flowsSql()}),
       net AS (
         SELECT group_id,
                LEAST(debtor_id, creditor_id) AS a,
                GREATEST(debtor_id, creditor_id) AS b,
                SUM(CASE WHEN debtor_id < creditor_id THEN amount ELSE -amount END) AS amt -- > 0: a owes b
           FROM flows
          GROUP BY 1, 2, 3
       )
       SELECT n.group_id, g.name AS group_name, g.currency,
              CASE WHEN n.amt > 0 THEN n.a ELSE n.b END AS debtor_id,
              CASE WHEN n.amt > 0 THEN n.b ELSE n.a END AS creditor_id,
              ABS(n.amt)::numeric(12,2) AS amount
         FROM net n
         JOIN groups g ON g.id = n.group_id AND g.deleted_at IS NULL
        WHERE ABS(n.amt) >= $1
          AND ($2::boolean OR COALESCE(g.is_archived, FALSE) = FALSE)
          AND ($3::uuid IS NULL OR n.a = $3::uuid OR n.b = $3::uuid)`,
      [minAmount, includeArchived, userId],
    );
    if (result.rows.length === 0) return [];

    // Drop pairs where either side has left the group or isn't a real account.
    const people = await query(
      `SELECT gm.group_id, gm.user_id, COALESCE(NULLIF(u.name, ''), gm.name) AS name
         FROM group_members gm
         JOIN users u ON u.id = gm.user_id
        WHERE gm.deleted_at IS NULL AND u.deleted_at IS NULL
          AND COALESCE(u.is_placeholder, FALSE) = FALSE
          AND gm.group_id = ANY($1::uuid[])`,
      [[...new Set(result.rows.map((r) => r.group_id))]],
    );
    const member = new Map(people.rows.map((p) => [`${p.group_id}:${p.user_id}`, p.name || 'A member']));

    return result.rows
      .filter((r) => member.has(`${r.group_id}:${r.debtor_id}`) && member.has(`${r.group_id}:${r.creditor_id}`))
      .map((r) => ({
        groupId: r.group_id,
        groupName: r.group_name,
        currency: r.currency || 'INR',
        debtorId: r.debtor_id,
        debtorName: member.get(`${r.group_id}:${r.debtor_id}`),
        creditorId: r.creditor_id,
        creditorName: member.get(`${r.group_id}:${r.creditor_id}`),
        amount: Number(r.amount),
      }));
  }

  /**
   * Invalidate every group member's per-user dashboard cache.
   *
   * Why: the dashboard endpoint caches under `user:<userId>:dashboard:<limit>`
   * (60s TTL). The existing Expense.invalidateGroupExpenses only nukes group-
   * keyed entries (`group:<id>:expenses`, `group:<id>:balances`), so the
   * dashboard summary cards continued to show stale "You owe / You're owed"
   * numbers for up to a minute after every expense or settlement write. Call
   * this from any controller that mutates expenses or settlements so all
   * affected users see fresh numbers on their next dashboard fetch.
   *
   * Best-effort: errors are swallowed (logged) — never block a successful
   * write because invalidation failed.
   */
  static async invalidateMemberDashboards(groupId) {
    try {
      const members = await Group.getMembers(groupId);
      for (const m of members) {
        if (m.user_id) {
          cache.invalidate(`user:${m.user_id}:dashboard`);
        }
      }
    } catch (err) {
      console.error('[GroupService] invalidateMemberDashboards failed:', err.message);
    }
  }
}

export default GroupService;
