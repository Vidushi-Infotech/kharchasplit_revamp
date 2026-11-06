-- 026: Monthly budgets in the Personal mode (Oct 2026)
--
-- One row per user and category: a monthly limit that applies every
-- month until changed or removed. category is an expense category id
-- (food, fuel, ...) or 'total' for the whole month's spending.
-- Idempotent and additive; the server also creates it on startup.

BEGIN;

CREATE TABLE IF NOT EXISTS personal_budgets (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category VARCHAR(50) NOT NULL,
  amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, category)
);

COMMIT;
