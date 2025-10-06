/**
 * Configuration Management
 * Environment-based configuration with validation
 */

import { z } from 'zod';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Configuration schema with Zod validation
const configSchema = z.object({
  // Application
  nodeEnv: z.enum(['development', 'staging', 'production']).default('development'),
  appName: z.string().default('NexusForge Node.js Service'),
  appVersion: z.string().default('1.0.0'),
  port: z.coerce.number().int().positive().default(3000),

  // Database
  databaseUrl: z.string().url(),

  // Redis
  redis: z.object({
    host: z.string().default('localhost'),
    port: z.coerce.number().int().positive().default(6379),
    password: z.string().optional(),
    db: z.coerce.number().int().nonnegative().default(0),
  }),

  // JWT
  jwt: z.object({
    secret: z.string().min(32),
    expiresIn: z.string().default('30m'),
    refreshExpiresIn: z.string().default('7d'),
  }),

  // Security
  security: z.object({
    corsOrigins: z.string().transform((val) => val.split(',')),
    allowedHosts: z.string().transform((val) => val.split(',')),
    bcryptRounds: z.coerce.number().int().positive().default(10),
  }),

  // Rate Limiting
  rateLimit: z.object({
    windowMs: z.coerce.number().int().positive().default(60000),
    maxRequests: z.coerce.number().int().positive().default(100),
  }),

  // Logging
  logging: z.object({
    level: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
    format: z.enum(['json', 'simple']).default('json'),
  }),

  // Monitoring
  monitoring: z.object({
    enableMetrics: z.coerce.boolean().default(true),
    metricsPort: z.coerce.number().int().positive().default(3000),
  }),

  // Feature Flags
  features: z.object({
    enableCache: z.coerce.boolean().default(true),
    enableSwagger: z.coerce.boolean().default(true),
  }),

  // External Services
  external: z.object({
    apiUrl: z.string().url().optional(),
    apiKey: z.string().optional(),
  }),

  // GCP
  gcp: z.object({
    projectId: z.string().optional(),
    bucketName: z.string().optional(),
    credentialsPath: z.string().optional(),
  }),
});

// Parse and validate configuration
const parseConfig = () => {
  const rawConfig = {
    nodeEnv: process.env.NODE_ENV,
    appName: process.env.APP_NAME,
    appVersion: process.env.APP_VERSION,
    port: process.env.PORT,

    databaseUrl: process.env.DATABASE_URL,

    redis: {
      host: process.env.REDIS_HOST,
      port: process.env.REDIS_PORT,
      password: process.env.REDIS_PASSWORD,
      db: process.env.REDIS_DB,
    },

    jwt: {
      secret: process.env.JWT_SECRET,
      expiresIn: process.env.JWT_EXPIRES_IN,
      refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN,
    },

    security: {
      corsOrigins: process.env.CORS_ORIGINS || 'http://localhost:3000',
      allowedHosts: process.env.ALLOWED_HOSTS || 'localhost',
      bcryptRounds: process.env.BCRYPT_ROUNDS,
    },

    rateLimit: {
      windowMs: process.env.RATE_LIMIT_WINDOW_MS,
      maxRequests: process.env.RATE_LIMIT_MAX_REQUESTS,
    },

    logging: {
      level: process.env.LOG_LEVEL,
      format: process.env.LOG_FORMAT,
    },

    monitoring: {
      enableMetrics: process.env.ENABLE_METRICS,
      metricsPort: process.env.METRICS_PORT,
    },

    features: {
      enableCache: process.env.ENABLE_CACHE,
      enableSwagger: process.env.ENABLE_SWAGGER,
    },

    external: {
      apiUrl: process.env.EXTERNAL_API_URL,
      apiKey: process.env.EXTERNAL_API_KEY,
    },

    gcp: {
      projectId: process.env.GCP_PROJECT_ID,
      bucketName: process.env.GCP_BUCKET_NAME,
      credentialsPath: process.env.GCP_CREDENTIALS_PATH,
    },
  };

  try {
    return configSchema.parse(rawConfig);
  } catch (error) {
    if (error instanceof z.ZodError) {
      const errorMessages = error.errors.map((err) => `${err.path.join('.')}: ${err.message}`);
      throw new Error(`Configuration validation failed:\n${errorMessages.join('\n')}`);
    }
    throw error;
  }
};

// Export validated configuration
export const config = parseConfig();

// Helper functions
export const isProduction = () => config.nodeEnv === 'production';
export const isDevelopment = () => config.nodeEnv === 'development';
export const isStaging = () => config.nodeEnv === 'staging';

// Type export
export type Config = z.infer<typeof configSchema>;
