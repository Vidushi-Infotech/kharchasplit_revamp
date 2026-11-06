-- 022: Recurring expenses (Oct 2026)
--
-- The server also creates these on startup (src/config/initDatabase.js).
-- Idempotent and additive.

BEGIN;

-- A repeating expense. `template` is the expense to create each time
-- (description, amount, currency, category, notes, splitType, splitMeta,
-- payers, participants). Occurrence n falls on occurrenceDate(anchor_date,
-- frequency, n) (src/utils/recurrence.js); next_index is the next one due.
CREATE TABLE IF NOT EXISTS recurring_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  template JSONB NOT NULL,
  frequency VARCHAR(10) NOT NULL,               -- weekly | biweekly | monthly | yearly
  anchor_date DATE NOT NULL,
  next_index INTEGER NOT NULL DEFAULT 1,
  next_run_date DATE NOT NULL,
  end_date DATE,
  paused BOOLEAN NOT NULL DEFAULT FALSE,
  pause_reason TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_recurring_rules_due
  ON recurring_rules(next_run_date) WHERE deleted_at IS NULL AND NOT paused;
CREATE INDEX IF NOT EXISTS idx_recurring_rules_group ON recurring_rules(group_id);

-- One row per created occurrence: the unique key makes a restart or a
-- second instance unable to create the same occurrence twice.
CREATE TABLE IF NOT EXISTS recurring_occurrences (
  rule_id UUID NOT NULL REFERENCES recurring_rules(id) ON DELETE CASCADE,
  occurrence_date DATE NOT NULL,
  expense_id UUID REFERENCES expenses(id) ON DELETE SET NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (rule_id, occurrence_date)
);

-- The rule an expense was created from (null for one-off expenses).
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS recurring_rule_id UUID REFERENCES recurring_rules(id) ON DELETE SET NULL;

COMMIT;
