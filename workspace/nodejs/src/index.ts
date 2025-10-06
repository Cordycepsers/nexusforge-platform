/**
 * NexusForge Platform - Node.js Service
 * Main application entry point with Express server
 */

import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/error.middleware';
import { requestLogger } from './middleware/logger.middleware';
import { rateLimiter } from './middleware/rate-limit.middleware';
import healthRouter from './routes/health.routes';
import userRouter from './routes/user.routes';
import { initializeDatabase, closeDatabaseConnection } from './utils/database';
import { initializeRedis, closeRedisConnection } from './utils/cache';
import { metricsMiddleware, metricsEndpoint } from './utils/metrics';

/**
 * Create Express application
 */
const createApp = (): Application => {
  const app = express();

  // Security middleware
  app.use(helmet());

  // CORS configuration
  app.use(
    cors({
      origin: config.security.corsOrigins,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    })
  );

  // Body parsing middleware
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Compression middleware
  app.use(compression());

  // Request logging
  app.use(requestLogger);

  // Metrics collection
  if (config.monitoring.enableMetrics) {
    app.use(metricsMiddleware);
  }

  // Rate limiting
  app.use(rateLimiter);

  // Health check routes (no rate limiting)
  app.use('/health', healthRouter);

  // API routes
  app.use('/api/v1/users', userRouter);

  // Root endpoint
  app.get('/', (req, res) => {
    res.json({
      service: config.appName,
      version: config.appVersion,
      environment: config.nodeEnv,
      status: 'running',
      endpoints: {
        health: '/health',
        metrics: config.monitoring.enableMetrics ? '/metrics' : 'disabled',
        api: '/api/v1',
      },
    });
  });

  // Metrics endpoint
  if (config.monitoring.enableMetrics) {
    app.get('/metrics', metricsEndpoint);
  }

  // Error handling middleware (must be last)
  app.use(errorHandler);

  return app;
};

/**
 * Start the server
 */
const startServer = async (): Promise<void> => {
  try {
    logger.info('Starting NexusForge Node.js Service', {
      environment: config.nodeEnv,
      version: config.appVersion,
    });

    // Initialize database
    await initializeDatabase();
    logger.info('Database connection established');

    // Initialize Redis
    await initializeRedis();
    logger.info('Redis connection established');

    // Create Express app
    const app = createApp();

    // Start server
    const server = app.listen(config.port, () => {
      logger.info(`Server started on port ${config.port}`, {
        port: config.port,
        environment: config.nodeEnv,
      });
    });

    // Graceful shutdown
    const shutdown = async (signal: string) => {
      logger.info(`${signal} received, starting graceful shutdown`);

      server.close(async () => {
        logger.info('HTTP server closed');

        // Close database connection
        await closeDatabaseConnection();
        logger.info('Database connection closed');

        // Close Redis connection
        await closeRedisConnection();
        logger.info('Redis connection closed');

        logger.info('Graceful shutdown complete');
        process.exit(0);
      });

      // Force shutdown after 10 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 10000);
    };

    // Handle shutdown signals
    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    // Handle uncaught errors
    process.on('uncaughtException', (error: Error) => {
      logger.error('Uncaught exception', { error: error.message, stack: error.stack });
      process.exit(1);
    });

    process.on('unhandledRejection', (reason: unknown) => {
      logger.error('Unhandled rejection', { reason });
      process.exit(1);
    });
  } catch (error) {
    logger.error('Failed to start server', { error });
    process.exit(1);
  }
};

// Start server if running directly
if (require.main === module) {
  startServer();
}

export { createApp, startServer };
