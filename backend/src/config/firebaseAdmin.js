import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Service-account JSON lives at backend/firebase-service-account.json (gitignored).
// In production set FIREBASE_SERVICE_ACCOUNT to the JSON contents (as a string)
// so we don't need the file on disk.
let initialized = false;

export function initFirebase() {
  if (initialized) return admin.app();

  try {
    let credential;

    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      credential = admin.credential.cert(
        JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT),
      );
    } else {
      const filePath = path.resolve(__dirname, '../../firebase-service-account.json');
      if (!fs.existsSync(filePath)) {
        console.warn('[Firebase] No service account found — push notifications disabled');
        return null;
      }
      credential = admin.credential.cert(JSON.parse(fs.readFileSync(filePath, 'utf8')));
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
