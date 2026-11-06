/**
 * Diagnostic: trace dashboard balance for a phone number.
 *
 * Usage:
 *   cd backend && node scripts/diagnose-dashboard.js <phoneE164>
 *
 * Pulls the user's id, then walks:
 *   1. Active groups for this user.
 *   2. Per-expense contributions (what this user paid vs owes per expense).
 *   3. Per-settlement contributions.
 *   4. Same SQL the /dashboard endpoint runs, so we see whether the bug is in
 *      data (split rows not pointing at this user) or in calculation (SQL).
 */
import 'dotenv/config';
import { pool, query } from '../src/config/database.js';

const arg = process.argv[2];
if (!arg) {
  console.error('Usage: node scripts/diagnose-dashboard.js <phoneE164 like +917744847294 or 7744847294>');
  process.exit(2);
}

// Normalize: 10-digit Indian → +91...; bare digits → assume already in international form
let phone = arg.replace(/\D/g, '');
if (phone.length === 10) phone = '91' + phone;
const phoneE164 = '+' + phone;

console.log(`Looking up user by phone ${phoneE164}…`);

const userRow = await query(
  `SELECT id, name, phone_number, email
   FROM users
   WHERE phone_number = $1 AND deleted_at IS NULL`,
  [phoneE164]
);
if (userRow.rows.length === 0) {
  console.error('User not found.');
  await pool.end();
  process.exit(1);
}
const user = userRow.rows[0];
console.log('User:', user);

const userId = user.id;

console.log('\n=== Active groups for this user ===');
const groups = await query(
  `SELECT g.id, g.name, g.currency
   FROM groups g
   JOIN group_members gm ON gm.group_id = g.id
   WHERE gm.user_id = $1 AND gm.deleted_at IS NULL AND g.deleted_at IS NULL
   ORDER BY g.updated_at DESC`,
  [userId]
);
console.table(groups.rows);

console.log('\n=== ALL expenses in these groups (just the rows) ===');
const expenses = await query(
  `SELECT e.id, e.group_id, g.name AS group_name, e.description, e.amount,
          e.paid_by, pu.name AS paid_by_name, e.deleted_at
   FROM expenses e
   JOIN groups g ON g.id = e.group_id
   LEFT JOIN users pu ON pu.id = e.paid_by
   WHERE e.group_id IN (
     SELECT group_id FROM group_members
     WHERE user_id = $1 AND deleted_at IS NULL
   )
   ORDER BY e.created_at DESC
   LIMIT 20`,
  [userId]
);
console.table(expenses.rows);

console.log('\n=== Per-expense contributions (paid-by vs my split row) ===');
const contribs = await query(
  `SELECT e.id AS expense_id,
          e.description,
          e.amount AS expense_amount,
          e.paid_by AS payer_id,
          (e.paid_by = $1) AS i_paid,
          es.user_id AS split_user_id,
          (es.user_id = $1) AS this_split_is_mine,
          es.amount AS split_amount,
          CASE
            WHEN e.paid_by = $1 AND es.user_id != $1 THEN es.amount
            WHEN e.paid_by != $1 AND es.user_id = $1 THEN -es.amount
            ELSE 0
          END AS my_contribution
   FROM expenses e
   JOIN expense_splits es ON es.expense_id = e.id
   WHERE e.deleted_at IS NULL
     AND e.group_id IN (
       SELECT group_id FROM group_members
       WHERE user_id = $1 AND deleted_at IS NULL
     )
   ORDER BY e.created_at DESC
   LIMIT 50`,
  [userId]
);
console.table(contribs.rows);

console.log('\n=== Per-group net (expenses only) ===');
const perGroupExpenses = await query(
  `SELECT e.group_id, g.name AS group_name,
          SUM(CASE
            WHEN e.paid_by = $1 AND es.user_id != $1 THEN es.amount
            WHEN e.paid_by != $1 AND es.user_id = $1 THEN -es.amount
            ELSE 0
          END) AS net_from_expenses
   FROM expenses e
   JOIN expense_splits es ON es.expense_id = e.id
   JOIN groups g ON g.id = e.group_id
   WHERE e.deleted_at IS NULL
     AND e.group_id IN (
       SELECT group_id FROM group_members
       WHERE user_id = $1 AND deleted_at IS NULL
     )
   GROUP BY e.group_id, g.name`,
  [userId]
);
console.table(perGroupExpenses.rows);

