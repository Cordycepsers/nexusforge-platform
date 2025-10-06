/**
 * User Routes
 */

import { Router } from 'express';
import {
  createUser,
  listUsers,
  getUserById,
  updateUser,
  deleteUser,
  getCurrentUser,
} from '../controllers/user.controller';
import { authenticate } from '../middleware/auth.middleware';
import { validate } from '../middleware/validation.middleware';
import { createUserSchema, updateUserSchema } from '../dto/user.dto';

const router = Router();

/**
 * @route POST /api/v1/users
 * @desc Create new user
 * @access Public
 */
router.post('/', validate(createUserSchema), createUser);

/**
 * @route GET /api/v1/users
 * @desc Get paginated list of users
 * @access Private
 */
router.get('/', authenticate, listUsers);

/**
 * @route GET /api/v1/users/me
 * @desc Get current authenticated user
 * @access Private
 */
router.get('/me', authenticate, getCurrentUser);

/**
 * @route GET /api/v1/users/:id
 * @desc Get user by ID
 * @access Private
 */
router.get('/:id', authenticate, getUserById);

/**
 * @route PUT /api/v1/users/:id
 * @desc Update user
 * @access Private
 */
router.put('/:id', authenticate, validate(updateUserSchema), updateUser);

/**
 * @route DELETE /api/v1/users/:id
 * @desc Delete user (soft delete)
 * @access Private (Superuser only)
 */
router.delete('/:id', authenticate, deleteUser);

export default router;
