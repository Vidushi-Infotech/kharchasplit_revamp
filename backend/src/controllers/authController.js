import { query } from '../config/database.js';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../utils/jwt.js';
import { generateOTP, getOTPExpiry } from '../utils/otp.js';
import Group from '../models/Group.js';
import User from '../models/User.js';
import EmailService from '../services/emailService.js';

/**
 * Pull device metadata for a refresh-token row out of the request body
 * (`device`) and headers. Caps each string to keep DB rows small.
 */
function extractDeviceInfo(req) {
  const d = (req.body && typeof req.body.device === 'object' && req.body.device) || {};
  const cap = (val, max) =>
    typeof val === 'string' && val.length > 0 ? val.slice(0, max) : null;
  const ip =
    (req.headers['x-forwarded-for'] || '').toString().split(',')[0].trim() ||
    req.ip ||
    req.connection?.remoteAddress ||
    null;
  return {
    deviceName: cap(d.name, 255),
    platform: cap(d.platform, 50),
    osVersion: cap(d.osVersion, 80),
    appVersion: cap(d.appVersion, 40),
    ipAddress: cap(ip, 64),
    userAgent: cap(req.headers['user-agent'], 1024),
  };
}

/**
 * Issue an access + refresh token pair for `userId` and persist the refresh
 * token (with device metadata) so it can be revoked from the Sessions UI.
 */
