-- Migration: Add <column> to <table>
-- Version: NNN
-- Description: <why>

ALTER TABLE <table>
ADD COLUMN IF NOT EXISTS <column> <type> /* DEFAULT ... CHECK (...) */;

-- If the column will be queried in WHERE / ORDER BY:
CREATE INDEX IF NOT EXISTS idx_<table>_<column> ON <table>(<column>);

-- If the column is added to a populated table and must end up NOT NULL:
--   1. Add nullable (this file).
--   2. Backfill with another migration:
--        UPDATE <table> SET <column> = <default> WHERE <column> IS NULL;
--   3. Tighten in a third migration:
--        ALTER TABLE <table> ALTER COLUMN <column> SET NOT NULL;
--   Splitting like this keeps each step idempotent and easy to roll back.

COMMENT ON COLUMN <table>.<column> IS '<purpose>';
