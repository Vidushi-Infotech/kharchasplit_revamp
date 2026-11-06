-- 027: Accounts and transfers in the Personal mode (Oct 2026)
--
-- The Personal wallet used to live only on the phone. Accounts (cash,
-- bank, credit card, e-wallet) are now on the server; an entry can say
-- which account it came from / went to (personal_expenses.account_id),
-- and money can move between accounts (personal_transfers). An account's
-- balance is computed: opening_balance + income - expenses + transfers in
-- - transfers out. Removing an account archives it (history stays).
-- Idempotent and additive; the server also creates these on startup.

BEGIN;

CREATE TABLE IF NOT EXISTS personal_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(60) NOT NULL,
  type VARCHAR(10) NOT NULL CHECK (type IN ('cash', 'bank', 'card', 'wallet')),
  opening_balance DECIMAL(14, 2) NOT NULL DEFAULT 0,
  archived_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_personal_accounts_user ON personal_accounts(user_id);

ALTER TABLE personal_expenses
  ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES personal_accounts(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_personal_expenses_account
  ON personal_expenses(account_id) WHERE account_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS personal_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  from_account_id UUID NOT NULL REFERENCES personal_accounts(id) ON DELETE CASCADE,
  to_account_id UUID NOT NULL REFERENCES personal_accounts(id) ON DELETE CASCADE,
  amount DECIMAL(14, 2) NOT NULL CHECK (amount > 0),
  note VARCHAR(200),
  transfer_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMP,
  CHECK (from_account_id <> to_account_id)
);
CREATE INDEX IF NOT EXISTS idx_personal_transfers_user ON personal_transfers(user_id, transfer_date DESC);

COMMIT;
