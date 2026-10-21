import express from 'express';
import { authenticate } from '../middleware/auth.js';
import recurringController from '../controllers/recurringController.js';

const router = express.Router();

router.get('/:id', authenticate, recurringController.getOne);
router.put('/:id', authenticate, recurringController.update);
router.post('/:id/pause', authenticate, recurringController.pause);
router.post('/:id/resume', authenticate, recurringController.resume);
router.delete('/:id', authenticate, recurringController.stop);

export default router;
