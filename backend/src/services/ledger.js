import { query } from '../config/database.js';

/**
 * Ledger — the single definition of "who owes whom".
 *
 * Every balance in the app (group balances, pairwise debts, groups list,
 * dashboard, reports, reminder / weekly-summary jobs) is derived from the
 * same set of directed flows:
 *
 *   - an expense split: the split's user owes the payer their share
 *     (rows where the user is the payer cancel out and are skipped);
 *   - a 'paid' settlement A → B: cancels A's debt to B, i.e. B owes A.
 *
 * Pending / failed / deleted settlements, deleted expenses and deleted
 * split rows never count. Change these rules here and nowhere else.
 *
 * Money is summed in SQL (NUMERIC, exact) and handled in JS as integer
 * paise, so no floating-point drift reaches the simplification step.
 */

/**
 * SQL for the flow rows (group_id, debtor_id, creditor_id, amount).
 *
 * @param {string} [groupCond] Condition on group_id, e.g. "= $1" or
 *   "IN (SELECT group_id FROM active_groups)". It is applied inside both
 *   branches of the UNION so Postgres can use the group_id indexes.
 */
export function flowsSql(groupCond = null) {
  const e = groupCond ? `AND e.group_id ${groupCond}` : '';
  const s = groupCond ? `AND s.group_id ${groupCond}` : '';
  return `
    SELECT e.group_id, es.user_id AS debtor_id, e.paid_by AS creditor_id, es.amount
      FROM expenses e
      JOIN expense_splits es ON es.expense_id = e.id
     WHERE e.deleted_at IS NULL AND es.deleted_at IS NULL
       AND es.user_id <> e.paid_by ${e}
    UNION ALL
    -- A paying B cancels A's debt to B: model it as B owing A.
    SELECT s.group_id, s.to_user_id, s.from_user_id, s.amount
      FROM settlements s
     WHERE s.deleted_at IS NULL AND s.status = 'paid' ${s}`;
}

/**
 * SQL for one user's net position with every other user, per group:
 * rows (group_id, other_user_id, net) where net > 0 means the other user
 * owes `userParam`, net < 0 means `userParam` owes them.
 */
export function userPairNetsSql(userParam, groupCond = null) {
  return `
    SELECT group_id,
           CASE WHEN creditor_id = ${userParam} THEN debtor_id ELSE creditor_id END AS other_user_id,
           SUM(CASE WHEN creditor_id = ${userParam} THEN amount ELSE -amount END) AS net
      FROM (${flowsSql(groupCond)}) f
     WHERE debtor_id = ${userParam} OR creditor_id = ${userParam}
     GROUP BY 1, 2`;
}

export const toPaise = (amount) => Math.round(Number(amount) * 100);
export const fromPaise = (paise) => (paise / 100).toFixed(2);

/**
 * Each member's net position in a group, in paise.
 * @returns {Promise<Map<string, number>>} positive = is owed, negative = owes
 */
export async function groupNetPaise(groupId) {
  const result = await query(
    `SELECT v.user_id, SUM(v.delta) AS net
       FROM (${flowsSql('= $1')}) f
       CROSS JOIN LATERAL (VALUES (f.creditor_id, f.amount), (f.debtor_id, -f.amount)) v(user_id, delta)
      GROUP BY v.user_id`,
    [groupId],
  );
  const net = new Map();
  for (const r of result.rows) {
    const p = toPaise(r.net);
    if (p !== 0) net.set(r.user_id, p);
  }
  return net;
}

/**
 * Minimise the number of payments that settle a set of net positions
 * (greedy: largest debtor pays largest creditor). Exact in paise; ties are
 * broken by user id so the output is stable across calls and processes.
 *
 * @param {Map<string, number>} netPaise positive = is owed
 * @returns {Array<{fromUserId, toUserId, amount: string}>}
 */
export function simplify(netPaise) {
  const byAmount = (a, b) => b.amount - a.amount || (a.userId < b.userId ? -1 : 1);
  const creditors = [];
  const debtors = [];
  for (const [userId, p] of netPaise) {
    if (p > 0) creditors.push({ userId, amount: p });
    else if (p < 0) debtors.push({ userId, amount: -p });
  }
  creditors.sort(byAmount);
  debtors.sort(byAmount);

  const out = [];
  let ci = 0;
  let di = 0;
  while (ci < creditors.length && di < debtors.length) {
    const pay = Math.min(creditors[ci].amount, debtors[di].amount);
    out.push({ fromUserId: debtors[di].userId, toUserId: creditors[ci].userId, amount: fromPaise(pay) });
    creditors[ci].amount -= pay;
    debtors[di].amount -= pay;
    if (creditors[ci].amount === 0) ci++;
    if (debtors[di].amount === 0) di++;
  }
  return out;
}

/**
 * One user's pairwise debts in a group.
 * @returns {Promise<Map<string, number>>} otherUserId → rupees; positive =
 *   the user owes the other party, negative = the other party owes them.
 */
export async function userPairDebts(groupId, userId) {
  const result = await query(
    `SELECT other_user_id, net FROM (${userPairNetsSql('$2', '= $1')}) p WHERE net <> 0`,
    [groupId, userId],
  );
  return new Map(result.rows.map((r) => [r.other_user_id, -Number(r.net)]));
}
