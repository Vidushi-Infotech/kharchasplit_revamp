import { query  } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';

class Settlement {
  // Columns shared by all settlement queries
  static get COLUMNS() {
    return `s.id, s.group_id, s.from_user_id, s.to_user_id, s.amount, s.currency,
            s.status, s.notes, s.confirmed_at, s.settled_at, s.created_at`;
  }

  /**
   * Find settlement by ID
   */
  static async findById(id) {
    const result = await query(
      `SELECT ${this.COLUMNS}, u1.name as from_user_name, u2.name as to_user_name
       FROM settlements s
       LEFT JOIN users u1 ON s.from_user_id = u1.id
       LEFT JOIN users u2 ON s.to_user_id = u2.id
       WHERE s.id = $1 AND s.deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Find settlements by group ID (cached — 60s TTL, paginated)
   */
  static async findByGroupId(groupId, limit = 50, offset = 0) {
    return cache.getOrSet(`group:${groupId}:settlements:${limit}:${offset}`, TTL.GROUP_SETTLEMENTS, async () => {
      const result = await query(
        `SELECT ${this.COLUMNS}, u1.name as from_user_name, u2.name as to_user_name
         FROM settlements s
         LEFT JOIN users u1 ON s.from_user_id = u1.id
         LEFT JOIN users u2 ON s.to_user_id = u2.id
         WHERE s.group_id = $1 AND s.deleted_at IS NULL
         ORDER BY s.created_at DESC
         LIMIT $2 OFFSET $3`,
        [groupId, limit, offset]
      );
      return result.rows;
    });
  }

  /**
   * Count settlements for pagination
   */
  static async countByGroupId(groupId) {
    const result = await query(
      'SELECT COUNT(*) as count FROM settlements WHERE group_id = $1 AND deleted_at IS NULL',
      [groupId]
    );
    return parseInt(result.rows[0].count);
  }

  /**
   * Find existing pending settlement between two users in a group
   * Used to prevent duplicate settlements — must be real-time (no cache)
   */
  static async findPendingBetweenUsers(groupId, fromUserId, toUserId) {
    const result = await query(
      `SELECT ${this.COLUMNS}, u1.name as from_user_name, u2.name as to_user_name
       FROM settlements s
       LEFT JOIN users u1 ON s.from_user_id = u1.id
       LEFT JOIN users u2 ON s.to_user_id = u2.id
       WHERE s.group_id = $1
       AND s.from_user_id = $2
       AND s.to_user_id = $3
       AND s.status = 'pending'
       AND s.deleted_at IS NULL
       LIMIT 1`,
      [groupId, fromUserId, toUserId]
    );
    return result.rows[0] || null;
  }

  /**
   * Create new settlement
   */
  static async create(settlementData) {
    const result = await query(
      `INSERT INTO settlements (
        group_id, from_user_id, to_user_id, amount, currency, status, notes
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING id, group_id, from_user_id, to_user_id, amount, currency,
                status, notes, confirmed_at, settled_at, created_at`,
      [
        settlementData.groupId,
        settlementData.fromUserId,
        settlementData.toUserId,
        settlementData.amount,
        settlementData.currency || 'INR', // Default to INR to match frontend
        settlementData.status || 'pending',
        settlementData.notes || null
      ]
    );
    return result.rows[0];
  }

  /**
   * Confirm settlement
   */
  static async confirm(id) {
    const result = await query(
      `UPDATE settlements
       SET status = 'paid',
           confirmed_at = NOW()
       WHERE id = $1 AND status = 'pending' AND deleted_at IS NULL
       RETURNING id, group_id, from_user_id, to_user_id, amount, currency,
                 status, notes, confirmed_at, settled_at, created_at`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Update settlement
   */
  static async update(id, settlementData) {
    const result = await query(
      `UPDATE settlements
       SET amount = COALESCE($1, amount),
           notes = COALESCE($2, notes)
       WHERE id = $3 AND status = 'pending' AND deleted_at IS NULL
       RETURNING id, group_id, from_user_id, to_user_id, amount, currency,
                 status, notes, confirmed_at, settled_at, created_at`,
      [settlementData.amount, settlementData.notes, id]
    );
    return result.rows[0] || null;
  }

  /**
   * Soft delete settlement
   */
  static async delete(id) {
    const result = await query(
      'UPDATE settlements SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL RETURNING id',
      [id]
    );
    return result.rows.length > 0;
  }
}

export default Settlement;
