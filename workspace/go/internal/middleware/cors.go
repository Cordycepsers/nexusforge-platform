/**
 * CORS Middleware
 * Cross-Origin Resource Sharing configuration
 */

package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/nexusforge/api/internal/config"
)

// CORS returns a gin middleware for handling CORS
func CORS(cfg config.CORSConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")

		// Check if origin is allowed
		allowedOrigin := "*"
		if len(cfg.AllowedOrigins) > 0 && cfg.AllowedOrigins[0] != "*" {
			for _, allowed := range cfg.AllowedOrigins {
				if allowed == origin {
					allowedOrigin = origin
					break
				}
			}
		}

		c.Writer.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Methods", joinStrings(cfg.AllowedMethods))
		c.Writer.Header().Set("Access-Control-Allow-Headers", joinStrings(cfg.AllowedHeaders))

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

func joinStrings(strs []string) string {
	result := ""
	for i, str := range strs {
		if i > 0 {
			result += ", "
		}
		result += str
	}
	return result
}
