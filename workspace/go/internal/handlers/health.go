/**
 * Health Check Handlers
 * HTTP handlers for health check endpoints
 */

package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/nexusforge/api/pkg/logger"
	"gorm.io/gorm"
)

// HealthHandler handles health check requests
type HealthHandler struct {
	db    *gorm.DB
	redis *redis.Client
	log   logger.Logger
}

// NewHealthHandler creates a new health handler
func NewHealthHandler(db *gorm.DB, redis *redis.Client, log logger.Logger) *HealthHandler {
	return &HealthHandler{
		db:    db,
		redis: redis,
		log:   log,
	}
}

// HealthCheck returns basic health status
func (h *HealthHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
		"service":   "nexusforge-go-api",
		"version":   "1.0.0",
	})
}

// ReadinessCheck checks if the service is ready to accept requests
func (h *HealthHandler) ReadinessCheck(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	checks := gin.H{}
	healthy := true

	// Check database
	sqlDB, err := h.db.DB()
	if err != nil || sqlDB.PingContext(ctx) != nil {
		checks["database"] = "down"
		healthy = false
		h.log.Error("Database health check failed", "error", err)
	} else {
		checks["database"] = "up"
	}

	// Check Redis
	if err := h.redis.Ping(ctx).Err(); err != nil {
		checks["redis"] = "down"
		healthy = false
		h.log.Error("Redis health check failed", "error", err)
	} else {
		checks["redis"] = "up"
	}

	status := "ready"
	statusCode := http.StatusOK
	if !healthy {
		status = "not ready"
		statusCode = http.StatusServiceUnavailable
	}

	c.JSON(statusCode, gin.H{
		"status":    status,
		"timestamp": time.Now().Format(time.RFC3339),
		"checks":    checks,
	})
}

// LivenessCheck checks if the service is alive
func (h *HealthHandler) LivenessCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "alive",
		"timestamp": time.Now().Format(time.RFC3339),
		"uptime":    time.Since(startTime).Seconds(),
	})
}

var startTime = time.Now()
