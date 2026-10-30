import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import { idempotent } from '../middleware/idempotency.js';
import personalExpenseController from '../controllers/personalExpenseController.js';

const router = express.Router();

router.get('/', authenticate, personalExpenseController.getPersonalExpenses);
// Before '/:id', which would otherwise take "summary" as an id.
router.get('/summary', authenticate, personalExpenseController.getPersonalSummary);
router.get('/:id', authenticate, personalExpenseController.getPersonalExpense);

router.post(
  '/',
  authenticate,
  idempotent,
  [
    body('kind').optional().isIn(['expense', 'income']),
    body('description').trim().isLength({ min: 1, max: 500 }),
    body('amount').custom((value) => {
      const num = typeof value === 'number' ? value : parseFloat(value);
      if (isNaN(num) || num < 0) throw new Error('amount must be a non-negative number');
      return true;
    })
  ],
  validate,
  personalExpenseController.createPersonalExpense
);

router.put(
  '/:id',
  authenticate,
  [body('kind').optional().isIn(['expense', 'income'])],
  validate,
  personalExpenseController.updatePersonalExpense
);
router.delete('/:id', authenticate, personalExpenseController.deletePersonalExpense);

export default router;
