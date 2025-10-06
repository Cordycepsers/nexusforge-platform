/**
 * Authentication Middleware
 * JWT token validation and user context
 */

package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// Auth validates JWT token and sets user context
func Auth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"message": "Authorization header required",
			})
			c.Abort()
			return
		}

		// Extract token from "Bearer <token>"
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"message": "Invalid authorization header format",
			})
			c.Abort()
			return
		}

		tokenString := parts[1]

		// Parse and validate token
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			// Validate signing method
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(secret), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{
				"message": "Invalid or expired token",
			})
			c.Abort()
			return
		}

		// Extract claims
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{
				"message": "Invalid token claims",
			})
			c.Abort()
			return
		}

		// Set user context
		userID, ok := claims["user_id"].(float64)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{
				"message": "Invalid user ID in token",
			})
			c.Abort()
			return
		}

		c.Set("userID", uint(userID))
		c.Set("email", claims["email"])
		c.Set("username", claims["username"])
		c.Set("isSuperuser", claims["is_superuser"])

		c.Next()
	}
}

// RequireSuperuser checks if the authenticated user is a superuser
func RequireSuperuser() gin.HandlerFunc {
	return func(c *gin.Context) {
		isSuperuser, exists := c.Get("isSuperuser")
		if !exists || !isSuperuser.(bool) {
			c.JSON(http.StatusForbidden, gin.H{
				"message": "Superuser access required",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}
