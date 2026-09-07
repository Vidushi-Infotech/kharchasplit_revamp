/**
 * Apply migrations/015_email_verification.sql (email verification columns)
 * without psql — reads DB credentials from the local .env, same as the
 * other scripts in this folder.
 *
 * Usage on the production server:
 *   cd /var/www/websites/kharchasplit/api/public_html
 *   node scripts/run-migration-015.js
 *
 * If the app's DB user is not allowed to ALTER TABLE (this production DB
 * has refused DDL from it before — see fix-user-devices.js), pass the
 * owner role instead; everything else still comes from .env:
 *   node scripts/run-migration-015.js --user=postgres --password='...'
 * or export MIGRATION_DB_USER / MIGRATION_DB_PASSWORD before running.
 *
 * Idempotent: every statement is IF NOT EXISTS. Safe to re-run. Ends by
 * listing the users.email_verif* columns so you can see it landed.
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

const sqlPath = resolve(__dirname, '../migrations/015_email_verification.sql');
const sql = readFileSync(sqlPath, 'utf8');

const EXPECTED = ['email_verified_at', 'email_verify_reminder_at', 'email_verify_reminder_count'];

async function main() {
  console.log(`\n🗄  Migration 015 — email verification`);
  console.log(`   ${user}@${host}:${port}/${database}`);
  const client = new pg.Client({
    host, port, database, user, password,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
  });
  client.on('notice', (n) => console.log(`   ↳ ${n.message}`));
  await client.connect();
  try {
    await client.query(sql);
    console.log('   ✅ SQL applied');
  } catch (e) {
    if (e.code === '42501') {
      console.error(`\n   ❌ Permission denied: "${user}" may not ALTER TABLE users/otps.`);
      console.error(`      Re-run with the owner role, e.g.:`);
      console.error(`      node scripts/run-migration-015.js --user=<owner> --password='<pwd>'\n`);
      process.exitCode = 2;
      return;
    }
    throw e;
  } finally {
    // Verify regardless — a previous run may already have added everything.
    const { rows } = await client.query(
      `SELECT column_name, data_type
         FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = ANY($1::text[])
        ORDER BY column_name`,
      [EXPECTED],
    );
    const present = rows.map((r) => r.column_name);
    const missing = EXPECTED.filter((c) => !present.includes(c));
    console.log(`\n   users columns present: ${present.join(', ') || '(none)'}`);
    if (missing.length) {
      console.error(`   ❌ still missing: ${missing.join(', ')}`);
      process.exitCode = process.exitCode || 1;
    } else {
      console.log('   ✅ Done. Restart the API (pm2 restart kharchasplit-api).\n');
    }
    await client.end();
  }
}

main().catch((e) => {
  console.error('\n   ❌ Migration failed:', e.message);
  process.exit(1);
});
