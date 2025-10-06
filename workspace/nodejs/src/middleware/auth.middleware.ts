/**
 * Authentication Middleware
 * JWT token validation and user authentication
 */

import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../utils/auth';
import { AppError } from '../utils/errors';
import { prisma } from '../utils/database';
import { User } from '@prisma/client';

// Extend Express Request to include user
declare global {
  namespace Express {
    interface Request {
      user?: User;
    }
  }
}

/**
 * Authenticate user from JWT token
 */
export const authenticate = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AppError('No token provided', 401);
    }

    const token = authHeader.substring(7);

    // Verify token
    const decoded = verifyToken(token);

    if (!decoded || !decoded.userId) {
      throw new AppError('Invalid token', 401);
    }

    // Get user from database
    const user = await prisma.user.findFirst({
      where: {
        id: decoded.userId,
        deletedAt: null,
      },
    });

    if (!user) {
      throw new AppError('User not found', 401);
    }

    if (!user.isActive) {
      throw new AppError('User account is inactive', 403);
    }

    // Attach user to request
    req.user = user;

    next();
  } catch (error) {
    if (error instanceof AppError) {
      next(error);
    } else {
      next(new AppError('Authentication failed', 401));
    }
  }
};

/**
 * Require superuser role
 */
export const requireSuperuser = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      throw new AppError('Not authenticated', 401);
    }

    if (!req.user.isSuperuser) {
      throw new AppError('Superuser access required', 403);
    }

    next();
  } catch (error) {
    next(error);
  }
};
