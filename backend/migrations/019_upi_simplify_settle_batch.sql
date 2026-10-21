-- 019: UPI ID, simplify-debts toggle, settle-all batches (Oct 2026)
--
-- The server also adds these columns on startup (src/config/initDatabase.js),
-- so running it by hand is only needed where the app user lacks DDL rights.
-- Idempotent and additive: older app builds keep working.

BEGIN;

-- Payee's UPI VPA (e.g. name@okhdfc). Shown only to people who owe them.
ALTER TABLE users ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100);

-- Per-group "Simplify group debts". Off by default so existing groups keep
-- their pairwise balances. (The legacy groups.simplified_debts column was
-- never read and defaults to TRUE, so it is deliberately not reused.)
ALTER TABLE groups ADD COLUMN IF NOT EXISTS simplify_debts BOOLEAN NOT NULL DEFAULT FALSE;

-- Rows recorded together by "Settle all balances" share a batch id.
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS batch_id UUID;
CREATE INDEX IF NOT EXISTS idx_settlements_batch ON settlements(batch_id) WHERE batch_id IS NOT NULL;

COMMIT;
