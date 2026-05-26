import express from 'express';
import { body  } from 'express-validator';
import { authenticate  } from '../middleware/auth.js';
import { validate  } from '../middleware/validation.js';
import settlementController from '../controllers/settlementController.js';

const router = express.Router();

router.get('/', authenticate, settlementController.getSettlements);

router.post(
  '/',
  authenticate,
  [
    body('groupId').notEmpty(),
    body('fromUserId').notEmpty(),
    body('toUserId').notEmpty(),
    body('amount').custom((value) => {
      const num = typeof value === 'number' ? value : parseFloat(value);
      if (isNaN(num) || num < 0) throw new Error('amount must be a non-negative number');
      return true;
    })
  ],
  validate,
  settlementController.createSettlement
);

router.patch('/:id/confirm', authenticate, settlementController.confirmSettlement);
router.delete('/:id', authenticate, settlementController.deleteSettlement);

export default router;
