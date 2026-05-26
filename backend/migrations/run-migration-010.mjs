import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../src/config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('Running migration 010: notification_prefs + user_devices...\n');

  try {
    const sqlPath = path.join(__dirname, '010_add_notifications.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    await pool.query(sql);
    console.log('Migration 010 completed.\n');

    const { rows: prefsCount } = await pool.query('SELECT COUNT(*) FROM notification_prefs');
    const { rows: devicesCount } = await pool.query('SELECT COUNT(*) FROM user_devices');
    console.log(`  notification_prefs rows: ${prefsCount[0].count}`);
    console.log(`  user_devices rows (backfilled): ${devicesCount[0].count}`);

    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
