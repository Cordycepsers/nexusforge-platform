/**
 * Redis Cache Utilities
 * Redis client and caching functionality
 */

import Redis from 'ioredis';
import { config } from '../config';
import { logger } from './logger';

// Create Redis client
export const redis = new Redis({
  host: config.redis.host,
  port: config.redis.port,
  password: config.redis.password,
  db: config.redis.db,
  retryStrategy: (times: number) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  maxRetriesPerRequest: 3,
});

// Redis event handlers
redis.on('connect', () => {
  logger.info('Redis connection established');
});

redis.on('error', (error) => {
  logger.error('Redis error', { error: error.message });
});

redis.on('close', () => {
  logger.info('Redis connection closed');
});

/**
 * Cache Manager
 */
export class CacheManager {
  private client: Redis;

  constructor(client: Redis) {
    this.client = client;
  }

  /**
   * Get value from cache
   */
  async get<T>(key: string): Promise<T | null> {
    if (!config.features.enableCache) {
      return null;
    }

    try {
      const value = await this.client.get(key);
      if (!value) {
        return null;
      }

      return JSON.parse(value) as T;
    } catch (error) {
      logger.error('Cache get error', { key, error });
      return null;
    }
  }

  /**
   * Set value in cache
   */
  async set(key: string, value: any, ttl?: number): Promise<boolean> {
    if (!config.features.enableCache) {
      return false;
    }

    try {
      const serialized = JSON.stringify(value);

      if (ttl) {
        await this.client.setex(key, ttl, serialized);
      } else {
        await this.client.set(key, serialized);
      }

      return true;
    } catch (error) {
      logger.error('Cache set error', { key, error });
      return false;
    }
  }

  /**
   * Delete key from cache
   */
  async delete(key: string): Promise<boolean> {
    if (!config.features.enableCache) {
      return false;
    }

    try {
      const result = await this.client.del(key);
      return result > 0;
    } catch (error) {
      logger.error('Cache delete error', { key, error });
      return false;
    }
  }

  /**
   * Check if key exists
   */
  async exists(key: string): Promise<boolean> {
    if (!config.features.enableCache) {
      return false;
    }

    try {
      const result = await this.client.exists(key);
      return result === 1;
    } catch (error) {
      logger.error('Cache exists error', { key, error });
      return false;
    }
  }

  /**
   * Delete keys by pattern
   */
  async deletePattern(pattern: string): Promise<number> {
    if (!config.features.enableCache) {
      return 0;
    }

    try {
      const keys = await this.client.keys(pattern);
      if (keys.length === 0) {
        return 0;
      }

      const result = await this.client.del(...keys);
      return result;
    } catch (error) {
      logger.error('Cache delete pattern error', { pattern, error });
      return 0;
    }
  }

  /**
   * Increment counter
   */
  async increment(key: string, amount: number = 1): Promise<number> {
    try {
      return await this.client.incrby(key, amount);
    } catch (error) {
      logger.error('Cache increment error', { key, error });
      return 0;
    }
  }

  /**
   * Set expiration on key
   */
  async expire(key: string, ttl: number): Promise<boolean> {
    try {
      const result = await this.client.expire(key, ttl);
      return result === 1;
    } catch (error) {
      logger.error('Cache expire error', { key, error });
      return false;
    }
  }
}

// Export cache manager instance
export const cacheManager = new CacheManager(redis);

/**
 * Initialize Redis connection
 */
export const initializeRedis = async (): Promise<void> => {
  try {
    await redis.ping();
    logger.info('Redis connection verified');
  } catch (error) {
    logger.error('Failed to connect to Redis', { error });
    throw error;
  }
};

/**
 * Close Redis connection
 */
export const closeRedisConnection = async (): Promise<void> => {
  try {
    await redis.quit();
    logger.info('Redis connection closed');
  } catch (error) {
    logger.error('Error closing Redis connection', { error });
    throw error;
  }
};
