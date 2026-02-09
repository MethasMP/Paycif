//! High-Performance FX Engine (Upgraded & Protocol-Matched)
//!
//! Features:
//! - 🧠 Jemalloc: Optimized Memory Allocator
//! - 🔓 DashMap: Lock-Free Concurrent Hash Maps
//! - ⚡ UDS Support: Unix Domain Sockets for IPC speedup
//! - 🔢 Decimal Math: Zero-error financial calculations

use anyhow::Result;
use chrono::Utc;
use dashmap::DashMap; // 🔓 Lock-Free Map
#[cfg(not(target_os = "windows"))]
use jemallocator::Jemalloc; // 🧠 Memory Optimizer
use rust_decimal::prelude::*;
use rust_decimal::Decimal;
use rust_decimal_macros::dec;
use ed25519_dalek::{Verifier, VerifyingKey, Signature}; // 🛡️ Cryptography
use std::collections::HashMap;
use std::env;
use std::sync::Arc;
use std::time::{Duration, Instant};
#[cfg(unix)]
use tokio::net::UnixListener;
#[cfg(unix)]
use tokio_stream::wrappers::UnixListenerStream;
use tokio_stream::StreamExt; // 📡 For Pub/Sub Stream
use tonic::{transport::Server, Request, Response, Status};
use tracing::info;

// 🧠 1. Secret Weapon: Jemalloc
// Replaces the system allocator to reduce fragmentation and improve concurrent scaling.
#[cfg(not(target_os = "windows"))]
#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;

// Include generated protobuf code
pub mod fx {
    tonic::include_proto!("fx");
}

mod rate_provider;
mod redis_cache;
mod limit_cache;
#[cfg(test)]
mod memory_tests;

use limit_cache::LimitCache;

use fx::fx_service_server::{FxService, FxServiceServer};
use fx::{
    AllRatesRequest, AllRatesResponse, ConvertRequest, ConvertResponse,
    FxHealthRequest, FxHealthResponse, RateRequest, RateResponse,
    UpdateRateRequest, UpdateRateResponse,
    VerifySignatureRequest, VerifySignatureResponse,
    GetLimitsRequest, GetLimitsResponse,
    PreValidateTransferRequest, PreValidateTransferResponse,
};

const MAX_DAILY_LIMIT: i64 = 3000;
const MAX_TRANSACTION_LIMIT: i64 = 3000;
const MIN_TRANSACTION_LIMIT: i64 = 500;

/// Cached exchange rate with metadata and TTL
#[derive(Debug, Clone)]
pub struct CachedRate {
    pub rate: Decimal,
    pub last_updated: i64,
    pub expires_at: i64,
    pub source: String,
}

impl CachedRate {
    /// Check if the rate has expired
    pub fn is_expired(&self) -> bool {
        Utc::now().timestamp() > self.expires_at
    }

    /// Check if the rate has expired at a specific timestamp
    pub fn is_expired_at(&self, timestamp: i64) -> bool {
        timestamp > self.expires_at
    }

    /// Create a new rate with TTL in seconds
    pub fn new(rate: Decimal, source: String, ttl_seconds: i64) -> Self {
        let now = Utc::now().timestamp();
        Self {
            rate,
            last_updated: now,
            expires_at: now + ttl_seconds,
            source,
        }
    }
}

/// FX Engine service implementation
/// Uses DashMap for Lock-Free concurrent access
pub struct FxEngineService {
    // 🔓 2. Secret Weapon: Lock-Free DashMap
    cache: Arc<DashMap<String, CachedRate>>,
    #[allow(dead_code)]
    redis_cache: Arc<redis_cache::RedisCache>, // Kept for rate caching only
    limit_cache: Arc<LimitCache>, // 🚀 NEW: In-Memory Limit Cache (replaces Redis for limits)
    start_time: Instant,
}

impl FxEngineService {
    fn new(default_ttl_seconds: i64, redis_cache: Arc<redis_cache::RedisCache>, limit_cache: Arc<LimitCache>) -> Self {
        let cache = Arc::new(DashMap::new());
        // Initialize Default Pair with TTL
        cache.insert(
            "USD:THB".to_string(),
            CachedRate::new(dec!(35.50), "default".to_string(), default_ttl_seconds),
        );
        Self {
            cache,
            redis_cache,
            limit_cache,
            start_time: Instant::now(),
        }
    }

