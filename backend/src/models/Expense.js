import { query, transaction  } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';

class Expense {
  /**
   * Find expense by ID with participants (detail view — includes receipt)
   */
  static async findById(id) {
    const expenseResult = await query(
      `SELECT e.id, e.group_id, e.description, e.amount, e.currency, e.category,
              e.paid_by, e.split_type, e.split_meta, e.receipt_base64, e.notes, e.expense_date,
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
    expense.payers = (await this.payersByExpense([id]))[id] || [];
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
              e.paid_by, e.split_type, e.split_meta, e.notes, e.expense_date,
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

    const payers = await this.payersByExpense(expenseIds);
    for (const expense of expenses) {
      expense.participants = participantsByExpense[expense.id] || [];
      expense.payers = payers[expense.id] || [];
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
   * Payers per expense: { expenseId: [{ user_id, name, amount }] }, largest
   * first. Expenses without payer rows (before migration 021) report
   * paid_by as the single payer of the full amount, like the ledger does.
   */
  static async payersByExpense(expenseIds) {
    if (expenseIds.length === 0) return {};
    const result = await query(
      `SELECT ep.expense_id, ep.user_id, ep.amount, u.name
         FROM expense_payers ep
         LEFT JOIN users u ON u.id = ep.user_id
        WHERE ep.expense_id = ANY($1::uuid[])
       UNION ALL
       SELECT e.id, e.paid_by, e.amount, u.name
         FROM expenses e
         LEFT JOIN users u ON u.id = e.paid_by
        WHERE e.id = ANY($1::uuid[]) AND e.paid_by IS NOT NULL AND e.amount > 0
          AND NOT EXISTS (SELECT 1 FROM expense_payers q WHERE q.expense_id = e.id)
       ORDER BY 3 DESC, 2`,
      [expenseIds],
    );
    const out = {};
    for (const r of result.rows) (out[r.expense_id] ??= []).push(r);
    return out;
  }

  /** Replace an expense's payer rows (inside the caller's transaction). */
  static async _writePayers(client, expenseId, payers) {
    await client.query('DELETE FROM expense_payers WHERE expense_id = $1', [expenseId]);
    const rows = payers.filter((p) => Number(p.amount) > 0);
    if (rows.length === 0) return;
    const values = rows.map((_, i) => `($1, $${i * 2 + 2}, $${i * 2 + 3})`);
    await client.query(
      `INSERT INTO expense_payers (expense_id, user_id, amount) VALUES ${values.join(', ')}`,
      [expenseId, ...rows.flatMap((p) => [p.userId, p.amount])],
    );
  }

  /** Everything needed to show or restore an expense as it is now. */
  static async _snapshot(client, id) {
    const { rows: [e] } = await client.query(
      `SELECT description, amount, currency, category, paid_by, split_type, split_meta,
              -- As text: a DATE read into a JS Date is local midnight, which
              -- JSON turns into the previous day in UTC (IST is +5:30).
              notes, to_char(expense_date, 'YYYY-MM-DD') AS expense_date, updated_at
         FROM expenses WHERE id = $1`,
      [id],
    );
    if (!e) return null;
    const splits = await client.query(
      `SELECT user_id, amount, percentage, shares FROM expense_splits
        WHERE expense_id = $1 AND deleted_at IS NULL ORDER BY amount DESC`,
      [id],
    );
    const payers = await client.query(
      'SELECT user_id, amount FROM expense_payers WHERE expense_id = $1 ORDER BY amount DESC',
      [id],
    );
    return {
      ...e,
      participants: splits.rows,
      payers: payers.rows.length > 0
        ? payers.rows
        : (e.paid_by && Number(e.amount) > 0 ? [{ user_id: e.paid_by, amount: e.amount }] : []),
    };
  }

  /**
   * Edit an expense in one transaction: record its current state as a
   * revision (expense_revisions), update the fields, and replace the
   * splits / payers when given. Without `payers`, an expense with at most
   * one payer keeps its payer row in step with paid_by + amount (the
   * controller refuses payer-less edits of multi-payer expenses).
   *
   * @param {object} fields  description, amount, currency, category,
   *   receiptBase64, notes, expenseDate, paidById, splitType, splitMeta
   *   (undefined = keep; splitMeta null = clear)
   * @param {object} o
   * @param {Array}  [o.participants] new split rows ({userId, amount, …})
   * @param {Array}  [o.payers]       new payer rows ({userId, amount})
   * @param {string} o.editorId       who made the edit (for the revision)
   */
  static async edit(id, fields, { participants, payers, editorId }) {
    return transaction(async (client) => {
      const before = await this._snapshot(client, id);
      if (!before) return null;
      await client.query(
        'INSERT INTO expense_revisions (expense_id, edited_by, snapshot) VALUES ($1, $2, $3)',
        [id, editorId || null, JSON.stringify(before)],
      );

      const { rows: [expense] } = await client.query(
        `UPDATE expenses
         SET description = COALESCE($1, description),
             amount = COALESCE($2, amount),
             currency = COALESCE($3, currency),
             category = COALESCE($4, category),
             receipt_base64 = COALESCE($5, receipt_base64),
             notes = COALESCE($6, notes),
             expense_date = COALESCE($7, expense_date),
             paid_by = COALESCE($8, paid_by),
             split_type = COALESCE($9, split_type),
             split_meta = CASE WHEN $11::boolean THEN $12::jsonb ELSE split_meta END
         WHERE id = $10 AND deleted_at IS NULL
         RETURNING id, group_id, description, amount, currency, category,
                   paid_by, split_type, split_meta, notes, expense_date, created_at, updated_at`,
        [
          fields.description,
          fields.amount,
          fields.currency,
          fields.category,
          fields.receiptBase64,
          fields.notes,
          fields.expenseDate,
          fields.paidById || null,
          fields.splitType || null,
          id,
          fields.splitMeta !== undefined,
          fields.splitMeta == null ? null : JSON.stringify(fields.splitMeta),
        ],
      );
      if (!expense) return null;

      if (Array.isArray(participants)) {
        // Replace wholesale so amounts/percentages/shares change atomically.
        await client.query('DELETE FROM expense_splits WHERE expense_id = $1', [id]);
        if (participants.length > 0) {
          const values = participants.map((_, i) =>
            `($1, $${i * 4 + 2}, $${i * 4 + 3}, $${i * 4 + 4}, $${i * 4 + 5})`);
          await client.query(
            `INSERT INTO expense_splits (expense_id, user_id, amount, percentage, shares)
             VALUES ${values.join(', ')}`,
            [id, ...participants.flatMap((p) => [p.userId, p.amount, p.percentage || null, p.shares || null])],
          );
        }
      }

      if (Array.isArray(payers)) {
        await this._writePayers(client, id, payers);
      } else if (before.payers.length <= 1 && expense.paid_by) {
        await this._writePayers(client, id, [{ userId: expense.paid_by, amount: expense.amount }]);
      }

      // Editing is also "latest activity" — sort the group to the top.
      await client.query('UPDATE groups SET updated_at = NOW() WHERE id = $1', [expense.group_id]);
      return expense;
    });
  }

  /**
   * Create new expense with participants
   */
  static async create(expenseData, participants, payers = null) {
    return transaction(async (client) => {
      // Create expense
      const expenseResult = await client.query(
        `INSERT INTO expenses (
          group_id, description, amount, currency, category,
          paid_by, split_type, receipt_base64, notes, expense_date, split_meta
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING id, group_id, description, amount, currency, category,
                  paid_by, split_type, split_meta, notes, expense_date, created_at, updated_at`,
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
          expenseData.expenseDate || new Date(),
          expenseData.splitMeta ? JSON.stringify(expenseData.splitMeta) : null,
        ]
      );
      const expense = expenseResult.rows[0];

      // Who paid: as given, or the single payer of the whole amount.
      await this._writePayers(client, expense.id, payers
        ?? (expense.paid_by ? [{ userId: expense.paid_by, amount: expense.amount }] : []));

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

      // Bump the group's updated_at so it sorts to the top of the groups list
      // / dashboard "Your Groups" (ORDER BY g.updated_at DESC). This is what
      // makes the group with the newest expense appear first.
      await client.query(
        `UPDATE groups SET updated_at = NOW() WHERE id = $1`,
        [expenseData.groupId]
      );

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
    const updated = result.rows[0] || null;
    if (updated) {
      // Keep the group at the top of the recency-sorted list after an edit.
      await query(`UPDATE groups SET updated_at = NOW() WHERE id = $1`, [
        updated.group_id,
      ]);
    }
    return updated;
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

      // Editing an expense is also "latest activity" — bump the group so it
      // sorts to the top of the groups list / dashboard.
      await client.query(
        `UPDATE groups SET updated_at = NOW() WHERE id = $1`,
        [expense.group_id]
      );

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
