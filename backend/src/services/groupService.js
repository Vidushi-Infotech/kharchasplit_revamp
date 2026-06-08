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
