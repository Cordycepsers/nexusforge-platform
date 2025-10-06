/**
 * Health Handler Tests
 */

package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/nexusforge/api/pkg/logger"
	"github.com/stretchr/testify/assert"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func setupTestDB() *gorm.DB {
	db, _ := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	return db
}

func setupTestRedis() *redis.Client {
	return redis.NewClient(&redis.Options{
		Addr: "localhost:6379",
	})
}

func TestHealthCheck(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()

	db := setupTestDB()
	redisClient := setupTestRedis()
	log := logger.New("error", "json")
	handler := NewHealthHandler(db, redisClient, log)

	router.GET("/health", handler.HealthCheck)

	req, _ := http.NewRequest("GET", "/health", nil)
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	assert.Equal(t, http.StatusOK, resp.Code)
	assert.Contains(t, resp.Body.String(), "healthy")
	assert.Contains(t, resp.Body.String(), "nexusforge-go-api")
}

func TestLivenessCheck(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()

	db := setupTestDB()
	redisClient := setupTestRedis()
	log := logger.New("error", "json")
	handler := NewHealthHandler(db, redisClient, log)

	router.GET("/health/live", handler.LivenessCheck)

	req, _ := http.NewRequest("GET", "/health/live", nil)
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	assert.Equal(t, http.StatusOK, resp.Code)
	assert.Contains(t, resp.Body.String(), "alive")
	assert.Contains(t, resp.Body.String(), "uptime")
}
