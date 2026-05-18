import { query, transaction  } from '../config/database.js';
import { cache, TTL } from '../services/cacheService.js';

class Group {
  /**
   * Find group by ID (cached — 60s TTL)
   * No cover_image_base64 — use findByIdFull for the detail endpoint
   */
  static async findById(id) {
    return cache.getOrSet(`group:${id}`, TTL.GROUP_DETAIL, async () => {
      const result = await query(
        `SELECT g.id, g.name, g.description, g.currency,
                g.is_archived, g.created_by, g.created_at, g.updated_at,
                (SELECT COUNT(*) FROM group_members gm
                 WHERE gm.group_id = g.id AND gm.deleted_at IS NULL) as member_count,
                (SELECT COUNT(*) FROM expenses e
                 WHERE e.group_id = g.id AND e.deleted_at IS NULL) as expense_count,
                (SELECT COALESCE(SUM(e.amount), 0) FROM expenses e
                 WHERE e.group_id = g.id AND e.deleted_at IS NULL) as total_expenses
         FROM groups g
         WHERE g.id = $1 AND g.deleted_at IS NULL`,
        [id]
      );
      return result.rows[0] || null;
    });
  }

  /**
   * Find group by ID with cover image (for detail endpoint only)
   */
  static async findByIdFull(id) {
    const result = await query(
      `SELECT g.id, g.name, g.description, g.cover_image_base64, g.currency,
              g.is_archived, g.created_by, g.created_at, g.updated_at,
              (SELECT COUNT(*) FROM group_members gm
               WHERE gm.group_id = g.id AND gm.deleted_at IS NULL) as member_count,
              (SELECT COUNT(*) FROM expenses e
               WHERE e.group_id = g.id AND e.deleted_at IS NULL) as expense_count,
              (SELECT COALESCE(SUM(e.amount), 0) FROM expenses e
               WHERE e.group_id = g.id AND e.deleted_at IS NULL) as total_expenses
       FROM groups g
       WHERE g.id = $1 AND g.deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Find groups by user ID
   */
  static async findByUserId(userId, limit = 20, offset = 0) {
    // Uses subqueries instead of triple JOIN + GROUP BY for much better performance.
    // cover_image_base64 is included so the groups list / dashboard cards
    // render the actual photo (cover images are compressed to ~30-80KB).
    const result = await query(
      `SELECT g.id, g.name, g.description, g.created_by, g.created_at, g.updated_at,
              g.currency, g.is_archived, g.cover_image_base64,
              (SELECT COUNT(*) FROM group_members gm2
               WHERE gm2.group_id = g.id AND gm2.deleted_at IS NULL) as member_count,
              (SELECT COUNT(*) FROM expenses e
               WHERE e.group_id = g.id AND e.deleted_at IS NULL) as expense_count,
              (SELECT COALESCE(SUM(e.amount), 0) FROM expenses e
               WHERE e.group_id = g.id AND e.deleted_at IS NULL) as total_expenses
       FROM groups g
       INNER JOIN group_members gm ON g.id = gm.group_id AND gm.user_id = $1 AND gm.deleted_at IS NULL
       WHERE g.deleted_at IS NULL
       ORDER BY g.updated_at DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );
    return result.rows;
  }

  /**
   * Create new group with members
   */
  static async create(groupData, members) {
    return transaction(async (client) => {
      // Create group
      const groupResult = await client.query(
        `INSERT INTO groups (name, description, cover_image_base64, currency, created_by)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, name, description, currency, created_by, created_at, updated_at`,
        [groupData.name, groupData.description || null, groupData.coverImageBase64 || null, groupData.currency || 'INR', groupData.createdBy]
      );
      const group = groupResult.rows[0];

      // Add creator as admin
      await client.query(
        `INSERT INTO group_members (group_id, user_id, name, phone_number, email, role, added_by)
         SELECT $1, $2, name, phone_number, email, 'creator', $2
         FROM users WHERE id = $2`,
        [group.id, groupData.createdBy]
      );

      // Add other members in a single batch INSERT
      if (members && members.length > 0) {
        const values = [];
        const params = [];
        let paramIndex = 1;

        for (const member of members) {
          values.push(`($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, $${paramIndex + 4}, 'member', $${paramIndex + 5})`);
          params.push(
            group.id, member.userId, member.name,
            member.phoneNumber || null, member.email || null, groupData.createdBy
          );
          paramIndex += 6;
        }

        await client.query(
          `INSERT INTO group_members (group_id, user_id, name, phone_number, email, role, added_by)
           VALUES ${values.join(', ')}`,
          params
        );
      }

      return group;
    });
  }

