import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// PostgreSQL connection pool
// Pool size guide: max = (CPU cores * 2) + disk spindles
// For a single-node setup with SSD, 10 is a good default.
// AWS RDS micro/small instances cap at ~60 connections total,
// so leave headroom for migrations, monitoring, and other services.
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'kharchasplit',
  user: process.env.DB_USER || 'kharchasplit',
  password: process.env.DB_PASSWORD,
  min: parseInt(process.env.DB_POOL_MIN) || 2,
  max: parseInt(process.env.DB_POOL_MAX) || 10,
  idleTimeoutMillis: 30000,       // close idle connections after 30s
  connectionTimeoutMillis: 5000,  // wait up to 5s for a connection (2s was too aggressive under load)
  application_name: 'kharchasplit-api',  // visible in pg_stat_activity
  statement_timeout: 30000,       // kill queries running longer than 30s
});

// Log pool errors but do NOT crash — the pool self-heals by replacing dead connections.
// process.exit(-1) here would kill the server on any transient network blip.
pool.on('error', (err) => {
  console.error('[Pool] Idle client error (connection will be replaced):', err.message);
});

// Helper function to execute queries
const SLOW_QUERY_THRESHOLD_MS = 100;
const query = async (text, params) => {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    // Only log slow queries to avoid blocking event loop
    if (duration >= SLOW_QUERY_THRESHOLD_MS) {
      console.warn(`[Pool] Slow query (${duration}ms):`, { text: text.substring(0, 120), rows: res.rowCount });
    }
    return res;
  } catch (error) {
    console.error('[Pool] Query error:', error.message);
    throw error;
  }
};

// Transaction helper
const transaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      // Connection may already be dead — log but don't mask the original error
      console.error('[Pool] Rollback failed:', rollbackError.message);
    }
    throw error;
  } finally {
    client.release();
  }
};

// Test connection and log pool config
const testConnection = async () => {
  try {
    const res = await query('SELECT NOW()');
    console.log('[Pool] Connection test successful:', res.rows[0].now);
    console.log(`[Pool] Config: min=${pool.options.min}, max=${pool.options.max}, idleTimeout=${pool.options.idleTimeoutMillis}ms, connectTimeout=${pool.options.connectionTimeoutMillis}ms`);
    return true;
  } catch (error) {
    console.error('[Pool] Connection test failed:', error.message);
    return false;
  }
};

/**
 * Get pool health metrics — call from a /health or /metrics endpoint.
 * Returns: { total, idle, waiting }
 *   total   = active connections in the pool
 *   idle    = connections sitting unused
 *   waiting = queued callers waiting for a free connection (>0 = pool saturated)
 */
const getPoolMetrics = () => ({
  total: pool.totalCount,
  idle: pool.idleCount,
  waiting: pool.waitingCount,
});

export {
  pool,
  query,
  transaction,
  testConnection,
  getPoolMetrics,
};
