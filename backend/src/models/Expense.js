import { query, transaction  } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';

class Expense {
  /**
   * Find expense by ID with participants (detail view — includes receipt)
   */
  static async findById(id) {
    const expenseResult = await query(
      `SELECT e.id, e.group_id, e.description, e.amount, e.currency, e.category,
              e.paid_by, e.split_type, e.receipt_base64, e.notes, e.expense_date,
              e.created_at, e.updated_at, u.name as paid_by_name
       FROM expenses e
       LEFT JOIN users u ON e.paid_by = u.id
       WHERE e.id = $1 AND e.deleted_at IS NULL`,
      [id]
    );

    if (expenseResult.rows.length === 0) {
      return null;
    }

    const expense = expenseResult.rows[0];

    // Get participants
    const participantsResult = await query(
      `SELECT es.expense_id, es.user_id, es.amount, es.percentage, es.shares, u.name
       FROM expense_splits es
       LEFT JOIN users u ON es.user_id = u.id
       WHERE es.expense_id = $1
       ORDER BY es.amount DESC`,
      [id]
    );

    expense.participants = participantsResult.rows;
    return expense;
  }

  /**
   * Find expenses by group ID with participants (cached — 60s TTL per page)
   */
  static async findByGroupId(groupId, limit = 50, offset = 0) {
    return cache.getOrSet(`group:${groupId}:expenses:${limit}:${offset}`, TTL.GROUP_EXPENSES, () => this._findByGroupId(groupId, limit, offset));
  }

  static async _findByGroupId(groupId, limit = 50, offset = 0) {
    // No receipt_base64 in list view — saves potentially MBs per response
    const expensesResult = await query(
      `SELECT e.id, e.group_id, e.description, e.amount, e.currency, e.category,
              e.paid_by, e.split_type, e.notes, e.expense_date,
              e.created_at, e.updated_at, u.name as paid_by_name
       FROM expenses e
       LEFT JOIN users u ON e.paid_by = u.id
       WHERE e.group_id = $1 AND e.deleted_at IS NULL
       ORDER BY e.expense_date DESC, e.created_at DESC
       LIMIT $2 OFFSET $3`,
      [groupId, limit, offset]
    );

    const expenses = expensesResult.rows;
    if (expenses.length === 0) return expenses;

    // Batch fetch participants for ALL expenses in a single query (eliminates N+1)
    const expenseIds = expenses.map(e => e.id);
    const placeholders = expenseIds.map((_, i) => `$${i + 1}`).join(', ');
    const participantsResult = await query(
      `SELECT es.expense_id, es.user_id, es.amount, es.percentage, es.shares, u.name
       FROM expense_splits es
       LEFT JOIN users u ON es.user_id = u.id
       WHERE es.expense_id IN (${placeholders})
       ORDER BY es.amount DESC`,
      expenseIds
    );

    // Group participants by expense_id
    const participantsByExpense = {};
    for (const row of participantsResult.rows) {
      if (!participantsByExpense[row.expense_id]) {
        participantsByExpense[row.expense_id] = [];
      }
      participantsByExpense[row.expense_id].push(row);
    }

    for (const expense of expenses) {
      expense.participants = participantsByExpense[expense.id] || [];
    }

    return expenses;
  }

  /**
   * Invalidate all expense-related caches for a group
   */
  static invalidateGroupExpenses(groupId) {
    cache.invalidate(`group:${groupId}:expenses`);
    cache.invalidate(`group:${groupId}:balances`);
    cache.del(`group:${groupId}`); // expense_count and total_expenses change
  }

  /**
   * Create new expense with participants
   */
  static async create(expenseData, participants) {
    return transaction(async (client) => {
      // Create expense
      const expenseResult = await client.query(
        `INSERT INTO expenses (
          group_id, description, amount, currency, category,
          paid_by, split_type, receipt_base64, notes, expense_date
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING id, group_id, description, amount, currency, category,
                  paid_by, split_type, notes, expense_date, created_at, updated_at`,
        [
          expenseData.groupId,
          expenseData.description,
          expenseData.amount,
          expenseData.currency || 'INR',
          expenseData.category || null,
          expenseData.paidById || expenseData.paidBy,
          expenseData.splitType || 'equal',
          expenseData.receiptBase64 || null,
          expenseData.notes || null,
          expenseData.expenseDate || new Date()
        ]
      );
      const expense = expenseResult.rows[0];

      // Add participants in a single batch INSERT
      if (participants && participants.length > 0) {
        const values = [];
        const params = [];
        let paramIndex = 1;

        for (const participant of participants) {
          values.push(`($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, $${paramIndex + 4})`);
          params.push(
            expense.id,
            participant.userId,
            participant.amount,
            participant.percentage || null,
            participant.shares || null
          );
          paramIndex += 5;
        }

        await client.query(
          `INSERT INTO expense_splits (expense_id, user_id, amount, percentage, shares)
           VALUES ${values.join(', ')}`,
          params
        );
      }

      return expense;
    });
  }

