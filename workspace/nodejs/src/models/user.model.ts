/**
 * User Model
 * Prisma client extensions and type definitions
 */

import { Prisma, User as PrismaUser } from '@prisma/client';

// Export Prisma User type
export type User = PrismaUser;

// User creation input (without system fields)
export type UserCreateInput = Omit<
  Prisma.UserCreateInput,
  'id' | 'createdAt' | 'updatedAt' | 'deletedAt'
>;

// User update input
export type UserUpdateInput = Partial<
  Omit<Prisma.UserUpdateInput, 'id' | 'createdAt' | 'updatedAt' | 'deletedAt'>
>;

// User response (safe - without password)
export type UserResponse = Omit<User, 'hashedPassword'>;

// Convert User to UserResponse
export const toUserResponse = (user: User): UserResponse => {
  const { hashedPassword, ...userResponse } = user;
  return userResponse;
};

// User filter options
export interface UserFilterOptions {
  isActive?: boolean;
  isVerified?: boolean;
  skip?: number;
  take?: number;
}

// Validation helpers
export const isValidEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

export const isValidUsername = (username: string): boolean => {
  const usernameRegex = /^[a-z0-9_]{3,30}$/;
  return usernameRegex.test(username);
};

export const isValidPassword = (password: string): boolean => {
  // At least 8 chars, 1 uppercase, 1 lowercase, 1 digit
  const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
  return passwordRegex.test(password);
};
