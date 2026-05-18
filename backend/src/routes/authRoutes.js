import express from 'express';
import { body } from 'express-validator';
import { validate } from '../middleware/validation.js';
import { authenticate } from '../middleware/auth.js';
import { otpRateLimit } from '../middleware/rateLimits.js';
import authController from '../controllers/authController.js';

const router = express.Router();

/**
 * @route   POST /api/v1/auth/register
 * @desc    Register a new user
 * @access  Public
 */
router.post(
  '/register',
  // Same per-phone bucket as /send-otp — register also issues an OTP.
  otpRateLimit,
  [
    body('phoneNumber')
      .matches(/^\+?[1-9]\d{1,14}$/)
      .withMessage('Invalid phone number format'),
    body('name')
      .trim()
      .isLength({ min: 2, max: 255 })
      .withMessage('Name must be between 2 and 255 characters'),
    body('email')
      .optional()
      .isEmail()
      .withMessage('Invalid email format'),
  ],
  validate,
  authController.register
);

/**
 * @route   POST /api/v1/auth/send-otp
 * @desc    Send OTP to phone number
 * @access  Public
 */
router.post(
  '/send-otp',
  // Per-phone limit before validation so a malformed payload still costs
  // a slot and we can't be probed for free.
  otpRateLimit,
  [
    body('phoneNumber')
      .matches(/^\+?[1-9]\d{1,14}$/)
      .withMessage('Invalid phone number format'),
  ],
  validate,
  authController.sendOTP
);

/**
 * @route   POST /api/v1/auth/verify-otp
 * @desc    Verify OTP and login
 * @access  Public
 */
router.post(
  '/verify-otp',
  [
    body('phoneNumber')
      .matches(/^\+?[1-9]\d{1,14}$/)
      .withMessage('Invalid phone number format'),
    body('otp')
      .isLength({ min: 4, max: 10 })
      .withMessage('Invalid OTP'),
  ],
  validate,
  authController.verifyOTP
);

/**
 * @route   POST /api/v1/auth/refresh
 * @desc    Refresh access token
 * @access  Public
 */
router.post(
  '/refresh',
  [
    body('refreshToken')
      .notEmpty()
      .withMessage('Refresh token is required'),
  ],
  validate,
  authController.refreshAccessToken
);

/**
 * @route   POST /api/v1/auth/logout
 * @desc    Logout user
 * @access  Public
 */
router.post('/logout', authController.logout);

/**
 * @route   POST /api/v1/auth/simple-login
 * @desc    Simple login with just phone number (no OTP)
 * @access  Public
 */
router.post(
  '/simple-login',
  [
    body('phoneNumber')
      .matches(/^\+?[1-9]\d{1,14}$/)
      .withMessage('Invalid phone number format'),
  ],
  validate,
  authController.simpleLogin
);

/**
 * @route   GET /api/v1/auth/sessions
 * @desc    List all active sessions (refresh tokens) for the current user
 * @access  Private
 */
router.get('/sessions', authenticate, authController.listSessions);

/**
 * @route   DELETE /api/v1/auth/sessions/:id
 * @desc    Revoke a single session by id
 * @access  Private
 */
router.delete('/sessions/:id', authenticate, authController.revokeSession);

/**
 * @route   DELETE /api/v1/auth/sessions
 * @desc    Revoke ALL sessions for the user except the one matching the
 *          provided refresh token in the body (if any)
 * @access  Private
 */
router.delete('/sessions', authenticate, authController.revokeAllSessions);

export default router;