    /// Helper to get rate key
    fn key(from: &str, to: &str) -> String {
        format!("{}:{}", from.to_uppercase(), to.to_uppercase())
    }

    /// Helper to find rate with fallback to Inverse and Cross-rate (triangular) calculation
    fn find_rate(&self, from: &str, to: &str) -> Option<(Decimal, String, i64)> {
        let from = from.to_uppercase();
        let to = to.to_uppercase();

        if from == to {
            return Some((Decimal::ONE, "identity".to_string(), Utc::now().timestamp()));
        }

        // 1. Try Direct match
        let key = Self::key(&from, &to);
        if let Some(entry) = self.cache.get(&key) {
            if !entry.is_expired() {
                return Some((entry.rate, entry.source.clone(), entry.last_updated));
            }
        }

        // 2. Try Inverse match
        let inv_key = Self::key(&to, &from);
        if let Some(entry) = self.cache.get(&inv_key) {
            if !entry.is_expired() {
                return Some((
                    Decimal::ONE / entry.rate,
                    format!("{}-inverted", entry.source),
                    entry.last_updated,
                ));
            }
        }

        // 3. Try Triangular Cross-rate via Pivot (USD, then EUR)
        for pivot in ["USD", "EUR"] {
            if from == pivot || to == pivot {
                continue;
            }

            if let (Some(r1), Some(r2)) = (
                self.get_direct_or_inverse(&from, pivot),
                self.get_direct_or_inverse(pivot, &to),
            ) {
                return Some((
                    r1.0 * r2.0,
                    format!("{}+{}-cross", r1.1, r2.1),
                    r1.2.min(r2.2),
                ));
            }
        }

        None
    }

    /// Internal helper for single-hop (direct or inverse)
    fn get_direct_or_inverse(&self, from: &str, to: &str) -> Option<(Decimal, String, i64)> {
        let key = Self::key(from, to);
        if let Some(entry) = self.cache.get(&key) {
            if !entry.is_expired() {
                return Some((entry.rate, entry.source.clone(), entry.last_updated));
            }
        }
        let inv_key = Self::key(to, from);
        if let Some(entry) = self.cache.get(&inv_key) {
            if !entry.is_expired() {
                return Some((
                    Decimal::ONE / entry.rate,
                    format!("{}-inverted", entry.source),
                    entry.last_updated,
                ));
            }
        }
        None
    }

    /// Remove expired entries from cache and return count of removed entries
    #[allow(dead_code)]
    fn clean_expired(&self) -> usize {
        let mut removed = 0;
        let now = Utc::now().timestamp();
        
        // Collect keys of expired entries
        let expired_keys: Vec<String> = self.cache
            .iter()
            .filter(|entry| entry.value().is_expired_at(now))
            .map(|entry| entry.key().clone())
            .collect();
        
        // Remove expired entries
        for key in expired_keys {
            if self.cache.remove(&key).is_some() {
                removed += 1;
            }
        }
        
        removed
    }
}

#[tonic::async_trait]
impl FxService for FxEngineService {
    /// Get exchange rate
    async fn get_rate(
        &self,
        request: Request<RateRequest>,
    ) -> Result<Response<RateResponse>, Status> {
        let req = request.into_inner();
        
        if let Some((rate, source, last_updated)) = self.find_rate(&req.from_currency, &req.to_currency) {
            let inv_rate = Decimal::ONE / rate;
            return Ok(Response::new(RateResponse {
                success: true,
                rate: rate.to_string(),
                inverse_rate: inv_rate.to_string(),
                last_updated,
                source,
                error_message: "".to_string(),
            }));
        }

        Ok(Response::new(RateResponse {
            success: false,
            rate: "0".to_string(),
            inverse_rate: "0".to_string(),
            last_updated: 0,
            source: "".to_string(),
            error_message: "Rate not found (even with cross-rate lookup)".to_string(),
        }))
    }

