/**
 * Configuration Management
 * Loads and validates application configuration from environment
 */

package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

// Config holds all application configuration
type Config struct {
	Env      string
	Port     string
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	Log      LogConfig
	RateLimit RateLimitConfig
	CORS     CORSConfig
	Features FeatureFlags
	Security SecurityConfig
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	Name     string
	SSLMode  string
}

// RedisConfig holds Redis configuration
type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

// JWTConfig holds JWT configuration
type JWTConfig struct {
	Secret           string
	ExpiresIn        time.Duration
	RefreshExpiresIn time.Duration
}

// LogConfig holds logging configuration
type LogConfig struct {
	Level  string
	Format string
}

// RateLimitConfig holds rate limiting configuration
type RateLimitConfig struct {
	Requests int
	Window   time.Duration
}

// CORSConfig holds CORS configuration
type CORSConfig struct {
	AllowedOrigins []string
	AllowedMethods []string
	AllowedHeaders []string
}

// FeatureFlags holds feature toggle configuration
type FeatureFlags struct {
	EnableCache   bool
	EnableMetrics bool
}

// SecurityConfig holds security configuration
type SecurityConfig struct {
	BcryptCost int
}

// Load loads configuration from environment variables
func Load() *Config {
	// Load .env file if it exists (development)
	_ = godotenv.Load()

	return &Config{
		Env:  getEnv("ENV", "development"),
		Port: getEnv("PORT", "8080"),
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "postgres"),
			Password: getEnv("DB_PASSWORD", "postgres"),
			Name:     getEnv("DB_NAME", "nexusforge_go"),
			SSLMode:  getEnv("DB_SSL_MODE", "disable"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getEnvAsInt("REDIS_DB", 0),
		},
		JWT: JWTConfig{
			Secret:           getEnv("JWT_SECRET", "your-secret-key-change-in-production"),
			ExpiresIn:        getEnvAsDuration("JWT_EXPIRES_IN", "24h"),
			RefreshExpiresIn: getEnvAsDuration("JWT_REFRESH_EXPIRES_IN", "168h"),
		},
		Log: LogConfig{
			Level:  getEnv("LOG_LEVEL", "info"),
			Format: getEnv("LOG_FORMAT", "json"),
		},
		RateLimit: RateLimitConfig{
			Requests: getEnvAsInt("RATE_LIMIT_REQUESTS", 100),
			Window:   getEnvAsDuration("RATE_LIMIT_WINDOW", "15m"),
		},
		CORS: CORSConfig{
			AllowedOrigins: getEnvAsSlice("CORS_ALLOWED_ORIGINS", []string{"*"}),
			AllowedMethods: getEnvAsSlice("CORS_ALLOWED_METHODS", []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}),
			AllowedHeaders: getEnvAsSlice("CORS_ALLOWED_HEADERS", []string{"Content-Type", "Authorization"}),
		},
		Features: FeatureFlags{
			EnableCache:   getEnvAsBool("ENABLE_CACHE", true),
			EnableMetrics: getEnvAsBool("ENABLE_METRICS", true),
		},
		Security: SecurityConfig{
			BcryptCost: getEnvAsInt("BCRYPT_COST", 10),
		},
	}
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if c.JWT.Secret == "your-secret-key-change-in-production" && c.Env == "production" {
		return fmt.Errorf("JWT_SECRET must be set in production")
	}
	if c.Database.Password == "" {
		return fmt.Errorf("DB_PASSWORD is required")
	}
	return nil
}

// Helper functions

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	valueStr := getEnv(key, "")
	if value, err := strconv.Atoi(valueStr); err == nil {
		return value
	}
	return defaultValue
}

func getEnvAsBool(key string, defaultValue bool) bool {
	valueStr := getEnv(key, "")
	if value, err := strconv.ParseBool(valueStr); err == nil {
		return value
	}
	return defaultValue
}

func getEnvAsDuration(key string, defaultValue string) time.Duration {
	valueStr := getEnv(key, defaultValue)
	if duration, err := time.ParseDuration(valueStr); err == nil {
		return duration
	}
	return 24 * time.Hour
}

func getEnvAsSlice(key string, defaultValue []string) []string {
	valueStr := getEnv(key, "")
	if valueStr == "" {
		return defaultValue
	}
	return strings.Split(valueStr, ",")
}
