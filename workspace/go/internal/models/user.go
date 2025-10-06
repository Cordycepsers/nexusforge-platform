/**
 * User Model
 * Database model and related types for user management
 */

package models

import (
	"time"

	"gorm.io/gorm"
)

// User represents a user in the system
type User struct {
	ID              uint           `gorm:"primaryKey" json:"id"`
	Email           string         `gorm:"uniqueIndex:idx_email_active;not null" json:"email"`
	Username        string         `gorm:"uniqueIndex:idx_username_active;not null" json:"username"`
	HashedPassword  string         `gorm:"not null" json:"-"`
	IsActive        bool           `gorm:"default:true;index:idx_email_active,idx_username_active" json:"isActive"`
	IsSuperuser     bool           `gorm:"default:false" json:"isSuperuser"`
	IsEmailVerified bool           `gorm:"default:false" json:"isEmailVerified"`
	LastLogin       *time.Time     `json:"lastLogin,omitempty"`
	CreatedAt       time.Time      `json:"createdAt"`
	UpdatedAt       time.Time      `json:"updatedAt"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}

// TableName specifies the table name for User model
func (User) TableName() string {
	return "users"
}

// UserResponse represents the public user data (without password)
type UserResponse struct {
	ID              uint       `json:"id"`
	Email           string     `json:"email"`
	Username        string     `json:"username"`
	IsActive        bool       `json:"isActive"`
	IsSuperuser     bool       `json:"isSuperuser"`
	IsEmailVerified bool       `json:"isEmailVerified"`
	LastLogin       *time.Time `json:"lastLogin,omitempty"`
	CreatedAt       time.Time  `json:"createdAt"`
	UpdatedAt       time.Time  `json:"updatedAt"`
}

// ToResponse converts User to UserResponse
func (u *User) ToResponse() *UserResponse {
	return &UserResponse{
		ID:              u.ID,
		Email:           u.Email,
		Username:        u.Username,
		IsActive:        u.IsActive,
		IsSuperuser:     u.IsSuperuser,
		IsEmailVerified: u.IsEmailVerified,
		LastLogin:       u.LastLogin,
		CreatedAt:       u.CreatedAt,
		UpdatedAt:       u.UpdatedAt,
	}
}

// CreateUserRequest represents the request body for creating a user
type CreateUserRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Username string `json:"username" binding:"required,min=3,max=50"`
	Password string `json:"password" binding:"required,min=8"`
}

// UpdateUserRequest represents the request body for updating a user
type UpdateUserRequest struct {
	Email    *string `json:"email" binding:"omitempty,email"`
	Username *string `json:"username" binding:"omitempty,min=3,max=50"`
	Password *string `json:"password" binding:"omitempty,min=8"`
}

// LoginRequest represents the request body for user login
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// PaginationQuery represents pagination parameters
type PaginationQuery struct {
	Page  int `form:"page" binding:"omitempty,min=1"`
	Limit int `form:"limit" binding:"omitempty,min=1,max=100"`
}

// PaginatedResponse represents a paginated response
type PaginatedResponse struct {
	Data       interface{} `json:"data"`
	Pagination Pagination  `json:"pagination"`
}

// Pagination represents pagination metadata
type Pagination struct {
	Total      int64 `json:"total"`
	Page       int   `json:"page"`
	Limit      int   `json:"limit"`
	TotalPages int   `json:"totalPages"`
}