console.log('\n=== Settlements affecting this user (paid status only after fix) ===');
const settlements = await query(
  `SELECT id, group_id, from_user_id, to_user_id, amount, status, deleted_at, created_at
   FROM settlements
   WHERE (from_user_id = $1 OR to_user_id = $1)
     AND deleted_at IS NULL
   ORDER BY created_at DESC
   LIMIT 20`,
  [userId]
);
console.table(settlements.rows);

console.log('\n=== Per-pair net per group (NEW Splitwise-style breakdown) ===');
const pairs = await query(
  `WITH active_groups AS (
     SELECT g.id AS group_id
     FROM groups g
     JOIN group_members gm ON gm.group_id = g.id
     WHERE gm.user_id = $1 AND gm.deleted_at IS NULL AND g.deleted_at IS NULL
   ),
   pair_deltas AS (
     SELECT e.group_id, es.user_id AS other_user_id, es.amount AS delta
     FROM expenses e JOIN expense_splits es ON es.expense_id = e.id
     WHERE e.deleted_at IS NULL AND e.paid_by = $1 AND es.user_id != $1
       AND e.group_id IN (SELECT group_id FROM active_groups)
     UNION ALL
     SELECT e.group_id, e.paid_by AS other_user_id, -es.amount AS delta
     FROM expenses e JOIN expense_splits es ON es.expense_id = e.id
     WHERE e.deleted_at IS NULL AND e.paid_by != $1 AND es.user_id = $1
       AND e.group_id IN (SELECT group_id FROM active_groups)
     UNION ALL
     SELECT s.group_id, s.to_user_id AS other_user_id, s.amount AS delta
     FROM settlements s
     WHERE s.deleted_at IS NULL AND s.status = 'paid' AND s.from_user_id = $1
       AND s.group_id IN (SELECT group_id FROM active_groups)
     UNION ALL
     SELECT s.group_id, s.from_user_id AS other_user_id, -s.amount AS delta
     FROM settlements s
     WHERE s.deleted_at IS NULL AND s.status = 'paid' AND s.to_user_id = $1
       AND s.group_id IN (SELECT group_id FROM active_groups)
   )
   SELECT g.name AS group_name, u.name AS other_user, SUM(pd.delta) AS net
   FROM pair_deltas pd
   JOIN groups g ON g.id = pd.group_id
   LEFT JOIN users u ON u.id = pd.other_user_id
   GROUP BY g.name, u.name
   HAVING ABS(SUM(pd.delta)) > 0.01
   ORDER BY g.name, net DESC`,
  [userId]
);
console.table(pairs.rows);

console.log('\n=== NEW dashboard SQL result (per-pair aggregation) ===');
const newResult = await query(
  `WITH active_groups AS (
     SELECT g.id AS group_id
     FROM groups g
     JOIN group_members gm ON gm.group_id = g.id
     WHERE gm.user_id = $1 AND gm.deleted_at IS NULL AND g.deleted_at IS NULL
   ),
   pair_deltas AS (
     SELECT e.group_id, es.user_id AS other_user_id, es.amount AS delta
     FROM expenses e JOIN expense_splits es ON es.expense_id = e.id
     WHERE e.deleted_at IS NULL AND e.paid_by = $1 AND es.user_id != $1
       AND e.group_id IN (SELECT group_id FROM active_groups)
     UNION ALL
     SELECT e.group_id, e.paid_by AS other_user_id, -es.amount AS delta
     FROM expenses e JOIN expense_splits es ON es.expense_id = e.id
     WHERE e.deleted_at IS NULL AND e.paid_by != $1 AND es.user_id = $1
       AND e.group_id IN (SELECT group_id FROM active_groups)
     UNION ALL
     SELECT s.group_id, s.to_user_id AS other_user_id, s.amount AS delta
     FROM settlements s
     WHERE s.deleted_at IS NULL AND s.status = 'paid' AND s.from_user_id = $1
       AND s.group_id IN (SELECT group_id FROM active_groups)
     UNION ALL
     SELECT s.group_id, s.from_user_id AS other_user_id, -s.amount AS delta
     FROM settlements s
     WHERE s.deleted_at IS NULL AND s.status = 'paid' AND s.to_user_id = $1
       AND s.group_id IN (SELECT group_id FROM active_groups)
   ),
   pair_net AS (
     SELECT group_id, other_user_id, SUM(delta) AS net
     FROM pair_deltas GROUP BY group_id, other_user_id
   )
   SELECT COALESCE(SUM(GREATEST(net, 0)), 0) AS you_are_owed,
          COALESCE(SUM(GREATEST(-net, 0)), 0) AS you_owe,
          COALESCE(SUM(net), 0) AS total
   FROM pair_net`,
  [userId]
);
console.log(newResult.rows[0]);

await pool.end();
