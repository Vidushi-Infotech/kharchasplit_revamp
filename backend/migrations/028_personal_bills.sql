-- 028: Bills in the Personal mode (Oct 2026)
--
-- A bill repeats (weekly, every two weeks, monthly, yearly) from its first
-- due date (anchor_date). The next due date is occurrence number
-- paid_count of that schedule (utils/recurrence.js), so paying or skipping
-- one just counts up. Paying creates a personal expense that points back
-- at the bill (personal_expenses.bill_id). A daily job pushes a reminder
-- remind_days before each due date, once per due date (last_reminded_due).
-- Idempotent and additive; the server also creates these on startup.

BEGIN;

CREATE TABLE IF NOT EXISTS personal_bills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(80) NOT NULL,
  amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
  category VARCHAR(50) NOT NULL DEFAULT 'utilities',
  account_id UUID REFERENCES personal_accounts(id) ON DELETE SET NULL,
  frequency VARCHAR(10) NOT NULL CHECK (frequency IN ('weekly', 'biweekly', 'monthly', 'yearly')),
  anchor_date DATE NOT NULL,
  paid_count INTEGER NOT NULL DEFAULT 0,
  remind_days INTEGER NOT NULL DEFAULT 2 CHECK (remind_days BETWEEN 0 AND 30),
  last_reminded_due DATE,
  archived_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_personal_bills_user ON personal_bills(user_id) WHERE archived_at IS NULL;

ALTER TABLE personal_expenses
  ADD COLUMN IF NOT EXISTS bill_id UUID REFERENCES personal_bills(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_personal_expenses_bill
  ON personal_expenses(bill_id) WHERE bill_id IS NOT NULL;

COMMIT;