async function issueTokens(userId, req) {
  const accessToken = generateAccessToken(userId);
  const refreshToken = generateRefreshToken(userId);

  const refreshExpiresAt = new Date();
  refreshExpiresAt.setDate(refreshExpiresAt.getDate() + 30);

  const device = extractDeviceInfo(req);
  await query(
    `INSERT INTO refresh_tokens
      (user_id, token, expires_at,
       device_name, platform, os_version, app_version, ip_address, user_agent,
       last_used_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
    [
      userId,
      refreshToken,
      refreshExpiresAt,
      device.deviceName,
      device.platform,
      device.osVersion,
      device.appVersion,
      device.ipAddress,
      device.userAgent,
    ],
  );

  return { accessToken, refreshToken };
}

function userPayload(row) {
  return {
    id: row.id,
    phoneNumber: row.phone_number,
    name: row.name,
    email: row.email,
    profileImageBase64: row.profile_image_base64 || null,
    preferredCurrency: row.preferred_currency || 'INR',
  };
}

/**
 * Register a new user with phone + password.
 * POST /api/v1/auth/register
 *
 * Body: { phoneNumber, password, confirmPassword, device? }
 *
 * Email + name come later via the profile-setup flow. On success the user
 * is signed in immediately (tokens returned) and `needsProfileSetup: true`
 * tells the client to route to /profile-setup before the dashboard.
 */
const register = async (req, res, next) => {
  try {
    const { phoneNumber, password, confirmPassword } = req.body;

    if (password !== confirmPassword) {
      return res.status(400).json({
        success: false,
        error: 'Passwords do not match',
      });
    }

    const passwordHash = await User.hashPassword(password);

    // Check for existing row (placeholder OR real) on this phone.
    const existing = await query(
      'SELECT id, is_placeholder FROM users WHERE phone_number = $1 AND deleted_at IS NULL',
      [phoneNumber],
    );

    let user;
    let convertedFromPlaceholder = false;

    if (existing.rows.length > 0) {
      const row = existing.rows[0];
      if (!row.is_placeholder) {
        return res.status(409).json({
          success: false,
          error: 'An account with this phone number already exists',
        });
      }
      // Placeholder → convert to real user, attach password hash.
      const converted = await User.convertPlaceholderToReal(phoneNumber, {
        name: '',
        email: null,
        passwordHash,
      });
      if (!converted) {
        return res.status(409).json({
          success: false,
          error: 'An account with this phone number already exists',
        });
      }
      user = converted;
      convertedFromPlaceholder = true;
    } else {
      user = await User.create({
        phoneNumber,
        name: '',
        email: null,
        passwordHash,
      });
    }

    // Process any pending invites this phone had received.
    let addedGroups = [];
    try {
      if (convertedFromPlaceholder) {
        const pendingInvites = await Group.getPendingInvitesByPhone(phoneNumber);
        if (pendingInvites.length > 0) {
          addedGroups = pendingInvites.map((invite) => ({
            groupId: invite.group_id,
            groupName: invite.group_name,
          }));
          await Group.deletePendingInvitesByIds(pendingInvites.map((i) => i.id));
        }
      } else {
        addedGroups = await Group.processPendingInvitesForUser(user.id, phoneNumber, '');
      }
    } catch (err) {
      // Pending-invite processing is best-effort; don't block registration.
      console.error('[Auth] pending invite processing failed:', err);
    }

    const { accessToken, refreshToken } = await issueTokens(user.id, req);

    res.status(201).json({
      success: true,
      message: 'Registration successful',
      data: {
        user: userPayload(user),
        accessToken,
        refreshToken,
        isNewUser: true,
        needsProfileSetup: true,
        convertedFromPlaceholder,
        addedGroups: addedGroups.length > 0 ? addedGroups : undefined,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Login with phone + password.
 * POST /api/v1/auth/login
 *
 * Body: { phoneNumber, password, device? }
 */
const login = async (req, res, next) => {
  try {
    const { phoneNumber, password } = req.body;

    const user = await User.findByPhoneForAuth(phoneNumber);
    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid phone number or password',
      });
    }

    // Reject password-less rows — legacy users would land here; they must
    // use forgot-password to set one before signing in.
    if (!user.password_hash) {
      return res.status(401).json({
        success: false,
        error: 'Password not set on this account. Use "Forgot password" to set one.',
      });
    }

    const ok = await User.verifyPassword(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({
        success: false,
        error: 'Invalid phone number or password',
      });
    }

    const { accessToken, refreshToken } = await issueTokens(user.id, req);

    // A user with an empty name (or no email) hasn't completed profile
    // setup yet — push them through it before the dashboard.
    const needsProfileSetup =
      !user.name || user.name.trim().length === 0 ||
      !user.email || user.email.trim().length === 0;

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: userPayload(user),
        accessToken,
        refreshToken,
        needsProfileSetup,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Request a password-reset OTP via email.
 * POST /api/v1/auth/forgot-password/request
 *
 * Body: { email }
 *
 * Always returns 200 with a generic "if the email is registered, we sent a
 * code" message so the endpoint can't be used to enumerate accounts.
 */
const forgotPasswordRequest = async (req, res, next) => {
  try {
    const { email } = req.body;
    const generic = {
      success: true,
      message: 'If that email is registered, a reset code has been sent.',
    };

    const user = await User.findByEmail(email);
    if (!user) {
      return res.json(generic);
    }

    const otp = generateOTP();
    const expiresAt = getOTPExpiry(10);

    await query(
      `INSERT INTO otps (email, phone_number, otp, expires_at, purpose, verified)
       VALUES ($1, NULL, $2, $3, 'password_reset', FALSE)`,
      [email.toLowerCase(), otp, expiresAt],
    );

    const sent = await EmailService.sendPasswordResetEmail({
      toEmail: user.email,
      recipientName: user.name,
      otp,
      expiresInMinutes: 10,
    });

    if (!sent.success) {
      console.error('[Auth] password reset email failed:', sent.error);
      // Don't leak that the email exists — still return generic 200.
      // (In dev, SMTP errors will be visible in the server log.)
    }

    res.json(generic);
  } catch (error) {
    next(error);
  }
};

/**
 * Verify a password-reset OTP and set the new password.
 * POST /api/v1/auth/forgot-password/verify
 *
 * Body: { email, otp, newPassword, confirmPassword, device? }
 *
 * On success: marks OTP as used, updates the hash, and returns fresh tokens
 * so the client can route straight to the dashboard.
 */
const forgotPasswordVerify = async (req, res, next) => {
  try {
    const { email, otp, newPassword, confirmPassword } = req.body;

    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        success: false,
        error: 'Passwords do not match',
      });
    }

    const otpRow = await query(
      `SELECT id, expires_at, verified
         FROM otps
        WHERE LOWER(email) = LOWER($1)
          AND otp = $2
          AND purpose = 'password_reset'
        ORDER BY created_at DESC
        LIMIT 1`,
      [email, otp],
    );

    if (otpRow.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Invalid reset code',
      });
    }

    const row = otpRow.rows[0];
    if (row.verified) {
      return res.status(401).json({
        success: false,
        error: 'This reset code has already been used',
      });
    }
    if (new Date(row.expires_at) < new Date()) {
      return res.status(401).json({
        success: false,
        error: 'Reset code has expired. Please request a new one.',
      });
    }

    const user = await User.findByEmail(email);
    if (!user) {
      // OTP existed but the user is gone — treat as invalid.
      return res.status(401).json({
        success: false,
        error: 'Invalid reset code',
      });
    }

    await User.setPassword(user.id, newPassword);

    await query(
      'UPDATE otps SET verified = TRUE WHERE id = $1',
      [row.id],
    );

    // Auto-login after reset.
    const { accessToken, refreshToken } = await issueTokens(user.id, req);
    const needsProfileSetup =
      !user.name || user.name.trim().length === 0 ||
      !user.email || user.email.trim().length === 0;

    res.json({
      success: true,
      message: 'Password updated',
      data: {
        user: userPayload(user),
        accessToken,
        refreshToken,
        needsProfileSetup,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Refresh access token
 * POST /api/v1/auth/refresh
 */
const refreshAccessToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: 'Refresh token is required',
      });
    }

    let decoded;
    try {
      decoded = verifyRefreshToken(refreshToken);
    } catch (error) {
      return res.status(401).json({
        success: false,
        error: 'Invalid refresh token',
      });
    }

    // Existence check only — the userId comes from the verified JWT
    // payload above, not from the DB row. Narrow projection keeps this
    // off the hot refresh path's wire.
    const tokenResult = await query(
      `SELECT id FROM refresh_tokens
        WHERE token = $1
          AND expires_at > NOW()
          AND deleted_at IS NULL
        LIMIT 1`,
      [refreshToken],
    );

    if (tokenResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Refresh token not found or expired',
      });
    }

    await query(
      'UPDATE refresh_tokens SET last_used_at = NOW() WHERE token = $1',
      [refreshToken],
    );

    const accessToken = generateAccessToken(decoded.userId);

    res.json({
      success: true,
      data: { accessToken },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Logout
 * POST /api/v1/auth/logout
 */
const logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken]);
    }
    res.json({ success: true, message: 'Logged out successfully' });
  } catch (error) {
    next(error);
  }
};

/**
 * List all active sessions (refresh tokens) for the authenticated user.
 * GET /api/v1/auth/sessions
 *
 * Optional header `X-Current-Refresh-Token` lets the client mark which
 * row is its own session. We never return the raw token in the payload.
 */
const listSessions = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const currentToken = req.headers['x-current-refresh-token'] || null;

    const result = await query(
      `SELECT id, token, expires_at, created_at,
              device_name, platform, os_version, app_version,
              ip_address, last_used_at
       FROM refresh_tokens
       WHERE user_id = $1 AND expires_at > NOW()
       ORDER BY COALESCE(last_used_at, created_at) DESC`,
      [userId],
    );

    const sessions = result.rows.map((row) => ({
      id: row.id,
      createdAt: row.created_at,
      expiresAt: row.expires_at,
      lastUsedAt: row.last_used_at,
      deviceName: row.device_name,
      platform: row.platform,
      osVersion: row.os_version,
      appVersion: row.app_version,
      ipAddress: row.ip_address,
      isCurrent: currentToken !== null && row.token === currentToken,
    }));

    res.json({ success: true, data: sessions });
  } catch (error) {
    next(error);
  }
};

/**
 * Revoke a single session by id.
 * DELETE /api/v1/auth/sessions/:id
 */
const revokeSession = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const result = await query(
      'DELETE FROM refresh_tokens WHERE id = $1 AND user_id = $2 RETURNING id',
      [id, userId],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Session not found',
      });
    }
    res.json({ success: true, message: 'Session revoked' });
  } catch (error) {
    next(error);
  }
};

/**
 * Revoke all sessions for the user. If the request body contains
 * `keepRefreshToken`, that one row is preserved (so the current device
 * stays signed in).
 * DELETE /api/v1/auth/sessions
 */
const revokeAllSessions = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const keepToken = req.body?.keepRefreshToken || null;
    let result;
    if (keepToken) {
      result = await query(
        'DELETE FROM refresh_tokens WHERE user_id = $1 AND token != $2 RETURNING id',
        [userId, keepToken],
      );
    } else {
      result = await query(
        'DELETE FROM refresh_tokens WHERE user_id = $1 RETURNING id',
        [userId],
      );
    }
    res.json({
      success: true,
      message: 'Other sessions signed out',
      data: { revokedCount: result.rowCount },
    });
  } catch (error) {
    next(error);
  }
};

export default {
  register,
  login,
  forgotPasswordRequest,
  forgotPasswordVerify,
  refreshAccessToken,
  logout,
  listSessions,
  revokeSession,
  revokeAllSessions,
};
