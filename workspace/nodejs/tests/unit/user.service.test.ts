/**
 * User Service Unit Tests
 */

import { UserService } from '@/services/user.service';
import { prisma } from '@/utils/database';
import { cacheManager } from '@/utils/cache';
import { ConflictError, NotFoundError } from '@/utils/errors';

// Mock dependencies
jest.mock('@/utils/database');
jest.mock('@/utils/cache');

describe('UserService', () => {
  let userService: UserService;

  beforeEach(() => {
    userService = new UserService();
    jest.clearAllMocks();
  });

  describe('createUser', () => {
    it('should create a new user successfully', async () => {
      const userData = {
        email: 'test@example.com',
        username: 'testuser',
        password: 'SecurePass123!',
      };

      const mockUser = {
        id: 1,
        email: userData.email,
        username: userData.username,
        hashedPassword: 'hashed_password',
        isActive: true,
        isSuperuser: false,
        isEmailVerified: false,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastLogin: null,
      };

      (prisma.user.findFirst as jest.Mock).mockResolvedValue(null);
      (prisma.user.create as jest.Mock).mockResolvedValue(mockUser);

      const result = await userService.createUser(userData);

      expect(result).toMatchObject({
        id: 1,
        email: userData.email,
        username: userData.username,
      });
      expect(result).not.toHaveProperty('hashedPassword');
    });

    it('should throw ConflictError if email already exists', async () => {
      const userData = {
        email: 'existing@example.com',
        username: 'testuser',
        password: 'SecurePass123!',
      };

      (prisma.user.findFirst as jest.Mock).mockResolvedValue({ id: 1 });

      await expect(userService.createUser(userData)).rejects.toThrow(ConflictError);
    });
  });

  describe('getUserById', () => {
    it('should return user from cache if available', async () => {
      const mockUser = {
        id: 1,
        email: 'test@example.com',
        username: 'testuser',
        isActive: true,
        isSuperuser: false,
        isEmailVerified: false,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastLogin: null,
      };

      (cacheManager.get as jest.Mock).mockResolvedValue(mockUser);

      const result = await userService.getUserById(1);

      expect(result).toEqual(mockUser);
      expect(prisma.user.findUnique).not.toHaveBeenCalled();
    });

    it('should fetch user from database and cache it', async () => {
      const mockUser = {
        id: 1,
        email: 'test@example.com',
        username: 'testuser',
        hashedPassword: 'hashed_password',
        isActive: true,
        isSuperuser: false,
        isEmailVerified: false,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastLogin: null,
      };

      (cacheManager.get as jest.Mock).mockResolvedValue(null);
      (prisma.user.findUnique as jest.Mock).mockResolvedValue(mockUser);
      (cacheManager.set as jest.Mock).mockResolvedValue(true);

      const result = await userService.getUserById(1);

      expect(result).toMatchObject({
        id: 1,
        email: 'test@example.com',
        username: 'testuser',
      });
      expect(result).not.toHaveProperty('hashedPassword');
      expect(cacheManager.set).toHaveBeenCalled();
    });

    it('should throw NotFoundError if user does not exist', async () => {
      (cacheManager.get as jest.Mock).mockResolvedValue(null);
      (prisma.user.findUnique as jest.Mock).mockResolvedValue(null);

      await expect(userService.getUserById(999)).rejects.toThrow(NotFoundError);
    });
  });

  describe('updateUser', () => {
    it('should update user and invalidate cache', async () => {
      const userId = 1;
      const updateData = {
        username: 'newusername',
      };

      const mockUser = {
        id: userId,
        email: 'test@example.com',
        username: updateData.username,
        hashedPassword: 'hashed_password',
        isActive: true,
        isSuperuser: false,
        isEmailVerified: false,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastLogin: null,
      };

      (prisma.user.findFirst as jest.Mock).mockResolvedValue(null);
      (prisma.user.update as jest.Mock).mockResolvedValue(mockUser);
      (cacheManager.delete as jest.Mock).mockResolvedValue(true);

      const result = await userService.updateUser(userId, updateData);

      expect(result.username).toBe(updateData.username);
      expect(cacheManager.delete).toHaveBeenCalledWith(`user:${userId}`);
    });
  });

  describe('deleteUser', () => {
    it('should soft delete user and invalidate cache', async () => {
      const userId = 1;

      const mockUser = {
        id: userId,
        email: 'test@example.com',
        username: 'testuser',
        hashedPassword: 'hashed_password',
        isActive: false,
        isSuperuser: false,
        isEmailVerified: false,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastLogin: null,
      };

      (prisma.user.update as jest.Mock).mockResolvedValue(mockUser);
      (cacheManager.delete as jest.Mock).mockResolvedValue(true);

      await userService.deleteUser(userId);

      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: userId },
        data: { isActive: false },
      });
      expect(cacheManager.delete).toHaveBeenCalledWith(`user:${userId}`);
    });
  });
});
