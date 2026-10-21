import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import { idempotent } from '../middleware/idempotency.js';
import groupController from '../controllers/groupController.js';

const router = express.Router();

// Cover-image endpoints opt in to the 10MB body limit; everything else
// stays on the 256KB default from server.js.
const largeJson = express.json({ limit: '10mb' });

router.get('/', authenticate, groupController.getGroups);
router.get('/:id', authenticate, groupController.getGroup);

// Non-group expenses with one friend (hidden "direct" group).
router.post(
  '/direct',
  authenticate,
  [body('friendId').isUUID()],
  validate,
  groupController.getDirectGroup
);

router.post(
  '/',
  largeJson,
  authenticate,
  idempotent,
  [body('name').trim().isLength({ min: 2, max: 255 })],
  validate,
  groupController.createGroup
);

router.put('/:id', largeJson, authenticate, groupController.rejectDirect, groupController.updateGroup);
router.delete('/:id', authenticate, groupController.rejectDirect, groupController.deleteGroup);

router.get('/:id/members', authenticate, groupController.getGroupMembers);

router.post(
  '/:id/members',
  authenticate,
  groupController.rejectDirect,
  [
    body('userId').notEmpty(),
    body('name').trim().isLength({ min: 2, max: 255 })
  ],
  validate,
  groupController.addGroupMember
);

router.delete('/:id/members/:userId', authenticate, groupController.rejectDirect, groupController.removeGroupMember);

router.put(
  '/:id/members/:userId',
  authenticate,
  groupController.rejectDirect,
  [body('role').isIn(['admin', 'member'])],
  validate,
  groupController.updateMemberRole
);

// Pending members routes (for non-registered users via WATI WhatsApp)
router.get('/:id/pending-members', authenticate, groupController.getPendingMembers);

router.post(
  '/:id/pending-members',
  authenticate,
  groupController.rejectDirect,
  [
    body('name').trim().isLength({ min: 1, max: 255 }).withMessage('Name is required'),
    body('phoneNumber').notEmpty().withMessage('Phone number is required'),
  ],
  validate,
  groupController.addPendingMember
);

router.post('/:id/pending-members/:phoneNumber/resend', authenticate, groupController.rejectDirect, groupController.resendPendingInvite);
router.delete('/:id/pending-members/:phoneNumber', authenticate, groupController.removePendingMember);

// Email-invite fallback. Independent of WATI / Twilio — sends an SMTP invite
// with Play Store + App Store install links. Used when WhatsApp delivery
// isn't viable. Does not modify group membership.
router.post(
  '/:id/invite-email',
  authenticate,
  groupController.rejectDirect,
  [
    body('email').isEmail().withMessage('A valid email address is required'),
    body('name').optional().trim().isLength({ max: 255 }),
  ],
  validate,
  groupController.inviteByEmail,
);

// Archive/Unarchive routes
router.put('/:id/archive', authenticate, groupController.rejectDirect, groupController.archiveGroup);
router.put('/:id/default-split', authenticate, groupController.rejectDirect, groupController.setDefaultSplit);
router.put('/:id/simplify', authenticate, groupController.rejectDirect, groupController.setSimplifyDebts);
router.put('/:id/unarchive', authenticate, groupController.rejectDirect, groupController.unarchiveGroup);
router.put('/:id/complete', authenticate, groupController.rejectDirect, groupController.completeGroup);

// Send a "you owe me" push reminder to another member of the group.
// Backend gates: caller is in group, target owes caller > 0, and 6-hour
// soft rate limit per (caller, target, group) tuple.
router.post('/:id/remind/:userId', authenticate, groupController.remindForBalance);

// Export full group ledger as an .xlsx file (multi-sheet workbook).
// Members get the file; the client saves + shares it.
router.get('/:id/export', authenticate, groupController.exportGroup);

export default router;
