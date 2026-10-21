-- 017: Idempotency-Key replay store (Oct 2026)
--
-- The server also creates this on startup (src/config/initDatabase.js),
-- so running it by hand is only needed where the app user lacks DDL rights.
-- Idempotent: safe to run more than once.

BEGIN;

-- Idempotency-Key replay store (middleware/idempotency.js). Rows expire
-- after 24h (hourly cleanup on PM2 instance 0).
CREATE TABLE IF NOT EXISTS idempotency_keys (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  key VARCHAR(100) NOT NULL,
  request_hash CHAR(64) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'in_progress', -- in_progress | done
  response_status INTEGER,
  response_body JSONB,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_created ON idempotency_keys(created_at);

COMMIT;
