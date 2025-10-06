/**
 * Test Setup
 * Global test configuration and utilities
 */

import { PrismaClient } from '@prisma/client';
import { redis } from '@/utils/cache';

// Mock environment variables for testing
process.env.NODE_ENV = 'test';
process.env.PORT = '3001';
process.env.DATABASE_URL = 'postgresql://postgres:postgres@localhost:5432/nexusforge_test';
process.env.REDIS_HOST = 'localhost';
process.env.REDIS_PORT = '6379';
process.env.JWT_SECRET = 'test-secret-key-for-testing-only';
process.env.JWT_EXPIRES_IN = '1h';

const prisma = new PrismaClient();

// Clean up database before each test
beforeEach(async () => {
  // Clear all tables
  await prisma.user.deleteMany({});
});

// Clean up after all tests
afterAll(async () => {
  await prisma.$disconnect();
  await redis.quit();
});
