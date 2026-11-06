-- 016: Notification email outbox, known devices, auto-reminder state,
--      email-on by default (Oct 2026)
--
-- The server also applies these automatically on startup
-- (src/config/initDatabase.js), so running this by hand is optional.
-- Idempotent: safe to run more than once.

BEGIN;

-- Durable queue for notification emails (services/emailOutbox.js).
CREATE TABLE IF NOT EXISTS email_outbox (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  to_email VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL,
  subject TEXT NOT NULL,
  text_body TEXT NOT NULL,
  html_body TEXT NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending', -- pending | sending | sent | failed
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  message_id TEXT,
  dedupe_key VARCHAR(255) UNIQUE,
  send_after TIMESTAMP NOT NULL DEFAULT NOW(),
  locked_at TIMESTAMP,
  sent_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_outbox_due
  ON email_outbox(send_after) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_email_outbox_user
  ON email_outbox(user_id, created_at DESC);

-- Devices each account has signed in from, for "new sign-in" alerts.
-- Kept separately from refresh_tokens, which are deleted on logout.
CREATE TABLE IF NOT EXISTS user_known_devices (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fingerprint VARCHAR(255) NOT NULL,
  first_seen_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, fingerprint)
);

-- Auto settlement reminders (jobs/settlementReminderJob.js): one row per
-- open debt (group, debtor → creditor). Deleted once the debt is settled,
-- which resets the reminder count.
CREATE TABLE IF NOT EXISTS auto_reminder_state (
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  debtor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  creditor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_seen_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_sent_at TIMESTAMP,
  sent_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (group_id, debtor_id, creditor_id)
);

-- Notification emails are now on by default for new prefs rows. Existing
-- rows keep their stored value.
ALTER TABLE notification_prefs ALTER COLUMN email_enabled SET DEFAULT TRUE;

COMMIT;

-- Verify:
--   SELECT status, COUNT(*) FROM email_outbox GROUP BY 1;