  /**
   * Invalidate all cached data for a group
   */
  static invalidateGroup(groupId) {
    cache.invalidate(`group:${groupId}`);
  }

  /**
   * Update group
   */
  static async update(id, groupData) {
    const { name, description, coverImageBase64, currency } = groupData;
    const result = await query(
      `UPDATE groups
       SET name = COALESCE($1, name),
           description = COALESCE($2, description),
           cover_image_base64 = COALESCE($3, cover_image_base64),
           currency = COALESCE($4, currency)
       WHERE id = $5 AND deleted_at IS NULL
       RETURNING id, name, description, currency, created_by, created_at, updated_at`,
      [name, description, coverImageBase64, currency, id]
    );
    if (result.rows[0]) cache.del(`group:${id}`);
    return result.rows[0] || null;
  }

  /**
   * Soft delete group
   */
  static async delete(id) {
    const result = await query(
      'UPDATE groups SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL RETURNING id',
      [id]
    );
    if (result.rows.length > 0) this.invalidateGroup(id);
    return result.rows.length > 0;
  }

  /**
   * Archive group
   */
  static async archive(id) {
    const result = await query(
      'UPDATE groups SET is_archived = TRUE WHERE id = $1 AND deleted_at IS NULL AND is_archived = FALSE RETURNING id',
      [id]
    );
    if (result.rows.length > 0) cache.del(`group:${id}`);
    return result.rows.length > 0;
  }

  /**
   * Unarchive group
   */
  static async unarchive(id) {
    const result = await query(
      'UPDATE groups SET is_archived = FALSE WHERE id = $1 AND deleted_at IS NULL AND is_archived = TRUE RETURNING id',
      [id]
    );
    if (result.rows.length > 0) cache.del(`group:${id}`);
    return result.rows.length > 0;
  }

  /**
   * Get group members (cached — 120s TTL)
   */
  static async getMembers(groupId) {
    return cache.getOrSet(`group:${groupId}:members`, TTL.GROUP_MEMBERS, async () => {
      const result = await query(
        // Prefer the canonical users.name (kept fresh by profile updates) over
        // the snapshot stored in group_members.name at invite time. Falls back
        // to gm.name only when the linked user row is missing (orphaned join).
        `SELECT gm.group_id, gm.user_id,
                COALESCE(u.name, gm.name) AS name,
                gm.phone_number, gm.email,
                gm.role, gm.joined_at, gm.added_by, u.is_placeholder,
                u.profile_image_base64
         FROM group_members gm
         LEFT JOIN users u ON gm.user_id = u.id
         WHERE gm.group_id = $1 AND gm.deleted_at IS NULL
         ORDER BY
           CASE gm.role
             WHEN 'creator' THEN 1
             WHEN 'admin' THEN 2
             ELSE 3
           END,
           gm.joined_at`,
        [groupId]
      );
      return result.rows;
    });
  }

