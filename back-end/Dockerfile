# Build Stage
FROM golang:1.22-bookworm as builder

WORKDIR /app

# Copy all files
COPY . .

# Download dependencies (No need for local go_home hacks here)
RUN go mod download

# Build
RUN go build -o main ./cmd/api

# Runtime Stage
FROM debian:bookworm-slim

WORKDIR /app

# Install CA certificates for HTTPS (Supabase/Stripe)
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/main .
COPY --from=builder /app/.env . 
# Note: copying .env is convenient for demo, but usually passed via Orchestrator

EXPOSE 8080

CMD ["./main"]
