/**
 * Logger Middleware
 * HTTP request/response logging
 */

package middleware

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/nexusforge/api/pkg/logger"
)

// Logger returns a gin middleware for logging requests
func Logger(log logger.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		// Process request
		c.Next()

		// Calculate latency
		latency := time.Since(start)

		// Get status code
		statusCode := c.Writer.Status()

		// Log request
		log.Info("HTTP request",
			"method", c.Request.Method,
			"path", path,
			"query", query,
			"status", statusCode,
			"latency", latency.String(),
			"ip", c.ClientIP(),
			"userAgent", c.Request.UserAgent(),
		)
	}
}
