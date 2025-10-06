/**
 * Security Utilities
 * Password hashing and verification
 */

import bcrypt from 'bcryptjs';
import { config } from '../config';
import { logger } from './logger';

/**
 * Hash password with bcrypt
 */
export const hashPassword = async (password: string): Promise<string> => {
  try {
    const salt = await bcrypt.genSalt(config.security.bcryptRounds);
    return await bcrypt.hash(password, salt);
  } catch (error) {
    logger.error('Password hashing error', { error });
    throw new Error('Failed to hash password');
  }
};

/**
 * Verify password against hash
 */
export const verifyPassword = async (password: string, hash: string): Promise<boolean> => {
  try {
    return await bcrypt.compare(password, hash);
  } catch (error) {
    logger.error('Password verification error', { error });
    return false;
  }
};