  /**
   * Batch fetch members for multiple groups in a single query
   * Eliminates N+1 problem when loading group lists
   */
  static async getMembersByGroupIds(groupIds) {
    if (!groupIds || groupIds.length === 0) return {};

    const placeholders = groupIds.map((_, i) => `$${i + 1}`).join(', ');
    const result = await query(
      // See note in getMembers — prefer the live users.name.
      `SELECT gm.group_id, gm.user_id,
              COALESCE(u.name, gm.name) AS name,
              gm.phone_number, gm.email,
              gm.role, gm.joined_at, gm.added_by, u.is_placeholder,
              u.profile_image_base64
       FROM group_members gm
       LEFT JOIN users u ON gm.user_id = u.id
       WHERE gm.group_id IN (${placeholders}) AND gm.deleted_at IS NULL
       ORDER BY
         CASE gm.role
           WHEN 'creator' THEN 1
           WHEN 'admin' THEN 2
           ELSE 3
         END,
         gm.joined_at`,
      groupIds
    );

    // Group results by group_id
    const membersByGroup = {};
    for (const groupId of groupIds) {
      membersByGroup[groupId] = [];
    }
    for (const row of result.rows) {
      membersByGroup[row.group_id].push(row);
    }
    return membersByGroup;
  }

  /**
   * Invalidate member-related caches for a group
   */
  static invalidateMembers(groupId, userId) {
    cache.del(`group:${groupId}:members`);
    cache.del(`group:${groupId}`); // member_count changes
    if (userId) {
      cache.del(`group:${groupId}:access:${userId}`);
      cache.del(`group:${groupId}:admin:${userId}`);
    }
  }

