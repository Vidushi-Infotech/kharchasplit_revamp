import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../src/config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Running migration 007: Add pending_group_invites table...\n');

  try {
    const sqlPath = path.join(__dirname, '007_add_pending_invites_table.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    await pool.query(sql);
    console.log('✅ Migration 007 completed successfully!\n');
    console.log('📊 Created table: pending_group_invites');
    console.log('   - Stores pending invitations for non-registered users');
    console.log('   - Tracks WATI WhatsApp message status');
    console.log('   - Auto-adds users when they register\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
