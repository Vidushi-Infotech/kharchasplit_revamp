import express from 'express';
import { authenticate } from '../middleware/auth.js';
import insights from '../controllers/insightsController.js';

/** Mounted at /api/v1: exchange rates, search and CSV exports. */
const router = express.Router();

router.get('/fx/rate', authenticate, insights.fxRate);
router.get('/search', authenticate, insights.search);
router.get('/groups/:id/export.csv', authenticate, insights.groupCsv);
router.get('/users/:id/expenses.csv', authenticate, insights.myExpensesCsv);

export default router;
