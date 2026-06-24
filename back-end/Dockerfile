# Build Stage
FROM golang:1.26-bookworm AS builder

WORKDIR /app

# Cache modules
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build argument for the service
ARG SERVICE_NAME
RUN if [ -z "$SERVICE_NAME" ]; then echo "SERVICE_NAME build arg is required" && exit 1; fi

# Build the specific service
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/main ./cmd/${SERVICE_NAME}

# Runtime Stage
FROM gcr.io/distroless/static-debian12

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/main .

# Command to run the executable
ENTRYPOINT ["/app/main"]
