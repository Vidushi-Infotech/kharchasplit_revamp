import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../src/config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('Running migration 012: relax expenses.paid_by_id / paid_by_name NOT NULL...\n');
  try {
    const sql = fs.readFileSync(
      path.join(__dirname, '012_relax_expenses_paid_by_legacy.sql'),
      'utf8',
    );
    await pool.query(sql);
    console.log('Migration 012 completed.\n');

    const { rows } = await pool.query(`
      SELECT column_name, is_nullable
        FROM information_schema.columns
       WHERE table_name = 'expenses'
         AND column_name IN ('paid_by_id', 'paid_by_name', 'paid_by')
       ORDER BY column_name
    `);
    console.log('expenses paid-by columns after migration:');
    for (const r of rows) {
      console.log(`  ${r.column_name.padEnd(14)} nullable=${r.is_nullable}`);
    }

    const { rows: filledRows } = await pool.query(
      `SELECT COUNT(*)::int AS filled
         FROM expenses
        WHERE paid_by IS NOT NULL`,
    );
    console.log(`Rows with paid_by populated: ${filledRows[0].filled}`);

    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  }
}

runMigration();
