/**
 * Health Check Controller
 * Endpoints for monitoring service health
 */

import { Request, Response } from 'express';
import { prisma } from '../utils/database';
import { redis } from '../utils/cache';
import { config } from '../config';
import { logger } from '../utils/logger';

/**
 * Basic health check
 */
export const healthCheck = async (req: Request, res: Response): Promise<void> => {
  res.status(200).json({
    status: 'healthy',
    service: config.appName,
    version: config.appVersion,
    environment: config.nodeEnv,
    timestamp: new Date().toISOString(),
  });
};

/**
 * Readiness check - verifies all dependencies
 */
export const readinessCheck = async (req: Request, res: Response): Promise<void> => {
  const checks = {
    database: false,
    redis: false,
  };

  // Check database
  try {
    await prisma.$queryRaw`SELECT 1`;
    checks.database = true;
  } catch (error) {
    logger.error('Database health check failed', { error });
  }

  // Check Redis
  try {
    await redis.ping();
    checks.redis = true;
  } catch (error) {
    logger.error('Redis health check failed', { error });
  }

  const allHealthy = Object.values(checks).every((check) => check);
  const statusCode = allHealthy ? 200 : 503;

  res.status(statusCode).json({
    status: allHealthy ? 'ready' : 'not_ready',
    checks,
    service: config.appName,
    version: config.appVersion,
    timestamp: new Date().toISOString(),
  });
};

/**
 * Liveness check - simple check to verify process is running
 */
export const livenessCheck = async (req: Request, res: Response): Promise<void> => {
  res.status(200).json({
    status: 'alive',
    service: config.appName,
    timestamp: new Date().toISOString(),
  });
};
