-- Migration: Relax legacy NOT NULL constraints on expenses.paid_by_id /
--            paid_by_name so INSERTs that only write the newer paid_by
--            column succeed.
-- Version:   012
--
-- Context:
--   001_initial_schema.sql created paid_by_id (NOT NULL) + paid_by_name
--   (NOT NULL). A later refactor introduced a single paid_by column
--   (added at runtime by initDatabase.js) and Expense.create now writes
--   only paid_by. Production INSERTs therefore left the two legacy
--   columns NULL and tripped the NOT NULL constraint — surfaced to the
--   user as "Required field missing".
--
--   Some environments (those bootstrapped from initDatabase.js rather
--   than the 001 migration) never had paid_by_id / paid_by_name in the
--   first place. The DO block makes this migration idempotent: it only
--   touches the columns it finds.
--
--   The legacy columns are NOT dropped. Removing them is a follow-up
--   migration once we're confident nothing reads them anymore.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_name = 'expenses'
           AND column_name = 'paid_by_id'
    ) THEN
        EXECUTE 'ALTER TABLE expenses ALTER COLUMN paid_by_id DROP NOT NULL';

        -- Backfill paid_by from the legacy column for any row that still
        -- has the old value but a NULL paid_by — keeps reads consistent.
        EXECUTE 'UPDATE expenses
                    SET paid_by = paid_by_id
                  WHERE paid_by IS NULL
                    AND paid_by_id IS NOT NULL';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_name = 'expenses'
           AND column_name = 'paid_by_name'
    ) THEN
        EXECUTE 'ALTER TABLE expenses ALTER COLUMN paid_by_name DROP NOT NULL';
    END IF;
END $$;
