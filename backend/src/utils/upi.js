/**
 * UPI VPA (virtual payment address) handling.
 *
 * Format only: handle@psp, e.g. "asha.k@okhdfcbank", "9876543210@ybl".
 * Whether the VPA actually exists can't be checked without a PSP/bank
 * integration — a typo surfaces in the payer's UPI app instead.
 */
const VPA_RE = /^[a-z0-9][a-z0-9._-]{1,255}@[a-z][a-z0-9]{1,63}$/;

/**
 * @returns {string|null} the normalised VPA (trimmed, lowercase), or null
 *   for empty input (= clear it).
 * @throws {Error} with `.status = 400` when the format is invalid.
 */
export function normalizeUpiId(value) {
  if (value === null || value === undefined) return null;
  const v = String(value).trim().toLowerCase();
  if (v === '') return null;
  if (v.length > 100 || !VPA_RE.test(v)) {
    const err = new Error('Enter a valid UPI ID, like name@okhdfcbank');
    err.status = 400;
    throw err;
  }
  return v;
}
