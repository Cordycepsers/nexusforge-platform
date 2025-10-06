/**
 * Authentication Utilities
 * JWT token generation and verification
 */

import jwt from 'jsonwebtoken';
import { config } from '../config';
import { logger } from './logger';

/**
 * JWT token payload
 */
export interface TokenPayload {
  userId: number;
  email: string;
  username: string;
}

/**
 * Generate JWT access token
 */
export const generateToken = (payload: TokenPayload): string => {
  try {
    return jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
    });
  } catch (error) {
    logger.error('Token generation error', { error });
    throw new Error('Failed to generate token');
  }
};

/**
 * Generate JWT refresh token
 */
export const generateRefreshToken = (payload: TokenPayload): string => {
  try {
    return jwt.sign(payload, config.jwt.secret, {
      expiresIn: config.jwt.refreshExpiresIn,
    });
  } catch (error) {
    logger.error('Refresh token generation error', { error });
    throw new Error('Failed to generate refresh token');
  }
};

/**
 * Verify JWT token
 */
export const verifyToken = (token: string): TokenPayload | null => {
  try {
    const decoded = jwt.verify(token, config.jwt.secret) as TokenPayload;
    return decoded;
  } catch (error) {
    logger.warn('Token verification failed', { error });
    return null;
  }
};

/**
 * Decode token without verification (for debugging)
 */
export const decodeToken = (token: string): any => {
  try {
    return jwt.decode(token);
  } catch (error) {
    logger.error('Token decode error', { error });
    return null;
  }
};