  /**
   * Add member to group
   * Handles re-adding previously removed members by reactivating their record
   */
  static async addMember(groupId, memberData) {
    // First, check if there's a soft-deleted record for this user
    const existingResult = await query(
      `SELECT id, deleted_at FROM group_members
       WHERE group_id = $1 AND user_id = $2`,
      [groupId, memberData.userId]
    );

    if (existingResult.rows.length > 0) {
      const existing = existingResult.rows[0];

      if (existing.deleted_at === null) {
        // Member is already active - return conflict error
        throw new Error('User is already a member of this group');
      }

      // Reactivate the soft-deleted member
      const reactivateResult = await query(
        `UPDATE group_members
         SET deleted_at = NULL,
             name = $3,
             phone_number = $4,
             email = $5,
             role = $6,
             added_by = $7,
             joined_at = NOW()
         WHERE group_id = $1 AND user_id = $2
         RETURNING *`,
        [
          groupId,
          memberData.userId,
          memberData.name,
          memberData.phoneNumber || null,
          memberData.email || null,
          memberData.role || 'member',
          memberData.addedBy
        ]
      );
      this.invalidateMembers(groupId, memberData.userId);
      return reactivateResult.rows[0];
    }

    // No existing record - insert new member
    const result = await query(
      `INSERT INTO group_members (group_id, user_id, name, phone_number, email, role, added_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        groupId,
        memberData.userId,
        memberData.name,
        memberData.phoneNumber || null,
        memberData.email || null,
        memberData.role || 'member',
        memberData.addedBy
      ]
    );
    this.invalidateMembers(groupId, memberData.userId);
    return result.rows[0];
  }

  /**
   * Remove member from group
   */
  static async removeMember(groupId, userId) {
    const result = await query(
      'UPDATE group_members SET deleted_at = NOW() WHERE group_id = $1 AND user_id = $2 AND deleted_at IS NULL RETURNING id',
      [groupId, userId]
    );
    if (result.rows.length > 0) this.invalidateMembers(groupId, userId);
    return result.rows.length > 0;
  }

  /**
   * Update member role
   */
  static async updateMemberRole(groupId, userId, role) {
    const result = await query(
      `UPDATE group_members
       SET role = $1
       WHERE group_id = $2 AND user_id = $3 AND deleted_at IS NULL
       RETURNING *`,
      [role, groupId, userId]
    );
    if (result.rows[0]) {
      cache.del(`group:${groupId}:admin:${userId}`);
      cache.del(`group:${groupId}:access:${userId}`);
    }
    return result.rows[0] || null;
  }

  /**
   * Check if user is group member (cached — 120s TTL)
   */
  static async isMember(groupId, userId) {
    return cache.getOrSet(`group:${groupId}:access:${userId}`, TTL.MEMBER_ACCESS, async () => {
      const result = await query(
        'SELECT id FROM group_members WHERE group_id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [groupId, userId]
      );
      return result.rows.length > 0;
    });
  }

  /**
   * Check if user is group admin/creator (cached — 120s TTL)
   */
  static async isAdmin(groupId, userId) {
    return cache.getOrSet(`group:${groupId}:admin:${userId}`, TTL.MEMBER_ACCESS, async () => {
      const result = await query(
        "SELECT id FROM group_members WHERE group_id = $1 AND user_id = $2 AND role IN ('creator', 'admin') AND deleted_at IS NULL",
        [groupId, userId]
      );
      return result.rows.length > 0;
    });
  }

  // =====================================================
  // PENDING INVITES METHODS (for non-registered users)
  // =====================================================

  /**
   * Add pending invite for non-registered user
   * @param {string} groupId - Group ID
   * @param {Object} inviteData - Invite data
   * @returns {Object} - Created pending invite
   */
  static async addPendingInvite(groupId, inviteData) {
    const { phoneNumber, name, email, invitedBy, watiMessageId, watiStatus } = inviteData;

    // Check if pending invite already exists
    const existingResult = await query(
      `SELECT id, invite_count FROM pending_group_invites
       WHERE group_id = $1 AND phone_number = $2`,
      [groupId, phoneNumber]
    );

    if (existingResult.rows.length > 0) {
      // Update existing invite (resend)
      const result = await query(
        `UPDATE pending_group_invites
         SET name = $3,
             email = $4,
             wati_message_id = $5,
             wati_status = $6,
             wati_sent_at = NOW(),
             invite_count = invite_count + 1,
             last_invited_at = NOW()
         WHERE group_id = $1 AND phone_number = $2
         RETURNING *`,
        [groupId, phoneNumber, name, email || null, watiMessageId || null, watiStatus || 'pending']
      );
      return result.rows[0];
    }

    // Create new pending invite
    const result = await query(
      `INSERT INTO pending_group_invites (group_id, phone_number, name, email, invited_by, wati_message_id, wati_status, wati_sent_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING *`,
      [groupId, phoneNumber, name, email || null, invitedBy, watiMessageId || null, watiStatus || 'pending']
    );
    return result.rows[0];
  }

  /**
   * Update WATI status for pending invite
   * @param {string} inviteId - Pending invite ID
   * @param {string} status - WATI status (sent, delivered, read, failed)
   * @param {string} error - Error message if failed
   */
  static async updatePendingInviteWatiStatus(inviteId, status, error = null) {
    const result = await query(
      `UPDATE pending_group_invites
       SET wati_status = $2, wati_error = $3
       WHERE id = $1
       RETURNING *`,
      [inviteId, status, error]
    );
    return result.rows[0];
  }

  /**
   * Get pending invites for a group
   * @param {string} groupId - Group ID
   * @returns {Array} - List of pending invites
   */
  static async getPendingInvites(groupId) {
    const result = await query(
      `SELECT pi.*, u.name as inviter_name
       FROM pending_group_invites pi
       LEFT JOIN users u ON pi.invited_by = u.id
       WHERE pi.group_id = $1
       ORDER BY pi.created_at DESC`,
      [groupId]
    );
    return result.rows;
  }

  /**
   * Get pending invites for a phone number (across all groups)
   * Used when user registers to auto-add them to groups
   * @param {string} phoneNumber - Phone number
   * @returns {Array} - List of pending invites
   */
  static async getPendingInvitesByPhone(phoneNumber) {
    const result = await query(
      `SELECT pi.*, g.name as group_name
       FROM pending_group_invites pi
       JOIN groups g ON pi.group_id = g.id AND g.deleted_at IS NULL
       WHERE pi.phone_number = $1`,
      [phoneNumber]
    );
    return result.rows;
  }

  /**
   * Delete pending invite (after user registers and joins)
   * @param {string} inviteId - Pending invite ID
   */
  static async deletePendingInvite(inviteId) {
    const result = await query(
      'DELETE FROM pending_group_invites WHERE id = $1 RETURNING id',
      [inviteId]
    );
    return result.rows.length > 0;
  }

  /**
   * Batch delete pending invites by IDs
   * @param {string[]} inviteIds - Array of pending invite IDs
   * @returns {number} - Number of deleted invites
   */
  static async deletePendingInvitesByIds(inviteIds) {
    if (!inviteIds || inviteIds.length === 0) return 0;
    const placeholders = inviteIds.map((_, i) => `$${i + 1}`).join(', ');
    const result = await query(
      `DELETE FROM pending_group_invites WHERE id IN (${placeholders}) RETURNING id`,
      inviteIds
    );
    return result.rowCount;
  }

  /**
   * Delete pending invite by group and phone
   * @param {string} groupId - Group ID
   * @param {string} phoneNumber - Phone number
   */
  static async deletePendingInviteByPhone(groupId, phoneNumber) {
    const result = await query(
      'DELETE FROM pending_group_invites WHERE group_id = $1 AND phone_number = $2 RETURNING id',
      [groupId, phoneNumber]
    );
    return result.rows.length > 0;
  }

  /**
   * Check if phone has pending invite in group
   * @param {string} groupId - Group ID
   * @param {string} phoneNumber - Phone number
   * @returns {boolean}
   */
  static async hasPendingInvite(groupId, phoneNumber) {
    const result = await query(
      'SELECT id FROM pending_group_invites WHERE group_id = $1 AND phone_number = $2',
      [groupId, phoneNumber]
    );
    return result.rows.length > 0;
  }

  /**
   * Process pending invites when user registers
   * Auto-adds user to groups where they have pending invites
   * @param {string} userId - New user's ID
   * @param {string} phoneNumber - User's phone number
   * @param {string} name - User's name
   * @returns {Array} - Groups user was added to
   */
  static async processPendingInvitesForUser(userId, phoneNumber, name) {
    const pendingInvites = await this.getPendingInvitesByPhone(phoneNumber);
    if (pendingInvites.length === 0) return [];

    const addedGroups = [];

    // Batch: add member to all groups + delete all invites in a single transaction
    return transaction(async (client) => {
      // Batch INSERT all group memberships in one query
      const memberValues = [];
      const memberParams = [];
      let paramIndex = 1;

      for (const invite of pendingInvites) {
        memberValues.push(
          `($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, $${paramIndex + 4}, 'member', $${paramIndex + 5})`
        );
        memberParams.push(
          invite.group_id, userId, name || invite.name,
          phoneNumber, invite.email || null, invite.invited_by
        );
        paramIndex += 6;

        addedGroups.push({
          groupId: invite.group_id,
          groupName: invite.group_name,
        });
      }

      // Use ON CONFLICT to skip groups where user is already a member
      await client.query(
        `INSERT INTO group_members (group_id, user_id, name, phone_number, email, role, added_by)
         VALUES ${memberValues.join(', ')}
         ON CONFLICT (group_id, user_id) DO UPDATE SET
           deleted_at = NULL, name = EXCLUDED.name, phone_number = EXCLUDED.phone_number,
           email = EXCLUDED.email, role = EXCLUDED.role, added_by = EXCLUDED.added_by, joined_at = NOW()`,
        memberParams
      );

      // Batch DELETE all pending invites in one query
      const inviteIds = pendingInvites.map(i => i.id);
      const invitePlaceholders = inviteIds.map((_, i) => `$${i + 1}`).join(', ');
      await client.query(
        `DELETE FROM pending_group_invites WHERE id IN (${invitePlaceholders})`,
        inviteIds
      );

      console.log(`[Group] Batch-added user ${userId} to ${addedGroups.length} groups from pending invites`);
      return addedGroups;
    });
  }
}

export default Group;
