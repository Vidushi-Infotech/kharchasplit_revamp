-- 024: Per-user read state for the shared activity feed (Oct 2026)
--
-- The Activity tab now shows everything that happens in your groups, not
-- only your own actions, so "read" can't live on the activity row any more
-- (activities.is_read is left in place, unused). Your own actions are
-- always read; others' get a row here when you open them or mark all read.
-- Idempotent and additive; the server also creates it on startup.

BEGIN;

CREATE TABLE IF NOT EXISTS activity_reads (
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  read_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (activity_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_activity_reads_user ON activity_reads(user_id);

-- Feed lookups by membership.
CREATE INDEX IF NOT EXISTS idx_group_members_user_group ON group_members(user_id, group_id);

-- Everything that happened before this migration counts as already read,
-- so nobody opens the app to a pile of "new" old activity from others.
-- Re-running only adds rows that are missing.
INSERT INTO activity_reads (activity_id, user_id)
SELECT a.id, gm.user_id
  FROM activities a
  JOIN group_members gm ON gm.group_id = a.group_id AND gm.user_id IS NOT NULL
 WHERE a.deleted_at IS NULL AND gm.user_id <> a.user_id
   AND NOT EXISTS (SELECT 1 FROM activity_reads r
                    WHERE r.activity_id = a.id AND r.user_id = gm.user_id)
ON CONFLICT DO NOTHING;

COMMIT;
