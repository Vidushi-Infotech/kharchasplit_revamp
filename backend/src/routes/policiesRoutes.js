import express from 'express';
import policiesController from '../controllers/policiesController.js';

const router = express.Router();

// Public — policies are legal text and should be readable without auth.
router.get('/privacy', policiesController.getPrivacy);
router.get('/terms', policiesController.getTerms);

export default router;
