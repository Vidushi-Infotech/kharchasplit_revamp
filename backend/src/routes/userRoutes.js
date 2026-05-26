import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import userController from '../controllers/userController.js';
import notificationController from '../controllers/notificationController.js';

const router = express.Router();

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

router.get('/:id/dashboard', authenticate, userController.getDashboard);

router.get('/:id/reports', authenticate, userController.getReports);

router.get('/:id/export', authenticate, userController.exportUserData);

router.get('/:id', authenticate, userController.getUser);

router.put(
  '/:id',
  authenticate,
  [
    body('name').optional().trim().isLength({ min: 2, max: 255 }),
    body('email').optional().isEmail(),
  ],
  validate,
  userController.updateUser
);

router.delete('/:id', authenticate, userController.deleteUser);

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
