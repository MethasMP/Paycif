#!/bin/bash
set -e

# =============================================================================
# Paycif Go Microservices Launcher
# =============================================================================
# Manages all Go-based high-performance services:
# - verify-service (Port 3001) - Ed25519 Signature Verification
# - accounting-core (Port 50051) - Double-Entry Ledger gRPC
# - fx-engine (Port 50052) - Currency Conversion gRPC  
# - payload-worker - SIMD-JSON Queue Processor
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
LOG_DIR="$SCRIPT_DIR/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create necessary directories
mkdir -p "$BIN_DIR" "$LOG_DIR"

# PID files
VERIFY_PID_FILE="$LOG_DIR/go-verify-service.pid"
ACCOUNTING_PID_FILE="$LOG_DIR/go-accounting-core.pid"
FX_PID_FILE="$LOG_DIR/go-fx-engine.pid"
WORKER_PID_FILE="$LOG_DIR/go-payload-worker.pid"
OUTBOX_WORKER_PID_FILE="$LOG_DIR/go-worker.pid"

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
        log_info "Run: $0 build"
        return 1
    fi
    
    log_info "Starting $name..."
    "$binary" > "$LOG_DIR/$name.log" 2>&1 &
    echo $! > "$pid_file"
    
    sleep 1.5
    
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

case "${1:-start}" in
    start)
        log_section "Starting Go Microservices"
        
        # verify-service (HTTP)
        start_service "verify-service" \
            "$BIN_DIR/verify-service" \
            "$VERIFY_PID_FILE" \
            "3001"
        
        # accounting-core (gRPC)
        start_service "accounting-core" \
            "$BIN_DIR/accounting-core" \
            "$ACCOUNTING_PID_FILE" \
            "50051"
        
        # fx-engine (gRPC)
        start_service "fx-engine" \
            "$BIN_DIR/fx-engine" \
            "$FX_PID_FILE" \
            "50052"
        
        # payload-worker (Background)
        start_service "payload-worker" \
            "$BIN_DIR/payload-worker" \
            "$WORKER_PID_FILE" \
            "N/A"
        
        # outbox-worker (Background)
        start_service "worker" \
            "$BIN_DIR/worker" \
            "$OUTBOX_WORKER_PID_FILE" \
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
        log_section "Stopping Go Microservices"
        stop_service "worker" "$OUTBOX_WORKER_PID_FILE"
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
        
        for pid_file in "$VERIFY_PID_FILE" "$ACCOUNTING_PID_FILE" "$FX_PID_FILE" "$WORKER_PID_FILE" "$OUTBOX_WORKER_PID_FILE"; do
            name=$(basename "$pid_file" .pid | sed 's/go-//')
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
        log_section "Building All Go Services"
        
        for service in verify-service accounting-core fx-engine payload-worker worker; do
            log_info "Building $service..."
            go build -o "$BIN_DIR/$service" "./cmd/$service"
            log_info "$service built successfully"
        done
        
        log_section "All Services Built"
        ;;
        
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [service]|build}"
        exit 1
        ;;
esac
