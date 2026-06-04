import { query } from './database.js';

/**
 * Database initialization script
 * Automatically creates tables and columns if they don't exist
 * Run this on server startup to ensure database schema is up to date
 */

// =====================================================
// TABLE DEFINITIONS
// =====================================================

const createTablesSQL = `
-- Users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number VARCHAR(20) UNIQUE NOT NULL,
  name VARCHAR(100),
  email VARCHAR(255),
  profile_image_base64 TEXT,
  preferred_currency VARCHAR(10) DEFAULT 'INR',
  is_placeholder BOOLEAN DEFAULT FALSE,
  fcm_token VARCHAR(255),
  fcm_token_updated_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Groups table
CREATE TABLE IF NOT EXISTS groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  created_by UUID REFERENCES users(id),
  cover_image_base64 TEXT,
  default_currency VARCHAR(10) DEFAULT 'INR',
  simplified_debts BOOLEAN DEFAULT TRUE,
  is_archived BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Group members table
CREATE TABLE IF NOT EXISTS group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  role VARCHAR(20) DEFAULT 'member',
  name VARCHAR(100),
  phone_number VARCHAR(20),
  email VARCHAR(255),
  added_by UUID,
  joined_at TIMESTAMP DEFAULT NOW(),
  left_at TIMESTAMP,
  deleted_at TIMESTAMP,
  UNIQUE(group_id, user_id)
);

-- Expenses table
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  description VARCHAR(255) NOT NULL,
  amount DECIMAL(12, 2) NOT NULL,
  currency VARCHAR(10) DEFAULT 'INR',
  paid_by UUID REFERENCES users(id),
  category VARCHAR(50),
  expense_date DATE DEFAULT CURRENT_DATE,
  split_type VARCHAR(20) DEFAULT 'equal',
  receipt_base64 TEXT,
  notes TEXT,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Expense splits table
CREATE TABLE IF NOT EXISTS expense_splits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id UUID REFERENCES expenses(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  amount DECIMAL(12, 2) NOT NULL,
  percentage DECIMAL(5, 2),
  shares INTEGER,
  is_settled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Settlements table
CREATE TABLE IF NOT EXISTS settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  from_user_id UUID REFERENCES users(id),
  to_user_id UUID REFERENCES users(id),
  amount DECIMAL(12, 2) NOT NULL,
  currency VARCHAR(10) DEFAULT 'INR',
  status VARCHAR(20) DEFAULT 'pending',
  notes TEXT,
  confirmed_at TIMESTAMP,
  settled_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Personal expenses table
CREATE TABLE IF NOT EXISTS personal_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  description VARCHAR(255) NOT NULL,
  amount DECIMAL(12, 2) NOT NULL,
  currency VARCHAR(10) DEFAULT 'INR',
  category VARCHAR(50),
  expense_date TIMESTAMP DEFAULT NOW(),
  receipt_base64 TEXT,
  notes TEXT,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Activities table
CREATE TABLE IF NOT EXISTS activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  activity_type VARCHAR(50) NOT NULL,
  entity_type VARCHAR(50),
  entity_id UUID,
  title VARCHAR(255),
  description TEXT,
  metadata JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Pending group invites table (for non-registered users)
CREATE TABLE IF NOT EXISTS pending_group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  phone_number VARCHAR(20) NOT NULL,
  name VARCHAR(100),
  email VARCHAR(255),
  invited_by UUID REFERENCES users(id),
  wati_message_id VARCHAR(100),
  wati_status VARCHAR(20) DEFAULT 'pending',
  wati_error TEXT,
  wati_sent_at TIMESTAMP,
  invite_count INTEGER DEFAULT 1,
  last_invited_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Group invites table
CREATE TABLE IF NOT EXISTS group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  invited_by UUID REFERENCES users(id),
  invited_phone VARCHAR(20),
  invited_user_id UUID REFERENCES users(id),
  status VARCHAR(20) DEFAULT 'pending',
  invite_code VARCHAR(50) UNIQUE,
  expires_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  responded_at TIMESTAMP
);

-- Invites table (referral system)
CREATE TABLE IF NOT EXISTS invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invite_code VARCHAR(20) UNIQUE NOT NULL,
  invited_by UUID REFERENCES users(id),
  phone_number VARCHAR(20) NOT NULL,
  context JSONB,
  status VARCHAR(20) DEFAULT 'pending',
  accepted_by UUID REFERENCES users(id),
  accepted_at TIMESTAMP,
  expires_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- OTPs table
CREATE TABLE IF NOT EXISTS otps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number VARCHAR(20) NOT NULL,
  otp VARCHAR(10) NOT NULL,
  verified BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Refresh tokens table
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- Push notification stack
-- (mirrors migrations/010_add_notifications.sql + 011_add_notifications_inbox.sql,
--  inlined here so the idempotent boot path creates them on a fresh DB)
-- =====================================================

-- Per-user notification preferences. Server consults these before every
-- send so user-level toggles are honored across every device.
CREATE TABLE IF NOT EXISTS notification_prefs (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  email_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  new_expense BOOLEAN NOT NULL DEFAULT TRUE,
  group_invite BOOLEAN NOT NULL DEFAULT TRUE,
  payment_received BOOLEAN NOT NULL DEFAULT TRUE,
  settlement_reminder BOOLEAN NOT NULL DEFAULT TRUE,
  comment_mention BOOLEAN NOT NULL DEFAULT TRUE,
  weekly_summary BOOLEAN NOT NULL DEFAULT FALSE,
  product_updates BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Multi-device FCM tokens. UNIQUE(fcm_token) makes the ON CONFLICT upsert
-- in NotificationService.registerDevice work; the legacy users.fcm_token
-- column stays as a backfill/transitional fallback.
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
);

-- In-app notification inbox — one row per delivered notification so the
-- app can render a persistent feed even after the OS push has been
-- dismissed.
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
`;

