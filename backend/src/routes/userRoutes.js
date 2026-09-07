import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import { phoneLookupRateLimit } from '../middleware/rateLimits.js';
import userController from '../controllers/userController.js';
import notificationController from '../controllers/notificationController.js';

const router = express.Router();

// User profile update is the only endpoint here that may carry a base64
// avatar — opt in to 10MB. Everything else stays on the global 256KB.
const largeJson = express.json({ limit: '10mb' });

// IMPORTANT: Specific routes must come BEFORE parameterized routes like /:id
router.post(
  '/check-registration',
  authenticate,
  [
    body('phoneNumbers').isArray({ min: 1 }).withMessage('Phone numbers array is required'),
  ],
  validate,
  userController.checkRegisteredUsers
);

router.get('/by-phone/:phoneNumber', authenticate, userController.getUserByPhone);

// Privacy-trimmed lookup for the "Add member by phone" search box. Rate
// limited per authenticated user so a logged-in client can't enumerate
// the user directory.
router.get(
  '/lookup-by-phone',
  authenticate,
  phoneLookupRateLimit,
  userController.lookupByPhone,
);

router.get('/:id/dashboard', authenticate, userController.getDashboard);

router.get('/:id/reports', authenticate, userController.getReports);

router.get('/:id/export', authenticate, userController.exportUserData);

router.get('/:id', authenticate, userController.getUser);

router.put(
  '/:id',
  largeJson,
  authenticate,
  [
    body('name').optional().trim().isLength({ min: 2, max: 255 }),
    body('email').optional().isEmail(),
  ],
  validate,
  userController.updateUser
);

router.delete('/:id', authenticate, userController.deleteUser);

// Optional email verification (Profile → "Not verified · Verify").
router.post(
  '/:id/email/verify/request',
  authenticate,
  userController.requestEmailVerification
);
router.post(
  '/:id/email/verify/confirm',
  authenticate,
  [body('otp').trim().isLength({ min: 4, max: 10 }).isNumeric()],
  validate,
  userController.confirmEmailVerification
);

router.delete('/:id/deactivate', authenticate, userController.deactivateUser);

// FCM Token endpoints for push notifications
router.put(
  '/:id/fcm-token',
  authenticate,
  [
    body('fcmToken').notEmpty().withMessage('FCM token is required'),
  ],
  validate,
  userController.updateFcmToken
);

router.delete('/:id/fcm-token', authenticate, userController.removeFcmToken);

// Notification preferences (backend-stored, syncs across devices)
router.get('/:id/notification-prefs', authenticate, notificationController.getPrefs);
router.put('/:id/notification-prefs', authenticate, notificationController.updatePrefs);

// Multi-device FCM token registration
router.post(
  '/:id/devices',
  authenticate,
  [body('fcmToken').notEmpty().withMessage('fcmToken is required')],
  validate,
  notificationController.registerDevice
);
router.delete('/:id/devices', authenticate, notificationController.unregisterDevice);

// Notifications inbox (in-app history of received push notifications)
router.get('/:id/notifications', authenticate, notificationController.listNotifications);
router.get('/:id/notifications/unread-count', authenticate, notificationController.unreadCount);
router.patch('/:id/notifications/read-all', authenticate, notificationController.markAllRead);
router.patch('/:id/notifications/:notifId/read', authenticate, notificationController.markRead);

export default router;
