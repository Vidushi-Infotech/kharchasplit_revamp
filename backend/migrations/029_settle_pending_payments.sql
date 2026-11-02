-- 029: Settle the payments still waiting for the receiver (Nov 2026)
--
-- Payments used to need the receiver's confirmation; since Oct 2026 every
-- new payment is final the moment it's recorded (any app version). This
-- brings the ones recorded before that, and never confirmed, in line:
-- they become 'paid' exactly as if the receiver had confirmed them, so
-- the balances finally count them. Deleted payments are left alone.
--
-- Preview first (what this will change):
--   SELECT id, group_id, from_user_id, to_user_id, amount, currency, created_at
--     FROM settlements
--    WHERE status = 'pending' AND deleted_at IS NULL
--    ORDER BY created_at;
--
-- Idempotent: a second run finds nothing pending and changes nothing.

BEGIN;

UPDATE settlements
   SET status = 'paid',
       confirmed_at = COALESCE(confirmed_at, NOW())
 WHERE status = 'pending'
   AND deleted_at IS NULL;

COMMIT;
