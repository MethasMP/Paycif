package middleware

import (
	"os"

	"github.com/gin-gonic/gin"
)

// CORSMiddleware sets CORS headers. Allowed origin is read from CORS_ORIGIN env var,
// defaults to the production domain.
func CORSMiddleware() gin.HandlerFunc {
	allowedOrigin := os.Getenv("CORS_ORIGIN")
	if allowedOrigin == "" {
		allowedOrigin = "https://paycif.com"
	}

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin == allowedOrigin || allowedOrigin == "*" {
			c.Header("Access-Control-Allow-Origin", origin)
		}
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Device-Id, X-Device-Signature, X-Request-ID")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