    /// Update a rate (Control Plane)
    async fn update_rate(
        &self,
        request: Request<UpdateRateRequest>,
    ) -> Result<Response<UpdateRateResponse>, Status> {
        let req = request.into_inner();
        
        // Parse String -> Decimal
        let rate_decimal = Decimal::from_str(&req.rate)
            .map_err(|_| Status::invalid_argument("Invalid rate format"))?;

        if rate_decimal <= Decimal::ZERO {
            return Err(Status::invalid_argument("Rate must be positive"));
        }

        let key = Self::key(&req.from_currency, &req.to_currency);
        
        // ⚡ Fast Lock-Free Write with TTL
        self.cache.insert(
            key,
            CachedRate::new(rate_decimal, req.source.clone(), 3600), // 1 hour TTL
        );

        info!("Rate updated: {} -> {} = {} (TTL: 1 hour)", req.from_currency, req.to_currency, req.rate);

        Ok(Response::new(UpdateRateResponse {
            success: true,
            message: "Rate updated via DashMap".to_string(),
        }))
    }

    /// Convert amount
    async fn convert(
        &self,
        request: Request<ConvertRequest>,
    ) -> Result<Response<ConvertResponse>, Status> {
        let req = request.into_inner();
        let amount_dec = Decimal::from(req.amount);

        if let Some((rate, _, last_updated)) = self.find_rate(&req.from_currency, &req.to_currency) {
            let converted = amount_dec * rate;
            let converted_int = converted.round().to_i64().unwrap_or(0);

            return Ok(Response::new(ConvertResponse {
                success: true,
                converted_amount: converted_int,
                rate_used: rate.to_string(),
                error_message: "".to_string(),
                timestamp: last_updated,
            }));
        }

        Ok(Response::new(ConvertResponse {
            success: false,
            converted_amount: 0,
            rate_used: "0".to_string(),
            error_message: "Pair not found".to_string(),
            timestamp: 0,
        }))
    }

    async fn get_all_rates(
        &self,
        request: Request<AllRatesRequest>,
    ) -> Result<Response<AllRatesResponse>, Status> {
        let base = request.into_inner().base_currency.to_uppercase();
        let prefix = format!("{}:", base);

        // Collect into HashMap<String, String> as per Proto
        let mut rates_map = HashMap::new();
        
        for entry in self.cache.iter() {
            if entry.key().starts_with(&prefix) {
                 let target = entry.key().strip_prefix(&prefix).unwrap_or("UNKNOWN").to_string();
                 rates_map.insert(target, entry.value().rate.to_string());
            }
        }

        Ok(Response::new(AllRatesResponse {
            success: true,
            base_currency: base,
            rates: rates_map,
            last_updated: Utc::now().timestamp(),
        }))
    }

    async fn verify_signature(
        &self,
        request: Request<VerifySignatureRequest>,
    ) -> Result<Response<VerifySignatureResponse>, Status> {
        let req = request.into_inner();

        // 1. Validation: Key Length (Ed25519 public keys are 32 bytes)
        if req.public_key.len() != 32 {
            return Ok(Response::new(VerifySignatureResponse {
                valid: false,
                error_message: "Invalid Public Key length (must be 32 bytes)".to_string(),
            }));
        }

        // 2. Validation: Signature Length (Ed25519 signatures are 64 bytes)
        if req.signature.len() != 64 {
            return Ok(Response::new(VerifySignatureResponse {
                valid: false,
                error_message: "Invalid Signature length (must be 64 bytes)".to_string(),
            }));
        }

        // 3. Parse Public Key
        let public_key_bytes: [u8; 32] = match req.public_key.try_into() {
            Ok(bytes) => bytes,
            Err(_) => return Err(Status::internal("Failed to convert public key bytes")),
        };
        
        let verifying_key = match VerifyingKey::from_bytes(&public_key_bytes) {
            Ok(vk) => vk,
            Err(_) => return Ok(Response::new(VerifySignatureResponse {
                valid: false,
                error_message: "Invalid Public Key format".to_string(),
            })),
        };

        // 4. Parse Signature
        let signature_bytes: [u8; 64] = match req.signature.try_into() {
            Ok(bytes) => bytes,
            Err(_) => return Err(Status::internal("Failed to convert signature bytes")),
        };
        
        let signature = Signature::from_bytes(&signature_bytes);

        // 5. Verify (SIMD Accelerated)
        match verifying_key.verify(&req.message, &signature) {
            Ok(_) => Ok(Response::new(VerifySignatureResponse {
                valid: true,
                error_message: "".to_string(),
            })),
            Err(_) => Ok(Response::new(VerifySignatureResponse {
                valid: false,
                error_message: "Signature verification failed".to_string(),
            })),
        }
    }

