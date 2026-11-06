/**
 * Push notification diagnostic.
 *
 * Usage (read-only — DEFAULT, just shows state):
 *   node scripts/diagnose-push.js <phoneE164>
 *
 * Usage (also send a real test push to every registered device):
 *   node scripts/diagnose-push.js <phoneE164> --send
 *
 * Runs on whatever .env the process is started against — so on the
 * production server it queries the production DB and uses the production
 * Firebase service account. Run it on a dev machine to inspect dev state.
 *
 * Checks, in order:
 *   1. Firebase Admin actually initialised? (catches missing service-account
 *      file or bad credential)
 *   2. User exists for the given phone?
 *   3. user_devices rows (the multi-device source of truth introduced after
 *      the legacy users.fcm_token column)
 *   4. Legacy users.fcm_token column (for users who haven't re-registered
 *      since the new flow shipped)
 *   5. With --send, fires a real FCM message to each token and reports per-
 *      token success/failure. Mirrors what NotificationService does so the
 *      outcome here is the same outcome the real flows see.
 *
 * Prints redacted token previews — never the full token.
 */
// Resolve .env relative to this file so the script works whether invoked
// from the backend root or from inside scripts/.
//
// IMPORTANT: dynamic-import database.js / firebaseAdmin.js AFTER
// dotenv.config() so the pg Pool and firebase-admin pick up DB_PASSWORD
// / FIREBASE_SERVICE_ACCOUNT at the moment they construct, not before
// (ES-module hoisting would otherwise resolve normal imports first).
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import dotenv from 'dotenv';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: resolve(__dirname, '../.env') });

const { pool, query } = await import('../src/config/database.js');
const { initFirebase, isFirebaseReady } =
  await import('../src/config/firebaseAdmin.js');
const admin = (await import('firebase-admin')).default;

const arg = process.argv[2];
const shouldSend = process.argv.includes('--send');
if (!arg) {
  console.error('Usage: node scripts/diagnose-push.js <phoneE164> [--send]');
  process.exit(2);
}

// Normalise to E.164 like the rest of the codebase
let phone = arg.replace(/\D/g, '');
if (phone.length === 10) phone = '91' + phone;
const phoneE164 = '+' + phone;

const redact = (token) =>
  !token ? '(null)' : token.length < 16 ? '(short:' + token.length + ')' : token.slice(0, 12) + '…' + token.slice(-6);

console.log('=== Step 1: Firebase Admin init ===');
await initFirebase();
const ready = isFirebaseReady();
console.log('  firebase.ready =', ready);
if (!ready) {
  console.log('  → Push notifications are DISABLED right now.');
  console.log('  → Either backend/firebase-service-account.json is missing/unreadable,');
  console.log('     or the FIREBASE_SERVICE_ACCOUNT env var is empty/malformed.');
  console.log('     Service account file expected at backend/firebase-service-account.json');
}

console.log('\n=== Step 2: User lookup ===');
const userRow = await query(
  `SELECT id, name, phone_number, email, fcm_token, fcm_token_updated_at
   FROM users
   WHERE phone_number = $1 AND deleted_at IS NULL`,
  [phoneE164],
);
if (userRow.rows.length === 0) {
  console.log('  User NOT FOUND for', phoneE164);
  await pool.end();
  process.exit(1);
}
const user = userRow.rows[0];
console.log('  id:', user.id);
console.log('  name:', user.name);
console.log('  phone:', user.phone_number);
console.log('  legacy fcm_token:', redact(user.fcm_token), 'updated:', user.fcm_token_updated_at);

console.log('\n=== Step 3: user_devices rows ===');
const devicesRow = await query(
  `SELECT fcm_token, platform, device_name, os_version, app_version, last_seen_at
   FROM user_devices
   WHERE user_id = $1
   ORDER BY last_seen_at DESC`,
  [user.id],
);
if (devicesRow.rows.length === 0) {
  console.log('  NO ROWS in user_devices for this user.');
  console.log('  → The mobile app never called POST /users/:id/devices on this login.');
  console.log('  → Likely causes:');
  console.log('     a. notification permission denied on the device');
  console.log('     b. Firebase init failed on the device (no token to send)');
  console.log('     c. authProvider._persistAuthResult fired the call but it errored —');
  console.log('        check the device logs for "[PushService] registerWithBackend failed"');
} else {
  console.table(
    devicesRow.rows.map((r) => ({
      platform: r.platform || '?',
      device: r.device_name || '?',
      os: r.os_version || '?',
      app: r.app_version || '?',
      last_seen: r.last_seen_at,
      token: redact(r.fcm_token),
    })),
  );
}

const allTokens = [
  ...devicesRow.rows.map((r) => ({ source: 'user_devices', token: r.fcm_token })),
  // Include legacy column if it's set AND not duplicated in user_devices.
  ...(user.fcm_token && !devicesRow.rows.some((r) => r.fcm_token === user.fcm_token)
    ? [{ source: 'users.fcm_token (legacy)', token: user.fcm_token }]
    : []),
].filter((t) => t.token);

if (allTokens.length === 0) {
  console.log('\nNo tokens to test — nothing to send a push to.');
  await pool.end();
  process.exit(0);
}

if (!shouldSend) {
  console.log(`\n${allTokens.length} token(s) registered. Re-run with --send to fire a real test push.`);
  await pool.end();
  process.exit(0);
}

if (!ready) {
  console.log('\nCannot send — Firebase Admin is not initialised. Exiting.');
  await pool.end();
  process.exit(1);
}

console.log(`\n=== Step 4: Sending test push to ${allTokens.length} token(s) ===`);
for (const { source, token } of allTokens) {
  const msg = {
    token,
    notification: {
      title: 'KharchaSplit — push diagnostic',
      body: `Test push sent at ${new Date().toLocaleString()}.`,
    },
    data: { type: 'DIAGNOSTIC' },
    android: { notification: { channelId: 'default_channel', priority: 'high' } },
    apns: { payload: { aps: { sound: 'default', badge: 1 } } },
  };
  try {
    const resp = await admin.messaging().send(msg);
    console.log(`  ✅ ${source} ${redact(token)} → sent (${resp})`);
  } catch (err) {
    console.log(`  ❌ ${source} ${redact(token)} → ${err.code || 'unknown'}: ${err.message}`);
    if (
      err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-registration-token'
    ) {
      console.log('     This token is stale. The device must re-register (next login or token refresh).');
    }
  }
}

await pool.end();
