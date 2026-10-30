import { query, transaction } from '../config/database.js';
import { billStatus } from '../utils/personalBills.js';
import { todayIST } from '../utils/recurrence.js';

/** The bill columns, prefixed with table alias [t] when given. */
const columns = (t = '') => {
  const c = t ? `${t}.` : '';
  return `${c}id, ${c}user_id, ${c}name, ${c}amount, ${c}category, ${c}account_id,
    ${c}frequency, to_char(${c}anchor_date, 'YYYY-MM-DD') AS anchor_date,
    ${c}paid_count, ${c}remind_days,
    to_char(${c}last_reminded_due, 'YYYY-MM-DD') AS last_reminded_due`;
};
const COLUMNS = columns();

/** A row as the schedule helpers and the app see it. */
export function toBill(r, today = todayIST()) {
  const bill = {
    id: r.id,
    userId: r.user_id,
    name: r.name,
    amount: Number(r.amount),
    category: r.category,
    accountId: r.account_id,
    frequency: r.frequency,
    anchorDate: r.anchor_date,
    paidCount: r.paid_count,
    remindDays: r.remind_days,
    lastRemindedDue: r.last_reminded_due,
  };
  return { ...bill, ...billStatus(bill, today) };
}

/**
 * Personal mode bills: a repeating amount with a next due date. Paying
 * one adds a personal expense (bill_id) and moves the bill to its next
 * due date; skipping just moves it on. Removing archives it.
 */
class PersonalBill {
  static async listForUser(userId) {
    const result = await query(
      `SELECT ${COLUMNS} FROM personal_bills
        WHERE user_id = $1 AND archived_at IS NULL`,
      [userId]
    );
    return result.rows
      .map((r) => toBill(r))
      .sort((a, b) => a.nextDue.localeCompare(b.nextDue) || a.name.localeCompare(b.name));
  }

  static async find(userId, id) {
    const result = await query(
      `SELECT ${COLUMNS} FROM personal_bills
        WHERE id = $2 AND user_id = $1 AND archived_at IS NULL`,
      [userId, id]
    );
    return result.rows[0] ? toBill(result.rows[0]) : null;
  }

  /** [dueDate] is the first due date; the schedule repeats from it. */
  static async create(userId, b) {
    const result = await query(
      `INSERT INTO personal_bills
         (user_id, name, amount, category, account_id, frequency, anchor_date, remind_days)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
      [userId, b.name, b.amount, b.category || 'utilities', b.accountId || null,
        b.frequency, b.dueDate, b.remindDays ?? 2]
    );
    return this.find(userId, result.rows[0].id);
  }

  /**
   * Change any of it. A new [dueDate] or [frequency] restarts the schedule
   * from that due date.
   */
  static async update(userId, id, b) {
    const current = await this.find(userId, id);
    if (!current) return null;
    const restart = b.dueDate != null || b.frequency != null;
    await query(
      `UPDATE personal_bills SET
          name = COALESCE($3, name),
          amount = COALESCE($4, amount),
          category = COALESCE($5, category),
          account_id = CASE WHEN $6::boolean THEN $7::uuid ELSE account_id END,
          frequency = COALESCE($8, frequency),
          anchor_date = CASE WHEN $9::boolean THEN $10::date ELSE anchor_date END,
          paid_count = CASE WHEN $9::boolean THEN 0 ELSE paid_count END,
          last_reminded_due = CASE WHEN $9::boolean THEN NULL ELSE last_reminded_due END,
          remind_days = COALESCE($11, remind_days),
          updated_at = NOW()
        WHERE id = $2 AND user_id = $1`,
      [userId, id, b.name ?? null, b.amount ?? null, b.category ?? null,
        b.accountId !== undefined, b.accountId || null, b.frequency ?? null,
        restart, b.dueDate ?? current.nextDue, b.remindDays ?? null]
    );
    return this.find(userId, id);
  }

  static async archive(userId, id) {
    const result = await query(
      `UPDATE personal_bills SET archived_at = NOW(), updated_at = NOW()
        WHERE id = $2 AND user_id = $1 AND archived_at IS NULL`,
      [userId, id]
    );
    return result.rowCount > 0;
  }

  /**
   * Pay the due bill: a personal expense for [amount] (default the bill's)
   * from [accountId] (default the bill's) on [date] (default now), then
   * the next due date. Returns { bill, expenseId }, or null if not found.
   */
  static async pay(userId, id, { amount, accountId, date }) {
    return transaction(async (client) => {
      const found = await client.query(
        `SELECT ${COLUMNS} FROM personal_bills
          WHERE id = $2 AND user_id = $1 AND archived_at IS NULL FOR UPDATE`,
        [userId, id]
      );
      if (!found.rows[0]) return null;
      const bill = toBill(found.rows[0]);
      const expense = await client.query(
        `INSERT INTO personal_expenses
           (user_id, description, amount, currency, category, expense_date,
            kind, account_id, bill_id)
         VALUES ($1, $2, $3, 'INR', $4, COALESCE($5::timestamptz, NOW()),
                 'expense', $6, $7)
         RETURNING id`,
        [userId, bill.name, amount ?? bill.amount, bill.category, date ?? null,
          accountId === undefined ? bill.accountId : accountId, id]
      );
      await client.query(
        `UPDATE personal_bills SET paid_count = paid_count + 1, updated_at = NOW()
          WHERE id = $1`,
        [id]
      );
      return { expenseId: expense.rows[0].id };
    }).then(async (r) => (r ? { ...r, bill: await this.find(userId, id) } : null));
  }

  /** Move past the due date without paying (e.g. nothing to pay this month). */
  static async skip(userId, id) {
    const result = await query(
      `UPDATE personal_bills SET paid_count = paid_count + 1, updated_at = NOW()
        WHERE id = $2 AND user_id = $1 AND archived_at IS NULL`,
      [userId, id]
    );
    return result.rowCount > 0 ? this.find(userId, id) : null;
  }

  /** The bill's latest payments (its expenses). */
  static async payments(userId, id, limit = 12) {
    const result = await query(
      `SELECT id, amount, expense_date, account_id
         FROM personal_expenses
        WHERE user_id = $1 AND bill_id = $2 AND deleted_at IS NULL
        ORDER BY expense_date DESC, created_at DESC LIMIT $3`,
      [userId, id, limit]
    );
    return result.rows.map((r) => ({
      id: r.id,
      amount: Number(r.amount),
      date: r.expense_date,
      accountId: r.account_id,
    }));
  }

  /** Every active bill of active users, for the reminder job. */
  static async allActive() {
    const result = await query(
      `SELECT ${columns('b')}
         FROM personal_bills b JOIN users u ON u.id = b.user_id AND u.deleted_at IS NULL
        WHERE b.archived_at IS NULL`
    );
    return result.rows;
  }

  static async markReminded(id, due) {
    await query('UPDATE personal_bills SET last_reminded_due = $2 WHERE id = $1', [id, due]);
  }
}

export default PersonalBill;
