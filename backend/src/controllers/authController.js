import { query  } from '../config/database.js';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken  } from '../utils/jwt.js';
import { generateOTP, getOTPExpiry, sendOTPviaSMS  } from '../utils/otp.js';
import Group from '../models/Group.js';
import User from '../models/User.js';
import TwilioService from '../services/twilioService.js';

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
 * Register new user
 * POST /api/v1/auth/register
 */
const register = async (req, res, next) => {
  try {
    const { phoneNumber, name, email } = req.body;

    // Check if user already exists (non-placeholder)
    const existingUser = await query(
      'SELECT id, is_placeholder FROM users WHERE phone_number = $1 AND deleted_at IS NULL',
      [phoneNumber]
    );

    let user;
    let convertedFromPlaceholder = false;

    if (existingUser.rows.length > 0) {
      const existing = existingUser.rows[0];

      if (existing.is_placeholder) {
        // Convert placeholder user to real user
        console.log(`[Auth] Converting placeholder user ${existing.id} to real user`);
        const convertedUser = await User.convertPlaceholderToReal(phoneNumber, { name, email });

        if (convertedUser) {
          user = convertedUser;
          convertedFromPlaceholder = true;
          console.log(`[Auth] Successfully converted placeholder user ${user.id}`);
        } else {
          // Fallback - shouldn't happen but handle gracefully
          return res.status(409).json({
            success: false,
            error: 'User with this phone number already exists',
          });
        }
      } else {
        // Real user already exists
        return res.status(409).json({
          success: false,
          error: 'User with this phone number already exists',
        });
      }
    } else {
      // Create new user
      const result = await query(
        `INSERT INTO users (phone_number, name, email)
         VALUES ($1, $2, $3)
         RETURNING id, phone_number, name, email, created_at`,
        [phoneNumber, name, email || null]
      );
      user = result.rows[0];
    }

    // Clean up pending invites for this phone number
    // (User is already in groups if they were a placeholder, but we should clean up invite records)
    let addedGroups = [];
    try {
      if (convertedFromPlaceholder) {
        // For placeholder users, just delete pending invite records and get group names
        const pendingInvites = await Group.getPendingInvitesByPhone(phoneNumber);
        if (pendingInvites.length > 0) {
          addedGroups = pendingInvites.map(invite => ({
            groupId: invite.group_id,
            groupName: invite.group_name,
          }));
          // Batch delete all pending invites in a single query
          await Group.deletePendingInvitesByIds(pendingInvites.map(i => i.id));
          console.log(`[Auth] Cleaned up ${addedGroups.length} pending invite records for converted placeholder user ${user.id}`);
        }
      } else {
        // For new users, process pending invites normally
        addedGroups = await Group.processPendingInvitesForUser(user.id, phoneNumber, name);
        if (addedGroups.length > 0) {
          console.log(`[Auth] Auto-added new user ${user.id} to ${addedGroups.length} groups from pending invites`);
        }
      }
    } catch (pendingError) {
      console.error('[Auth] Error processing pending invites:', pendingError);
      // Don't fail registration if pending invites fail
    }

    // Generate OTP (use test OTP for test phone number)
    const otp = phoneNumber === '+919822192700' ? '123456' : generateOTP();
    const expiresAt = getOTPExpiry();

    // Save OTP
    await query(
      'INSERT INTO otps (phone_number, otp, expires_at) VALUES ($1, $2, $3)',
      [phoneNumber, otp, expiresAt]
    );

    // Send OTP (skip WATI for test phone number since it will fail anyway)
    if (phoneNumber !== '+919822192700') {
      await sendOTPviaSMS(phoneNumber, otp);
    }

    res.status(201).json({
      success: true,
      message: convertedFromPlaceholder
        ? `Welcome! Your account has been activated. You're already in ${addedGroups.length} group(s). OTP sent to your phone.`
        : addedGroups.length > 0
          ? `User registered successfully. You've been added to ${addedGroups.length} group(s). OTP sent to your phone.`
          : 'User registered successfully. OTP sent to your phone.',
      data: {
        user: {
          id: user.id,
          phoneNumber: user.phone_number,
          name: user.name,
          email: user.email,
        },
        addedGroups: addedGroups.length > 0 ? addedGroups : undefined,
        convertedFromPlaceholder,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Send OTP for unified login/signup.
 * POST /api/v1/auth/send-otp
 *
 * Triggers a Twilio Verify SMS to the given phone number. Does NOT
 * require the user to exist yet — a new user is auto-created on
 * verifyOTP if the number isn't on file.
 */
const sendOTP = async (req, res, next) => {
  try {
    const { phoneNumber } = req.body;
    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        error: 'Phone number is required',
      });
    }

    if (!TwilioService.isConfigured()) {
      return res.status(500).json({
        success: false,
        error: 'OTP service not configured on the server',
      });
    }

    await TwilioService.sendVerification(phoneNumber);

    res.json({
      success: true,
      message: 'OTP sent successfully',
    });
  } catch (error) {
    // Surface Twilio errors meaningfully so the client can show a useful
    // message (invalid number, unverified trial recipient, etc.).
    if (error?.status && error?.message) {
      return res.status(error.status === 400 ? 400 : 502).json({
        success: false,
        error: error.message,
        code: error.code,
      });
    }
    next(error);
  }
};

/**
 * Verify OTP and login
 * POST /api/v1/auth/verify-otp
 */
const verifyOTP = async (req, res, next) => {
  try {
    const { phoneNumber, otp } = req.body;

    if (!phoneNumber || !otp) {
      return res.status(400).json({
        success: false,
        error: 'Phone number and OTP are required',
      });
    }

    if (!TwilioService.isConfigured()) {
      return res.status(500).json({
        success: false,
        error: 'OTP service not configured on the server',
      });
    }

    // Verify the code with Twilio Verify.
    let approved = false;
    try {
      const result = await TwilioService.checkVerification(phoneNumber, otp);
      approved = result.approved;
    } catch (err) {
      // Twilio returns 404 if the verification has already been
      // consumed/expired and no longer exists. Treat that as an invalid
      // code rather than a 500.
      if (err?.status === 404) {
        return res.status(401).json({
          success: false,
          error: 'OTP expired. Please request a new one.',
        });
      }
      throw err;
    }

    if (!approved) {
      return res.status(401).json({
        success: false,
        error: 'Invalid OTP',
      });
    }

    // Look up the user; auto-create a placeholder row if this is their
    // first time. Profile-setup screen on the client will fill in name +
    // email + photo right after the redirect.
    let userRow;
    let isNewUser = false;
    const existing = await query(
      'SELECT id, phone_number, name, email, profile_image_base64, preferred_currency FROM users WHERE phone_number = $1 AND deleted_at IS NULL',
      [phoneNumber],
    );
    if (existing.rows.length > 0) {
      userRow = existing.rows[0];
    } else {
      const created = await query(
        `INSERT INTO users (phone_number, name, email, preferred_currency)
         VALUES ($1, '', NULL, 'INR')
         RETURNING id, phone_number, name, email, profile_image_base64, preferred_currency`,
        [phoneNumber],
      );
      userRow = created.rows[0];
      isNewUser = true;
    }

    // A user with a blank name (e.g. auto-created earlier but never
    // completed setup) should be treated as "new" on the client so it
    // pushes them through the profile-setup flow.
    const needsProfileSetup =
      isNewUser || !userRow.name || userRow.name.trim().length === 0;

    // Issue tokens
    const accessToken = generateAccessToken(userRow.id);
    const refreshToken = generateRefreshToken(userRow.id);

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
        userRow.id,
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

    res.json({
      success: true,
      message: isNewUser ? 'Account created' : 'Login successful',
      data: {
        user: {
          id: userRow.id,
          phoneNumber: userRow.phone_number,
          name: userRow.name,
          email: userRow.email,
          profileImageBase64: userRow.profile_image_base64,
          preferredCurrency: userRow.preferred_currency,
        },
        accessToken,
        refreshToken,
        isNewUser,
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

    // Verify refresh token
    let decoded;
    try {
      decoded = verifyRefreshToken(refreshToken);
    } catch (error) {
      return res.status(401).json({
        success: false,
        error: 'Invalid refresh token',
      });
    }

    // Check if refresh token exists and is not expired
    const tokenResult = await query(
      `SELECT * FROM refresh_tokens
       WHERE token = $1
       AND expires_at > NOW()
       LIMIT 1`,
      [refreshToken]
    );

    if (tokenResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Refresh token not found or expired',
      });
    }

    // Bump last_used_at so the Active Sessions list stays accurate.
    await query(
      'UPDATE refresh_tokens SET last_used_at = NOW() WHERE token = $1',
      [refreshToken]
    );

    // Generate new access token
    const accessToken = generateAccessToken(decoded.userId);

    res.json({
      success: true,
      data: {
        accessToken,
      },
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
      // Delete refresh token
      await query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken]);
    }

    res.json({
      success: true,
      message: 'Logged out successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Simple login with just phone number (no OTP)
 * POST /api/v1/auth/simple-login
 */
const simpleLogin = async (req, res, next) => {
  try {
    const { phoneNumber } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        error: 'Phone number is required',
      });
    }

    // Check if user exists
    const userResult = await query(
      'SELECT id, phone_number, name, email, profile_image_base64, preferred_currency, created_at FROM users WHERE phone_number = $1 AND deleted_at IS NULL',
      [phoneNumber]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found. Please complete registration first.',
      });
    }

    const user = userResult.rows[0];

    // Generate tokens
    const accessToken = generateAccessToken(user.id);
    const refreshToken = generateRefreshToken(user.id);

    // Save refresh token
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
        user.id,
        refreshToken,
        refreshExpiresAt,
        device.deviceName,
        device.platform,
        device.osVersion,
        device.appVersion,
        device.ipAddress,
        device.userAgent,
      ]
    );

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: {
          id: user.id,
          phoneNumber: user.phone_number,
          name: user.name,
          email: user.email,
          profileImageBase64: user.profile_image_base64,
          preferredCurrency: user.preferred_currency,
          createdAt: user.created_at,
        },
        accessToken,
        refreshToken,
      },
    });
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
      [userId]
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
      [id, userId]
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
        [userId, keepToken]
      );
    } else {
      result = await query(
        'DELETE FROM refresh_tokens WHERE user_id = $1 RETURNING id',
        [userId]
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
  sendOTP,
  verifyOTP,
  refreshAccessToken,
  logout,
  simpleLogin,
  listSessions,
  revokeSession,
  revokeAllSessions,
};
