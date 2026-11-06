import crypto from 'crypto';
import pg from 'pg';
import { connectionConfig, query } from '../config/database.js';
import { cache } from './cacheService.js';
import { logger } from '../utils/logger.js';

/**
 * Cross-process cache invalidation over Postgres LISTEN/NOTIFY.
 *
 * PM2 runs the API in cluster mode, and each process has its own in-memory
 * cache. Without this, a write handled by process A leaves process B
 * serving the old balances / membership checks until the TTL expires.
 *
 * - Outgoing: cache.del()/invalidate() call publish(); invalidations made in
 *   the same tick are batched into one NOTIFY (payload is capped at 8000
 *   bytes by Postgres, so large batches are chunked).
 * - Incoming: one dedicated connection (not from the pool) LISTENs and
 *   applies other processes' invalidations locally.
 * - Failure: while the listener is down the cache is bypassed (see
 *   CacheService.setCoherent), and it reconnects with back-off. Messages
 *   sent while we were disconnected are lost, which is why reconnecting
 *   starts from an empty cache.
 *
 * CACHE_BUS=false disables it (single-process deployments only).
 */
const CHANNEL = 'cache_inval';
const MAX_PAYLOAD = 7500;
const ORIGIN = `${process.pid}-${crypto.randomBytes(4).toString('hex')}`;

let client = null;
let stopped = false;
let retryMs = 1000;
let pending = [];
let flushScheduled = false;

function publish(op, key) {
  pending.push([op, key]);
  if (flushScheduled) return;
  flushScheduled = true;
  setImmediate(flush);
}

function flush() {
  flushScheduled = false;
  const items = pending;
  pending = [];
  let batch = [];
  let size = 0;
  const send = () => {
    if (batch.length === 0) return;
    const payload = JSON.stringify({ o: ORIGIN, i: batch });
    query('SELECT pg_notify($1, $2)', [CHANNEL, payload]).catch((err) => {
      // Other processes keep this entry until its TTL; nothing else to do.
      logger.warn({ err: err.message }, '[cacheBus] publish failed');
    });
    batch = [];
    size = 0;
  };
  for (const item of items) {
    const itemSize = item[1].length + 12;
    if (size + itemSize > MAX_PAYLOAD) send();
    batch.push(item);
    size += itemSize;
  }
  send();
}

function onNotification(msg) {
  if (msg.channel !== CHANNEL) return;
  let data;
  try {
    data = JSON.parse(msg.payload);
  } catch {
    return;
  }
  if (data.o === ORIGIN || !Array.isArray(data.i)) return;
  for (const [op, key] of data.i) {
    if ((op === 'del' || op === 'prefix') && typeof key === 'string') cache.applyRemote(op, key);
  }
}

function scheduleReconnect() {
  if (stopped) return;
  const wait = retryMs;
  retryMs = Math.min(retryMs * 2, 30_000);
  setTimeout(connect, wait).unref();
}

async function connect() {
  if (stopped) return;
  const c = new pg.Client({ ...connectionConfig, application_name: 'kharchasplit-cachebus', keepAlive: true });
  let dropped = false;
  const onDrop = (err) => {
    if (dropped) return;
    dropped = true;
    cache.setCoherent(false);
    if (client === c) client = null;
    c.removeAllListeners('notification');
    c.end().catch(() => {});
    if (!stopped) logger.warn({ err: err?.message }, '[cacheBus] listener lost, cache bypassed until reconnect');
    scheduleReconnect();
  };
  c.on('error', onDrop);
  c.on('end', () => onDrop(new Error('connection ended')));
  try {
    await c.connect();
    c.on('notification', onNotification);
    await c.query(`LISTEN ${CHANNEL}`);
    client = c;
    retryMs = 1000;
    cache.setCoherent(true);
    logger.info({ origin: ORIGIN }, '[cacheBus] listening');
  } catch (err) {
    onDrop(err);
  }
}

export async function startCacheBus() {
  if (process.env.CACHE_BUS === 'false') {
    logger.info('[cacheBus] disabled via CACHE_BUS=false (single-process cache)');
    return;
  }
  stopped = false;
  cache.publisher = publish;
  await connect();
}

export async function stopCacheBus() {
  stopped = true;
  cache.publisher = null;
  const c = client;
  client = null;
  if (c) await c.end().catch(() => {});
}
