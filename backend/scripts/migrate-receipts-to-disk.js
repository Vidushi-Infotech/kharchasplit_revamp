/**
 * Move receipt photos stored as base64 in the database (expenses and
 * personal expenses) to files under RECEIPTS_DIR (src/services/
 * receiptStore.js), in batches. Safe to stop and re-run: each row is moved
 * in its own update, only rows still holding base64 are picked, and an
 * unreadable receipt is skipped (left in the database) and reported.
 *
 *   cd /var/www/websites/kharchasplit/api/public_html
 *   node scripts/run-migration-023.js        # first
 *   node scripts/migrate-receipts-to-disk.js [--dry-run] [--batch=50]
 *
 * Back up the database before the first run. Afterwards the uploads/
 * folder must be part of server backups.
 */
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import dotenv from 'dotenv';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: resolve(__dirname, '../.env') });

const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith('--')).map((a) => {
  const [k, ...v] = a.slice(2).split('=');
  return [k, v.join('=') || 'true'];
}));
const dryRun = args['dry-run'] === 'true';
const batch = Math.max(1, Math.min(500, Number(args.batch) || 50));

const { query, pool } = await import('../src/config/database.js');
const { saveReceipt, deleteReceipt } = await import('../src/services/receiptStore.js');

let moved = 0;
let skipped = 0;
for (const table of ['expenses', 'personal_expenses']) {
  const { rows: [{ n }] } = await query(
    `SELECT COUNT(*)::int AS n FROM ${table} WHERE receipt_base64 IS NOT NULL AND receipt_path IS NULL`,
  );
  console.log(`${table}: ${n} receipt(s) in the database`);
  if (dryRun) continue;
  const failed = new Set();
  for (;;) {
    const { rows } = await query(
      `SELECT id, receipt_base64 FROM ${table}
        WHERE receipt_base64 IS NOT NULL AND receipt_path IS NULL AND NOT (id = ANY($1::uuid[]))
        ORDER BY id LIMIT $2`,
      [[...failed], batch],
    );
    if (rows.length === 0) break;
    for (const row of rows) {
      let name;
      try {
        name = await saveReceipt(row.receipt_base64);
      } catch (e) {
        failed.add(row.id);
        skipped += 1;
        console.log(`  skipped ${table} ${row.id}: ${e.message}`);
        continue;
      }
      const res = await query(
        `UPDATE ${table} SET receipt_path = $2, receipt_base64 = NULL
          WHERE id = $1 AND receipt_path IS NULL`,
        [row.id, name],
      );
      if (res.rowCount === 0) await deleteReceipt(name); // moved meanwhile
      else moved += 1;
    }
    process.stdout.write(`  ${table}: ${moved} moved\r`);
  }
  console.log('');
}
console.log(dryRun ? 'Dry run — nothing moved.' : `Done: ${moved} moved, ${skipped} skipped.`);
await pool.end();
