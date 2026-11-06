import express from 'express';
import appVersionController from '../controllers/appVersionController.js';

const router = express.Router();

// Public — runs on Flutter splash BEFORE login, so no authenticate middleware.
router.get('/', appVersionController.getAppVersion);

export default router;
