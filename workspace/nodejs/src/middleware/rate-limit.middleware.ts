/**
 * Rate Limiting Middleware
 * Prevent abuse with rate limiting
 */

import rateLimit from 'express-rate-limit';
import { config } from '../config';

/**
 * Rate limiter configuration
 */
export const rateLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
  message: {
    error: 'Too many requests',
    message: `You have exceeded the ${config.rateLimit.maxRequests} requests in ${config.rateLimit.windowMs / 1000} seconds limit!`,
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  skip: (req) => {
    // Skip rate limiting for health checks
    return req.path.startsWith('/health');
  },
});
