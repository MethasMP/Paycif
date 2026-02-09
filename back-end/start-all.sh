#!/bin/bash
set -e

echo "🚀 Starting Paysif Backend Services..."

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
pkill -f fx_engine || true
# kill any process on port 8080 (Go API)
lsof -ti:8080 | xargs kill -9 2>/dev/null || true

# Function to cleanup on exit
cleanup() {
    echo "🛑 Shutting down services..."
    kill $FX_PID $GO_PID 2>/dev/null
    exit
}

# Trap signals for graceful shutdown
trap cleanup SIGINT SIGTERM

# 1. Start Rust FX Engine
echo "💱 Building Rust FX Engine..."
cd rust/fx-engine
cargo build --release
export FX_ENGINE_UDS="/tmp/fx_engine.sock"
./target/release/fx_engine > ../../fx_engine.log 2>&1 &
FX_PID=$!
echo "✅ FX Engine started [PID: $FX_PID]"
cd ../..

echo "⏳ Waiting for FX Engine socket..."
for i in {1..10}; do
    if [ -S "/tmp/fx_engine.sock" ]; then
        echo "📡 Socket ready!"
        break
    fi
    sleep 1
done

# 2. Build and Start Go API
echo "🐹 Building Go API..."
go build -o tmp_go_build/api ./cmd/api
echo "🚀 Starting Go API..."
export GIN_MODE=release
./tmp_go_build/api > api.log 2>&1 &
GO_PID=$!
echo "✅ Go API started [PID: $GO_PID]"

echo "✨ All services are running! Press Ctrl+C to stop."

# Monitor
wait $FX_PID $GO_PID