// =====================================================
// COLUMN ADDITIONS (for existing tables)
// =====================================================

const columnAdditions = [
  // Users table columns
  { table: 'users', column: 'fcm_token', type: 'VARCHAR(255)' },
  { table: 'users', column: 'fcm_token_updated_at', type: 'TIMESTAMP' },
  { table: 'users', column: 'is_placeholder', type: 'BOOLEAN DEFAULT FALSE' },
  { table: 'users', column: 'preferred_currency', type: "VARCHAR(10) DEFAULT 'INR'" },
  { table: 'users', column: 'profile_image_base64', type: 'TEXT' },

  // Groups table columns
  { table: 'groups', column: 'currency', type: "VARCHAR(10) DEFAULT 'INR'" },
  { table: 'groups', column: 'cover_image_base64', type: 'TEXT' },
  { table: 'groups', column: 'default_currency', type: "VARCHAR(10) DEFAULT 'INR'" },
  { table: 'groups', column: 'simplified_debts', type: 'BOOLEAN DEFAULT TRUE' },
  { table: 'groups', column: 'is_archived', type: 'BOOLEAN DEFAULT FALSE' },

  // Expenses table columns
  { table: 'expenses', column: 'deleted_at', type: 'TIMESTAMP' },
  { table: 'expenses', column: 'paid_by', type: 'UUID REFERENCES users(id)' },
  { table: 'expenses', column: 'category', type: 'VARCHAR(50)' },
  { table: 'expenses', column: 'expense_date', type: 'DATE DEFAULT CURRENT_DATE' },
  { table: 'expenses', column: 'split_type', type: "VARCHAR(20) DEFAULT 'equal'" },
  { table: 'expenses', column: 'receipt_base64', type: 'TEXT' },
  { table: 'expenses', column: 'notes', type: 'TEXT' },
  { table: 'expenses', column: 'is_deleted', type: 'BOOLEAN DEFAULT FALSE' },

  // Expense splits columns
  { table: 'expense_splits', column: 'deleted_at', type: 'TIMESTAMP' },
  { table: 'expense_splits', column: 'percentage', type: 'DECIMAL(5, 2)' },
  { table: 'expense_splits', column: 'shares', type: 'INTEGER' },
  { table: 'expense_splits', column: 'is_settled', type: 'BOOLEAN DEFAULT FALSE' },

  // Settlements columns
  { table: 'settlements', column: 'deleted_at', type: 'TIMESTAMP' },
  { table: 'settlements', column: 'notes', type: 'TEXT' },
  { table: 'settlements', column: 'status', type: "VARCHAR(20) DEFAULT 'pending'" },
  { table: 'settlements', column: 'confirmed_at', type: 'TIMESTAMP' },

  // Personal expenses columns
  { table: 'personal_expenses', column: 'deleted_at', type: 'TIMESTAMP' },
  { table: 'personal_expenses', column: 'receipt_base64', type: 'TEXT' },
  { table: 'personal_expenses', column: 'notes', type: 'TEXT' },
  { table: 'personal_expenses', column: 'is_deleted', type: 'BOOLEAN DEFAULT FALSE' },

  // Activities columns
  { table: 'activities', column: 'deleted_at', type: 'TIMESTAMP' },
  { table: 'activities', column: 'metadata', type: 'JSONB' },
  { table: 'activities', column: 'is_read', type: 'BOOLEAN DEFAULT FALSE' },

  // Group members columns
  { table: 'group_members', column: 'left_at', type: 'TIMESTAMP' },
  { table: 'group_members', column: 'deleted_at', type: 'TIMESTAMP' },
  { table: 'group_members', column: 'name', type: 'VARCHAR(100)' },
  { table: 'group_members', column: 'phone_number', type: 'VARCHAR(20)' },
  { table: 'group_members', column: 'email', type: 'VARCHAR(255)' },
  { table: 'group_members', column: 'added_by', type: 'UUID' },

  // Group invites columns
  { table: 'group_invites', column: 'deleted_at', type: 'TIMESTAMP' },
  { table: 'group_invites', column: 'invite_code', type: 'VARCHAR(50)' },
  { table: 'group_invites', column: 'expires_at', type: 'TIMESTAMP' },
  { table: 'group_invites', column: 'responded_at', type: 'TIMESTAMP' },

  // Refresh tokens — device fingerprint + last-used tracking (added later;
  // backwards-compatible with rows inserted before these columns existed).
  { table: 'refresh_tokens', column: 'device_name', type: 'VARCHAR(255)' },
  { table: 'refresh_tokens', column: 'platform', type: 'VARCHAR(50)' },
  { table: 'refresh_tokens', column: 'os_version', type: 'VARCHAR(50)' },
  { table: 'refresh_tokens', column: 'app_version', type: 'VARCHAR(50)' },
  { table: 'refresh_tokens', column: 'ip_address', type: 'VARCHAR(64)' },
  { table: 'refresh_tokens', column: 'user_agent', type: 'TEXT' },
  { table: 'refresh_tokens', column: 'last_used_at', type: 'TIMESTAMP' },
];

