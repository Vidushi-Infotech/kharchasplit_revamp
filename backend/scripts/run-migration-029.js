/**
 * Apply migrations/029_settle_pending_payments.sql: every payment still
 * waiting for the receiver's confirmation becomes 'paid' (as if
 * confirmed), matching how payments work since Oct 2026.
 *
 * Usage on the production server:
 *   cd /var/www/websites/kharchasplit/api/public_html
 *   node scripts/run-migration-029.js --dry-run   # list them, change nothing
 *   node scripts/run-migration-029.js             # settle them
 *
 * Owner role if the app's DB user may not UPDATE (same as the others):
 *   node scripts/run-migration-029.js --user=<owner> --password='...'
 *
 * Idempotent: a second run finds nothing pending.
 */
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import { readFileSync } from 'fs';
import dotenv from 'dotenv';
import pg from 'pg';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: resolve(__dirname, '../.env') });

const args = Object.fromEntries(
  process.argv.slice(2)
    .filter((a) => a.startsWith('--'))
    .map((a) => {
      const [k, ...v] = a.slice(2).split('=');
      return [k, v.join('=') || 'true'];
    }),
);

const user = args.user || process.env.MIGRATION_DB_USER || process.env.DB_USER;
const password = args.password || process.env.MIGRATION_DB_PASSWORD || process.env.DB_PASSWORD;
const host = process.env.DB_HOST || 'localhost';
const port = Number(process.env.DB_PORT) || 5432;
const database = process.env.DB_NAME;
const dryRun = args['dry-run'] === 'true';

const sql = readFileSync(resolve(__dirname, '../migrations/029_settle_pending_payments.sql'), 'utf8');

const PENDING = `
  SELECT s.id, g.name AS group_name, uf.name AS from_name, ut.name AS to_name,
         s.amount, s.currency, s.created_at::date AS recorded_on
    FROM settlements s
    LEFT JOIN groups g ON g.id = s.group_id
    LEFT JOIN users uf ON uf.id = s.from_user_id
    LEFT JOIN users ut ON ut.id = s.to_user_id
   WHERE s.status = 'pending' AND s.deleted_at IS NULL
   ORDER BY s.created_at`;

async function main() {
  console.log(`\n🗄  Migration 029 — settle pending payments${dryRun ? ' (dry run)' : ''}`);
  console.log(`   ${user}@${host}:${port}/${database}`);
  const client = new pg.Client({
    host, port, database, user, password,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
  });
  await client.connect();
  try {
    const before = await client.query(PENDING);
    console.log(`\n   Pending payments: ${before.rowCount}`);
    for (const r of before.rows) {
      console.log(`   · ${r.recorded_on.toISOString().slice(0, 10)}  ${r.group_name ?? '?'}: `
        + `${r.from_name ?? '?'} → ${r.to_name ?? '?'}  ${r.currency} ${r.amount}`);
    }
    if (dryRun || before.rowCount === 0) {
      console.log(dryRun ? '\n   Dry run: nothing changed.\n' : '\n   ✅ Nothing to do.\n');
      return;
    }
    await client.query(sql);
    const after = await client.query(PENDING);
    console.log(`\n   ✅ Settled ${before.rowCount - after.rowCount}; still pending: ${after.rowCount}.`);
    console.log('   Restart the API (pm2 restart kharchasplit-api) so cached balances refresh.\n');
  } catch (e) {
    if (e.code === '42501') {
      console.error(`\n   ❌ Permission denied for "${user}". Re-run with the owner role:`);
      console.error(`      node scripts/run-migration-029.js --user=<owner> --password='<pwd>'\n`);
      process.exitCode = 2;
      return;
    }
    throw e;
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error('\n   ❌ Migration failed:', e.message);
  process.exit(1);
});
