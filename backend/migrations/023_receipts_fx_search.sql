-- 023: Receipts on disk, currency conversion, search index (Oct 2026)
--
-- The server also adds the columns/tables on startup (initDatabase.js).
-- Idempotent and additive. Moving existing receipts out of the database is
-- a separate, resumable step: node scripts/migrate-receipts-to-disk.js

BEGIN;

-- Receipt photos as files under RECEIPTS_DIR (services/receiptStore.js);
-- receipt_base64 stays for rows not moved yet.
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS receipt_path TEXT;
ALTER TABLE personal_expenses ADD COLUMN IF NOT EXISTS receipt_path TEXT;

-- An expense entered in another currency: what was entered, and the rate
-- used (fixed when saved — never recalculated). amount / splits / payers
-- are in the group's currency.
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS original_amount DECIMAL(12, 2);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS original_currency VARCHAR(10);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS fx_rate DECIMAL(18, 8);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS fx_date DATE;

-- Daily exchange rates (services/fxService.js, from frankfurter.app).
CREATE TABLE IF NOT EXISTS fx_rates (
  rate_date DATE NOT NULL,
  base VARCHAR(10) NOT NULL,
  quote VARCHAR(10) NOT NULL,
  rate DECIMAL(18, 8) NOT NULL,
  fetched_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (rate_date, base, quote)
);

COMMIT;

-- Search (GET /search). Trigram indexes need the pg_trgm extension, which
-- may need a superuser; the runner tries it separately and search works
-- without it (just slower on very large data).
