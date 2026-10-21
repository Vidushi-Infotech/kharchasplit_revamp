-- 020: Non-group expenses between two friends (Oct 2026)
--
-- Each friend pair gets one hidden "direct" group (groups.kind = 'direct'),
-- so balances, payments, notifications, reminders and exports all reuse the
-- group machinery. direct_pairs makes it one per pair (user_low < user_high).
--
-- The server also applies this on startup (src/config/initDatabase.js).
-- Idempotent and additive: older app builds never see direct groups in the
-- groups list.

BEGIN;

ALTER TABLE groups ADD COLUMN IF NOT EXISTS kind VARCHAR(10) NOT NULL DEFAULT 'group';

CREATE TABLE IF NOT EXISTS direct_pairs (
  user_low UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_high UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  group_id UUID NOT NULL UNIQUE REFERENCES groups(id) ON DELETE CASCADE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_low, user_high),
  CHECK (user_low < user_high)
);

COMMIT;
