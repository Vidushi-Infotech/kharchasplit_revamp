-- Migration 013: Switch auth from phone-OTP to phone-password.
-- Adds purpose + email columns to otps so it can carry password-reset OTPs
-- (sent to email instead of SMS). Makes otps.phone_number nullable since
-- password-reset OTPs are looked up by email.
--
-- Dev wipe: clear users, refresh_tokens, otps so password-less legacy rows
-- don't block the new flow. Cascading FKs will clear dependent rows
-- (groups, expenses, etc.) via ON DELETE CASCADE / SET NULL where defined.

BEGIN;

-- otps: add columns for email-based password reset
ALTER TABLE otps
    ADD COLUMN IF NOT EXISTS purpose VARCHAR(32) NOT NULL DEFAULT 'login';

ALTER TABLE otps
    ADD COLUMN IF NOT EXISTS email VARCHAR(255);

ALTER TABLE otps
    ALTER COLUMN phone_number DROP NOT NULL;

ALTER TABLE otps
    ADD CONSTRAINT otps_identifier_present
    CHECK (phone_number IS NOT NULL OR email IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_otps_email ON otps(email);
CREATE INDEX IF NOT EXISTS idx_otps_purpose ON otps(purpose);

-- Wipe all dev data so the new password-auth flow starts from a clean slate.
-- TRUNCATE CASCADE clears users + everything FK'd to it.
TRUNCATE TABLE
    refresh_tokens,
    otps,
    users
RESTART IDENTITY CASCADE;

COMMIT;
