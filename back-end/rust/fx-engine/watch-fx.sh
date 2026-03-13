#!/bin/bash
# watch-fx.sh - Supervisor for Rust FX Engine
# Ensures the engine automatically restarts if it crashes.

FX_ENGINE_BIN="./target/release/fx_engine"
LOG_FILE="../../fx_engine.log"
export FX_ENGINE_UDS="/tmp/fx_engine.sock"

# Load environment variables if available
if [ -f ../.env ]; then
    set -a
    source ../.env
    set +a
fi

echo "🛡️ FX Engine Supervisor started [PID: $$]"

while true; do
    if [ ! -f "$FX_ENGINE_BIN" ]; then
        echo "⚠️ $FX_ENGINE_BIN not found. Please build it first."
        sleep 5
        continue
    fi

    echo "🚀 Starting FX Engine..."
    # Clean up old socket if it exists
    rm -f "$FX_ENGINE_UDS"
    
    # Run the engine and wait for it
    $FX_ENGINE_BIN >> "$LOG_FILE" 2>&1
    
    EXIT_CODE=$?
    echo "🚨 FX Engine exited with code $EXIT_CODE. Restarting in 2 seconds..."
    sleep 2
done
