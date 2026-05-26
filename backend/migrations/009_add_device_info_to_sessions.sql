-- Migration: Add device info to refresh tokens
-- Version: 009
-- Description: Tracks per-session device metadata so users can identify and
-- revoke individual sign-ins in the Active Sessions screen.

ALTER TABLE refresh_tokens
  ADD COLUMN IF NOT EXISTS device_name VARCHAR(255),
  ADD COLUMN IF NOT EXISTS platform VARCHAR(50),
  ADD COLUMN IF NOT EXISTS os_version VARCHAR(80),
  ADD COLUMN IF NOT EXISTS app_version VARCHAR(40),
  ADD COLUMN IF NOT EXISTS ip_address VARCHAR(64),
  ADD COLUMN IF NOT EXISTS user_agent TEXT,
  ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_last_used
  ON refresh_tokens(last_used_at);
