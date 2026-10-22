import { query  } from '../config/database.js';

/**
 * Activity Model
 * Handles activity feed and notification data
 */
class Activity {
  // Columns shared by activity queries
  static get COLUMNS() {
    return `a.id, a.group_id, a.user_id, a.activity_type, a.entity_type,
            a.entity_id, a.title, a.description, a.metadata, a.is_read, a.created_at`;
  }

  /**
   * Find activity by ID
   */
  static async findById(id) {
    const result = await query(
      `SELECT ${this.COLUMNS.replace(/a\./g, '')} FROM activities
       WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Feed visibility for user $1 (Splitwise-style): your own actions plus
   * everything that happened in your groups while you were a member (a
   * minute of slack either side, so "added you" / "you left" show up).
   */
  static get VISIBLE_TO_USER() {
    return `a.deleted_at IS NULL AND (
      a.user_id = $1 OR EXISTS (
        SELECT 1 FROM group_members gm
         WHERE gm.group_id = a.group_id AND gm.user_id = $1
           AND a.created_at >= gm.joined_at - INTERVAL '1 minute'
           AND a.created_at <= COALESCE(gm.left_at, gm.deleted_at, 'infinity'::timestamp)
                               + INTERVAL '1 minute'))`;
  }

  /**
   * Read state for user $1: your own actions are always read; others' are
   * read once you open them or mark all read (activity_reads, migration 024).
   */
  static get IS_READ_FOR_USER() {
    return `(a.user_id = $1 OR EXISTS (
      SELECT 1 FROM activity_reads r WHERE r.activity_id = a.id AND r.user_id = $1))`;
  }

  /**
   * Get the activity feed for a user. Expense rows also carry the
   * expense's category and the viewer's net on it (paid − share; null when
   * not involved or the expense is deleted), matching ledger.js payer rules.
   */
  static async findByUserId(userId, limit = 50, offset = 0) {
    const result = await query(
      `SELECT a.id, a.group_id, a.user_id, a.activity_type, a.entity_type,
              a.entity_id, a.title, a.description, a.metadata, a.created_at,
              ${this.IS_READ_FOR_USER} AS is_read,
              u.name as actor_name,
              g.name as group_name,
              e.category AS expense_category,
              CASE WHEN e.id IS NULL OR e.deleted_at IS NOT NULL
                     OR (mine.paid = 0 AND mine.share IS NULL) THEN NULL
                   ELSE mine.paid - COALESCE(mine.share, 0) END AS your_net
       FROM activities a
       LEFT JOIN users u ON a.user_id = u.id
       LEFT JOIN groups g ON a.group_id = g.id
       LEFT JOIN expenses e ON a.entity_type = 'expense' AND e.id = a.entity_id
       LEFT JOIN LATERAL (
         SELECT
           CASE WHEN EXISTS (SELECT 1 FROM expense_payers p WHERE p.expense_id = e.id)
                THEN (SELECT COALESCE(SUM(p.amount), 0) FROM expense_payers p
                       WHERE p.expense_id = e.id AND p.user_id = $1)
                WHEN e.paid_by = $1 THEN e.amount
                ELSE 0 END AS paid,
           (SELECT SUM(s.amount) FROM expense_splits s
             WHERE s.expense_id = e.id AND s.user_id = $1 AND s.deleted_at IS NULL) AS share
       ) mine ON e.id IS NOT NULL
       WHERE ${this.VISIBLE_TO_USER}
       ORDER BY a.created_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );
    return result.rows;
  }

  /**
   * Get activities for a group
   */
  static async findByGroupId(groupId, limit = 50, offset = 0) {
    const result = await query(
      `SELECT ${this.COLUMNS},
              u.name as actor_name,
              g.name as group_name
       FROM activities a
       LEFT JOIN users u ON a.user_id = u.id
       LEFT JOIN groups g ON a.group_id = g.id
       WHERE a.group_id = $1 AND a.deleted_at IS NULL
       ORDER BY a.created_at DESC
       LIMIT $2 OFFSET $3`,
      [groupId, limit, offset]
    );
    return result.rows;
  }

  /**
   * Get unread activities count for user
   */
  static async getUnreadCount(userId) {
    const result = await query(
      `SELECT COUNT(*) as count FROM activities a
       WHERE ${this.VISIBLE_TO_USER} AND NOT ${this.IS_READ_FOR_USER}`,
      [userId]
    );
    return parseInt(result.rows[0].count);
  }

  /**
   * Create new activity
   */
  static async create(activityData) {
    const {
      groupId,
      userId,
      activityType,
      entityType,
      entityId,
      title,
      description,
      metadata,
    } = activityData;

    const result = await query(
      `INSERT INTO activities (
        group_id, user_id, activity_type, entity_type, entity_id,
        title, description, metadata
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id, group_id, user_id, activity_type, entity_type,
                entity_id, title, description, metadata, is_read, created_at`,
      [
        groupId || null,
        userId,
        activityType,
        entityType,
        entityId,
        title,
        description || null,
        metadata ? JSON.stringify(metadata) : null,
      ]
    );

    return result.rows[0];
  }

  /**
   * Mark one activity read for a user (any activity in their feed)
   */
  static async markAsRead(id, userId) {
    const result = await query(
      `INSERT INTO activity_reads (activity_id, user_id)
       SELECT a.id, $1 FROM activities a
        WHERE a.id = $2 AND ${this.VISIBLE_TO_USER}
       ON CONFLICT DO NOTHING
       RETURNING activity_id AS id`,
      [userId, id]
    );
    if (result.rows[0]) return { id, is_read: true };
    // Already read (or your own action) still counts as found.
    const seen = await query(
      `SELECT a.id FROM activities a WHERE a.id = $2 AND ${this.VISIBLE_TO_USER}`,
      [userId, id]
    );
    return seen.rows[0] ? { id, is_read: true } : null;
  }

  /**
   * Mark all activities as read for a user
   */
  static async markAllAsRead(userId) {
    await query(
      `INSERT INTO activity_reads (activity_id, user_id)
       SELECT a.id, $1 FROM activities a
        WHERE ${this.VISIBLE_TO_USER} AND NOT ${this.IS_READ_FOR_USER}
       ON CONFLICT DO NOTHING`,
      [userId]
    );
    return true;
  }

  /**
   * Mark all activities as read for a group
   */
  static async markGroupActivitiesAsRead(groupId, userId) {
    await query(
      `INSERT INTO activity_reads (activity_id, user_id)
       SELECT a.id, $1 FROM activities a
        WHERE a.group_id = $2 AND ${this.VISIBLE_TO_USER} AND NOT ${this.IS_READ_FOR_USER}
       ON CONFLICT DO NOTHING`,
      [userId, groupId]
    );
    return true;
  }

  /**
   * Delete activity (soft delete)
   */
  static async delete(id) {
    const result = await query(
      `UPDATE activities
       SET deleted_at = NOW()
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING id`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Count total activities in a user's feed
   */
  static async countByUserId(userId) {
    const result = await query(
      `SELECT COUNT(*) as count FROM activities a WHERE ${this.VISIBLE_TO_USER}`,
      [userId]
    );
    return parseInt(result.rows[0].count);
  }

  /**
   * Count total activities for a group
   */
  static async countByGroupId(groupId) {
    const result = await query(
      `SELECT COUNT(*) as count
       FROM activities
       WHERE group_id = $1 AND deleted_at IS NULL`,
      [groupId]
    );
    return parseInt(result.rows[0].count);
  }
}

export default Activity;
