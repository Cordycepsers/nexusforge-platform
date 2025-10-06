/**
 * Database Utilities
 * Prisma client initialization and management
 */

import { PrismaClient } from '@prisma/client';
import { logger } from './logger';

// Create Prisma client instance
export const prisma = new PrismaClient({
  log: [
    {
      emit: 'event',
      level: 'query',
    },
    {
      emit: 'event',
      level: 'error',
    },
    {
      emit: 'event',
      level: 'warn',
    },
  ],
});

// Log queries in development
if (process.env.NODE_ENV === 'development') {
  prisma.$on('query' as never, (e: any) => {
    logger.debug('Database query', {
      query: e.query,
      duration: `${e.duration}ms`,
    });
  });
}

// Log errors
prisma.$on('error' as never, (e: any) => {
  logger.error('Database error', { error: e.message });
});

// Log warnings
prisma.$on('warn' as never, (e: any) => {
  logger.warn('Database warning', { message: e.message });
});

/**
 * Initialize database connection
 */
export const initializeDatabase = async (): Promise<void> => {
  try {
    await prisma.$connect();
    logger.info('Database connection established');
  } catch (error) {
    logger.error('Failed to connect to database', { error });
    throw error;
  }
};

/**
 * Close database connection
 */
export const closeDatabaseConnection = async (): Promise<void> => {
  try {
    await prisma.$disconnect();
    logger.info('Database connection closed');
  } catch (error) {
    logger.error('Error closing database connection', { error });
    throw error;
  }
};
