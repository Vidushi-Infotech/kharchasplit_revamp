/**
 * One-off fix: create the user_devices table on production + backfill from
 * the legacy users.fcm_token column.
 *
 * Symptom this fixes:
 *   diagnose-push.js fails Step 3 with
 *     'relation "user_devices" does not exist'
 *   and no FCM pushes are delivered, even though /health reports
 *   firebase.ready=true and the in-app notifications inbox does populate
 *   on manual refresh.
 *
 * Why it's needed: the backend's automatic schema init creates user_devices
 * via CREATE TABLE IF NOT EXISTS, but on this database the DB user doesn't
 * have CREATE permission (or the init silently failed) so the table never
 * landed. NotificationService._fetchTokens then throws on every push send,
 * the outer controller try/catch swallows it, and pushes silently no-op.
 *
 * Safe to re-run — every statement is idempotent (IF NOT EXISTS / ON CONFLICT
 * DO NOTHING). Will not duplicate data.
 *
 * Usage on the production server:
 *   cd /var/www/websites/kharchasplit/api/public_html
 *   node scripts/fix-user-devices.js
 *
 * Reads DB credentials from the local .env via the existing config/database.js.
 * No psql / pgAdmin / SSH tunnel required.
 *
 * After this finishes, re-run scripts/diagnose-push.js +91<phone> and Step 3
 * should now show one or more user_devices rows.
 */
// Resolve .env relative to this file (not process.cwd()) so the script
// works whether invoked from the backend root OR from inside scripts/.
//
// IMPORTANT: database.js builds the pg Pool at module-load time using
// process.env. If we used a normal `import` for it, ES-module hoisting
// would resolve that import BEFORE dotenv.config() runs in the body,
// and the Pool would end up with an empty DB_PASSWORD (SASL error). We
// dynamic-import database.js AFTER calling dotenv.config so the env
// vars are present at the moment the Pool is constructed.
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import dotenv from 'dotenv';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: resolve(__dirname, '../.env') });

const { pool, query } = await import('../src/config/database.js');

const CREATE_TABLE_SQL = `
CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform VARCHAR(20),
  device_name VARCHAR(255),
  os_version VARCHAR(80),
  app_version VARCHAR(40),
  last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (fcm_token)
)
`;

const CREATE_INDEX_USER_ID =
  'CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id)';

const CREATE_INDEX_LAST_SEEN =
  'CREATE INDEX IF NOT EXISTS idx_user_devices_last_seen ON user_devices(last_seen_at)';

// Backfill from the legacy users.fcm_token column so users who haven't
// re-logged in since the multi-device flow shipped still get pushes.
// ON CONFLICT DO NOTHING covers (theoretical) duplicate tokens across users.
const BACKFILL_SQL = `
INSERT INTO user_devices (user_id, fcm_token, last_seen_at, created_at)
SELECT id, fcm_token, COALESCE(fcm_token_updated_at, NOW()), NOW()
FROM users
WHERE fcm_token IS NOT NULL AND fcm_token <> ''
ON CONFLICT (fcm_token) DO NOTHING
RETURNING id
`;

async function main() {
  console.log('=== fix-user-devices ===');
  console.log('DB host:', process.env.DB_HOST, ' DB name:', process.env.DB_NAME);

  console.log('\n[1/4] Create user_devices table…');
  await query(CREATE_TABLE_SQL);
  console.log('     ✅ table exists');

  console.log('\n[2/4] Create indexes…');
  await query(CREATE_INDEX_USER_ID);
  await query(CREATE_INDEX_LAST_SEEN);
  console.log('     ✅ indexes ensured');

  console.log('\n[3/4] Backfill from legacy users.fcm_token…');
  const backfill = await query(BACKFILL_SQL);
  console.log(`     ✅ ${backfill.rowCount} legacy token(s) migrated`);

  console.log('\n[4/4] Final state:');
  const totalRow = await query('SELECT COUNT(*)::int AS n FROM user_devices');
  console.log(`     user_devices rows: ${totalRow.rows[0].n}`);
  const recent = await query(
    `SELECT u.phone_number, u.name, d.platform, d.device_name, d.app_version, d.last_seen_at
       FROM user_devices d
       JOIN users u ON u.id = d.user_id
      ORDER BY d.last_seen_at DESC
      LIMIT 5`,
  );
  if (recent.rows.length > 0) {
    console.table(recent.rows);
  }

  console.log('\nDone. Re-run scripts/diagnose-push.js to verify.');
  await pool.end();
}

main().catch(async (err) => {
  console.error('\n❌ fix failed:', err.message);
  await pool.end();
  process.exit(1);
});
