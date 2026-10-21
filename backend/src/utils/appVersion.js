/**
 * Client app version (X-App-Version header, sent by every app build from
 * 3.5.0 — see frontend RequestMetaInterceptor) and server feature flags.
 *
 * Use these to roll features out safely:
 *   - isClientAtLeast(req, '3.6.0') before accepting a write whose shape an
 *     older build can't round-trip (e.g. editing a multi-payer expense).
 *     A request without the header counts as an old build.
 *   - isFeatureEnabled('multiPayer') to gate server behaviour; the same
 *     list is published to the app via GET /app-version → data.features.
 *
 * FEATURES env: comma-separated names, e.g. FEATURES=multiPayer,upiPay
 */

/** "3.4.0" / "3.4.0+25" → [3, 4, 0]; anything else → null. */
export function parseVersion(value) {
  const m = /^(\d+)\.(\d+)\.(\d+)/.exec(String(value ?? '').trim());
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}

/** < 0 when a < b, 0 when equal, > 0 when a > b. Unparseable sorts lowest. */
export function compareVersions(a, b) {
  const pa = parseVersion(a);
  const pb = parseVersion(b);
  if (!pa || !pb) return (pa ? 1 : 0) - (pb ? 1 : 0);
  for (let i = 0; i < 3; i++) if (pa[i] !== pb[i]) return pa[i] - pb[i];
  return 0;
}

export function clientVersion(req) {
  return parseVersion(req.get('X-App-Version')) ? req.get('X-App-Version').trim() : null;
}

export function isClientAtLeast(req, minVersion) {
  const v = clientVersion(req);
  return v !== null && compareVersions(v, minVersion) >= 0;
}

export function enabledFeatures() {
  return (process.env.FEATURES || '')
    .split(',')
    .map((f) => f.trim())
    .filter(Boolean);
}

export function isFeatureEnabled(name) {
  return enabledFeatures().includes(name);
}
