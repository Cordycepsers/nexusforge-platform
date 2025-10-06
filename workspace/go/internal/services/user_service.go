/**
 * User Service
 * Business logic layer for user operations
 */

package services

import (
	"errors"
	"fmt"
	"time"

	"github.com/nexusforge/api/internal/models"
	"github.com/nexusforge/api/internal/repository"
	"github.com/nexusforge/api/pkg/cache"
	"github.com/nexusforge/api/pkg/logger"
	"github.com/nexusforge/api/pkg/security"
)

// UserService handles user business logic
type UserService interface {
	CreateUser(req *models.CreateUserRequest) (*models.UserResponse, error)
	GetUserByID(id uint) (*models.UserResponse, error)
	GetUserByEmail(email string) (*models.User, error)
	GetUserByUsername(username string) (*models.User, error)
	ListUsers(page, limit int) ([]*models.UserResponse, int64, error)
	UpdateUser(id uint, req *models.UpdateUserRequest) (*models.UserResponse, error)
	DeleteUser(id uint) error
	VerifyUserEmail(id uint) error
	UpdateLastLogin(id uint) error
}

type userService struct {
	repo  repository.UserRepository
	cache cache.CacheManager
	log   logger.Logger
}

// NewUserService creates a new user service
func NewUserService(repo repository.UserRepository, cache cache.CacheManager, log logger.Logger) UserService {
	return &userService{
		repo:  repo,
		cache: cache,
		log:   log,
	}
}

// CreateUser creates a new user
func (s *userService) CreateUser(req *models.CreateUserRequest) (*models.UserResponse, error) {
	// Check if email already exists
	existingUser, err := s.repo.FindByEmail(req.Email)
	if err != nil {
		s.log.Error("Error checking email uniqueness", "error", err)
		return nil, errors.New("failed to check email uniqueness")
	}
	if existingUser != nil {
		return nil, errors.New("email already registered")
	}

	// Check if username already exists
	existingUser, err = s.repo.FindByUsername(req.Username)
	if err != nil {
		s.log.Error("Error checking username uniqueness", "error", err)
		return nil, errors.New("failed to check username uniqueness")
	}
	if existingUser != nil {
		return nil, errors.New("username already taken")
	}

	// Hash password
	hashedPassword, err := security.HashPassword(req.Password)
	if err != nil {
		s.log.Error("Error hashing password", "error", err)
		return nil, errors.New("failed to hash password")
	}

	// Create user
	user := &models.User{
		Email:          req.Email,
		Username:       req.Username,
		HashedPassword: hashedPassword,
		IsActive:       true,
		IsSuperuser:    false,
		IsEmailVerified: false,
	}

	if err := s.repo.Create(user); err != nil {
		s.log.Error("Error creating user", "error", err)
		return nil, errors.New("failed to create user")
	}

	s.log.Info("User created successfully", "userId", user.ID, "email", user.Email)

	return user.ToResponse(), nil
}

// GetUserByID retrieves a user by ID with caching
func (s *userService) GetUserByID(id uint) (*models.UserResponse, error) {
	cacheKey := fmt.Sprintf("user:%d", id)

	// Try to get from cache
	var cachedUser models.UserResponse
	if err := s.cache.Get(cacheKey, &cachedUser); err == nil {
		s.log.Debug("User retrieved from cache", "userId", id)
		return &cachedUser, nil
	}

	// Get from database
	user, err := s.repo.FindByID(id)
	if err != nil {
		return nil, err
	}

	userResponse := user.ToResponse()

	// Cache the result
	if err := s.cache.Set(cacheKey, userResponse, 5*time.Minute); err != nil {
		s.log.Warn("Failed to cache user", "userId", id, "error", err)
	}

	return userResponse, nil
}

// GetUserByEmail retrieves a user by email
func (s *userService) GetUserByEmail(email string) (*models.User, error) {
	return s.repo.FindByEmail(email)
}

