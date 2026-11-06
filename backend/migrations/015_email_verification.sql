-- 015: Email verification + reminder bookkeeping (Sep 2026)
--
-- The server also applies these automatically on startup
-- (src/config/initDatabase.js → columnAdditions), so running this by hand
-- is optional. It is idempotent: safe to run more than once.

BEGIN;

-- NULL = not verified. Reset to NULL by User.update() whenever the email changes.
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP;

-- jobs/emailVerifyReminderJob.js: last reminder sent / how many sent (max 3).
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verify_reminder_at TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verify_reminder_count INTEGER DEFAULT 0;

-- The OTP flow reuses the otps table with purpose = 'email_verify'.
-- These columns already exist on servers that run the password-reset flow;
-- included for completeness.
ALTER TABLE otps ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE otps ADD COLUMN IF NOT EXISTS purpose VARCHAR(32) NOT NULL DEFAULT 'login';
CREATE INDEX IF NOT EXISTS idx_otps_email ON otps(email);
CREATE INDEX IF NOT EXISTS idx_otps_purpose ON otps(purpose);

-- Speeds up the reminder job's "unverified + active" scan.
CREATE INDEX IF NOT EXISTS idx_users_email_unverified
  ON users(id) WHERE email_verified_at IS NULL AND deleted_at IS NULL;

COMMIT;

-- Verify:
--   SELECT column_name FROM information_schema.columns
--    WHERE table_name = 'users' AND column_name LIKE 'email_verif%';
