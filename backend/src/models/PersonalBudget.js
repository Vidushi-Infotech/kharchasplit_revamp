import { query } from '../config/database.js';

/**
 * Personal mode monthly budgets: a limit per expense category, or for the
 * whole month (category 'total'), applying every month until changed.
 */
class PersonalBudget {
  static async listForUser(userId) {
    const result = await query(
      `SELECT category, amount FROM personal_budgets
        WHERE user_id = $1 ORDER BY category`,
      [userId]
    );
    return result.rows;
  }

  static async upsert(userId, category, amount) {
    const result = await query(
      `INSERT INTO personal_budgets (user_id, category, amount)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, category)
       DO UPDATE SET amount = EXCLUDED.amount, updated_at = NOW()
       RETURNING category, amount`,
      [userId, category, amount]
    );
    return result.rows[0];
  }

  static async remove(userId, category) {
    const result = await query(
      'DELETE FROM personal_budgets WHERE user_id = $1 AND category = $2',
      [userId, category]
    );
    return result.rowCount > 0;
  }

  /**
   * Spending per category in [month] ('YYYY-MM'), by the user's local days
   * ([tzOffsetMinutes] east of UTC). Expenses only, not income.
   */
  static async spentByCategory(userId, month, tzOffsetMinutes) {
    const result = await query(
      `WITH e AS (
         SELECT category, amount,
                (expense_date::timestamptz AT TIME ZONE 'UTC')
                  + make_interval(mins => $2) AS local_at
           FROM personal_expenses
          WHERE user_id = $1 AND deleted_at IS NULL AND kind = 'expense'
       )
       SELECT COALESCE(category, 'other') AS category, SUM(amount) AS spent
         FROM e
        WHERE local_at >= to_date($3, 'YYYY-MM')
          AND local_at < to_date($3, 'YYYY-MM') + interval '1 month'
        GROUP BY 1`,
      [userId, tzOffsetMinutes, month]
    );
    return result.rows;
  }
}

export default PersonalBudget;
