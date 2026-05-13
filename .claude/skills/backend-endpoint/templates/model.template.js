// Template: backend/src/models/<Resource>.js
import { query, transaction } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';

class <Resource> {
  /**
   * Find one — no caching here unless we know we'll hit the same id many times.
   */
  static async findById(id) {
    const result = await query(
      `SELECT id, group_id, /* explicit columns only */ created_at, updated_at
       FROM <resource>s
       WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Cached list — pattern from Expense.findByGroupId. 60s TTL is typical for list views.
   */
  static async findByGroupId(groupId, limit = 50, offset = 0) {
    return cache.getOrSet(
      `group:${groupId}:<resource>s:${limit}:${offset}`,
      TTL.GROUP_EXPENSES, // pick the closest matching TTL constant
      () => this._findByGroupId(groupId, limit, offset)
    );
  }

  static async _findByGroupId(groupId, limit, offset) {
    const result = await query(
      `SELECT id, group_id, /* explicit columns — no large blobs in list view */
              created_at, updated_at
       FROM <resource>s
       WHERE group_id = $1 AND deleted_at IS NULL
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [groupId, limit, offset]
    );
    return result.rows;
  }

  static async countByGroupId(groupId) {
    const result = await query(
      'SELECT COUNT(*) as count FROM <resource>s WHERE group_id = $1 AND deleted_at IS NULL',
      [groupId]
    );
    return parseInt(result.rows[0].count);
  }

  /**
   * Multi-row write — use transaction.
   * Single-row write — use plain query().
   */
  static async create(data) {
    return transaction(async (client) => {
      const result = await client.query(
        `INSERT INTO <resource>s (group_id /*, fields */)
         VALUES ($1 /*, $2, ... */)
         RETURNING id, group_id, created_at, updated_at`,
        [data.groupId /*, data.field, ... */]
      );
      return result.rows[0];
    });
  }

  static async update(id, data) {
    // COALESCE pattern: only update fields actually passed
    const result = await query(
      `UPDATE <resource>s
       SET /* field = COALESCE($1, field), */
           updated_at = NOW()
       WHERE id = $N AND deleted_at IS NULL
       RETURNING id, group_id, created_at, updated_at`,
      [/* data.field, */ id]
    );
    return result.rows[0] || null;
  }

  /**
   * Soft delete only.
   */
  static async delete(id) {
    const result = await query(
      'UPDATE <resource>s SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL RETURNING id',
      [id]
    );
    return result.rows.length > 0;
  }

  /**
   * Invalidate every read key produced by this model for a given group.
   * Pair this with EVERY write call from the controller.
   */
  static invalidate(groupId) {
    cache.invalidate(`group:${groupId}:<resource>s`);
    cache.del(`group:${groupId}`); // group_count / aggregate columns may change
  }
}

export default <Resource>;
