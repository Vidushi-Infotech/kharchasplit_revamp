-- Migration 013: Switch auth from phone-OTP to phone-password.
-- Adds purpose + email columns to otps so it can carry password-reset OTPs
-- (sent to email instead of SMS). Makes otps.phone_number nullable since
-- password-reset OTPs are looked up by email.
--
-- It used to end by wiping users, refresh_tokens and otps (and, through
-- cascades, every group and expense) for a clean dev start. That wipe is
-- gone: re-running this file on a live database must never delete data.
-- The schema changes are safe to re-run.

BEGIN;

-- otps: add columns for email-based password reset
ALTER TABLE otps
    ADD COLUMN IF NOT EXISTS purpose VARCHAR(32) NOT NULL DEFAULT 'login';

ALTER TABLE otps
    ADD COLUMN IF NOT EXISTS email VARCHAR(255);

ALTER TABLE otps
    ALTER COLUMN phone_number DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'otps_identifier_present') THEN
    ALTER TABLE otps
      ADD CONSTRAINT otps_identifier_present
      CHECK (phone_number IS NOT NULL OR email IS NOT NULL);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_otps_email ON otps(email);
CREATE INDEX IF NOT EXISTS idx_otps_purpose ON otps(purpose);

COMMIT;
