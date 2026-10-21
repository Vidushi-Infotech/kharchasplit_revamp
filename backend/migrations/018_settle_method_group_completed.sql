-- 018: Settlement payment method + group completed state (Oct 2026)
--
-- The server also adds these columns on startup (src/config/initDatabase.js),
-- so running it by hand is only needed where the app user lacks DDL rights.
-- Idempotent: safe to run more than once. Additive only — older app builds
-- never send `method` and keep working (NULL is shown as "Other").

BEGIN;

-- How a payment was made: cash | upi | bank_transfer | other.
-- NULL = recorded before this column existed (or by an older app build).
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS method VARCHAR(20);

-- archived_at may be missing on databases created from initDatabase.js
-- (migration 005 was not always applied).
ALTER TABLE groups ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;
-- Set when a fully settled group is marked complete (always archived too).
ALTER TABLE groups ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;

COMMIT;
