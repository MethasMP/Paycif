package middleware

import (
	"context"
	"log/slog"
	"paysif/internal/infrastructure/logger"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func StructuredLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		
		// generate or get request ID
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = uuid.New().String()
		}
		
		// Set in headers and context
		c.Header("X-Request-ID", requestID)
		
		// Add to context for slog usage
		ctx := context.WithValue(c.Request.Context(), logger.RequestIDKey, requestID)
		c.Request = c.Request.WithContext(ctx)

		c.Next()

		// Final log after request processing
		latency := time.Since(start)
		status := c.Writer.Status()

		logger.WithContext(c.Request.Context()).Info("HTTP Request",
			slog.Int("status", status),
			slog.String("method", c.Request.Method),
			slog.String("path", c.Request.URL.Path),
			slog.String("ip", c.ClientIP()),
			slog.Duration("latency", latency),
			slog.String("user_agent", c.Request.UserAgent()),
		)
	}
}
