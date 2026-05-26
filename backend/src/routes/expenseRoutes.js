import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import { expenseCreateRateLimit } from '../middleware/rateLimits.js';
import expenseController from '../controllers/expenseController.js';

const router = express.Router();

router.get('/', authenticate, expenseController.getExpenses);
router.get('/:id', authenticate, expenseController.getExpense);

router.post(
  '/',
  authenticate,
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
    body('paidById').notEmpty().withMessage('paidById is required'),
    body('participants').isArray({ min: 1 }).withMessage('participants must be a non-empty array'),
  ],
  validate,
  expenseController.createExpense
);

router.put('/:id', authenticate, expenseController.updateExpense);
router.delete('/:id', authenticate, expenseController.deleteExpense);

export default router;
