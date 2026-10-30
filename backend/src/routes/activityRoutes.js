import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import activityController from '../controllers/activityController.js';

const router = express.Router();

// Activities are written by the server as things happen (services/
// activityService.js). There is no client "create", and no per-group feed
// or group read-all: those let any user post into, or read, any group's
// feed without being a member, and no app ever called them.

// Get user activities
router.get('/', authenticate, activityController.getUserActivities);

// Get unread count
router.get('/unread/count', authenticate, activityController.getUnreadCount);

// Get single activity
router.get('/:id', authenticate, activityController.getActivity);

// Mark activity as read
router.patch('/:id/read', authenticate, activityController.markAsRead);

// Mark all activities as read
router.patch(
  '/read-all',
  authenticate,
  [body('userId').notEmpty()],
  validate,
  activityController.markAllAsRead
);

// Delete activity
router.delete('/:id', authenticate, activityController.deleteActivity);

export default router;
