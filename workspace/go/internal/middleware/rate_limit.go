/**
 * Rate Limiting Middleware
 * Request rate limiting per IP address
 */

package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/nexusforge/api/internal/config"
)

type visitor struct {
	lastSeen time.Time
	count    int
}

var (
	visitors = make(map[string]*visitor)
	mu       sync.RWMutex
)

// RateLimit returns a gin middleware for rate limiting
func RateLimit(cfg config.RateLimitConfig) gin.HandlerFunc {
	// Background cleanup of old visitors
	go cleanupVisitors(cfg.Window)

	return func(c *gin.Context) {
		// Skip rate limiting for health checks
		if c.Request.URL.Path == "/health" ||
			c.Request.URL.Path == "/health/ready" ||
			c.Request.URL.Path == "/health/live" {
			c.Next()
			return
		}

		ip := c.ClientIP()

		mu.Lock()
		v, exists := visitors[ip]

		if !exists {
			visitors[ip] = &visitor{
				lastSeen: time.Now(),
				count:    1,
			}
			mu.Unlock()
			c.Next()
			return
		}

		// Check if window has expired
		if time.Since(v.lastSeen) > cfg.Window {
			v.count = 1
			v.lastSeen = time.Now()
			mu.Unlock()
			c.Next()
			return
		}

		// Check if limit exceeded
		if v.count >= cfg.Requests {
			mu.Unlock()
			c.JSON(http.StatusTooManyRequests, gin.H{
				"message": "Too many requests",
			})
			c.Abort()
			return
		}

		v.count++
		v.lastSeen = time.Now()
		mu.Unlock()

		c.Next()
	}
}

// cleanupVisitors removes old visitor entries
func cleanupVisitors(window time.Duration) {
	for {
		time.Sleep(window)

		mu.Lock()
		for ip, v := range visitors {
			if time.Since(v.lastSeen) > window {
				delete(visitors, ip)
			}
		}
		mu.Unlock()
	}
}