// =====================================================
// INDEX DEFINITIONS
// =====================================================

const createIndexesSQL = `
-- =====================================================
-- USERS: phone_number already has UNIQUE constraint (users_phone_number_key)
-- No separate idx_users_phone needed — UNIQUE index serves lookups
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;

-- Functional index for normalized phone lookups (last 10 digits)
CREATE INDEX IF NOT EXISTS idx_users_phone_normalized ON users(RIGHT(REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g'), 10));

-- Case-insensitive email lookup (forgot-password / duplicate-check).
-- Partial: skips soft-deleted rows + rows where email is missing.
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users(LOWER(email))
WHERE deleted_at IS NULL AND email IS NOT NULL;

-- =====================================================
-- GROUP_MEMBERS: UNIQUE(group_id, user_id) already covers group_id prefix lookups
-- Replaced idx_group_members_group (redundant) with a covering partial index
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_active ON group_members(group_id, user_id, role, joined_at) WHERE deleted_at IS NULL;

-- =====================================================
-- EXPENSES: partial composite index covers all hot-path queries
-- Removed idx_expenses_group (redundant prefix of idx_expenses_group_active)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses(paid_by);
CREATE INDEX IF NOT EXISTS idx_expenses_group_active ON expenses(group_id, expense_date DESC, created_at DESC) WHERE deleted_at IS NULL;

-- =====================================================
-- EXPENSE_SPLITS: composite index covers both single and batch lookups
-- Removed idx_expense_splits_expense (redundant prefix of idx_expense_splits_batch)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_expense_splits_batch ON expense_splits(expense_id, amount DESC);
-- Composite COVERING index for the dashboard sum-by-user + pairwise-debt
-- queries. INCLUDE(amount) lets Postgres do a true Index-Only Scan
-- (skip heap fetch entirely) for SUM(amount) aggregations. This
-- supersedes both the old (user_id) and (user_id, expense_id) indexes —
-- their use cases are strict prefixes of this one.
CREATE INDEX IF NOT EXISTS idx_expense_splits_user_expense_covering
ON expense_splits(user_id, expense_id) INCLUDE (amount)
WHERE deleted_at IS NULL;

-- =====================================================
-- SETTLEMENTS: composite indexes for hot-path queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_settlements_group_active ON settlements(group_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_settlements_pending ON settlements(group_id, from_user_id, to_user_id) WHERE status = 'pending' AND deleted_at IS NULL;
-- Covering indexes for the pairwise balance compute (one per direction).
-- Each also closes the FK-coverage gap for from_user_id / to_user_id.
-- INCLUDE columns enable Index-Only Scans for the balance aggregation.
CREATE INDEX IF NOT EXISTS idx_settlements_from
ON settlements(from_user_id, group_id) INCLUDE (to_user_id, amount, status)
WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_settlements_to
ON settlements(to_user_id, group_id) INCLUDE (from_user_id, amount, status)
WHERE deleted_at IS NULL;

-- =====================================================
-- ACTIVITIES: composite partial indexes for feed queries
-- Removed idx_activities_created (never queried standalone)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_activities_user_feed ON activities(user_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_activities_group_feed ON activities(group_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_activities_unread ON activities(user_id, is_read) WHERE deleted_at IS NULL AND is_read = FALSE;

-- =====================================================
-- PERSONAL_EXPENSES: composite for paginated user list
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_personal_expenses_user_active ON personal_expenses(user_id, expense_date DESC, created_at DESC) WHERE deleted_at IS NULL;

-- =====================================================
-- GROUPS: FK coverage for ownership lookups + CASCADE perf
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups(created_by) WHERE deleted_at IS NULL;

-- =====================================================
-- PENDING_GROUP_INVITES: composite for exact-match lookups + FK coverage
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_pending_invites_group_phone ON pending_group_invites(group_id, phone_number);
CREATE INDEX IF NOT EXISTS idx_pending_invites_phone ON pending_group_invites(phone_number);
CREATE INDEX IF NOT EXISTS idx_pending_invites_invited_by ON pending_group_invites(invited_by);

-- =====================================================
-- GROUP_INVITES: foreign key indexes (group + phone + author + invitee)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_group_invites_group ON group_invites(group_id);
CREATE INDEX IF NOT EXISTS idx_group_invites_phone ON group_invites(invited_phone);
CREATE INDEX IF NOT EXISTS idx_group_invites_invited_by ON group_invites(invited_by);
CREATE INDEX IF NOT EXISTS idx_group_invites_invited_user ON group_invites(invited_user_id);

-- =====================================================
-- INVITES: invite_code already has UNIQUE constraint
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_invites_invited_by ON invites(invited_by, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_invites_phone ON invites(phone_number) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_invites_accepted_by ON invites(accepted_by) WHERE deleted_at IS NULL;

-- =====================================================
-- OTPS: composite for verification query
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_otps_phone_verify ON otps(phone_number, verified, expires_at DESC);

-- =====================================================
-- REFRESH_TOKENS: covering index for token lookup
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_lookup ON refresh_tokens(token, expires_at);

-- =====================================================
-- USER_DEVICES: per-user lookup + last-seen sweep
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_last_seen ON user_devices(last_seen_at);

-- =====================================================
-- NOTIFICATIONS: list (per user, newest first) + unread count
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications(user_id) WHERE is_read = FALSE;
`;

