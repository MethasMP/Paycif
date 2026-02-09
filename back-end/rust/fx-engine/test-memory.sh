#!/bin/bash

# Memory Testing & Monitoring Script for FX Engine
# Usage: ./test-memory.sh [monitor|benchmark|leak|cache]

FX_BINARY="./target/release/fx_engine"
REDIS_URL="redis://127.0.0.1:6379/0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get memory usage of a process
get_memory_usage() {
    local pid=$1
    if [ -f "/proc/$pid/status" ]; then
        grep -E "VmRSS|VmSize" /proc/$pid/status | awk '{
            if ($1 == "VmRSS:") printf "RSS: %.2f MB\n", $2/1024
            if ($1 == "VmSize:") printf "VSZ: %.2f MB\n", $2/1024
        }'
    else
        echo "Process not found"
    fi
}

# Function to monitor memory over time
monitor_memory() {
    log_info "Starting memory monitor (Press Ctrl+C to stop)..."
    log_info "Monitoring FX Engine processes..."
    echo ""
    
    printf "%-10s %-10s %-12s %-12s %-10s\n" "TIME" "PID" "RSS(MB)" "VSZ(MB)" "CACHE"
    printf "%-10s %-10s %-12s %-12s %-10s\n" "----------" "----------" "------------" "------------" "----------"
    
    while true; do
        for pid in $(pgrep fx_engine); do
            if [ -f "/proc/$pid/status" ]; then
                rss=$(grep "VmRSS:" /proc/$pid/status | awk '{printf "%.2f", $2/1024}')
                vsz=$(grep "VmSize:" /proc/$pid/status | awk '{printf "%.2f", $2/1024}')
                time=$(date +%H:%M:%S)
                
                # Try to get cache size from Redis or log
                cache_size="N/A"
                
                printf "%-10s %-10s %-12s %-12s %-10s\n" "$time" "$pid" "$rss" "$vsz" "$cache_size"
            fi
        done
        sleep 2
    done
}

# Function to benchmark memory with different cache sizes
benchmark_memory() {
    log_info "Memory Benchmark Test"
    log_info "====================="
    echo ""
    
    # Build benchmark if not exists
    if [ ! -f "$FX_BINARY" ]; then
        log_warn "Binary not found. Building..."
        cargo build --release
    fi
    
    # Start FX Engine
    log_info "Starting FX Engine..."
    REDIS_URL=$REDIS_URL $FX_BINARY &
    FX_PID=$!
    sleep 3
    
    log_info "Baseline Memory (empty cache):"
    get_memory_usage $FX_PID
    echo ""
    
    # Simulate adding rates to cache using Redis
    log_info "Simulating cache growth..."
    
    # Add rates in batches
    for batch in 100 500 1000 5000 10000; do
        log_info "Adding $batch rate pairs..."
        
        # Add rates to Redis
        for i in $(seq 1 $batch); do
            # Generate random rate pairs
            from="CUR$(($i % 100))"
            to="CUR$(($i % 100 + 1))"
            rate=$(echo "scale=4; 1 + ($i % 100) / 100" | bc -l 2>/dev || echo "1.00")
            
            # Store in Redis
            docker exec paysif-redis redis-cli SETEX "fx:rate:${from}:${to}" 3600 "${rate}:benchmark" > /dev/null 2>&1
        done
        
        # Wait a moment and check memory
        sleep 1
        
        rss=$(grep "VmRSS:" /proc/$FX_PID/status 2>/dev/null | awk '{printf "%.2f", $2/1024}')
        cache_count=$(docker exec paysif-redis redis-cli KEYS 'fx:rate:*' 2>/dev/null | wc -l)
        
        printf "  Cache: %5s pairs | Memory: %6s MB\n" "$cache_count" "$rss"
    done
    
    echo ""
    log_info "Cleaning up..."
    docker exec paysif-redis redis-cli FLUSHDB > /dev/null 2>&1
    kill $FX_PID 2>/dev/null
    
    log_info "Benchmark complete!"
}

