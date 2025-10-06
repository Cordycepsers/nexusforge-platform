/**
 * User Handlers
 * HTTP handlers for user-related operations
 */

package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/nexusforge/api/internal/models"
	"github.com/nexusforge/api/internal/services"
	"github.com/nexusforge/api/pkg/logger"
)

// UserHandler handles user-related requests
type UserHandler struct {
	service services.UserService
	log     logger.Logger
}

// NewUserHandler creates a new user handler
func NewUserHandler(service services.UserService, log logger.Logger) *UserHandler {
	return &UserHandler{
		service: service,
		log:     log,
	}
}

// CreateUser handles user creation
func (h *UserHandler) CreateUser(c *gin.Context) {
	var req models.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Validation failed",
			"error":   err.Error(),
		})
		return
	}

	user, err := h.service.CreateUser(&req)
	if err != nil {
		statusCode := http.StatusInternalServerError
		if err.Error() == "email already registered" || err.Error() == "username already taken" {
			statusCode = http.StatusConflict
		}
		c.JSON(statusCode, gin.H{
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "User created successfully",
		"data":    user,
	})
}

// ListUsers handles listing users with pagination
func (h *UserHandler) ListUsers(c *gin.Context) {
	var query models.PaginationQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Invalid query parameters",
			"error":   err.Error(),
		})
		return
	}

	// Set defaults
	if query.Page < 1 {
		query.Page = 1
	}
	if query.Limit < 1 {
		query.Limit = 10
	}

	users, total, err := h.service.ListUsers(query.Page, query.Limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Failed to fetch users",
			"error":   err.Error(),
		})
		return
	}

	// Calculate total pages
	totalPages := int(total) / query.Limit
	if int(total)%query.Limit > 0 {
		totalPages++
	}

	c.JSON(http.StatusOK, gin.H{
		"data": users,
		"pagination": models.Pagination{
			Total:      total,
			Page:       query.Page,
			Limit:      query.Limit,
			TotalPages: totalPages,
		},
	})
}

// GetUserByID handles getting a user by ID
func (h *UserHandler) GetUserByID(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Invalid user ID",
		})
		return
	}

	user, err := h.service.GetUserByID(uint(id))
	if err != nil {
		statusCode := http.StatusInternalServerError
		if err.Error() == "user not found" {
			statusCode = http.StatusNotFound
		}
		c.JSON(statusCode, gin.H{
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data": user,
	})
}

// GetCurrentUser handles getting the current authenticated user
func (h *UserHandler) GetCurrentUser(c *gin.Context) {
	// Get user ID from context (set by auth middleware)
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"message": "User not authenticated",
		})
		return
	}

	user, err := h.service.GetUserByID(userID.(uint))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "Failed to fetch user",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data": user,
	})
}

// UpdateUser handles updating a user
func (h *UserHandler) UpdateUser(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Invalid user ID",
		})
		return
	}

	// Check if user is updating their own profile
	userID, _ := c.Get("userID")
	isSuperuser, _ := c.Get("isSuperuser")
	if userID.(uint) != uint(id) && !isSuperuser.(bool) {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Not authorized to update this user",
		})
		return
	}

	var req models.UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Validation failed",
			"error":   err.Error(),
		})
		return
	}

	user, err := h.service.UpdateUser(uint(id), &req)
	if err != nil {
		statusCode := http.StatusInternalServerError
		if err.Error() == "user not found" {
			statusCode = http.StatusNotFound
		} else if err.Error() == "email already registered" || err.Error() == "username already taken" {
			statusCode = http.StatusConflict
		}
		c.JSON(statusCode, gin.H{
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "User updated successfully",
		"data":    user,
	})
}

// DeleteUser handles soft deleting a user
func (h *UserHandler) DeleteUser(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Invalid user ID",
		})
		return
	}

	if err := h.service.DeleteUser(uint(id)); err != nil {
		statusCode := http.StatusInternalServerError
		if errors.Is(err, errors.New("user not found")) {
			statusCode = http.StatusNotFound
		}
		c.JSON(statusCode, gin.H{
			"message": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "User deleted successfully",
	})
}
