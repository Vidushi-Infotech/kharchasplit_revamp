import express from 'express';
import { body, param } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import budgets from '../controllers/personalBudgetController.js';

/** Mounted at /api/v1/personal-budgets: Personal mode monthly budgets. */
const router = express.Router();

// A category id (food, gift_received, ...) or 'total'.
const category = param('category').matches(/^[a-z_]{1,50}$/);

router.get('/', authenticate, budgets.getBudgets);
router.put(
  '/:category',
  authenticate,
  [category, body('amount').isFloat({ gt: 0, max: 9999999999 }).toFloat()],
  validate,
  budgets.setBudget
);
router.delete('/:category', authenticate, [category], validate, budgets.removeBudget);

export default router;
