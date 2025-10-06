/**
 * Main Application Entry Point
 * Initializes and starts the HTTP server
 */

package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/nexusforge/api/internal/config"
	"github.com/nexusforge/api/internal/handlers"
	"github.com/nexusforge/api/internal/middleware"
	"github.com/nexusforge/api/internal/repository"
	"github.com/nexusforge/api/internal/services"
	"github.com/nexusforge/api/pkg/cache"
	"github.com/nexusforge/api/pkg/database"
	"github.com/nexusforge/api/pkg/logger"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Initialize logger
	log := logger.New(cfg.Log.Level, cfg.Log.Format)
	log.Info("Starting NexusForge Go API")

	// Initialize database
	db, err := database.Connect(cfg.Database)
	if err != nil {
		log.Fatal("Failed to connect to database", "error", err)
	}
	log.Info("Database connection established")

	// Auto-migrate database schema
	if err := database.AutoMigrate(db); err != nil {
		log.Fatal("Failed to migrate database", "error", err)
	}
	log.Info("Database migration completed")

	// Initialize Redis cache
	redisClient, err := cache.Connect(cfg.Redis)
	if err != nil {
		log.Fatal("Failed to connect to Redis", "error", err)
	}
	log.Info("Redis connection established")

	// Initialize repositories
	userRepo := repository.NewUserRepository(db)

	// Initialize cache manager
	cacheManager := cache.NewCacheManager(redisClient, cfg.Features.EnableCache)

	// Initialize services
	userService := services.NewUserService(userRepo, cacheManager, log)

	// Initialize handlers
	healthHandler := handlers.NewHealthHandler(db, redisClient, log)
	userHandler := handlers.NewUserHandler(userService, log)

	// Setup Gin router
	if cfg.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Global middleware
	router.Use(middleware.Logger(log))
	router.Use(middleware.Recovery(log))
	router.Use(middleware.CORS(cfg.CORS))

	// Metrics endpoint
	if cfg.Features.EnableMetrics {
		router.GET("/metrics", gin.WrapH(promhttp.Handler()))
	}

	// Health check routes
	health := router.Group("/health")
	{
		health.GET("", healthHandler.HealthCheck)
		health.GET("/ready", healthHandler.ReadinessCheck)
		health.GET("/live", healthHandler.LivenessCheck)
	}

	// API routes
	api := router.Group("/api")
	
	// Apply metrics middleware
	if cfg.Features.EnableMetrics {
		api.Use(middleware.Metrics())
	}

	// Apply rate limiting
	api.Use(middleware.RateLimit(cfg.RateLimit))

	// User routes
	users := api.Group("/users")
	{
		users.POST("", userHandler.CreateUser)
		
		// Authenticated routes
		authenticated := users.Group("")
		authenticated.Use(middleware.Auth(cfg.JWT.Secret))
		{
			authenticated.GET("", userHandler.ListUsers)
			authenticated.GET("/me", userHandler.GetCurrentUser)
			authenticated.GET("/:id", userHandler.GetUserByID)
			authenticated.PUT("/:id", userHandler.UpdateUser)
			authenticated.DELETE("/:id", middleware.RequireSuperuser(), userHandler.DeleteUser)
		}
	}

	// Create HTTP server
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.Info("Server starting", "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server", "error", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Error("Server forced to shutdown", "error", err)
	}

	// Close database connection
	sqlDB, _ := db.DB()
	if err := sqlDB.Close(); err != nil {
		log.Error("Error closing database connection", "error", err)
	}

	// Close Redis connection
	if err := redisClient.Close(); err != nil {
		log.Error("Error closing Redis connection", "error", err)
	}

	log.Info("Server exited")
}
