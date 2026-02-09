#!/bin/bash

# FX Engine Quick Start Script
# Usage: ./run-fx-engine.sh [start|stop|status|test]

set -e

FX_DIR="/Users/maemp/Desktop/Paycif/back-end/rust/fx-engine"
PID_FILE="/tmp/fx_engine.pid"

case "${1:-start}" in
  start)
    echo "🚀 Starting FX Engine..."
    
    # Check if already running
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
      echo "✅ FX Engine is already running (PID: $(cat $PID_FILE))"
      exit 0
    fi
    
    # Check Redis
    if ! docker ps | grep -q paysif-redis; then
      echo "📦 Starting Redis..."
      cd /Users/maemp/Desktop/Paycif/back-end
      ./start-redis.sh up
      sleep 3
    fi
    
    # Start FX Engine
    cd "$FX_DIR"
    nohup ./target/release/fx_engine > /tmp/fx_engine.log 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    
    if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
      echo "✅ FX Engine started successfully!"
      echo "   PID: $(cat $PID_FILE)"
      echo "   Port: 50052"
      echo "   Logs: tail -f /tmp/fx_engine.log"
    else
      echo "❌ Failed to start FX Engine"
      exit 1
    fi
    ;;
    
  stop)
    echo "🛑 Stopping FX Engine..."
    if [ -f "$PID_FILE" ]; then
      PID=$(cat "$PID_FILE")
      if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        rm "$PID_FILE"
        echo "✅ FX Engine stopped"
      else
        echo "⚠️  FX Engine not running"
        rm -f "$PID_FILE"
      fi
    else
      pkill fx_engine 2>/dev/null || true
      echo "✅ FX Engine stopped (if was running)"
    fi
    ;;
    
  status)
    echo "📊 FX Engine Status"
    echo "=================="
    
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
      echo "✅ Status: RUNNING"
      echo "   PID: $(cat $PID_FILE)"
      echo "   Port: 50052"
      echo "   Memory: $(ps -o rss= -p $(cat $PID_FILE) 2>/dev/null | awk '{print $1/1024 " MB"}')"
    else
      echo "❌ Status: STOPPED"
    fi
    
    echo ""
    echo "📦 Redis:"
    if docker ps | grep -q paysif-redis; then
      echo "   ✅ Running"
    else
      echo "   ❌ Stopped"
    fi
    
    echo ""
    echo "📝 Recent Logs:"
    tail -5 /tmp/fx_engine.log 2>/dev/null || echo "   No logs available"
    ;;
    
  test)
    echo "🧪 Testing FX Engine..."
    echo "======================="
    
    cd "$FX_DIR"
    cargo test --quiet 2>&1 | grep -E "(running|test result)" || echo "Tests completed"
    
    echo ""
    echo "📊 Service Status:"
    if nc -zv localhost 50052 2>&1 | grep -q succeeded; then
      echo "   ✅ Port 50052: OPEN"
    else
      echo "   ⚠️  Port 50052: Check manually"
    fi
    ;;
    
  build)
    echo "🔨 Building FX Engine..."
    cd "$FX_DIR"
    cargo build --release
    echo "✅ Build complete"
    ;;
    
  logs)
    echo "📜 FX Engine Logs:"
    tail -f /tmp/fx_engine.log
    ;;
    
  *)
    echo "Usage: $0 [start|stop|status|test|build|logs]"
    exit 1
    ;;
esac
