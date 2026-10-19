import Group from '../models/Group.js';
import User from '../models/User.js';
import { query } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';

class GroupService {
  /**
   * Calculate group balances (cached — 120s TTL)
   * Most expensive computation: full table scan + O(n log n) algorithm
   */
  static async calculateBalances(groupId) {
    return cache.getOrSet(`group:${groupId}:balances`, TTL.GROUP_BALANCES, () => this._computeBalances(groupId));
  }

  static async _computeBalances(groupId) {

    // Get all expenses with splits for this group in a single query
    const expensesResult = await query(
      `SELECT e.paid_by, es.user_id, es.amount
       FROM expenses e
       JOIN expense_splits es ON e.id = es.expense_id
       WHERE e.group_id = $1 AND e.deleted_at IS NULL`,
      [groupId]
    );

    // O(n) net balance calculation: each user's net position
    // positive = owed money, negative = owes money
    const netBalance = new Map();

    for (const row of expensesResult.rows) {
      const paidBy = row.paid_by;
      const userId = row.user_id;
      const amount = +row.amount; // unary plus is faster than parseFloat

      if (userId !== paidBy) {
        // paidBy is owed money, userId owes money
        netBalance.set(paidBy, (netBalance.get(paidBy) || 0) + amount);
        netBalance.set(userId, (netBalance.get(userId) || 0) - amount);
      }
    }

    // Apply settlements: when A pays B ₹X, B's positive balance shrinks by X
    // and A's negative balance shrinks (becomes less negative) by X.
    // Only confirmed ('paid') settlements affect the balance. Pending
    // settlements await the recipient's confirmation before they count.
    // Failed / cancelled / null statuses are excluded.
    const settlementsResult = await query(
      `SELECT from_user_id, to_user_id, amount
       FROM settlements
       WHERE group_id = $1
         AND deleted_at IS NULL
         AND status = 'paid'`,
      [groupId]
    );

    for (const row of settlementsResult.rows) {
      const from = row.from_user_id;
      const to = row.to_user_id;
      const amount = +row.amount;
      netBalance.set(to, (netBalance.get(to) || 0) - amount);
      netBalance.set(from, (netBalance.get(from) || 0) + amount);
    }

    // Simplify debts using greedy algorithm — O(n log n)
    const creditors = []; // positive balance = owed money
    const debtors = [];   // negative balance = owes money

    for (const [userId, balance] of netBalance) {
      if (balance > 0.005) {
        creditors.push({ userId, amount: balance });
      } else if (balance < -0.005) {
        debtors.push({ userId, amount: -balance }); // store as positive
      }
    }

    // Sort descending by amount for optimal pairing
    creditors.sort((a, b) => b.amount - a.amount);
    debtors.sort((a, b) => b.amount - a.amount);

    const simplifiedBalances = [];
    let ci = 0, di = 0;

    while (ci < creditors.length && di < debtors.length) {
      const settleAmount = Math.min(creditors[ci].amount, debtors[di].amount);

      if (settleAmount > 0.005) {
        simplifiedBalances.push({
          fromUserId: debtors[di].userId,
          toUserId: creditors[ci].userId,
          amount: settleAmount.toFixed(2),
        });
      }

      creditors[ci].amount -= settleAmount;
      debtors[di].amount -= settleAmount;

      if (creditors[ci].amount < 0.005) ci++;
      if (debtors[di].amount < 0.005) di++;
    }

    return simplifiedBalances;
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
   * Pairwise debts for a single user in a group, derived from expense splits
   * + settlements. Returns Map<otherUserId, amount> where positive = the
   * user owes the other party that much; negative = the other party owes them.
   * Excludes failed/cancelled settlements.
   */
  static async getUserPairwiseDebts(groupId, userId) {
    const pair = new Map();

    const expensesResult = await query(
      `SELECT e.paid_by, es.user_id AS split_user, es.amount
       FROM expenses e
       JOIN expense_splits es ON e.id = es.expense_id
       WHERE e.group_id = $1 AND e.deleted_at IS NULL AND es.deleted_at IS NULL`,
      [groupId]
    );
    for (const r of expensesResult.rows) {
      const paidBy = r.paid_by;
      const splitUser = r.split_user;
      const amt = +r.amount;
      if (paidBy === userId && splitUser !== userId) {
        pair.set(splitUser, (pair.get(splitUser) || 0) - amt);
      } else if (paidBy !== userId && splitUser === userId) {
        pair.set(paidBy, (pair.get(paidBy) || 0) + amt);
      }
    }

    const settlementsResult = await query(
      `SELECT from_user_id, to_user_id, amount
       FROM settlements
       WHERE group_id = $1 AND deleted_at IS NULL
         AND status = 'paid'`,
      [groupId]
    );
    for (const r of settlementsResult.rows) {
      const amt = +r.amount;
      if (r.from_user_id === userId) {
        pair.set(r.to_user_id, (pair.get(r.to_user_id) || 0) - amt);
      } else if (r.to_user_id === userId) {
        pair.set(r.from_user_id, (pair.get(r.from_user_id) || 0) + amt);
      }
    }
    return pair;
  }

  /**
   * Every open pairwise debt across groups, in one query — same rules as
   * getUserPairwiseDebts (expense splits minus 'paid' settlements, netted per
   * pair). Used by the reminder and weekly-summary jobs.
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
      `WITH flows AS (
         SELECT e.group_id, es.user_id AS debtor, e.paid_by AS creditor, es.amount
           FROM expenses e
           JOIN expense_splits es ON es.expense_id = e.id
          WHERE e.deleted_at IS NULL AND es.deleted_at IS NULL
            AND es.user_id <> e.paid_by
         UNION ALL
         -- A paying B cancels A's debt to B: model it as B owing A.
         SELECT group_id, to_user_id, from_user_id, amount
           FROM settlements
          WHERE deleted_at IS NULL AND status = 'paid'
       ),
       net AS (
         SELECT group_id,
                LEAST(debtor, creditor) AS a,
                GREATEST(debtor, creditor) AS b,
                SUM(CASE WHEN debtor < creditor THEN amount ELSE -amount END) AS amt -- > 0: a owes b
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
