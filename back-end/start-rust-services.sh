#!/bin/bash
set -e

# =============================================================================
# Paycif Rust Microservices Launcher
# =============================================================================
# Manages all Rust-based high-performance services:
# - verify-service (Port 3001) - Ed25519 Signature Verification
# - accounting-core (Port 50051) - Double-Entry Ledger gRPC
# - fx-engine (Port 50052) - Currency Conversion gRPC  
# - payload-worker - SIMD-JSON Queue Processor
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$SCRIPT_DIR/rust"
LOG_DIR="$SCRIPT_DIR/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "$LOG_DIR"

# PID files
VERIFY_PID_FILE="$LOG_DIR/verify-service.pid"
ACCOUNTING_PID_FILE="$LOG_DIR/accounting-core.pid"
FX_PID_FILE="$LOG_DIR/fx-engine.pid"
WORKER_PID_FILE="$LOG_DIR/payload-worker.pid"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

start_service() {
    local name=$1
    local binary=$2
    local pid_file=$3
    local port=$4
    
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log_warn "$name already running (PID: $(cat "$pid_file"))"
        return 0
    fi
    
    if [ ! -f "$binary" ]; then
        log_error "$name binary not found at $binary"
        log_info "Run: cargo build --release in $RUST_DIR/$(dirname "$binary" | xargs basename)"
        return 1
    fi
    
    log_info "Starting $name..."
    "$binary" > "$LOG_DIR/$name.log" 2>&1 &
    echo $! > "$pid_file"
    
    sleep 2
    
    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log_info "$name started (PID: $(cat "$pid_file"), Port: $port)"
        return 0
    else
        log_error "$name failed to start. Check $LOG_DIR/$name.log"
        return 1
    fi
}

stop_service() {
    local name=$1
    local pid_file=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping $name (PID: $pid)..."
            kill "$pid"
            rm -f "$pid_file"
        else
            log_warn "$name was not running"
            rm -f "$pid_file"
        fi
    else
        log_warn "$name PID file not found"
    fi
}

health_check() {
    local name=$1
    local url=$2
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200"; then
        log_info "$name: ✅ Healthy"
    else
        log_warn "$name: ❌ Not responding"
    fi
}

case "${1:-start}" in
    start)
        log_section "Starting Rust Microservices"
        
        # verify-service (HTTP)
        start_service "verify-service" \
            "$RUST_DIR/verify-service/target/release/verify_service" \
            "$VERIFY_PID_FILE" \
            "3001"
        
        # accounting-core (gRPC)
        start_service "accounting-core" \
            "$RUST_DIR/accounting-core/target/release/accounting_core" \
            "$ACCOUNTING_PID_FILE" \
            "50051"
        
        # fx-engine (gRPC)
        start_service "fx-engine" \
            "$RUST_DIR/fx-engine/target/release/fx_engine" \
            "$FX_PID_FILE" \
            "50052"
        
        # payload-worker (Background)
        start_service "payload-worker" \
            "$RUST_DIR/payload-worker/target/release/payload_worker" \
            "$WORKER_PID_FILE" \
            "N/A"
        
        log_section "All Services Started"
        echo ""
        echo "Services:"
        echo "  • verify-service:   http://localhost:3001/verify"
        echo "  • accounting-core:  grpc://[::1]:50051"
        echo "  • fx-engine:        grpc://[::1]:50052"
        echo "  • payload-worker:   (background)"
        echo ""
        echo "Logs: $LOG_DIR/"
        ;;
        
    stop)
        log_section "Stopping Rust Microservices"
        stop_service "payload-worker" "$WORKER_PID_FILE"
        stop_service "fx-engine" "$FX_PID_FILE"
        stop_service "accounting-core" "$ACCOUNTING_PID_FILE"
        stop_service "verify-service" "$VERIFY_PID_FILE"
        log_info "All services stopped"
        ;;
        
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
        
    status)
        log_section "Service Status"
        
        for pid_file in "$VERIFY_PID_FILE" "$ACCOUNTING_PID_FILE" "$FX_PID_FILE" "$WORKER_PID_FILE"; do
            name=$(basename "$pid_file" .pid)
            if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
                log_info "$name: Running (PID: $(cat "$pid_file"))"
            else
                log_warn "$name: Stopped"
            fi
        done
        ;;
        
    logs)
        service="${2:-all}"
        if [ "$service" = "all" ]; then
            tail -f "$LOG_DIR"/*.log
        else
            tail -f "$LOG_DIR/$service.log"
        fi
        ;;
        
    build)
        log_section "Building All Rust Services"
        
        export PATH="/Users/maemp/.cargo/bin:$PATH"
        
        for service in verify-service accounting-core fx-engine payload-worker; do
            log_info "Building $service..."
            cd "$RUST_DIR/$service"
            
            # Set up env for sandboxed cargo
            export CARGO_HOME="$RUST_DIR/$service/.cargo_home"
            export TMPDIR="$RUST_DIR/$service/tmp"
            mkdir -p "$CARGO_HOME" "$TMPDIR"
            
            if [ "$service" = "accounting-core" ] || [ "$service" = "fx-engine" ]; then
                export PROTOC="$SCRIPT_DIR/tools/protoc/bin/protoc"
            fi
            
            cargo build --release
            log_info "$service built successfully"
        done
        
        log_section "All Services Built"
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [service]|build}"
        exit 1
        ;;
esac
