import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import { idempotent } from '../middleware/idempotency.js';
import { expenseCreateRateLimit } from '../middleware/rateLimits.js';
import expenseController from '../controllers/expenseController.js';
import expenseExtras from '../controllers/expenseExtrasController.js';

const router = express.Router();

// Receipt-bearing endpoints opt in to the 10MB body limit. Other routes
// stay on the global 256KB default set in server.js.
const largeJson = express.json({ limit: '10mb' });

router.get('/', authenticate, expenseController.getExpenses);
// Before '/:id' so "category-suggestion" isn't taken for an expense id.
router.get('/category-suggestion', authenticate, expenseExtras.suggestCategory);
router.get('/:id', authenticate, expenseController.getExpense);

router.get('/:id/comments', authenticate, expenseExtras.listComments);
router.post(
  '/:id/comments',
  authenticate,
  [body('body').isString().trim().isLength({ min: 1, max: 1000 })],
  validate,
  expenseExtras.addComment
);
router.delete('/:id/comments/:commentId', authenticate, expenseExtras.deleteComment);
router.get('/:id/history', authenticate, expenseExtras.getHistory);
router.post('/:id/history/:revisionId/restore', authenticate, expenseExtras.restoreRevision);

router.post(
  '/',
  largeJson,
  authenticate,
  // Before the rate limit, so replaying a retried request costs no slot.
  idempotent,
  // Per-user limit (60/min) sits AFTER authenticate so the key generator
  // can read req.user.id; before validate so a malformed payload still
  // costs a slot.
  expenseCreateRateLimit,
  [
    body('groupId').notEmpty().withMessage('groupId is required'),
    body('description').trim().isLength({ min: 1, max: 500 }).withMessage('description must be 1-500 chars'),
    body('amount').custom((value) => {
      const num = typeof value === 'number' ? value : parseFloat(value);
      if (isNaN(num) || num < 0) throw new Error('amount must be a non-negative number');
      return true;
    }),
    // Multi-payer clients send `payers` (paid_by becomes the largest payer).
    body('paidById').if(body('payers').not().exists()).notEmpty().withMessage('paidById is required'),
    body('payers').optional().isArray({ min: 1, max: 50 }),
    body('participants').isArray({ min: 1 }).withMessage('participants must be a non-empty array'),
  ],
  validate,
  expenseController.createExpense
);

router.put('/:id', largeJson, authenticate, expenseController.updateExpense);
router.delete('/:id', authenticate, expenseController.deleteExpense);

export default router;
