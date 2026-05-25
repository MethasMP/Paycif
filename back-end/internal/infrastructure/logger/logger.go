package logger

import (
	"context"
	"log/slog"
	"os"
)

var L *slog.Logger

func Init() {
	var handler slog.Handler
	
	// In Production, always JSON. In Dev, you can use Text for readability.
	// But let's go World-Class and use JSON even in Dev to see the behavior.
	handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})

	L = slog.New(handler)
	slog.SetDefault(L)
}

// RequestIDKey is the context key for Request ID
type ctxKey string
const RequestIDKey ctxKey = "request_id"

// WithContext returns a logger with request id from context
func WithContext(ctx context.Context) *slog.Logger {
	if rid, ok := ctx.Value(RequestIDKey).(string); ok {
		return L.With(slog.String("request_id", rid))
	}
	return L
}
