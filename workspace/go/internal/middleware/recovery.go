/**
 * Recovery Middleware
 * Panic recovery and error handling
 */

package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/nexusforge/api/pkg/logger"
)

// Recovery returns a gin middleware for panic recovery
func Recovery(log logger.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				log.Error("Panic recovered",
					"error", err,
					"path", c.Request.URL.Path,
					"method", c.Request.Method,
				)

				c.JSON(http.StatusInternalServerError, gin.H{
					"message": "Internal server error",
				})
			}
		}()

		c.Next()
	}
}
