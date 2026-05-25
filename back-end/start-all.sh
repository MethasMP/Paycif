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
pkill -f accounting_core || true
pkill -f payload_worker || true
pkill -f verify_service || true
pkill -f tmp_go_build || true
# kill any process on port 8080 (Go API)
lsof -ti:8080 | xargs kill -9 2>/dev/null || true

# Function to cleanup on exit
cleanup() {
    echo "🛑 Shutting down services..."
    kill $FX_WATCH_PID $GO_PID $ACCOUNTING_PID $VERIFY_PID $WORKER_PID 2>/dev/null || true
    echo "✨ All services stopped."
    exit
}

# Trap signals for graceful shutdown
trap cleanup SIGINT SIGTERM

# 1. Start Rust Verify Service (Auth)
echo "🛡️ Starting Rust Verify Service..."
cd rust/verify-service
cargo build --release
./target/release/verify_service > ../../logs/verify.log 2>&1 &
VERIFY_PID=$!
cd ../..

# 2. Start Rust Accounting Core (Ledger)
echo "📒 Starting Rust Accounting Core..."
cd rust/accounting-core
cargo build --release
./target/release/accounting_core > ../../logs/accounting.log 2>&1 &
ACCOUNTING_PID=$!
cd ../..

# 3. Start Rust FX Engine (with Supervisor)
echo "💱 Starting Rust FX Engine Supervisor..."
cd rust/fx-engine
cargo build --release
./watch-fx.sh &
FX_WATCH_PID=$!
cd ../..

# 4. Start Payload Worker (Outbox)
echo "📦 Starting Payload Worker..."
cd rust/payload-worker
cargo build --release
./target/release/payload_worker > ../../logs/worker.log 2>&1 &
WORKER_PID=$!
cd ../..

echo "⏳ Waiting for services to stabilize..."
for i in {1..15}; do
    if [ -S "/tmp/fx_engine.sock" ]; then
        echo "📡 Socket ready!"
        break
    fi
    sleep 1
done

# 5. Build and Start Go API
echo "🐹 Building Go API..."
mkdir -p tmp_go_build
go build -o tmp_go_build/api ./cmd/api
echo "🚀 Starting Go API..."
export GIN_MODE=${GIN_MODE:-debug}
./tmp_go_build/api > api.log 2>&1 &
GO_PID=$!
echo "✅ Go API started [PID: $GO_PID]"

echo "✨ All services are running! Press Ctrl+C to stop."

# Monitor
wait $FX_WATCH_PID $GO_PID $ACCOUNTING_PID $VERIFY_PID $WORKER_PID