// =====================================================
// INITIALIZATION FUNCTIONS
// =====================================================

/**
 * Check if a table exists
 */
async function tableExists(tableName) {
  const result = await query(
    `SELECT table_name FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = $1`,
    [tableName]
  );
  return result.rows.length > 0;
}

/**
 * Check if a column exists in a table
 */
async function columnExists(tableName, columnName) {
  const result = await query(
    `SELECT column_name FROM information_schema.columns
     WHERE table_name = $1 AND column_name = $2`,
    [tableName, columnName]
  );
  return result.rows.length > 0;
}

/**
 * Add a column if it doesn't exist
 */
async function addColumnIfNotExists(tableName, columnName, columnType) {
  // First check if table exists
  const tblExists = await tableExists(tableName);
  if (!tblExists) {
    // Table doesn't exist, skip silently (table will be created in next run)
    return false;
  }

  const exists = await columnExists(tableName, columnName);
  if (!exists) {
    try {
      await query(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${columnType}`);
      console.log(`  ✅ Added column: ${tableName}.${columnName}`);
      return true;
    } catch (error) {
      // Ignore error if column already exists (race condition)
      if (!error.message.includes('already exists')) {
        console.error(`  ❌ Failed to add column ${tableName}.${columnName}:`, error.message);
      }
      return false;
    }
  }
  return false;
}

/**
 * Initialize database schema
 */
export async function initializeDatabase() {
  console.log('');
  console.log('╔════════════════════════════════════════╗');
  console.log('║   📦 Database Initialization           ║');
  console.log('╚════════════════════════════════════════╝');
  console.log('');

  try {
    // Step 1: Create tables
    console.log('📋 Creating tables if not exist...');
    const tableStatements = createTablesSQL
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0)
      .filter(s => {
        // Remove comments and check if it's a CREATE TABLE statement
        const withoutComments = s.replace(/--.*$/gm, '').trim();
        return withoutComments.toUpperCase().startsWith('CREATE TABLE');
      });

    for (const statement of tableStatements) {
      try {
        await query(statement);
      } catch (error) {
        // Ignore "already exists" errors
        if (!error.message.includes('already exists')) {
          console.error('  ⚠️ Table creation warning:', error.message);
        }
      }
    }
    console.log('  ✅ Tables checked/created');

    // Step 2: Add missing columns
    console.log('');
    console.log('📋 Checking for missing columns...');
    let columnsAdded = 0;
    for (const col of columnAdditions) {
      const added = await addColumnIfNotExists(col.table, col.column, col.type);
      if (added) columnsAdded++;
    }
    if (columnsAdded === 0) {
      console.log('  ✅ All columns present');
    } else {
      console.log(`  ✅ Added ${columnsAdded} missing column(s)`);
    }

    // Step 3: Create indexes
    console.log('');
    console.log('📋 Creating indexes if not exist...');
    const indexStatements = createIndexesSQL
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0)
      .filter(s => {
        const withoutComments = s.replace(/--.*$/gm, '').trim();
        return withoutComments.toUpperCase().startsWith('CREATE INDEX');
      });

    for (const statement of indexStatements) {
      try {
        // Extract table name from statement to check if table exists
        const tableMatch = statement.match(/ON\s+(\w+)/i);
        if (tableMatch) {
          const tableName = tableMatch[1];
          const tblExists = await tableExists(tableName);
          if (!tblExists) {
            // Skip index if table doesn't exist
            continue;
          }
        }
        await query(statement);
      } catch (error) {
        // Ignore "already exists" and "does not exist" errors
        if (!error.message.includes('already exists') &&
            !error.message.includes('does not exist')) {
          console.error('  ⚠️ Index creation warning:', error.message);
        }
      }
    }
    console.log('  ✅ Indexes checked/created');

    console.log('');
    console.log('✅ Database initialization complete!');
    console.log('');

    return true;
  } catch (error) {
    console.error('❌ Database initialization failed:', error);
    return false;
  }
}

export default initializeDatabase;
