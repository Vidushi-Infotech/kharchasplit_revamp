import express from 'express';
import { body } from 'express-validator';
import { validate } from '../middleware/validation.js';
import { authenticate } from '../middleware/auth.js';
import {
  loginRateLimit,
  passwordResetRateLimit,
} from '../middleware/rateLimits.js';
import authController from '../controllers/authController.js';

const router = express.Router();

const phoneValidator = body('phoneNumber')
  .matches(/^\+?[1-9]\d{1,14}$/)
  .withMessage('Invalid phone number format');

const passwordValidator = body('password')
  .isString()
  .isLength({ min: 6, max: 128 })
  .withMessage('Password must be at least 6 characters');

const confirmPasswordValidator = body('confirmPassword')
  .isString()
  .isLength({ min: 6, max: 128 })
  .withMessage('Confirm password is required');

const newPasswordValidator = body('newPassword')
  .isString()
  .isLength({ min: 6, max: 128 })
  .withMessage('Password must be at least 6 characters');

/**
 * @route   POST /api/v1/auth/register
 * @desc    Register a new user with phone + password
 * @access  Public
 */
router.post(
  '/register',
  loginRateLimit,
  [phoneValidator, passwordValidator, confirmPasswordValidator],
  validate,
  authController.register,
);

/**
 * @route   POST /api/v1/auth/login
 * @desc    Login with phone + password
 * @access  Public
 */
router.post(
  '/login',
  loginRateLimit,
  [phoneValidator, passwordValidator],
  validate,
  authController.login,
);

/**
 * @route   POST /api/v1/auth/forgot-password/request
 * @desc    Request a password-reset OTP via email
 * @access  Public
 */
router.post(
  '/forgot-password/request',
  passwordResetRateLimit,
  [
    body('email')
      .isEmail()
      .withMessage('Invalid email format')
      .normalizeEmail(),
  ],
  validate,
  authController.forgotPasswordRequest,
);

/**
 * @route   POST /api/v1/auth/forgot-password/verify
 * @desc    Verify OTP and set new password (auto-login on success)
 * @access  Public
 */
router.post(
  '/forgot-password/verify',
  passwordResetRateLimit,
  [
    body('email').isEmail().withMessage('Invalid email format'),
    body('otp')
      .isLength({ min: 4, max: 10 })
      .withMessage('Invalid OTP'),
    newPasswordValidator,
    body('confirmPassword')
      .isString()
      .isLength({ min: 6, max: 128 })
      .withMessage('Confirm password is required'),
  ],
  validate,
  authController.forgotPasswordVerify,
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
  authController.refreshAccessToken,
);

/**
 * @route   POST /api/v1/auth/logout
 * @desc    Logout user
 * @access  Public
 */
router.post('/logout', authController.logout);

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
