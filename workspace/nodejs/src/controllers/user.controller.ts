/**
 * User Controller
 * HTTP request handlers for user management
 */

import { Request, Response, NextFunction } from 'express';
import { UserService } from '../services/user.service';
import { CreateUserDTO, UpdateUserDTO, UserQueryDTO } from '../dto/user.dto';
import { AppError } from '../utils/errors';
import { logger } from '../utils/logger';
import { toUserResponse } from '../models/user.model';

const userService = new UserService();

/**
 * Create new user
 */
export const createUser = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userData: CreateUserDTO = req.body;

    const user = await userService.createUser(userData);

    logger.info('User created', { userId: user.id, username: user.username });

    res.status(201).json(toUserResponse(user));
  } catch (error) {
    next(error);
  }
};

/**
 * Get paginated list of users
 */
export const listUsers = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const query: UserQueryDTO = {
      skip: parseInt(req.query.skip as string) || 0,
      take: parseInt(req.query.take as string) || 100,
      isActive: req.query.isActive === 'true' ? true : req.query.isActive === 'false' ? false : undefined,
    };

    const { users, total } = await userService.getUsers(query);

    res.status(200).json({
      users: users.map(toUserResponse),
      total,
      skip: query.skip,
      limit: query.take,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get user by ID
 */
export const getUserById = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = parseInt(req.params.id);

    if (isNaN(userId)) {
      throw new AppError('Invalid user ID', 400);
    }

    const user = await userService.getUserById(userId);

    if (!user) {
      throw new AppError(`User with ID ${userId} not found`, 404);
    }

    res.status(200).json(toUserResponse(user));
  } catch (error) {
    next(error);
  }
};

/**
 * Update user
 */
export const updateUser = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = parseInt(req.params.id);
    const updateData: UpdateUserDTO = req.body;

    if (isNaN(userId)) {
      throw new AppError('Invalid user ID', 400);
    }

    // Check authorization (user can only update their own account or be superuser)
    const currentUser = req.user;
    if (currentUser && currentUser.id !== userId && !currentUser.isSuperuser) {
      throw new AppError('Not authorized to update this user', 403);
    }

    const user = await userService.updateUser(userId, updateData);

    if (!user) {
      throw new AppError(`User with ID ${userId} not found`, 404);
    }

    logger.info('User updated', { userId: user.id, username: user.username });

    res.status(200).json(toUserResponse(user));
  } catch (error) {
    next(error);
  }
};

/**
 * Delete user (soft delete)
 */
export const deleteUser = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = parseInt(req.params.id);

    if (isNaN(userId)) {
      throw new AppError('Invalid user ID', 400);
    }

    // Only superusers can delete users
    const currentUser = req.user;
    if (!currentUser || !currentUser.isSuperuser) {
      throw new AppError('Only superusers can delete users', 403);
    }

    const success = await userService.deleteUser(userId);

    if (!success) {
      throw new AppError(`User with ID ${userId} not found`, 404);
    }

    logger.info('User deleted', { userId });

    res.status(204).send();
  } catch (error) {
    next(error);
  }
};

/**
 * Get current authenticated user
 */
export const getCurrentUser = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const currentUser = req.user;

    if (!currentUser) {
      throw new AppError('Not authenticated', 401);
    }

    res.status(200).json(toUserResponse(currentUser));
  } catch (error) {
    next(error);
  }
};
