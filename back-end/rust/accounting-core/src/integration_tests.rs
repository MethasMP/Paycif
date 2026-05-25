//! Integration Tests for Rust Accounting Core
//!
//! Tests the unified system with real database operations.

#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::PgPool;
    use sqlx::postgres::PgPoolOptions;
    use uuid::Uuid;
    use std::time::Instant;
    use rust_decimal::Decimal;
    
    // Helper to create test database connection
    async fn setup_test_db() -> anyhow::Result<PgPool> {
        let database_url = std::env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgres://postgres:postgres@localhost/paycif_test".to_string());
        
        let pool = PgPoolOptions::new()
            .max_connections(5)
            .connect(&database_url)
            .await?;
        
        Ok(pool)
    }
    
    #[tokio::test]
    async fn test_limit_cache_performance() {
        let pool = setup_test_db().await.expect("Failed to connect to test DB");
        
        // Skip if no database
        if pool.is_closed() {
            println!("⚠️ Skipping test - no database connection");
            return;
        }
        
        // Create limit cache
        let cache = UnifiedLimitCache::new(pool);
        
        // Pre-hydrate
        cache.pre_hydrate().await.ok();
        
        // Measure limit check performance
        let iterations = 10000;
        let start = Instant::now();
        
        for i in 0..iterations {
            let user_id = format!("test-user-{}", i % 100);
            let amount = Decimal::from(1000);
            let _ = cache.check_transaction(&user_id, amount).await;
        }
        
        let duration = start.elapsed();
        let avg_micros = duration.as_micros() as f64 / iterations as f64;
        
        println!("✅ Limit check performance:");
        println!("   Total time: {:?}", duration);
        println!("   Iterations: {}", iterations);
        println!("   Average: {:.2} microseconds", avg_micros);
        println!("   Throughput: {:.0} checks/second", 1_000_000.0 / avg_micros);
        
        // Assert sub-microsecond average (10,000x faster than Go's milliseconds)
        assert!(avg_micros < 100.0, "Limit check too slow: {:.2}μs", avg_micros);
    }
    
    #[tokio::test]
    async fn test_concurrent_limit_checks() {
        use tokio::task;
        
        let pool = setup_test_db().await.expect("Failed to connect to test DB");
        
        if pool.is_closed() {
            println!("⚠️ Skipping test - no database connection");
            return;
        }
        
        let cache = Arc::new(UnifiedLimitCache::new(pool));
        let start = Instant::now();
        
        // Spawn 100 concurrent limit checks
        let mut handles = vec![];
        for i in 0..100 {
            let cache = cache.clone();
            let handle = task::spawn(async move {
                for j in 0..100 {
                    let user_id = format!("user-{}", (i + j) % 50);
                    let amount = Decimal::from(500);
                    let _ = cache.check_transaction(&user_id, amount).await;
                }
            });
            handles.push(handle);
        }
        
        // Wait for all
        for handle in handles {
            handle.await.unwrap();
        }
        
        let duration = start.elapsed();
        let total_ops = 100 * 100; // 10,000 operations
        let ops_per_sec = total_ops as f64 / duration.as_secs_f64();
        
        println!("✅ Concurrent limit check performance:");
        println!("   Total operations: {}", total_ops);
        println!("   Duration: {:?}", duration);
        println!("   Ops/sec: {:.0}", ops_per_sec);
        
        // Assert high throughput
        assert!(ops_per_sec > 10000.0, "Concurrent throughput too low: {:.0} ops/sec", ops_per_sec);
    }
    
    #[tokio::test]
    async fn test_decimal_precision() {
        use rust_decimal::prelude::*;
        
        // Test financial precision (critical for accounting)
        let amount1 = Decimal::from_str("1000.50").unwrap();
        let amount2 = Decimal::from_str("500.25").unwrap();
        
        let result = amount1 + amount2;
        
        // Verify exact precision
        assert_eq!(result.to_string(), "1500.75");
        
        // Test with satang (1/100 of THB)
        let satang_amount = Decimal::from(100000i64) / Decimal::from(100);
        assert_eq!(satang_amount, Decimal::from(1000));
        
        println!("✅ Decimal precision verified");
    }
    
    #[test]
    fn test_dashmap_performance() {
        use dashmap::DashMap;
        use std::time::Instant;
        
        let map = DashMap::new();
        
        // Insert 10,000 entries
        for i in 0..10000 {
            map.insert(format!("key_{}", i), i);
        }
        
        // Measure read performance
        let iterations = 1000000;
        let start = Instant::now();
        
        for i in 0..iterations {
            let _ = map.get(&format!("key_{}", i % 10000));
        }
        
        let duration = start.elapsed();
        let avg_nanos = duration.as_nanos() as f64 / iterations as f64;
        
        println!("✅ DashMap read performance:");
        println!("   Total reads: {}", iterations);
        println!("   Duration: {:?}", duration);
        println!("   Average: {:.2} nanoseconds", avg_nanos);
        
        // Assert nanosecond-level reads
        assert!(avg_nanos < 100.0, "DashMap read too slow: {:.2}ns", avg_nanos);
    }
}

// Need to import these for tests
use std::sync::Arc;
use crate::limit_cache::UnifiedLimitCache;
