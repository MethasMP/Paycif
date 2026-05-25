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

		fields := []slog.Attr{
			slog.Int("status", status),
			slog.String("method", c.Request.Method),
			slog.String("path", c.Request.URL.Path),
			slog.String("ip", c.ClientIP()),
			slog.Duration("latency", latency),
			slog.String("user_agent", c.Request.UserAgent()),
		}

		// Log any errors attached to the context
		if len(c.Errors) > 0 {
			fields = append(fields, slog.String("errors", c.Errors.String()))
		}

		lvl := slog.LevelInfo
		if status >= 500 {
			lvl = slog.LevelError
		} else if status >= 400 {
			lvl = slog.LevelWarn
		}

		logger.WithContext(c.Request.Context()).LogAttrs(c.Request.Context(), lvl, "HTTP Request Completed", fields...)
	}
}
