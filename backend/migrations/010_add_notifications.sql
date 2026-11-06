-- Migration: Notification preferences + multi-device FCM tokens
-- Version: 010
-- Description:
--   1. notification_prefs table — per-user toggles (push/email + per-type).
--      Server consults these before sending any push so prefs are honored
--      consistently across devices.
--   2. user_devices table — one row per (user, device). Replaces the single
--      users.fcm_token column so a user can be signed in on multiple devices
--      and receive push on all of them. The old users.fcm_token column is
--      kept for now so the legacy PUT /users/:id/fcm-token endpoint can
--      backfill silently during the transition.

CREATE TABLE IF NOT EXISTS notification_prefs (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  email_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  new_expense BOOLEAN NOT NULL DEFAULT TRUE,
  group_invite BOOLEAN NOT NULL DEFAULT TRUE,
  payment_received BOOLEAN NOT NULL DEFAULT TRUE,
  settlement_reminder BOOLEAN NOT NULL DEFAULT TRUE,
  comment_mention BOOLEAN NOT NULL DEFAULT TRUE,
  weekly_summary BOOLEAN NOT NULL DEFAULT FALSE,
  product_updates BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform VARCHAR(20),
  device_name VARCHAR(255),
  os_version VARCHAR(80),
  app_version VARCHAR(40),
  last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_last_seen ON user_devices(last_seen_at);

-- Backfill: copy any existing users.fcm_token into user_devices so legacy
-- tokens registered before this migration continue working.
INSERT INTO user_devices (user_id, fcm_token, last_seen_at, created_at)
SELECT id, fcm_token, COALESCE(fcm_token_updated_at, CURRENT_TIMESTAMP), COALESCE(fcm_token_updated_at, CURRENT_TIMESTAMP)
FROM users
WHERE fcm_token IS NOT NULL AND fcm_token <> ''
ON CONFLICT (fcm_token) DO NOTHING;
