import { query } from '../config/database.js';

/**
 * Ledger — the single definition of "who owes whom".
 *
 * Every balance in the app (group balances, pairwise debts, groups list,
 * dashboard, reports, reminder / weekly-summary jobs) is derived from the
 * same set of directed flows:
 *
 *   - an expense split: the split's user owes each payer their share of it,
 *     in proportion to what each payer paid (expense_payers);
 *   - a 'paid' settlement A → B: cancels A's debt to B, i.e. B owes A.
 *
 * Pending / failed / deleted settlements, deleted expenses and deleted
 * split rows never count. Change these rules here and nowhere else.
 *
 * Money is summed in SQL (NUMERIC, exact) and handled in JS as integer
 * paise, so no floating-point drift reaches the simplification step.
 */

/**
 * SQL for who paid each expense and what fraction of it:
 * rows (expense_id, user_id, share) with the shares of one expense summing
 * to 1. From expense_payers; an expense without payer rows (created before
 * migration 021, or by an old server during a deploy) counts as fully paid
 * by expenses.paid_by.
 */
function payersSql(groupCond) {
  const x = groupCond ? `AND x.group_id ${groupCond}` : '';
  return `
    SELECT ep.expense_id, ep.user_id,
           ep.amount / NULLIF(SUM(ep.amount) OVER (PARTITION BY ep.expense_id), 0) AS share
      FROM expense_payers ep
      JOIN expenses x ON x.id = ep.expense_id
     WHERE x.deleted_at IS NULL ${x}
    UNION ALL
    SELECT x.id, x.paid_by, 1
      FROM expenses x
     WHERE x.deleted_at IS NULL AND x.paid_by IS NOT NULL ${x}
       AND NOT EXISTS (SELECT 1 FROM expense_payers q WHERE q.expense_id = x.id)`;
}

/**
 * SQL for the flow rows (group_id, debtor_id, creditor_id, amount).
 *
 * An expense split: the split's user owes each payer their share of it
 * (one payer → the whole split amount, as before multi-payer). Rows where
 * the user is that payer cancel out and are skipped. Amounts are exact
 * NUMERIC; callers round to paise after summing.
 *
 * @param {string} [groupCond] Condition on group_id, e.g. "= $1" or
 *   "IN (SELECT group_id FROM active_groups)". It is applied inside every
 *   branch so Postgres can use the group_id indexes.
 */
export function flowsSql(groupCond = null) {
  const e = groupCond ? `AND e.group_id ${groupCond}` : '';
  const s = groupCond ? `AND s.group_id ${groupCond}` : '';
  return `
    SELECT e.group_id, es.user_id AS debtor_id, p.user_id AS creditor_id, es.amount * p.share AS amount
      FROM expenses e
      JOIN expense_splits es ON es.expense_id = e.id
      JOIN (${payersSql(groupCond)}) p ON p.expense_id = e.id
     WHERE e.deleted_at IS NULL AND es.deleted_at IS NULL
       AND es.user_id <> p.user_id ${e}
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
 * Each member's net position in each of several groups, in paise.
 * @returns {Promise<Map<string, Map<string, number>>>} groupId → (userId →
 *   paise; positive = is owed, negative = owes). Zero nets are omitted.
 */
export async function groupsNetPaise(groupIds) {
  const out = new Map();
  if (groupIds.length === 0) return out;
  const result = await query(
    `SELECT f.group_id, v.user_id, SUM(v.delta) AS net
       FROM (${flowsSql('= ANY($1::uuid[])')}) f
       CROSS JOIN LATERAL (VALUES (f.creditor_id, f.amount), (f.debtor_id, -f.amount)) v(user_id, delta)
      GROUP BY f.group_id, v.user_id`,
    [groupIds],
  );
  for (const r of result.rows) {
    const p = toPaise(r.net);
    if (p === 0) continue;
    if (!out.has(r.group_id)) out.set(r.group_id, new Map());
    out.get(r.group_id).set(r.user_id, p);
  }
  return out;
}

/**
 * Each member's net position in a group, in paise.
 * @returns {Promise<Map<string, number>>} positive = is owed, negative = owes
 */
export async function groupNetPaise(groupId) {
  return (await groupsNetPaise([groupId])).get(groupId) ?? new Map();
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
 * One user's raw pairwise debts in a group, ignoring simplify_debts. Used
 * where every underlying debt must be cleared (leaving / removing a member);
 * for what the user sees, use userVisibleDebts.
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

/**
 * The ids (of `groupIds`) of groups with "Simplify group debts" on.
 * @returns {Promise<Set<string>>}
 */
export async function simplifiedGroupIds(groupIds) {
  if (groupIds.length === 0) return new Set();
  const result = await query(
    'SELECT id FROM groups WHERE id = ANY($1::uuid[]) AND simplify_debts',
    [groupIds],
  );
  return new Set(result.rows.map((r) => r.id));
}

/**
 * The debts a user sees, per group and other user — what the Balances tab,
 * groups list, dashboard, reports, friends and settle-all agree on.
 *
 * Normally the raw pairwise net. In a group with simplify_debts on, the
 * transfers of simplify() instead: every member's total is unchanged, but
 * debts are re-routed to minimise the number of payments, so the user may
 * owe someone they never shared an expense with.
 *
 * @param {string}   userId
 * @param {string[]} groupIds
 * @returns {Promise<Array<{group_id, other_user_id, net: number}>>} rupees;
 *   net > 0 = the other user owes `userId`. Zero rows are omitted.
 */
export async function userPairNets(userId, groupIds) {
  if (groupIds.length === 0) return [];
  const simplified = await simplifiedGroupIds(groupIds);
  const plain = groupIds.filter((id) => !simplified.has(id));
  const rows = [];

  if (plain.length > 0) {
    const result = await query(
      `SELECT group_id, other_user_id, net
         FROM (${userPairNetsSql('$1', '= ANY($2::uuid[])')}) p
        WHERE net <> 0`,
      [userId, plain],
    );
    for (const r of result.rows) {
      rows.push({ group_id: r.group_id, other_user_id: r.other_user_id, net: Number(r.net) });
    }
  }

  for (const [groupId, net] of await groupsNetPaise([...simplified])) {
    for (const t of simplify(net)) {
      if (t.toUserId === userId) {
        rows.push({ group_id: groupId, other_user_id: t.fromUserId, net: Number(t.amount) });
      } else if (t.fromUserId === userId) {
        rows.push({ group_id: groupId, other_user_id: t.toUserId, net: -Number(t.amount) });
      }
    }
  }
  return rows;
}

/**
 * One user's visible debts in a group (see userPairNets), with the same
 * sign convention as userPairDebts: positive = the user owes the other.
 * @returns {Promise<Map<string, number>>}
 */
export async function userVisibleDebts(groupId, userId) {
  const rows = await userPairNets(userId, [groupId]);
  return new Map(rows.map((r) => [r.other_user_id, -r.net]));
}