    async fn get_limits(
        &self,
        request: Request<GetLimitsRequest>,
    ) -> Result<Response<GetLimitsResponse>, Status> {
        let req = request.into_inner();
        let user_id = req.user_id;

        tracing::info!("📊 GetLimits request | user_id={}", user_id);

        // 🚀 Use In-Memory LimitCache (Postgres-backed) instead of Redis
        let usage = self.limit_cache.get_daily_usage(&user_id).await;
        let usage_f64 = usage.to_f64().unwrap_or(0.0);

        let max_daily = self.limit_cache.max_daily_limit().to_f64().unwrap_or(MAX_DAILY_LIMIT as f64);
        let remaining = (max_daily - usage_f64).max(0.0);

        Ok(Response::new(GetLimitsResponse {
            success: true,
            max_daily_amount: max_daily,
            remaining_daily_amount: remaining,
            current_daily_total: usage_f64,
            max_transaction_amount: self.limit_cache.max_transaction_limit().to_f64().unwrap_or(MAX_TRANSACTION_LIMIT as f64),
            error_message: "".to_string(),
        }))
    }

    async fn pre_validate_transfer(
        &self,
        request: Request<PreValidateTransferRequest>,
    ) -> Result<Response<PreValidateTransferResponse>, Status> {
        let req = request.into_inner();

        // 1. Amount Check
        if req.amount <= 0 {
            return Ok(Response::new(PreValidateTransferResponse {
                valid: false,
                signature_valid: false, // Not checked
                limits_valid: false,
                error_message: "Amount must be positive".to_string(),
                remaining_daily_amount: 0.0,
            }));
        }

        let amount_major = (req.amount as f64) / 100.0; // Assume minor units (satang) to major units (THB)

        if amount_major > MAX_TRANSACTION_LIMIT as f64 {
            return Ok(Response::new(PreValidateTransferResponse {
                valid: false,
                signature_valid: false,
                limits_valid: false,
                error_message: format!("Amount exceeds transaction limit of {}", MAX_TRANSACTION_LIMIT),
                remaining_daily_amount: 0.0,
            }));
        }

        if amount_major < MIN_TRANSACTION_LIMIT as f64 {
            return Ok(Response::new(PreValidateTransferResponse {
                valid: false,
                signature_valid: false,
                limits_valid: false,
                error_message: format!("Amount is below minimum requirement of {}", MIN_TRANSACTION_LIMIT),
                remaining_daily_amount: 0.0,
            }));
        }

        // 2. Signature Verification (Ed25519)
        if req.public_key.len() != 32 || req.signature.len() != 64 {
             return Ok(Response::new(PreValidateTransferResponse {
                valid: false,
                signature_valid: false,
                limits_valid: false,
                error_message: "Invalid key/signature length".to_string(),
                remaining_daily_amount: 0.0,
            }));
        }

        let public_key_bytes: [u8; 32] = match req.public_key.try_into() {
            Ok(b) => b,
            Err(_) => return Err(Status::internal("Key conversion failed")),
        };
        let signature_bytes: [u8; 64] = match req.signature.try_into() {
            Ok(b) => b,
            Err(_) => return Err(Status::internal("Signature conversion failed")),
        };

        let verifying_key = VerifyingKey::from_bytes(&public_key_bytes).map_err(|_| Status::invalid_argument("Invalid Public Key"))?;
        let signature = Signature::from_bytes(&signature_bytes);

        if verifying_key.verify(&req.message, &signature).is_err() {
            return Ok(Response::new(PreValidateTransferResponse {
                valid: false,
                signature_valid: false,
                limits_valid: false, // Won't check limit if sig fails to save Redis calls
                error_message: "Signature verification failed".to_string(),
                remaining_daily_amount: 0.0,
            }));
        }

        // 3. Limit Check (In-Memory with Postgres Hydration - replaces Redis)
        let (limits_ok, limit_error, remaining_after) = self.limit_cache.check_limits(&req.user_id, rust_decimal::Decimal::from_f64_retain(amount_major).unwrap_or_default()).await;

        if !limits_ok {
            return Ok(Response::new(PreValidateTransferResponse {
                valid: false,
                signature_valid: true,
                limits_valid: false,
                error_message: limit_error,
                remaining_daily_amount: remaining_after.to_f64().unwrap_or(0.0),
            }));
        }

        // 🚀 Optimistic Reservation: Reserve the limit in RAM immediately
        // This prevents race conditions for concurrent requests
        let remaining = self.limit_cache.reserve_limit(
            &req.user_id, 
            rust_decimal::Decimal::from_f64_retain(amount_major).unwrap_or_default()
        );

        // All Valid!
        Ok(Response::new(PreValidateTransferResponse {
            valid: true,
            signature_valid: true,
            limits_valid: true,
            error_message: "".to_string(),
            remaining_daily_amount: remaining.to_f64().unwrap_or(0.0),
        }))
    }

