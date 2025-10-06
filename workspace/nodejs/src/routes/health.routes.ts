/**
 * Health Check Routes
 */

import { Router } from 'express';
import { healthCheck, readinessCheck, livenessCheck } from '../controllers/health.controller';

const router = Router();

/**
 * @route GET /health
 * @desc Basic health check
 * @access Public
 */
router.get('/', healthCheck);

/**
 * @route GET /health/ready
 * @desc Readiness check (dependencies)
 * @access Public
 */
router.get('/ready', readinessCheck);

/**
 * @route GET /health/live
 * @desc Liveness check
 * @access Public
 */
router.get('/live', livenessCheck);

export default router;
