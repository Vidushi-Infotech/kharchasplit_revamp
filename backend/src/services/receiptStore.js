import { randomUUID } from 'crypto';
import { mkdir, readFile, rename, unlink, writeFile } from 'fs/promises';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';
import { logger } from '../utils/logger.js';

/**
 * Receipt photos as files instead of base64 TEXT in the database (which
 * bloated every backup and query touching the row).
 *
 * Files live in RECEIPTS_DIR (default backend/uploads/receipts), named by
 * a random uuid — never by user input. All PM2 workers on one machine share
 * the folder; it must be included in server backups. The API is unchanged:
 * expenses still come back with `receipt_base64` (read from the file on
 * the detail endpoint), so every app version keeps working.
 */
const ROOT = process.env.RECEIPTS_DIR
  || resolve(dirname(fileURLToPath(import.meta.url)), '../../uploads/receipts');

export const MAX_RECEIPT_BYTES = 8 * 1024 * 1024;

const FILE_RE = /^[0-9a-f-]{36}\.(jpg|png|webp|heic|pdf)$/;

/** File type from the first bytes; null when it isn't an image/PDF we take. */
export function sniffType(buf) {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'png';
  if (buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') return 'webp';
  if (buf.toString('ascii', 4, 8) === 'ftyp' && /^(heic|heix|mif1|msf1)$/.test(buf.toString('ascii', 8, 12))) return 'heic';
  if (buf.toString('ascii', 0, 5) === '%PDF-') return 'pdf';
  return null;
}

/**
 * Decode an app's base64 receipt (optionally a data: URL) and store it.
 * @returns {Promise<string>} the stored file name
 * @throws Error with status 400 for oversize / unknown content
 */
export async function saveReceipt(base64) {
  const raw = String(base64).replace(/^data:[^;]+;base64,/, '');
  const buf = Buffer.from(raw, 'base64');
  const bad = (msg) => Object.assign(new Error(msg), { status: 400 });
  if (buf.length === 0) throw bad('Receipt is empty');
  if (buf.length > MAX_RECEIPT_BYTES) throw bad('Receipt photo is too large (max 8 MB)');
  const ext = sniffType(buf);
  if (!ext) throw bad('Receipt must be a photo (JPEG, PNG, WebP, HEIC) or a PDF');

  await mkdir(ROOT, { recursive: true });
  const name = `${randomUUID()}.${ext}`;
  const tmp = join(ROOT, `.${name}.tmp`);
  await writeFile(tmp, buf, { mode: 0o640 });
  await rename(tmp, join(ROOT, name)); // atomic: never a half-written file
  return name;
}

/** The stored receipt as base64 (what the API returns), or null. */
export async function readReceiptBase64(name) {
  if (!name || !FILE_RE.test(name)) return null;
  try {
    return (await readFile(join(ROOT, name))).toString('base64');
  } catch (e) {
    logger.warn({ name, err: e.code }, '[receipts] file missing');
    return null;
  }
}

/** Best-effort delete of a replaced receipt. */
export async function deleteReceipt(name) {
  if (!name || !FILE_RE.test(name)) return;
  await unlink(join(ROOT, name)).catch(() => {});
}
