// Template: backend/src/routes/<resource>Routes.js
// Replace <Resource> / <resource> placeholders and the body() validators.
import express from 'express';
import { body, query, param } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { validate } from '../middleware/validation.js';
import <resource>Controller from '../controllers/<resource>Controller.js';

const router = express.Router();

// GET /api/v1/<resource>?groupId=:id&page=1&limit=50
router.get(
  '/',
  authenticate,
  [
    query('groupId').optional().isUUID().withMessage('groupId must be UUID'),
    query('page').optional().isInt({ min: 1 }).withMessage('page must be >= 1'),
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('limit 1-100'),
  ],
  validate,
  <resource>Controller.list
);

// GET /api/v1/<resource>/:id
router.get(
  '/:id',
  authenticate,
  [param('id').isUUID().withMessage('id must be UUID')],
  validate,
  <resource>Controller.getOne
);

// POST /api/v1/<resource>
router.post(
  '/',
  authenticate,
  [
    body('groupId').notEmpty().withMessage('groupId is required'),
    // body('field').trim().isLength({ min: 1, max: 500 }).withMessage('...'),
    // body('amount').custom((value) => {
    //   const num = typeof value === 'number' ? value : parseFloat(value);
    //   if (isNaN(num) || num < 0) throw new Error('amount must be a non-negative number');
    //   return true;
    // }),
  ],
  validate,
  <resource>Controller.create
);

// PUT /api/v1/<resource>/:id
router.put(
  '/:id',
  authenticate,
  [param('id').isUUID()],
  validate,
  <resource>Controller.update
);

// DELETE /api/v1/<resource>/:id  — soft delete only
router.delete(
  '/:id',
  authenticate,
  [param('id').isUUID()],
  validate,
  <resource>Controller.remove
);

export default router;
