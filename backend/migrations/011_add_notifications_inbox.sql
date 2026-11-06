-- Migration: In-app notifications inbox
-- Version: 011
-- Description: One row per notification delivered to a user. Lets the app
--   show a persistent inbox (with unread badge + mark-read) even after a
--   push notification has been dismissed from the system tray. Each row is
--   created at the moment the backend sends the corresponding FCM push so
--   the two stay in sync.

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Inbox queries always filter by user + sort by created_at DESC, so a
-- composite index serves both list and unread-count fast.
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications(user_id, created_at DESC);

-- Partial index for unread-count: most queries hit this and only need
-- to scan the (typically tiny) unread tail.
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications(user_id)
  WHERE is_read = FALSE;
