/**
 * User Repository
 * Data access layer for user operations
 */

package repository

import (
	"errors"

	"github.com/nexusforge/api/internal/models"
	"gorm.io/gorm"
)

// UserRepository handles user data access
type UserRepository interface {
	Create(user *models.User) error
	FindByID(id uint) (*models.User, error)
	FindByEmail(email string) (*models.User, error)
	FindByUsername(username string) (*models.User, error)
	List(page, limit int) ([]*models.User, int64, error)
	Update(user *models.User) error
	Delete(id uint) error
	UpdateLastLogin(id uint) error
}

type userRepository struct {
	db *gorm.DB
}

// NewUserRepository creates a new user repository
func NewUserRepository(db *gorm.DB) UserRepository {
	return &userRepository{db: db}
}

// Create creates a new user
func (r *userRepository) Create(user *models.User) error {
	return r.db.Create(user).Error
}

// FindByID finds a user by ID
func (r *userRepository) FindByID(id uint) (*models.User, error) {
	var user models.User
	err := r.db.Where("id = ? AND is_active = ?", id, true).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("user not found")
		}
		return nil, err
	}
	return &user, nil
}

// FindByEmail finds a user by email
func (r *userRepository) FindByEmail(email string) (*models.User, error) {
	var user models.User
	err := r.db.Where("email = ? AND is_active = ?", email, true).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

// FindByUsername finds a user by username
func (r *userRepository) FindByUsername(username string) (*models.User, error) {
	var user models.User
	err := r.db.Where("username = ? AND is_active = ?", username, true).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

// List returns a paginated list of users
func (r *userRepository) List(page, limit int) ([]*models.User, int64, error) {
	var users []*models.User
	var total int64

	// Count total records
	if err := r.db.Model(&models.User{}).Where("is_active = ?", true).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Calculate offset
	offset := (page - 1) * limit

	// Fetch paginated results
	err := r.db.Where("is_active = ?", true).
		Order("created_at DESC").
		Offset(offset).
		Limit(limit).
		Find(&users).Error

	if err != nil {
		return nil, 0, err
	}

	return users, total, nil
}

// Update updates a user
func (r *userRepository) Update(user *models.User) error {
	return r.db.Save(user).Error
}

// Delete soft deletes a user
func (r *userRepository) Delete(id uint) error {
	return r.db.Model(&models.User{}).Where("id = ?", id).Update("is_active", false).Error
}

// UpdateLastLogin updates the last login timestamp
func (r *userRepository) UpdateLastLogin(id uint) error {
	return r.db.Model(&models.User{}).Where("id = ?", id).Update("last_login", gorm.Expr("NOW()")).Error
}