# Function to test for memory leaks
leak_test() {
    log_info "Memory Leak Test"
    log_info "================="
    echo ""
    
    if [ ! -f "$FX_BINARY" ]; then
        log_warn "Binary not found. Building..."
        cargo build --release
    fi
    
    # Check if valgrind is available
    if ! command -v valgrind &> /dev/null; then
        log_warn "Valgrind not installed. Installing..."
        brew install valgrind 2>/dev/null || apt-get install valgrind 2>/dev/null || echo "Please install valgrind manually"
    fi
    
    if command -v valgrind &> /dev/null; then
        log_info "Running Valgrind memory leak check (this will take a while)..."
        
        timeout 30 valgrind --leak-check=full \
            --show-leak-kinds=all \
            --track-origins=yes \
            --verbose \
            --log-file=/tmp/valgrind-fx-engine.log \
            $FX_BINARY &
        
        VALGRIND_PID=$!
        
        # Wait for valgrind to finish
        sleep 35
        
        if [ -f "/tmp/valgrind-fx-engine.log" ]; then
            echo ""
            log_info "Valgrind Results:"
            grep -E "(definitely lost|indirectly lost|possibly lost|still reachable)" /tmp/valgrind-fx-engine.log | head -10
            
            LEAKS=$(grep "definitely lost:" /tmp/valgrind-fx-engine.log | grep -v "0 bytes" | wc -l)
            if [ "$LEAKS" -eq 0 ]; then
                log_info "✅ No definite memory leaks detected!"
            else
                log_error "⚠️  Potential memory leaks found. Check /tmp/valgrind-fx-engine.log"
            fi
        fi
    else
        log_warn "Valgrind not available. Skipping leak test."
        log_info "To install: brew install valgrind (macOS) or apt-get install valgrind (Linux)"
    fi
}

# Function to show cache memory usage
cache_memory() {
    log_info "Cache Memory Analysis"
    log_info "====================="
    echo ""
    
    # Check Redis memory
    log_info "Redis Memory Usage:"
    docker exec paysif-redis redis-cli INFO memory 2>/dev/null | grep -E "used_memory:|used_memory_human:" | while read line; do
        echo "  $line"
    done
    
    echo ""
    log_info "Cache Statistics:"
    docker exec paysif-redis redis-cli KEYS 'fx:rate:*' 2>/dev/null | wc -l | xargs -I {} echo "  Total cached pairs: {}"
    
    # Show FX Engine memory
    echo ""
    log_info "FX Engine Process Memory:"
    for pid in $(pgrep fx_engine); do
        echo "  PID $pid:"
        get_memory_usage $pid | sed 's/^/    /'
    done
}

# Main menu
case "${1:-status}" in
    monitor|m)
        monitor_memory
        ;;
    benchmark|b)
        benchmark_memory
        ;;
    leak|l)
        leak_test
        ;;
    cache|c)
        cache_memory
        ;;
    status|s|*)
        echo "FX Engine Memory Testing Toolkit"
        echo "================================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  monitor, m     - Monitor memory usage in real-time"
        echo "  benchmark, b   - Run memory benchmark with cache growth"
        echo "  leak, l        - Run memory leak test (requires valgrind)"
        echo "  cache, c       - Show cache memory statistics"
        echo "  status, s      - Show this help message"
        echo ""
        echo "Current Status:"
        echo "---------------"
        
        # Show current memory
        for pid in $(pgrep fx_engine); do
            if [ -f "/proc/$pid/status" ]; then
                rss=$(grep "VmRSS:" /proc/$pid/status | awk '{printf "%.2f MB", $2/1024}')
                vsz=$(grep "VmSize:" /proc/$pid/status | awk '{printf "%.2f MB", $2/1024}')
                echo "  Process $pid: RSS=$rss, VSZ=$vsz"
            fi
        done
        
        # Show binary size
        if [ -f "$FX_BINARY" ]; then
            ls -lh $FX_BINARY | awk '{print "  Binary size: " $5}'
        fi
        ;;
esac