// GetUserByUsername retrieves a user by username
func (s *userService) GetUserByUsername(username string) (*models.User, error) {
	return s.repo.FindByUsername(username)
}

// ListUsers returns a paginated list of users
func (s *userService) ListUsers(page, limit int) ([]*models.UserResponse, int64, error) {
	// Set defaults
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 10
	}

	users, total, err := s.repo.List(page, limit)
	if err != nil {
		s.log.Error("Error listing users", "error", err)
		return nil, 0, errors.New("failed to list users")
	}

	// Convert to response format
	responses := make([]*models.UserResponse, len(users))
	for i, user := range users {
		responses[i] = user.ToResponse()
	}

	return responses, total, nil
}

// UpdateUser updates a user
func (s *userService) UpdateUser(id uint, req *models.UpdateUserRequest) (*models.UserResponse, error) {
	// Get existing user
	user, err := s.repo.FindByID(id)
	if err != nil {
		return nil, err
	}

	// Check email uniqueness if updating email
	if req.Email != nil && *req.Email != user.Email {
		existingUser, err := s.repo.FindByEmail(*req.Email)
		if err != nil {
			s.log.Error("Error checking email uniqueness", "error", err)
			return nil, errors.New("failed to check email uniqueness")
		}
		if existingUser != nil {
			return nil, errors.New("email already registered")
		}
		user.Email = *req.Email
	}

	// Check username uniqueness if updating username
	if req.Username != nil && *req.Username != user.Username {
		existingUser, err := s.repo.FindByUsername(*req.Username)
		if err != nil {
			s.log.Error("Error checking username uniqueness", "error", err)
			return nil, errors.New("failed to check username uniqueness")
		}
		if existingUser != nil {
			return nil, errors.New("username already taken")
		}
		user.Username = *req.Username
	}

	// Update password if provided
	if req.Password != nil {
		hashedPassword, err := security.HashPassword(*req.Password)
		if err != nil {
			s.log.Error("Error hashing password", "error", err)
			return nil, errors.New("failed to hash password")
		}
		user.HashedPassword = hashedPassword
	}

	// Update user
	if err := s.repo.Update(user); err != nil {
		s.log.Error("Error updating user", "error", err)
		return nil, errors.New("failed to update user")
	}

	// Invalidate cache
	cacheKey := fmt.Sprintf("user:%d", id)
	if err := s.cache.Delete(cacheKey); err != nil {
		s.log.Warn("Failed to invalidate cache", "userId", id, "error", err)
	}

	s.log.Info("User updated successfully", "userId", id)

	return user.ToResponse(), nil
}

// DeleteUser soft deletes a user
func (s *userService) DeleteUser(id uint) error {
	if err := s.repo.Delete(id); err != nil {
		s.log.Error("Error deleting user", "error", err)
		return errors.New("failed to delete user")
	}

	// Invalidate cache
	cacheKey := fmt.Sprintf("user:%d", id)
	if err := s.cache.Delete(cacheKey); err != nil {
		s.log.Warn("Failed to invalidate cache", "userId", id, "error", err)
	}

	s.log.Info("User deleted successfully", "userId", id)

	return nil
}

// VerifyUserEmail marks a user's email as verified
func (s *userService) VerifyUserEmail(id uint) error {
	user, err := s.repo.FindByID(id)
	if err != nil {
		return err
	}

	user.IsEmailVerified = true
	if err := s.repo.Update(user); err != nil {
		s.log.Error("Error verifying user email", "error", err)
		return errors.New("failed to verify email")
	}

	// Invalidate cache
	cacheKey := fmt.Sprintf("user:%d", id)
	s.cache.Delete(cacheKey)

	return nil
}

// UpdateLastLogin updates the last login timestamp
func (s *userService) UpdateLastLogin(id uint) error {
	return s.repo.UpdateLastLogin(id)
}