    async fn health_check(
        &self,
        _request: Request<FxHealthRequest>,
    ) -> Result<Response<FxHealthResponse>, Status> {
        Ok(Response::new(FxHealthResponse {
            healthy: true,
            version: "2.0-jemalloc-uds".to_string(),
            cached_pairs: self.cache.len() as i32,
            uptime_seconds: self.start_time.elapsed().as_secs() as i64,
        }))
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    // Load .env
    dotenv::dotenv().ok();
    
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .init();

    info!("🚀 Rust FX Engine v3.0 Starting...");
    info!("   🧠 Memory: Jemalloc (Optimized)");
    info!("   🔓 Cache: DashMap (Lock-Free)");
    info!("   📦 Redis: Persistent Cache");
    info!("   🌍 Rate Providers: ECB + OpenExchangeRates");

    // Configuration
    let default_ttl: i64 = env::var("RATE_TTL_SECONDS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(3600); // 1 hour default
    
    let cleanup_interval: u64 = env::var("CLEANUP_INTERVAL_SECONDS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(300); // 5 minutes
    
    let refresh_interval: u64 = env::var("REFRESH_INTERVAL_SECONDS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1800); // 30 minutes

    // Initialize Redis cache (kept for FX rate caching)
    let redis_cache = Arc::new(redis_cache::RedisCache::new());
    
    // 🚀 Initialize In-Memory Limit Cache (replaces Redis for user limits)
    let limit_cache = Arc::new(LimitCache::with_defaults());
    // Try to connect to Postgres for hydration
    if let Err(e) = limit_cache.init_db().await {
        tracing::warn!("⚠️ LimitCache DB init failed: {}. Will operate in memory-only mode.", e);
    } else {
        // Run initial pre-hydration
        let lc = limit_cache.clone();
        tokio::spawn(async move {
            if let Err(e) = lc.pre_hydrate_recent_users().await {
                tracing::error!("❌ Pre-hydration failed: {}", e);
            }
        });
    }
    
    // Background: Periodic Limit Refresh (to reflect updates from other Go nodes if any)
    let lc_periodic = limit_cache.clone();
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(300)).await; // Every 5 minutes
            if let Err(e) = lc_periodic.pre_hydrate_recent_users().await {
                tracing::error!("❌ Periodic hydration refresh failed: {}", e);
            }
        }
    });
    
    // Initialize service with both caches
    let service = FxEngineService::new(default_ttl, redis_cache.clone(), limit_cache.clone());
    let cache_ref = service.cache.clone();
    
    // Load rates from Redis on startup (cache warmup)
    if redis_cache.is_available() {
        let cached_rates = redis_cache.load_all_rates().await;
        for (key, rate, source) in cached_rates {
            service.cache.insert(key, CachedRate::new(rate, source, default_ttl));
        }
    }

