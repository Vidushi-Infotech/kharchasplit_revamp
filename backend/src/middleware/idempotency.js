import crypto from 'crypto';
import { query } from '../config/database.js';
import { logger } from '../utils/logger.js';

/**
 * Idempotency-Key support for create endpoints.
 *
 * A client that may retry a write (double tap, network timeout, offline
 * queue, coming back from a UPI app) sends the same `Idempotency-Key`
 * header on every attempt. The first attempt runs; later ones get the
 * first response replayed (header `Idempotent-Replayed: true`) instead of
 * creating a duplicate expense / settlement.
 *
 * - No header → the request runs normally (older app versions).
 * - Same key, different body or endpoint → 422 (client bug; never guess).
 * - Same key while the first attempt is still running → 409, retry later.
 * - Only 2xx responses are stored. On 4xx/5xx the key is released, so a
 *   corrected or later retry runs for real.
 * - A key stuck "in progress" for STALE_SECONDS (process died mid-request)
 *   is taken over by the next attempt.
 * - Keys are per user and kept for RETENTION_HOURS.
 *
 * Mount after `authenticate` (keys are scoped to req.user.id).
 */
const KEY_RE = /^[A-Za-z0-9_-]{8,100}$/;
const STALE_SECONDS = 60;
const RETENTION_HOURS = 24;

const fingerprint = (req) =>
  crypto.createHash('sha256')
    .update(`${req.method} ${req.baseUrl}${req.path}\n${JSON.stringify(req.body ?? null)}`)
    .digest('hex');

export function idempotent(req, res, next) {
  const key = req.get('Idempotency-Key');
  if (!key) return next();
  if (!KEY_RE.test(key)) {
    return res.status(400).json({ success: false, error: 'Idempotency-Key must be 8-100 characters of A-Z, a-z, 0-9, _ or -' });
  }
  const userId = req.user.id;
  const hash = fingerprint(req);

  (async () => {
    // Claim the key, or take over one abandoned by a crashed attempt.
    const claimed = await query(
      `INSERT INTO idempotency_keys (user_id, key, request_hash)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, key) DO UPDATE
          SET created_at = NOW()
        WHERE idempotency_keys.status = 'in_progress'
          AND idempotency_keys.request_hash = EXCLUDED.request_hash
          AND idempotency_keys.created_at < NOW() - make_interval(secs => ${STALE_SECONDS})
       RETURNING key`,
      [userId, key, hash],
    );

    if (claimed.rowCount === 0) {
      const { rows: [row] } = await query(
        `SELECT request_hash, status, response_status, response_body
           FROM idempotency_keys WHERE user_id = $1 AND key = $2`,
        [userId, key],
      );
      if (!row) return next(); // released between our two queries; just run
      if (row.request_hash !== hash) {
        return res.status(422).json({ success: false, error: 'Idempotency-Key was already used for a different request' });
      }
      if (row.status !== 'done') {
        res.set('Retry-After', '2');
        return res.status(409).json({ success: false, error: 'This request is already being processed' });
      }
      res.set('Idempotent-Replayed', 'true');
      return res.status(row.response_status).json(row.response_body);
    }

    // We own the key: record the outcome when the handler responds.
    const json = res.json.bind(res);
    res.json = (body) => {
      const status = res.statusCode;
      const save = status >= 200 && status < 300
        ? query(
          `UPDATE idempotency_keys
              SET status = 'done', response_status = $3, response_body = $4
            WHERE user_id = $1 AND key = $2`,
          [userId, key, status, JSON.stringify(body)],
        )
        : query('DELETE FROM idempotency_keys WHERE user_id = $1 AND key = $2', [userId, key]);
      // Record before sending, so a retry fired the moment the client gets
      // this response already sees the stored result.
      save
        .catch((err) => logger.warn({ err: err.message, key }, '[idempotency] could not record response'))
        .finally(() => json(body));
      return res;
    };
    next();
  })().catch(next);
}

/** Hourly purge of expired keys (PM2 instance 0 only). */
export function startIdempotencyCleanup() {
  const instance = process.env.NODE_APP_INSTANCE ?? process.env.pm_id;
  if (instance !== undefined && String(instance) !== '0') return () => {};
  const purge = () => query(
    `DELETE FROM idempotency_keys WHERE created_at < NOW() - make_interval(hours => ${RETENTION_HOURS})`,
  ).catch((err) => logger.warn({ err: err.message }, '[idempotency] cleanup failed'));
  const handle = setInterval(purge, 60 * 60_000);
  handle.unref();
  return () => clearInterval(handle);
}
