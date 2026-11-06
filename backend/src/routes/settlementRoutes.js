import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import { idempotent } from '../middleware/idempotency.js';
import settlementController from '../controllers/settlementController.js';

const router = express.Router();

// Also the settlements.method values (migration 018). NULL = not recorded.
const SETTLEMENT_METHODS = ['cash', 'upi', 'bank_transfer', 'other'];

router.get('/', authenticate, settlementController.getSettlements);

router.post(
  '/',
  authenticate,
  idempotent,
  [
    body('groupId').notEmpty(),
    body('fromUserId').notEmpty(),
    body('toUserId').notEmpty(),
    body('amount').custom((value) => {
      const num = typeof value === 'number' ? value : parseFloat(value);
      if (isNaN(num) || num < 0) throw new Error('amount must be a non-negative number');
      return true;
    }),
    // When the payment happened (recorded later): today or up to a year
    // back, never in the future.
    body('paidAt')
      .optional({ values: 'null' })
      .isISO8601()
      .custom((v) => {
        const t = new Date(v).getTime();
        const now = Date.now();
        if (t > now + 36 * 3600 * 1000) throw new Error('paidAt is in the future');
        if (t < now - 366 * 86400 * 1000) throw new Error('paidAt is more than a year ago');
        return true;
      }),
    body('method').optional({ values: 'null' }).isIn(SETTLEMENT_METHODS)
      .withMessage(`method must be one of: ${SETTLEMENT_METHODS.join(', ')}`),
  ],
  validate,
  settlementController.createSettlement
);

router.post(
  '/settle-all',
  authenticate,
  idempotent,
  [
    body('friendId').isUUID(),
    body('currency').isString().isLength({ min: 3, max: 10 }),
    body('expected').isArray({ min: 1, max: 200 }),
    body('expected.*.groupId').isUUID(),
    body('expected.*.amount').isFloat(),
    body('method').optional({ values: 'null' }).isIn(SETTLEMENT_METHODS),
    body('notes').optional({ values: 'null' }).isString().isLength({ max: 500 }),
  ],
  validate,
  settlementController.settleAll
);

router.patch('/:id/confirm', authenticate, settlementController.confirmSettlement);
router.delete('/:id', authenticate, settlementController.deleteSettlement);

export default router;
