#!/bin/bash
set -e

echo "🚀 Starting Paysif Backend Services (Go Engines)..."

# 0. Load Environment Variables
if [ -f .env ]; then
    echo "📄 Loading environment variables from .env..."
    set -a
    source .env
    set +a
else
    echo "⚠️ .env file not found. Using default environment."
fi

# 0. Cleanup old processes
echo "🧹 Cleaning up old processes..."
./start-go-services.sh stop || true
pkill -f tmp_go_build || true
# kill any process on port 8080 (Go API)
lsof -ti:8080 | xargs kill -9 2>/dev/null || true

# Function to cleanup on exit
cleanup() {
    echo "🛑 Shutting down services..."
    ./start-go-services.sh stop || true
    kill $GO_PID 2>/dev/null || true
    echo "✨ All services stopped."
    exit
}

# Trap signals for graceful shutdown
trap cleanup SIGINT SIGTERM

# 1. Build and Start Go Microservices
echo "🐹 Building Go Microservices..."
./start-go-services.sh build

echo "🚀 Starting Go Microservices..."
./start-go-services.sh start

# 2. Wait for UDS Socket
echo "⏳ Waiting for services to stabilize..."
for i in {1..15}; do
    if [ -S "/tmp/fx_engine.sock" ]; then
        echo "📡 UDS Socket ready!"
        break
    fi
    sleep 1
done

# 3. Build and Start Go API
echo "🐹 Building Go API..."
mkdir -p tmp_go_build
go build -o tmp_go_build/api ./cmd/api
echo "🚀 Starting Go API..."
export GIN_MODE=${GIN_MODE:-debug}
./tmp_go_build/api > api.log 2>&1 &
GO_PID=$!
echo "✅ Go API started [PID: $GO_PID]"

echo "✨ All services are running! Press Ctrl+C to stop."

# Monitor API Gateway process
wait $GO_PID
