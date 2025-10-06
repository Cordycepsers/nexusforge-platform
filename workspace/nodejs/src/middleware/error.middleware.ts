/**
 * Error Handling Middleware
 * Global error handler for Express
 */

import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';
import { config } from '../config';

/**
 * Global error handler
 */
export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Log error
  logger.error('Request error', {
    error: error.message,
    stack: error.stack,
    path: req.path,
    method: req.method,
  });

  // Handle AppError
  if (error instanceof AppError) {
    res.status(error.statusCode).json({
      error: error.message,
      details: error.details,
      path: req.path,
    });
    return;
  }

  // Handle unknown errors
  const statusCode = 500;
  const message = config.nodeEnv === 'production' ? 'Internal server error' : error.message;

  res.status(statusCode).json({
    error: message,
    path: req.path,
  });
};

/**
 * 404 Not Found handler
 */
export const notFoundHandler = (req: Request, res: Response): void => {
  res.status(404).json({
    error: 'Not found',
    message: `Route ${req.method} ${req.path} not found`,
    path: req.path,
  });
};
