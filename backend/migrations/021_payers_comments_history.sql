-- 021: Multiple payers, comments, edit history, adjustment split meta,
--      group default split (Oct 2026)
--
-- The server also creates the tables/columns on startup
-- (src/config/initDatabase.js); the backfill below only runs here.
-- Idempotent and additive.

BEGIN;

-- Who paid how much. expenses.paid_by stays (= the largest payer) so older
-- app builds and every display query keep working; the ledger reads this
-- table (falling back to paid_by for expenses with no rows yet).
CREATE TABLE IF NOT EXISTS expense_payers (
  expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
  PRIMARY KEY (expense_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_expense_payers_user ON expense_payers(user_id);

-- Backfill: one payer row per existing expense.
INSERT INTO expense_payers (expense_id, user_id, amount)
SELECT e.id, e.paid_by, e.amount
  FROM expenses e
 WHERE e.paid_by IS NOT NULL AND e.amount > 0
   AND NOT EXISTS (SELECT 1 FROM expense_payers p WHERE p.expense_id = e.id);

-- How the split was entered, for splits stored as plain amounts, e.g.
-- {"mode":"adjustment","adjustments":{"<userId>":150}}. split_type stays a
-- value older builds understand ('exact').
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS split_meta JSONB;

CREATE TABLE IF NOT EXISTS expense_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_expense_comments_expense ON expense_comments(expense_id, created_at);

-- State of an expense before each edit (and before a restore).
CREATE TABLE IF NOT EXISTS expense_revisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  edited_by UUID REFERENCES users(id) ON DELETE SET NULL,
  snapshot JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_expense_revisions_expense ON expense_revisions(expense_id, created_at DESC);

-- Group default split, e.g. {"type":"percentage","values":{"<userId>":60,…}}.
ALTER TABLE groups ADD COLUMN IF NOT EXISTS default_split JSONB;

COMMIT;
