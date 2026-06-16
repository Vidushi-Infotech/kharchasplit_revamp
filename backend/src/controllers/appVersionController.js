/**
 * GET /api/v1/app-version
 *
 * Public endpoint (NO auth) — Flutter calls this on app start, before the
 * user logs in. Returns the latest released version + the minimum supported
 * version so the client can decide:
 *   current < minSupported → FORCE update (blocking dialog)
 *   current < latest       → SOFT update (dismissible dialog)
 *   else                   → no update
 *
 * Config lives in env vars so a rollout doesn't need a code deploy:
 *   LATEST_APP_VERSION         e.g. "3.3.0"   (no build code suffix)
 *   MIN_SUPPORTED_APP_VERSION  e.g. "3.0.0"
 *   FORCE_UPDATE_MESSAGE       optional human-readable reason
 *
 * Store URLs are derived from the package name / Apple ID and kept here so
 * the client doesn't hardcode store-specific strings.
 */

const APP_STORE_URL = 'https://apps.apple.com/app/id6754237285';
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.kharchasplit';

const getAppVersion = async (req, res) => {
  const latest = process.env.LATEST_APP_VERSION || '3.3.0';
  const minSupported = process.env.MIN_SUPPORTED_APP_VERSION || '3.0.0';
  const forceUpdateMessage =
    process.env.FORCE_UPDATE_MESSAGE ||
    'A critical update is required to keep using KharchaSplit.';
  const softUpdateMessage =
    process.env.SOFT_UPDATE_MESSAGE ||
    'A new version of KharchaSplit is available with improvements and fixes.';

  res.json({
    success: true,
    data: {
      latestVersion: latest,
      minSupportedVersion: minSupported,
      forceUpdateMessage,
      softUpdateMessage,
      storeUrls: {
        android: PLAY_STORE_URL,
        ios: APP_STORE_URL,
      },
    },
  });
};

export default { getAppVersion };
