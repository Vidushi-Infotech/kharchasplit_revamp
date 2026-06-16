import admin from 'firebase-admin';
import { promises as fsp } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Service-account JSON lives at backend/firebase-service-account.json (gitignored).
// In production set FIREBASE_SERVICE_ACCOUNT to the JSON contents (as a string)
// so we don't need the file on disk.
let initialized = false;

export async function initFirebase() {
  if (initialized) return admin.app();

  try {
    let credential;

    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      credential = admin.credential.cert(
        JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT),
      );
    } else {
      // Async file read instead of the previous existsSync + readFileSync
      // pair. The window is startup, so the latency win is small (~1ms),
      // but it eliminates the only sync FS calls in the codebase and
      // lets the event loop service /health pings during boot.
      const filePath = path.resolve(__dirname, '../../firebase-service-account.json');
      let raw;
      try {
        raw = await fsp.readFile(filePath, 'utf8');
      } catch (err) {
        if (err.code === 'ENOENT') {
          console.warn('[Firebase] No service account found — push notifications disabled');
          return null;
        }
        throw err;
      }
      credential = admin.credential.cert(JSON.parse(raw));
    }

    const app = admin.initializeApp({ credential });
    initialized = true;
    console.log('[Firebase] Admin SDK initialized');
    return app;
  } catch (err) {
    console.error('[Firebase] Init failed:', err.message);
    return null;
  }
}

export function isFirebaseReady() {
  return initialized;
}
