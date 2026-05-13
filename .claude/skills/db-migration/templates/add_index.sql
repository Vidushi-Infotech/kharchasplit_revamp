-- Migration: Add index for <query description>
-- Version: NNN
-- Description: Targets the <slow query / hot endpoint> in <controller/model>.

-- Single column index — for equality / range filters
CREATE INDEX IF NOT EXISTS idx_<table>_<column>
  ON <table>(<column>)
  /* WHERE deleted_at IS NULL  -- partial index if every reader filters this */;

-- Composite index — order columns by most-selective first, matching the WHERE shape
-- CREATE INDEX IF NOT EXISTS idx_<table>_<col1>_<col2>
--   ON <table>(<col1>, <col2>)
--   WHERE deleted_at IS NULL;

-- Verify after running:
--   psql kharchasplit -c "EXPLAIN ANALYZE SELECT ... your query ..."
-- Look for "Index Scan using idx_<table>_<column>" not "Seq Scan".
