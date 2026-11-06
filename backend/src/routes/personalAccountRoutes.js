import express from 'express';
import { body, param } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import { idempotent } from '../middleware/idempotency.js';
import accounts from '../controllers/personalAccountController.js';
import { ACCOUNT_TYPES } from '../models/PersonalAccount.js';

/** Mounted at /api/v1/personal-accounts: Personal mode accounts and transfers. */
const router = express.Router();

const MAX = 9999999999;
const id = param('id').isUUID();
const name = (field) => body(field).trim().isLength({ min: 1, max: 60 });
const balance = (field) => body(field).isFloat({ min: -MAX, max: MAX }).toFloat();

router.get('/', authenticate, accounts.list);
router.post(
  '/',
  authenticate,
  idempotent,
  [name('name'), body('type').isIn(ACCOUNT_TYPES), balance('balance').optional()],
  validate,
  accounts.create
);
router.post(
  '/import',
  authenticate,
  [
    body('accounts').isArray({ max: 50 }),
    body('accounts.*.key').isString().isLength({ min: 1, max: 100 }),
    name('accounts.*.name'),
    body('accounts.*.type').isIn(ACCOUNT_TYPES),
    balance('accounts.*.balance'),
    body('links').optional().isObject(),
  ],
  validate,
  accounts.importWallet
);

// Before '/:id'.
router.get('/transfers', authenticate, accounts.listTransfers);
router.post(
  '/transfers',
  authenticate,
  idempotent,
  [
    body('fromAccountId').isUUID(),
    body('toAccountId').isUUID(),
    body('amount').isFloat({ gt: 0, max: MAX }).toFloat(),
    body('note').optional({ values: 'null' }).trim().isLength({ max: 200 }),
    body('date').optional({ values: 'null' }).isISO8601(),
  ],
  validate,
  accounts.createTransfer
);
router.delete('/transfers/:id', authenticate, [id], validate, accounts.deleteTransfer);

router.put(
  '/:id',
  authenticate,
  [id, name('name').optional(), balance('balance').optional()],
  validate,
  accounts.update
);
router.delete('/:id', authenticate, [id], validate, accounts.archive);

export default router;
