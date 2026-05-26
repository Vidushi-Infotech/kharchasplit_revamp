import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../src/config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('Running migration 013: switch auth to phone+password (otps.purpose/email, wipe dev data)...\n');
  try {
    const sql = fs.readFileSync(
      path.join(__dirname, '013_password_auth.sql'),
      'utf8',
    );
    await pool.query(sql);
    console.log('Migration 013 completed.\n');

    const { rows: otpCols } = await pool.query(`
      SELECT column_name, is_nullable, data_type
        FROM information_schema.columns
       WHERE table_name = 'otps'
       ORDER BY ordinal_position
    `);
    console.log('otps columns after migration:');
    for (const r of otpCols) {
      console.log(`  ${r.column_name.padEnd(14)} ${r.data_type.padEnd(28)} nullable=${r.is_nullable}`);
    }

    const { rows: counts } = await pool.query(`
      SELECT 'users' AS t, COUNT(*)::int AS n FROM users
      UNION ALL SELECT 'otps', COUNT(*)::int FROM otps
      UNION ALL SELECT 'refresh_tokens', COUNT(*)::int FROM refresh_tokens
    `);
    console.log('\nRow counts after wipe:');
    for (const r of counts) console.log(`  ${r.t.padEnd(16)} ${r.n}`);

    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  }
}

runMigration();
