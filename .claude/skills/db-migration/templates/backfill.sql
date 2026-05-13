-- Migration: Backfill <column> in <table>
-- Version: NNN
-- Description: <what data is being filled, and the upstream change that introduced the column>

-- Idempotency: WHERE col IS NULL makes re-runs a no-op once data is populated.
UPDATE <table>
SET <column> = <expression>
WHERE <column> IS NULL
  /* AND deleted_at IS NULL */;

-- For larger tables you may prefer batched updates inside a transaction to
-- avoid long locks. Example template:
--
-- DO $$
-- DECLARE
--   updated_count INT;
-- BEGIN
--   LOOP
--     WITH batch AS (
--       SELECT id FROM <table>
--       WHERE <column> IS NULL
--       LIMIT 1000
--       FOR UPDATE SKIP LOCKED
--     )
--     UPDATE <table> t
--     SET <column> = <expression>
--     FROM batch b
--     WHERE t.id = b.id;
--
--     GET DIAGNOSTICS updated_count = ROW_COUNT;
--     EXIT WHEN updated_count = 0;
--   END LOOP;
-- END $$;
