/**
 * User Service
 * Business logic for user management
 */

import { User } from '@prisma/client';
import { prisma } from '../utils/database';
import { hashPassword } from '../utils/security';
import { cacheManager } from '../utils/cache';
import { AppError } from '../utils/errors';
import { logger } from '../utils/logger';
import { CreateUserDTO, UpdateUserDTO, UserQueryDTO } from '../dto/user.dto';

export class UserService {
  /**
   * Create new user
   */
  async createUser(userData: CreateUserDTO): Promise<User> {
    // Check if email exists
    const existingEmail = await this.getUserByEmail(userData.email);
    if (existingEmail) {
      throw new AppError(`Email '${userData.email}' is already registered`, 400);
    }

    // Check if username exists
    const existingUsername = await this.getUserByUsername(userData.username);
    if (existingUsername) {
      throw new AppError(`Username '${userData.username}' is already taken`, 400);
    }

    // Hash password
    const hashedPassword = await hashPassword(userData.password);

    // Create user
    const user = await prisma.user.create({
      data: {
        email: userData.email.toLowerCase(),
        username: userData.username.toLowerCase(),
        hashedPassword,
        fullName: userData.fullName,
        isActive: true,
        isVerified: false,
        isSuperuser: false,
      },
    });

    logger.info('User created', { userId: user.id, username: user.username });

    return user;
  }

  /**
   * Get user by ID
   */
  async getUserById(userId: number): Promise<User | null> {
    // Try cache first
    const cacheKey = `user:${userId}`;
    const cached = await cacheManager.get<User>(cacheKey);

    if (cached) {
      logger.debug('User found in cache', { userId });
      return cached;
    }

    // Query database
    const user = await prisma.user.findFirst({
      where: {
        id: userId,
        deletedAt: null,
      },
    });

    // Cache result
    if (user) {
      await cacheManager.set(cacheKey, user, 300); // 5 minutes
    }

    return user;
  }

  /**
   * Get user by email
   */
  async getUserByEmail(email: string): Promise<User | null> {
    return prisma.user.findFirst({
      where: {
        email: email.toLowerCase(),
        deletedAt: null,
      },
    });
  }

  /**
   * Get user by username
   */
  async getUserByUsername(username: string): Promise<User | null> {
    return prisma.user.findFirst({
      where: {
        username: username.toLowerCase(),
        deletedAt: null,
      },
    });
  }

  /**
   * Get paginated list of users
   */
  async getUsers(query: UserQueryDTO): Promise<{ users: User[]; total: number }> {
    const where: any = {
      deletedAt: null,
    };

    if (query.isActive !== undefined) {
      where.isActive = query.isActive;
    }

    // Get total count
    const total = await prisma.user.count({ where });

    // Get users with pagination
    const users = await prisma.user.findMany({
      where,
      skip: query.skip,
      take: query.take,
      orderBy: {
        createdAt: 'desc',
      },
    });

    return { users, total };
  }

  /**
   * Update user
   */
  async updateUser(userId: number, updateData: UpdateUserDTO): Promise<User | null> {
    const user = await this.getUserById(userId);
    if (!user) {
      return null;
    }

    // Check email uniqueness
    if (updateData.email && updateData.email !== user.email) {
      const existingEmail = await this.getUserByEmail(updateData.email);
      if (existingEmail) {
        throw new AppError(`Email '${updateData.email}' is already registered`, 400);
      }
    }

    // Check username uniqueness
    if (updateData.username && updateData.username !== user.username) {
      const existingUsername = await this.getUserByUsername(updateData.username);
      if (existingUsername) {
        throw new AppError(`Username '${updateData.username}' is already taken`, 400);
      }
    }

    // Prepare update data
    const data: any = {};

    if (updateData.email) data.email = updateData.email.toLowerCase();
    if (updateData.username) data.username = updateData.username.toLowerCase();
    if (updateData.fullName !== undefined) data.fullName = updateData.fullName;
    if (updateData.password) data.hashedPassword = await hashPassword(updateData.password);
    if (updateData.isActive !== undefined) data.isActive = updateData.isActive;

    // Update user
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data,
    });

    // Invalidate cache
    await cacheManager.delete(`user:${userId}`);

    logger.info('User updated', { userId, username: updatedUser.username });

    return updatedUser;
  }

  /**
   * Delete user (soft delete)
   */
  async deleteUser(userId: number): Promise<boolean> {
    const user = await this.getUserById(userId);
    if (!user) {
      return false;
    }

    // Soft delete
    await prisma.user.update({
      where: { id: userId },
      data: {
        deletedAt: new Date(),
        isActive: false,
      },
    });

    // Invalidate cache
    await cacheManager.delete(`user:${userId}`);

    logger.info('User deleted', { userId, username: user.username });

    return true;
  }

  /**
   * Verify user email
   */
  async verifyUserEmail(userId: number): Promise<User | null> {
    const user = await this.getUserById(userId);
    if (!user) {
      return null;
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        isVerified: true,
        emailVerifiedAt: new Date(),
      },
    });

    // Invalidate cache
    await cacheManager.delete(`user:${userId}`);

    logger.info('User email verified', { userId, username: updatedUser.username });

    return updatedUser;
  }

  /**
   * Update last login timestamp
   */
  async updateLastLogin(userId: number): Promise<void> {
    await prisma.user.update({
      where: { id: userId },
      data: {
        lastLoginAt: new Date(),
      },
    });

    // Invalidate cache
    await cacheManager.delete(`user:${userId}`);
  }
}