    // 📡 Background: Redis Pub/Sub Listener (The "Pro" Sync Layer)
    // This allows multiple Rust instances to stay in sync in real-time.
    let lc_pubsub = limit_cache.clone();
    let redis_url = env::var("REDIS_URL").unwrap_or_else(|_| "redis://127.0.0.1:6379/0".to_string());
    tokio::spawn(async move {
        let client = match redis::Client::open(redis_url) {
            Ok(c) => c,
            Err(e) => {
                tracing::error!("❌ Failed to open Redis for Pub/Sub: {}", e);
                return;
            }
        };

        loop {
            // Note: In newer redis crates (0.32+), we can get a pubsub directly or 
            // via an async connection. We'll use get_async_pubsub for clarity.
            match client.get_async_pubsub().await {
                Ok(mut pubsub) => {
                    if let Err(e) = pubsub.subscribe("user_limit_updates").await {
                        tracing::error!("❌ Failed to subscribe to channel: {}", e);
                        tokio::time::sleep(Duration::from_secs(5)).await;
                        continue;
                    }

                    tracing::info!("📡 Rust FX Engine subscribed to 'user_limit_updates' channel");
                    let mut stream = pubsub.on_message();

                    while let Some(msg) = stream.next().await {
                        // Type annotation required for get_payload in this context
                        let payload: String = msg.get_payload::<String>().unwrap_or_default();
                        // Format: "user_id:amount"
                        let parts: Vec<&str> = payload.split(':').collect();
                        if parts.len() == 2 {
                            let user_id = parts[0];
                            if let Ok(amount) = Decimal::from_str(parts[1]) {
                                lc_pubsub.handle_remote_increment(user_id, amount);
                            }
                        }
                    }
                }
                Err(e) => {
                    tracing::error!("❌ Redis Pub/Sub connection lost: {}. Retrying in 5s...", e);
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    });

    // Background: Health Monitor
    let cache_health = cache_ref.clone();
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(60)).await;
            info!("❤️  Health Report: Cache Items: {}", cache_health.len());
        }
    });

    // Background: Cleanup expired rates
    let _cache_cleanup = cache_ref.clone();
    let default_ttl_cleanup = default_ttl;
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(cleanup_interval)).await;
            
            // Clean expired entries directly from cache
            let expired_keys: Vec<String> = _cache_cleanup
                .iter()
                .filter(|entry| entry.value().is_expired())
                .map(|entry| entry.key().clone())
                .collect();

            let count = expired_keys.len();
            for key in expired_keys {
                _cache_cleanup.remove(&key);
            }
            
            if count > 0 {
                info!("🧹 Cleaned up {} expired rates", count);
            }
        }
    });

    // Background: Rate refresh from providers
    let cache_refresh = cache_ref.clone();
    let redis_for_refresh = redis_cache.clone();
    tokio::spawn(async move {
        use rate_provider::{ECBProvider, MockProvider, OpenExchangeProvider, RateProviderManager};
        
        let mut provider_manager = RateProviderManager::new();
        
        // Add providers in order of preference
        provider_manager.add_provider(Box::new(ECBProvider::new()));
        
        // Add OpenExchangeRates if API key available
        if let Ok(key) = env::var("OPEN_EXCHANGE_RATES_APP_ID") {
            provider_manager.add_provider(Box::new(OpenExchangeProvider::new(key)));
        }

        provider_manager.add_provider(Box::new(MockProvider));
        
        loop {
            tokio::time::sleep(Duration::from_secs(refresh_interval)).await;
            
            // Periodically refresh major base currencies
            let bases = ["EUR", "USD", "GBP", "JPY"];
            for base in bases {
                match provider_manager.fetch_rates(base).await {
                    Ok(rates) => {
                        info!("🔄 Fetched {} rates from providers for base: {}", rates.len(), base);
                        
                        let mut redis_rates = Vec::new();
                        for rate in rates {
                            let key = format!("{}:{}", rate.from, rate.to);
                            cache_refresh.insert(
                                key.clone(),
                                CachedRate::new(rate.rate, rate.source.clone(), default_ttl_cleanup / 2),
                            );
                            redis_rates.push((key, rate.rate, rate.source));
                        }
                        
                        // Save to Redis
                        redis_for_refresh.save_all_rates(&redis_rates, default_ttl_cleanup as usize).await;
                    }
                    Err(e) => {
                        tracing::warn!("Failed to refresh rates for {}: {}", base, e);
                    }
                }
                // Small delay between bases to avoid rate limiting
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
        }
    });

    // ⚡ 3. Secret Weapon: UDS (Unix Domain Socket) for IPC
    
    let uds_path = env::var("FX_ENGINE_UDS").unwrap_or_default();
    
    if !uds_path.is_empty() {
        // IPC Mode
        #[cfg(unix)]
        {
            info!("⚡ Starting in IPC Mode on UDS: {}", uds_path);
            
            // Clean up old socket file
            let _ = std::fs::remove_file(&uds_path);
            
            // Create Unix Listener
            let uds = UnixListener::bind(&uds_path)?;
            let uds_stream = UnixListenerStream::new(uds);
            
            // Set permissions (777 for dev, restrict in prod)
            use std::os::unix::fs::PermissionsExt;
            let _ = std::fs::set_permissions(&uds_path, std::fs::Permissions::from_mode(0o777));

            Server::builder()
                .add_service(FxServiceServer::new(service))
                .serve_with_incoming_shutdown(uds_stream, async {
                    let _ = tokio::signal::ctrl_c().await;
                    info!("🛑 Shutting down FX Engine (IPC)...");
                    let _ = std::fs::remove_file(&uds_path);
                })
                .await?;
        }
        #[cfg(not(unix))]
        {
            error!("UDS is only supported on Unix systems!");
        }
    } else {
        // TCP Mode (Classic)
        let addr = "[::1]:50052".parse()?;
        info!("🌐 Starting in Network Mode on TCP: {}", addr);

        Server::builder()
            .add_service(FxServiceServer::new(service))
            .serve_with_shutdown(addr, async {
                let _ = tokio::signal::ctrl_c().await;
                info!("🛑 Shutting down FX Engine (TCP)...");
            })
            .await?;
    }

    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_key_generation() {
        assert_eq!(FxEngineService::key("USD", "THB"), "USD:THB");
        assert_eq!(FxEngineService::key("usd", "thb"), "USD:THB");
        assert_eq!(FxEngineService::key("EUR", "usd"), "EUR:USD");
    }

    #[test]
    fn test_service_creation() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        assert_eq!(service.cache.len(), 1); // Default USD:THB pair
        
        // Verify default rate exists
        let key = FxEngineService::key("USD", "THB");
        let entry = service.cache.get(&key).unwrap();
        assert_eq!(entry.rate, dec!(35.50));
        assert_eq!(entry.source, "default");
    }

    #[tokio::test]
    async fn test_get_rate_direct() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        let request = Request::new(RateRequest {
            from_currency: "USD".to_string(),
            to_currency: "THB".to_string(),
            request_id: "test-1".to_string(),
        });

        let response = service.get_rate(request).await.unwrap();
        let rate_response = response.into_inner();
        
        assert!(rate_response.success);
        assert_eq!(rate_response.rate, "35.50");
        assert!(!rate_response.inverse_rate.is_empty());
        assert!(rate_response.error_message.is_empty());
    }

    #[tokio::test]
    async fn test_get_rate_inverse() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        // Request THB->USD (should calculate inverse of USD->THB)
        let request = Request::new(RateRequest {
            from_currency: "THB".to_string(),
            to_currency: "USD".to_string(),
            request_id: "test-2".to_string(),
        });

        let response = service.get_rate(request).await.unwrap();
        let rate_response = response.into_inner();
        
        assert!(rate_response.success);
        // Rate should be approximately 1/35.50 = 0.028169...
        let rate: Decimal = rate_response.rate.parse().unwrap();
        let expected = Decimal::ONE / dec!(35.50);
        assert!((rate - expected).abs() < dec!(0.0001));
        assert!(rate_response.source.contains("inverted"));
    }

    #[tokio::test]
    async fn test_get_rate_not_found() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        let request = Request::new(RateRequest {
            from_currency: "XYZ".to_string(),
            to_currency: "ABC".to_string(),
            request_id: "test-3".to_string(),
        });

        let response = service.get_rate(request).await.unwrap();
        let rate_response = response.into_inner();
        
        assert!(!rate_response.success);
        assert_eq!(rate_response.rate, "0");
        assert!(!rate_response.error_message.is_empty());
    }

    #[tokio::test]
    async fn test_update_rate() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        let request = Request::new(UpdateRateRequest {
            from_currency: "EUR".to_string(),
            to_currency: "USD".to_string(),
            rate: "1.0850".to_string(),
            source: "test".to_string(),
        });

        let response = service.update_rate(request).await.unwrap();
        let update_response = response.into_inner();
        
        assert!(update_response.success);
        assert!(update_response.message.contains("updated"));

        // Verify the rate was stored
        let key = FxEngineService::key("EUR", "USD");
        let entry = service.cache.get(&key).unwrap();
        assert_eq!(entry.rate, dec!(1.0850));
        assert_eq!(entry.source, "test");
    }

    #[tokio::test]
    async fn test_update_rate_invalid_format() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        let request = Request::new(UpdateRateRequest {
            from_currency: "EUR".to_string(),
            to_currency: "USD".to_string(),
            rate: "invalid".to_string(),
            source: "test".to_string(),
        });

        let result = service.update_rate(request).await;
        assert!(result.is_err());
        
        let status = result.unwrap_err();
        assert_eq!(status.code(), tonic::Code::InvalidArgument);
    }

    #[tokio::test]
    async fn test_update_rate_negative() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        let request = Request::new(UpdateRateRequest {
            from_currency: "EUR".to_string(),
            to_currency: "USD".to_string(),
            rate: "-1.0".to_string(),
            source: "test".to_string(),
        });

        let result = service.update_rate(request).await;
        assert!(result.is_err());
        
        let status = result.unwrap_err();
        assert_eq!(status.code(), tonic::Code::InvalidArgument);
    }

    #[tokio::test]
    async fn test_convert_direct_rate() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        // Convert 100 USD to THB (should be 100 * 35.50 = 3550)
        let request = Request::new(ConvertRequest {
            from_currency: "USD".to_string(),
            to_currency: "THB".to_string(),
            amount: 100,
            request_id: "test-4".to_string(),
        });

        let response = service.convert(request).await.unwrap();
        let convert_response = response.into_inner();
        
        assert!(convert_response.success);
        assert_eq!(convert_response.converted_amount, 3550);
        assert_eq!(convert_response.rate_used, "35.50");
        assert!(convert_response.error_message.is_empty());
    }

    #[tokio::test]
    async fn test_convert_inverse_rate() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        // Convert 3550 THB to USD (should be approximately 100)
        let request = Request::new(ConvertRequest {
            from_currency: "THB".to_string(),
            to_currency: "USD".to_string(),
            amount: 3550,
            request_id: "test-5".to_string(),
        });

        let response = service.convert(request).await.unwrap();
        let convert_response = response.into_inner();
        
        assert!(convert_response.success);
        // Should be approximately 100 (3550 / 35.50 = 100)
        assert!((convert_response.converted_amount - 100).abs() <= 1);
        assert!(convert_response.rate_used.contains("0.028"));
    }

    #[tokio::test]
    async fn test_convert_not_found() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        let request = Request::new(ConvertRequest {
            from_currency: "XYZ".to_string(),
            to_currency: "ABC".to_string(),
            amount: 1000,
            request_id: "test-6".to_string(),
        });

        let response = service.convert(request).await.unwrap();
        let convert_response = response.into_inner();
        
        assert!(!convert_response.success);
        assert_eq!(convert_response.converted_amount, 0);
        assert!(!convert_response.error_message.is_empty());
    }

    #[tokio::test]
    async fn test_get_all_rates() {
        let redis_cache = Arc::new(redis_cache::RedisCache::new());
        let service = FxEngineService::new(3600, redis_cache);
        
        // Add some rates for EUR
        service.cache.insert(
            FxEngineService::key("EUR", "USD"),
            CachedRate::new(dec!(1.0850), "test".to_string(), 3600),
        );
        service.cache.insert(
            FxEngineService::key("EUR", "GBP"),
            CachedRate::new(dec!(0.8500), "test".to_string(), 3600),
        );

        let request = Request::new(AllRatesRequest {
            base_currency: "EUR".to_string(),
            request_id: "test-7".to_string(),
        });

        let response = service.get_all_rates(request).await.unwrap();
        let all_rates_response = response.into_inner();
        
        assert!(all_rates_response.success);
        assert_eq!(all_rates_response.base_currency, "EUR");
        assert_eq!(all_rates_response.rates.len(), 2);
        assert!(all_rates_response.rates.contains_key("USD"));
        assert!(all_rates_response.rates.contains_key("GBP"));
    }

    #[tokio::test]
    async fn test_health_check() {
        let service = FxEngineService::new(3600);
        
        let request = Request::new(FxHealthRequest {});

        let response = service.health_check(request).await.unwrap();
        let health_response = response.into_inner();
        
        assert!(health_response.healthy);
        assert!(!health_response.version.is_empty());
        assert!(health_response.cached_pairs >= 0);
        assert!(health_response.uptime_seconds >= 0);
    }

    #[test]
    fn test_decimal_math_precision() {
        // Test that decimal math maintains precision
        let rate = dec!(35.50);
        let amount = Decimal::from(100i64);
        let converted = amount * rate;
        
        assert_eq!(converted, dec!(3550.00));
        
        // Test inverse calculation (limited to 28 decimal places)
        let inverse = Decimal::ONE / rate;
        let expected = Decimal::from_str("0.0281690140845070422535211267").unwrap();
        assert!((inverse - expected).abs() < dec!(0.0000000001));
    }
}
