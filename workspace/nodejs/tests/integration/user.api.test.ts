/**
 * User API Integration Tests
 */

import request from 'supertest';
import express from 'express';
import { userRouter } from '@/routes/user.routes';
import { prisma } from '@/utils/database';
import { generateToken } from '@/utils/auth';
import { hashPassword } from '@/utils/security';

const app = express();
app.use(express.json());
app.use('/api/users', userRouter);

describe('User API Integration Tests', () => {
  let authToken: string;
  let testUserId: number;

  beforeEach(async () => {
    // Create test user
    const hashedPass = await hashPassword('TestPass123!');
    const testUser = await prisma.user.create({
      data: {
        email: 'test@example.com',
        username: 'testuser',
        hashedPassword: hashedPass,
        isActive: true,
        isSuperuser: false,
        isEmailVerified: true,
      },
    });

    testUserId = testUser.id;

    // Generate auth token
    authToken = generateToken({
      userId: testUser.id,
      email: testUser.email,
      username: testUser.username,
    });
  });

  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const userData = {
        email: 'newuser@example.com',
        username: 'newuser',
        password: 'SecurePass123!',
      };

      const response = await request(app).post('/api/users').send(userData);

      expect(response.status).toBe(201);
      expect(response.body.data).toHaveProperty('id');
      expect(response.body.data.email).toBe(userData.email);
      expect(response.body.data.username).toBe(userData.username);
      expect(response.body.data).not.toHaveProperty('hashedPassword');
    });

    it('should return 400 for invalid email', async () => {
      const userData = {
        email: 'invalid-email',
        username: 'newuser',
        password: 'SecurePass123!',
      };

      const response = await request(app).post('/api/users').send(userData);

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('message', 'Validation failed');
    });

    it('should return 409 for duplicate email', async () => {
      const userData = {
        email: 'test@example.com', // Already exists
        username: 'anotheruser',
        password: 'SecurePass123!',
      };

      const response = await request(app).post('/api/users').send(userData);

      expect(response.status).toBe(409);
    });
  });

  describe('GET /api/users', () => {
    it('should return paginated list of users', async () => {
      const response = await request(app)
        .get('/api/users')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data).toBeInstanceOf(Array);
      expect(response.body).toHaveProperty('pagination');
      expect(response.body.pagination).toHaveProperty('total');
      expect(response.body.pagination).toHaveProperty('page');
      expect(response.body.pagination).toHaveProperty('limit');
    });

    it('should return 401 without authentication', async () => {
      const response = await request(app).get('/api/users');

      expect(response.status).toBe(401);
    });
  });

  describe('GET /api/users/:id', () => {
    it('should return user by id', async () => {
      const response = await request(app)
        .get(`/api/users/${testUserId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.id).toBe(testUserId);
      expect(response.body.data.email).toBe('test@example.com');
    });

    it('should return 404 for non-existent user', async () => {
      const response = await request(app)
        .get('/api/users/99999')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(404);
    });
  });

  describe('PUT /api/users/:id', () => {
    it('should update own user profile', async () => {
      const updateData = {
        username: 'updatedusername',
      };

      const response = await request(app)
        .put(`/api/users/${testUserId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(updateData);

      expect(response.status).toBe(200);
      expect(response.body.data.username).toBe(updateData.username);
    });

    it('should return 403 when updating another user', async () => {
      // Create another user
      const otherUser = await prisma.user.create({
        data: {
          email: 'other@example.com',
          username: 'otheruser',
          hashedPassword: await hashPassword('Pass123!'),
          isActive: true,
        },
      });

      const updateData = { username: 'hacked' };

      const response = await request(app)
        .put(`/api/users/${otherUser.id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(updateData);

      expect(response.status).toBe(403);
    });
  });

  describe('DELETE /api/users/:id', () => {
    it('should return 403 for non-superuser', async () => {
      const response = await request(app)
        .delete(`/api/users/${testUserId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(403);
    });

    it('should delete user as superuser', async () => {
      // Create superuser
      const superuser = await prisma.user.create({
        data: {
          email: 'admin@example.com',
          username: 'admin',
          hashedPassword: await hashPassword('AdminPass123!'),
          isActive: true,
          isSuperuser: true,
        },
      });

      const superuserToken = generateToken({
        userId: superuser.id,
        email: superuser.email,
        username: superuser.username,
      });

      const response = await request(app)
        .delete(`/api/users/${testUserId}`)
        .set('Authorization', `Bearer ${superuserToken}`);

      expect(response.status).toBe(200);

      // Verify user is soft deleted
      const deletedUser = await prisma.user.findUnique({
        where: { id: testUserId },
      });
      expect(deletedUser?.isActive).toBe(false);
    });
  });

  describe('GET /api/users/me', () => {
    it('should return current user profile', async () => {
      const response = await request(app)
        .get('/api/users/me')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.id).toBe(testUserId);
      expect(response.body.data.email).toBe('test@example.com');
    });
  });
});