  /**
   * Update expense fields (no split changes). Use [updateWithSplits] when the
   * participant set, amounts, or split type need to change too.
   */
  static async update(id, expenseData) {
    const result = await query(
      `UPDATE expenses
       SET description = COALESCE($1, description),
           amount = COALESCE($2, amount),
           currency = COALESCE($3, currency),
           category = COALESCE($4, category),
           receipt_base64 = COALESCE($5, receipt_base64),
           notes = COALESCE($6, notes),
           expense_date = COALESCE($7, expense_date),
           paid_by = COALESCE($8, paid_by),
           split_type = COALESCE($9, split_type)
       WHERE id = $10 AND deleted_at IS NULL
       RETURNING id, group_id, description, amount, currency, category,
                 paid_by, split_type, notes, expense_date, created_at, updated_at`,
      [
        expenseData.description,
        expenseData.amount,
        expenseData.currency,
        expenseData.category,
        expenseData.receiptBase64,
        expenseData.notes,
        expenseData.expenseDate,
        expenseData.paidById || expenseData.paidBy || null,
        expenseData.splitType || null,
        id,
      ]
    );
    return result.rows[0] || null;
  }

  /**
   * Update expense + replace its splits in a single transaction. Used by the
   * edit-expense flow when amount / payer / split type / participant set
   * change and the splits need to be recomputed wholesale.
   */
  static async updateWithSplits(id, expenseData, participants) {
    return transaction(async (client) => {
      const updateRes = await client.query(
        `UPDATE expenses
         SET description = COALESCE($1, description),
             amount = COALESCE($2, amount),
             currency = COALESCE($3, currency),
             category = COALESCE($4, category),
             receipt_base64 = COALESCE($5, receipt_base64),
             notes = COALESCE($6, notes),
             expense_date = COALESCE($7, expense_date),
             paid_by = COALESCE($8, paid_by),
             split_type = COALESCE($9, split_type)
         WHERE id = $10 AND deleted_at IS NULL
         RETURNING id, group_id, description, amount, currency, category,
                   paid_by, split_type, notes, expense_date, created_at, updated_at`,
        [
          expenseData.description,
          expenseData.amount,
          expenseData.currency,
          expenseData.category,
          expenseData.receiptBase64,
          expenseData.notes,
          expenseData.expenseDate,
          expenseData.paidById || expenseData.paidBy || null,
          expenseData.splitType || null,
          id,
        ]
      );
      const expense = updateRes.rows[0];
      if (!expense) return null;

      // Replace the split rows wholesale. We always wipe first — even when the
      // caller passes the same member set — so amounts/percentages/shares can
      // change atomically without leaving stale rows behind.
      await client.query(
        'DELETE FROM expense_splits WHERE expense_id = $1',
        [id]
      );

      if (Array.isArray(participants) && participants.length > 0) {
        const values = [];
        const params = [];
        let paramIndex = 1;
        for (const p of participants) {
          values.push(`($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, $${paramIndex + 4})`);
          params.push(
            expense.id,
            p.userId,
            p.amount,
            p.percentage || null,
            p.shares || null
          );
          paramIndex += 5;
        }
        await client.query(
          `INSERT INTO expense_splits (expense_id, user_id, amount, percentage, shares)
           VALUES ${values.join(', ')}`,
          params
        );
      }

      return expense;
    });
  }

  /**
   * Soft delete expense
   */
  static async delete(id) {
    const result = await query(
      'UPDATE expenses SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL RETURNING id',
      [id]
    );
    return result.rows.length > 0;
  }

  /**
   * Get total count for pagination
   */
  static async countByGroupId(groupId) {
    const result = await query(
      'SELECT COUNT(*) as count FROM expenses WHERE group_id = $1 AND deleted_at IS NULL',
      [groupId]
    );
    return parseInt(result.rows[0].count);
  }
}

export default Expense;
