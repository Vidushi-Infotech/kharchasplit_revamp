import { query, transaction } from '../config/database.js';

export const ACCOUNT_TYPES = ['cash', 'bank', 'card', 'wallet'];

/**
 * An account's balance: opening balance, plus income and minus expenses
 * tagged to it, plus transfers in and minus transfers out. [id] is the
 * account id column to compute it for.
 */
const BALANCE_SQL = (id) => `
  a.opening_balance
  + COALESCE((SELECT SUM(CASE WHEN e.kind = 'income' THEN e.amount ELSE -e.amount END)
                FROM personal_expenses e
               WHERE e.account_id = ${id} AND e.deleted_at IS NULL), 0)
  + COALESCE((SELECT SUM(t.amount) FROM personal_transfers t
               WHERE t.to_account_id = ${id} AND t.deleted_at IS NULL), 0)
  - COALESCE((SELECT SUM(t.amount) FROM personal_transfers t
               WHERE t.from_account_id = ${id} AND t.deleted_at IS NULL), 0)`;

const SELECT_ACCOUNT = `
  SELECT a.id, a.name, a.type, a.opening_balance, a.created_at,
         ${BALANCE_SQL('a.id')} AS balance,
         (SELECT COUNT(*) FROM personal_expenses e
           WHERE e.account_id = a.id AND e.deleted_at IS NULL)::int AS entry_count
    FROM personal_accounts a`;

const toAccount = (r) => ({
  id: r.id,
  name: r.name,
  type: r.type,
  balance: Math.round(Number(r.balance) * 100) / 100,
  entryCount: r.entry_count ?? 0,
  createdAt: r.created_at,
});

const toTransfer = (r) => ({
  id: r.id,
  fromAccountId: r.from_account_id,
  toAccountId: r.to_account_id,
  amount: Number(r.amount),
  note: r.note,
  date: r.transfer_date,
});

/**
 * Personal mode accounts (cash, bank, credit card, e-wallet) and transfers
 * between them. Removing an account archives it so history keeps it.
 */
class PersonalAccount {
  static async listForUser(userId) {
    const result = await query(
      `${SELECT_ACCOUNT}
        WHERE a.user_id = $1 AND a.archived_at IS NULL
        ORDER BY a.created_at, a.name`,
      [userId]
    );
    return result.rows.map(toAccount);
  }

  /** The caller's active account [id], or null. */
  static async find(userId, id) {
    const result = await query(
      `${SELECT_ACCOUNT}
        WHERE a.id = $2 AND a.user_id = $1 AND a.archived_at IS NULL`,
      [userId, id]
    );
    return result.rows[0] ? toAccount(result.rows[0]) : null;
  }

  static async create(userId, { name, type, balance = 0 }) {
    const result = await query(
      `INSERT INTO personal_accounts (user_id, name, type, opening_balance)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [userId, name, type, balance]
    );
    return this.find(userId, result.rows[0].id);
  }

  /**
   * Rename and/or set the balance. A new balance moves the opening balance
   * by the difference, so entries and transfers stay as they are.
   */
  static async update(userId, id, { name, balance }) {
    const current = await this.find(userId, id);
    if (!current) return null;
    await query(
      `UPDATE personal_accounts
          SET name = COALESCE($3, name),
              opening_balance = opening_balance + $4,
              updated_at = NOW()
        WHERE id = $2 AND user_id = $1`,
      [userId, id, name ?? null, balance == null ? 0 : balance - current.balance]
    );
    return this.find(userId, id);
  }

  static async archive(userId, id) {
    const result = await query(
      `UPDATE personal_accounts SET archived_at = NOW(), updated_at = NOW()
        WHERE id = $2 AND user_id = $1 AND archived_at IS NULL`,
      [userId, id]
    );
    return result.rowCount > 0;
  }

  /**
   * One-time move of the phone-only wallet to the server. accounts:
   * [{ key, name, type, balance }] (balance as the phone shows it now);
   * links: { expenseId: key } for entries the phone tagged. Linked entries
   * get the account, and each opening balance is set so the computed
   * balance equals what the phone showed. Does nothing (imported: false)
   * when the user already has accounts, so a retry can't import twice.
   */
  static async importWallet(userId, accounts, links) {
    return transaction(async (client) => {
      // One import at a time per user.
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [
        `personal_accounts:${userId}`,
      ]);
      const existing = await client.query(
        'SELECT 1 FROM personal_accounts WHERE user_id = $1 LIMIT 1',
        [userId]
      );
      if (existing.rowCount > 0) return { imported: false };

      for (const a of accounts) {
        const created = await client.query(
          `INSERT INTO personal_accounts (user_id, name, type, opening_balance)
           VALUES ($1, $2, $3, 0) RETURNING id`,
          [userId, a.name, a.type]
        );
        const accountId = created.rows[0].id;
        const expenseIds = Object.entries(links)
          .filter(([, key]) => key === a.key)
          .map(([expenseId]) => expenseId);
        let effect = 0;
        if (expenseIds.length) {
          const tagged = await client.query(
            `UPDATE personal_expenses SET account_id = $1
              WHERE user_id = $2 AND id = ANY($3::uuid[]) AND deleted_at IS NULL
              RETURNING kind, amount`,
            [accountId, userId, expenseIds]
          );
          for (const r of tagged.rows) {
            effect += r.kind === 'income' ? Number(r.amount) : -Number(r.amount);
          }
        }
        await client.query(
          'UPDATE personal_accounts SET opening_balance = $2 WHERE id = $1',
          [accountId, a.balance - effect]
        );
      }
      return { imported: true };
    });
  }

  static async listTransfers(userId, { accountId, limit = 50 } = {}) {
    const result = await query(
      `SELECT id, from_account_id, to_account_id, amount, note, transfer_date
         FROM personal_transfers
        WHERE user_id = $1 AND deleted_at IS NULL
          AND ($2::uuid IS NULL OR from_account_id = $2 OR to_account_id = $2)
        ORDER BY transfer_date DESC, created_at DESC
        LIMIT $3`,
      [userId, accountId ?? null, limit]
    );
    return result.rows.map(toTransfer);
  }

  static async createTransfer(userId, { fromAccountId, toAccountId, amount, note, date }) {
    const result = await query(
      `INSERT INTO personal_transfers
         (user_id, from_account_id, to_account_id, amount, note, transfer_date)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6::timestamptz, NOW()))
       RETURNING id, from_account_id, to_account_id, amount, note, transfer_date`,
      [userId, fromAccountId, toAccountId, amount, note || null, date ?? null]
    );
    return toTransfer(result.rows[0]);
  }

  static async deleteTransfer(userId, id) {
    const result = await query(
      `UPDATE personal_transfers SET deleted_at = NOW()
        WHERE id = $2 AND user_id = $1 AND deleted_at IS NULL`,
      [userId, id]
    );
    return result.rowCount > 0;
  }
}

export default PersonalAccount;
