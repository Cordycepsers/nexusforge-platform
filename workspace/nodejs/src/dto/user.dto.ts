/**
 * Data Transfer Objects (DTOs)
 * Request/response validation schemas using Zod
 */

import { z } from 'zod';

/**
 * User creation DTO
 */
export const createUserSchema = z.object({
  email: z.string().email('Invalid email address'),
  username: z
    .string()
    .min(3, 'Username must be at least 3 characters')
    .max(30, 'Username must not exceed 30 characters')
    .regex(/^[a-z0-9_]+$/, 'Username can only contain lowercase letters, numbers, and underscores'),
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
    .regex(/[0-9]/, 'Password must contain at least one digit'),
  fullName: z.string().max(255).optional(),
});

export type CreateUserDTO = z.infer<typeof createUserSchema>;

/**
 * User update DTO
 */
export const updateUserSchema = z.object({
  email: z.string().email('Invalid email address').optional(),
  username: z
    .string()
    .min(3, 'Username must be at least 3 characters')
    .max(30, 'Username must not exceed 30 characters')
    .regex(/^[a-z0-9_]+$/, 'Username can only contain lowercase letters, numbers, and underscores')
    .optional(),
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
    .regex(/[0-9]/, 'Password must contain at least one digit')
    .optional(),
  fullName: z.string().max(255).optional(),
  isActive: z.boolean().optional(),
});

export type UpdateUserDTO = z.infer<typeof updateUserSchema>;

/**
 * User query DTO
 */
export const userQuerySchema = z.object({
  skip: z.number().int().nonnegative().default(0),
  take: z.number().int().positive().max(1000).default(100),
  isActive: z.boolean().optional(),
});

export type UserQueryDTO = z.infer<typeof userQuerySchema>;

/**
 * Login DTO
 */
export const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
});

export type LoginDTO = z.infer<typeof loginSchema>;
