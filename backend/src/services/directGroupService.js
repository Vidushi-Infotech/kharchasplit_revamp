import { query, transaction } from '../config/database.js';
import { cache } from './cacheService.js';

/**
 * Non-group expenses between two friends live in a hidden "direct" group
 * (groups.kind = 'direct', exactly the two of them), one per pair via
 * direct_pairs. Everything else — balances (ledger), payments, settle-all,
 * notifications, reminders, export — works on it like any group.
 *
 * Direct groups never show in the groups list, can't be renamed, archived,
 * deleted, left or given more members (routes/groupRoutes.js rejectDirect).
 */
export const DIRECT_GROUP_NAME = 'Non-group expenses';

export class DirectGroupError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

/**
 * The direct group of `userId` and `friendId`, created on first use.
 * @returns {Promise<{groupId: string, created: boolean}>}
 */
export async function getOrCreateDirectGroup(userId, friendId) {
  if (userId === friendId) throw new DirectGroupError('You can\'t add an expense with yourself', 400);
  const [low, high] = [userId, friendId].sort();

  const existing = await query(
    'SELECT group_id FROM direct_pairs WHERE user_low = $1 AND user_high = $2',
    [low, high],
  );
  if (existing.rows[0]) return { groupId: existing.rows[0].group_id, created: false };

  // Who may start one: anyone you already share a group with, or any real
  // (registered) account — e.g. found by phone number. Placeholders that
  // aren't in any of your groups are not reachable this way.
  const { rows: [friend] } = await query(
    `SELECT u.id, u.name, u.phone_number, u.email, COALESCE(u.is_placeholder, FALSE) AS is_placeholder,
            EXISTS (
              SELECT 1 FROM group_members a
                JOIN group_members b ON b.group_id = a.group_id AND b.user_id = u.id AND b.deleted_at IS NULL
                JOIN groups g ON g.id = a.group_id AND g.deleted_at IS NULL
               WHERE a.user_id = $2 AND a.deleted_at IS NULL
            ) AS shares_group
       FROM users u WHERE u.id = $1 AND u.deleted_at IS NULL`,
    [friendId, userId],
  );
  if (!friend || (friend.is_placeholder && !friend.shares_group)) {
    throw new DirectGroupError('User not found', 404);
  }

  const { rows: [me] } = await query(
    "SELECT COALESCE(preferred_currency, 'INR') AS currency FROM users WHERE id = $1",
    [userId],
  );

  return transaction(async (client) => {
    // Serialise the two people creating it at the same moment.
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [`direct:${low}:${high}`]);
    const again = await client.query(
      'SELECT group_id FROM direct_pairs WHERE user_low = $1 AND user_high = $2',
      [low, high],
    );
    if (again.rows[0]) return { groupId: again.rows[0].group_id, created: false };

    const { rows: [group] } = await client.query(
      `INSERT INTO groups (name, currency, created_by, kind)
       VALUES ($1, $2, $3, 'direct') RETURNING id`,
      [DIRECT_GROUP_NAME, me?.currency || 'INR', userId],
    );
    // Both are plain members: there is nothing to administer.
    await client.query(
      `INSERT INTO group_members (group_id, user_id, name, phone_number, email, role, added_by)
       SELECT $1, u.id, u.name, u.phone_number, u.email, 'member', $2
         FROM users u WHERE u.id = ANY($3::uuid[])`,
      [group.id, userId, [userId, friendId]],
    );
    await client.query(
      'INSERT INTO direct_pairs (user_low, user_high, group_id) VALUES ($1, $2, $3)',
      [low, high, group.id],
    );
    return { groupId: group.id, created: true };
  }).then((r) => {
    if (r.created) {
      // Membership caches (MEMBER_ACCESS) may hold "not a member" for this id.
      cache.invalidate(`group:${r.groupId}`);
      cache.invalidate(`user:${userId}`);
      cache.invalidate(`user:${friendId}`);
    }
    return r;
  });
}
