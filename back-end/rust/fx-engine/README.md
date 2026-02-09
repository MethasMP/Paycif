# FX Engine v3.0 - High Performance Exchange Rate Service

High-performance Foreign Exchange (FX) engine built with Rust, featuring lock-free caching, Redis persistence, and automatic rate updates from external providers.

## 🚀 Features

- **⚡ High Performance**: Lock-free DashMap cache + Jemalloc memory allocator
- **🔒 Type-safe**: Decimal arithmetic with zero floating-point errors
- **📦 Redis Persistence**: Cache warmup on restart, distributed caching
- **🌍 Rate Providers**: ECB (free) + OpenExchangeRates (API key)
- **⏰ Auto Refresh**: Background tasks for cleanup & rate updates
- **🔌 Dual Transport**: TCP ([::1]:50052) or Unix Domain Socket
- **🧪 Well Tested**: 17 comprehensive tests

## 📁 Project Structure

```
back-end/rust/fx-engine/
├── src/
│   ├── main.rs           # Main service with gRPC endpoints
│   ├── rate_provider.rs  # External rate providers (ECB, OXR)
│   └── redis_cache.rs    # Redis integration
├── Cargo.toml
├── build.rs             # Protobuf generation
└── .env                 # Environment config
```

## 🛠️ Quick Start

### 1. Start Dependencies (Redis)

```bash
# In back-end directory
./start-redis.sh up
```

### 2. Build & Run

```bash
# Build release version
cargo build --release

# Run the server
cargo run --release

# Or use the helper script
./run-fx-engine.sh start
```

### 3. Test

```bash
# Run all tests
cargo test

# Check status
./run-fx-engine.sh status

# View logs
./run-fx-engine.sh logs
```

## ⚙️ Configuration

Create `.env` file:

```bash
# Redis
REDIS_URL=redis://127.0.0.1:6379/0

# Rate TTL (seconds)
RATE_TTL_SECONDS=3600        # 1 hour
CLEANUP_INTERVAL_SECONDS=300 # 5 minutes
REFRESH_INTERVAL_SECONDS=1800 # 30 minutes

# Logging
RUST_LOG=info

# Unix Domain Socket (optional)
# FX_ENGINE_UDS=/tmp/fx_engine.sock
```

## 📡 API Endpoints (gRPC)

### Get Rate
```protobuf
rpc GetRate(RateRequest) returns (RateResponse);

// Request
{
  "from_currency": "USD",
  "to_currency": "THB",
  "request_id": "uuid"
}

// Response
{
  "success": true,
  "rate": "35.50",
  "inverse_rate": "0.02817",
  "last_updated": 1704512345,
  "source": "ECB"
}
```

### Convert Currency
```protobuf
rpc Convert(ConvertRequest) returns (ConvertResponse);

// Request
{
  "from_currency": "USD",
  "to_currency": "THB",
  "amount": 100,  // in minor units (cents/satang)
  "request_id": "uuid"
}

// Response
{
  "success": true,
  "converted_amount": 3550,
  "rate_used": "35.50",
  "timestamp": 1704512345
}
```

### Update Rate (Admin)
```protobuf
rpc UpdateRate(UpdateRateRequest) returns (UpdateRateResponse);

// Request
{
  "from_currency": "EUR",
  "to_currency": "USD",
  "rate": "1.0850",
  "source": "manual"
}
```

### Health Check
```protobuf
rpc HealthCheck(FXHealthRequest) returns (FXHealthResponse);

// Response
{
  "healthy": true,
  "version": "3.0",
  "cached_pairs": 150,
  "uptime_seconds": 3600
}
```

## 🧪 Testing with grpcurl

```bash
# Get Rate
grpcurl -plaintext \
  -d '{"from_currency": "USD", "to_currency": "THB"}' \
  localhost:50052 fx.FXService/GetRate

# Convert
grpcurl -plaintext \
  -d '{"from_currency": "USD", "to_currency": "THB", "amount": 100}' \
  localhost:50052 fx.FXService/Convert

# Health Check
grpcurl -plaintext \
  localhost:50052 fx.FXService/HealthCheck

# Update Rate
grpcurl -plaintext \
  -d '{"from_currency": "EUR", "to_currency": "USD", "rate": "1.0850", "source": "test"}' \
  localhost:50052 fx.FXService/UpdateRate
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│           gRPC Clients                  │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      FX Engine Service (Tonic)          │
│  ┌─────────────────────────────────┐    │
│  │     Lock-free DashMap Cache     │    │
│  │  - O(1) reads/writes            │    │
│  │  - No mutex contention          │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │     Redis Cache (Optional)      │    │
│  │  - Persistence                  │    │
│  │  - Cache warmup                 │    │
│  │  - Distributed caching          │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │   Rate Provider Manager         │    │
│  │  - ECB (free)                   │    │
│  │  - OpenExchangeRates            │    │
│  │  - Auto fallback                │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## 🔄 Background Tasks

1. **Health Monitor** - Logs cache stats every 60s
2. **Cleanup** - Removes expired rates every 5 minutes
3. **Auto Refresh** - Fetches rates from providers every 30 minutes

## 📊 Performance

- **Cache Read**: ~50ns (lock-free)
- **Cache Write**: ~100ns (lock-free)
- **gRPC Latency**: <1ms (local)
- **Memory**: ~10MB base + ~1KB per rate pair

## 📝 Development

### Add New Rate Provider

```rust
use async_trait::async_trait;
use rate_provider::{RateProvider, ExchangeRate};

pub struct MyProvider;

#[async_trait]
impl RateProvider for MyProvider {
    async fn fetch_rates(&self, base: &str) -> Result<Vec<ExchangeRate>, Box<dyn std::error::Error + Send + Sync>> {
        // Implement provider logic
        Ok(vec![/* rates */])
    }
    
    fn name(&self) -> &'static str {
        "MyProvider"
    }
}
```

### Run Tests

```bash
# All tests
cargo test

# Specific test
cargo test test_convert_direct_rate

# With output
cargo test -- --nocapture
```

## 🛑 Troubleshooting

### Redis Connection Failed
```bash
# Check Redis status
docker ps | grep redis

# Restart Redis
./start-redis.sh down
./start-redis.sh up
```

### Port Already in Use
```bash
# Find process
lsof -i :50052

# Kill it
pkill fx_engine
```

### Build Errors
```bash
# Clean and rebuild
cargo clean
cargo build --release
```

## 🎯 Production Checklist

- [ ] Set `RUST_LOG=warn` (reduce logging)
- [ ] Configure TLS for gRPC
- [ ] Set up monitoring (Prometheus)
- [ ] Use Redis Cluster for HA
- [ ] Set up rate limiting
- [ ] Add API authentication
- [ ] Configure UDS with proper permissions (not 777)

## 📄 License

MIT License - See LICENSE file

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

---

Built with ❤️ using Rust + Tonic + DashMap + Redis
