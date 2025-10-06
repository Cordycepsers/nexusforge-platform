/**
 * Health Controller Tests
 */

import request from 'supertest';
import express from 'express';
import { healthRouter } from '@/routes/health.routes';
import { prisma } from '@/utils/database';
import { redis } from '@/utils/cache';

const app = express();
app.use('/health', healthRouter);

describe('Health Controller', () => {
  describe('GET /health', () => {
    it('should return 200 and health status', async () => {
      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('service', 'nexusforge-nodejs-api');
      expect(response.body).toHaveProperty('version');
    });
  });

  describe('GET /health/ready', () => {
    it('should return 200 when all services are available', async () => {
      const response = await request(app).get('/health/ready');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'ready');
      expect(response.body.checks.database).toBe('up');
      expect(response.body.checks.redis).toBe('up');
    });

    it('should return 503 when database is unavailable', async () => {
      // Mock database failure
      jest.spyOn(prisma, '$queryRaw').mockRejectedValueOnce(new Error('DB error'));

      const response = await request(app).get('/health/ready');

      expect(response.status).toBe(503);
      expect(response.body.checks.database).toBe('down');
    });
  });

  describe('GET /health/live', () => {
    it('should return 200 and alive status', async () => {
      const response = await request(app).get('/health/live');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'alive');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
    });
  });
});
