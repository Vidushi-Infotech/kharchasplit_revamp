import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../src/config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('Running migration 011: notifications inbox...\n');
  try {
    const sql = fs.readFileSync(
      path.join(__dirname, '011_add_notifications_inbox.sql'),
      'utf8',
    );
    await pool.query(sql);
    console.log('Migration 011 completed.');
    const { rows } = await pool.query('SELECT COUNT(*) FROM notifications');
    console.log(`  notifications rows: ${rows[0].count}`);
    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  }
}

runMigration();
