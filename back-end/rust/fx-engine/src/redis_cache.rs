use deadpool_redis::{Config, Pool, Runtime};
use redis::AsyncCommands;
use rust_decimal::Decimal;
use rust_decimal::prelude::FromStr;
use std::env;

/// Redis-backed cache for exchange rates
pub struct RedisCache {
    pool: Option<Pool>,
}

impl RedisCache {
    /// Create new Redis cache from environment
    pub fn new() -> Self {
        let redis_url = env::var("REDIS_URL").unwrap_or_else(|_| {
            // Default to localhost
            "redis://127.0.0.1:6379/0".to_string()
        });

        let cfg = Config::from_url(&redis_url);
        match cfg.create_pool(Some(Runtime::Tokio1)) {
            Ok(pool) => {
                tracing::info!("✅ Redis cache initialized");
                Self { pool: Some(pool) }
            }
            Err(e) => {
                tracing::warn!("⚠️ Failed to connect to Redis: {}. Using in-memory only.", e);
                Self { pool: None }
            }
        }
    }

    /// Check if Redis is available
    pub fn is_available(&self) -> bool {
        self.pool.is_some()
    }

    /// Save rate to Redis
    #[allow(dead_code)]
    pub async fn save_rate(&self, key: &str, rate: Decimal, source: &str, ttl_seconds: usize) {
        if let Some(ref pool) = self.pool {
            let mut conn = match pool.get().await {
                Ok(conn) => conn,
                Err(e) => {
                    tracing::warn!("Failed to get Redis connection: {}", e);
                    return;
                }
            };

            let value = format!("{}:{}", rate, source);
            let redis_key = format!("fx:rate:{}", key);
            
            let _: Result<(), _> = redis::cmd("SETEX")
                .arg(&redis_key)
                .arg(ttl_seconds)
                .arg(&value)
                .query_async(&mut conn)
                .await;
        }
    }

    /// Load rate from Redis
    #[allow(dead_code)]
    pub async fn load_rate(&self, key: &str) -> Option<(Decimal, String)> {
        if let Some(ref pool) = self.pool {
            let mut conn = pool.get().await.ok()?;
            
            let redis_key = format!("fx:rate:{}", key);
            let value: Option<String> = conn.get(&redis_key).await.ok()?;
            
            if let Some(val) = value {
                let parts: Vec<&str> = val.split(':').collect();
                if parts.len() >= 2 {
                    if let Ok(rate) = Decimal::from_str(parts[0]) {
                        return Some((rate, parts[1..].join(":")));
                    }
                }
            }
        }
        None
    }

    /// Save all rates (cache warmup)
    pub async fn save_all_rates(&self, rates: &[(String, Decimal, String)], ttl_seconds: usize) {
        if let Some(ref pool) = self.pool {
            let mut conn = match pool.get().await {
                Ok(conn) => conn,
                Err(e) => {
                    tracing::warn!("Failed to get Redis connection: {}", e);
                    return;
                }
            };

            let pipeline = redis::pipe();
            let mut pipeline = pipeline;
            
            for (key, rate, source) in rates {
                let value = format!("{}:{}", rate, source);
                let redis_key = format!("fx:rate:{}", key);
                pipeline.set_ex(&redis_key, &value, ttl_seconds as u64).ignore();
            }
            
            let _: Result<(), _> = pipeline.query_async(&mut conn).await;
            tracing::info!("💾 Saved {} rates to Redis", rates.len());
        }
    }

    /// Load all rates from Redis (cache warmup)
    pub async fn load_all_rates(&self) -> Vec<(String, Decimal, String)> {
        let mut result = Vec::new();
        
        if let Some(ref pool) = self.pool {
            let mut conn = match pool.get().await {
                Ok(conn) => conn,
                Err(e) => {
                    tracing::warn!("Failed to get Redis connection: {}", e);
                    return result;
                }
            };

            // Get all keys matching fx:rate:*
            let keys: Vec<String> = match redis::cmd("KEYS")
                .arg("fx:rate:*")
                .query_async(&mut conn)
                .await
            {
                Ok(keys) => keys,
                Err(_) => return result,
            };

            for key in keys {
                if let Ok(Some(value)) = conn.get::<_, Option<String>>(&key).await {
                    let parts: Vec<&str> = value.split(':').collect();
                    if parts.len() >= 2 {
                        if let Ok(rate) = Decimal::from_str(parts[0]) {
                            // Extract the currency pair from key (fx:rate:EUR:USD -> EUR:USD)
                            let pair = key.strip_prefix("fx:rate:")
                                .unwrap_or(&key)
                                .to_string();
                            result.push((pair, rate, parts[1..].join(":")));
                        }
                    }
                }
            }
            
            tracing::info!("📥 Loaded {} rates from Redis", result.len());
        }
        
        result
    }

    /// Get daily total usage for a user (in major units, e.g., THB)
    #[allow(dead_code)]
    pub async fn get_daily_user_total(&self, user_id: &str) -> Decimal {
        if let Some(ref pool) = self.pool {
            match pool.get().await {
                Ok(mut conn) => {
                    // Key assumes daily rotation or manual expiry management in Go
                    // Recommended key format: stats:user:{id}:daily_total
                    // Value should be float/decimal string
                    let key = format!("stats:user:{}:daily_total", user_id);
                    let val: Result<Option<String>, _> = conn.get(&key).await;
                    
                    if let Ok(Some(v)) = val {
                        return Decimal::from_str(&v).unwrap_or(Decimal::ZERO);
                    }
                },
                Err(e) => {
                    tracing::warn!("Failed to get Redis connection: {}", e);
                }
            }
        }
        Decimal::ZERO
    }

    /// Increment daily user total (for testing/mocking or if Rust becomes primary writer)
    #[allow(dead_code)]
    pub async fn increment_daily_user_total(&self, user_id: &str, amount: Decimal) {
        if let Some(ref pool) = self.pool {
            if let Ok(mut conn) = pool.get().await {
                let key = format!("stats:user:{}:daily_total", user_id);
                // INCRBYFLOAT is standard for accumulating decimal amounts
                let _: Result<f64, _> = redis::cmd("INCRBYFLOAT")
                    .arg(&key)
                    .arg(amount.to_string())
                    .query_async(&mut conn)
                    .await;
                
                // Set expiry to 24 hours if new key (simplified, ideally aligns with day boundary)
                let _: Result<(), _> = redis::cmd("EXPIRE")
                    .arg(&key)
                    .arg(86400)
                    .query_async(&mut conn)
                    .await;
            }
        }
    }
}

impl Default for RedisCache {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_redis_cache_creation() {
        // This will fail to connect if Redis is not running, which is OK
        let cache = RedisCache::new();
        // Just verify it doesn't panic
        assert!(cache.pool.is_none() || cache.is_available());
    }
}
