import express from 'express';
import { body, param } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { idempotent } from '../middleware/idempotency.js';
import bills from '../controllers/personalBillController.js';
import { FREQUENCIES, isDateString } from '../utils/recurrence.js';

/** Mounted at /api/v1/personal-bills: Personal mode bills. */
const router = express.Router();

const MAX = 9999999999;
const id = param('id').isUUID();
const fields = (optional) => {
  const f = (chain) => (optional ? chain.optional() : chain);
  return [
    f(body('name')).trim().isLength({ min: 1, max: 80 }),
    f(body('amount')).isFloat({ gt: 0, max: MAX }).toFloat(),
    f(body('frequency')).isIn(FREQUENCIES),
    f(body('dueDate')).custom(isDateString),
    body('category').optional().matches(/^[a-z_]{1,50}$/),
    body('accountId').optional({ values: 'null' }).isUUID(),
    body('remindDays').optional().isInt({ min: 0, max: 30 }).toInt(),
  ];
};

router.get('/', authenticate, bills.list);
router.post('/', authenticate, idempotent, fields(false), validate, bills.create);
router.put('/:id', authenticate, [id, ...fields(true)], validate, bills.update);
router.delete('/:id', authenticate, [id], validate, bills.archive);
router.get('/:id/payments', authenticate, [id], validate, bills.payments);
router.post(
  '/:id/pay',
  authenticate,
  idempotent,
  [
    id,
    body('amount').optional().isFloat({ gt: 0, max: MAX }).toFloat(),
    body('accountId').optional({ values: 'null' }).isUUID(),
    body('date').optional({ values: 'null' }).isISO8601(),
  ],
  validate,
  bills.pay
);
router.post('/:id/skip', authenticate, [id], validate, bills.skip);

export default router;
