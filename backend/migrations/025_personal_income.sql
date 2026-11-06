-- 025: Income in the Personal mode (Oct 2026)
--
-- A personal entry is now money out (an expense, as before) or money in
-- (salary, a refund, a gift...). Existing rows are expenses. Apps that
-- don't ask for income (?includeIncome=1) never see income rows, so older
-- builds keep showing only expenses.
-- Idempotent and additive; the server also adds the column on startup.

BEGIN;

ALTER TABLE personal_expenses
  ADD COLUMN IF NOT EXISTS kind VARCHAR(10) NOT NULL DEFAULT 'expense';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conname = 'personal_expenses_kind_check') THEN
    ALTER TABLE personal_expenses
      ADD CONSTRAINT personal_expenses_kind_check
      CHECK (kind IN ('expense', 'income'));
  END IF;
END $$;

COMMIT;
