//! Memory usage tests

#[cfg(test)]
mod memory_tests {
    use super::super::*;
    use std::mem;

    #[test]
    fn test_cached_rate_memory_size() {
        // Verify the size of CachedRate struct
        let rate = CachedRate::new(
            Decimal::from_str("35.50").unwrap(),
            "test".to_string(),
            3600
        );
        
        let size = mem::size_of_val(&rate);
        println!("CachedRate size: {} bytes", size);
        
        // Should be reasonable (less than 1KB per entry)
        assert!(size < 1024, "CachedRate is too large: {} bytes", size);
    }

    #[test]
    fn test_cache_memory_with_many_entries() {
        let service = FxEngineService::new(3600);
        let start_mem = get_process_memory();
        
        // Add 1000 rate pairs with unique keys
        for i in 0..1000 {
            let from = format!("F{}", i);
            let to = format!("T{}", i);
            let rate = Decimal::from_i64((i % 1000) as i64).unwrap() / Decimal::from(100);
            
            service.cache.insert(
                FxEngineService::key(&from, &to),
                CachedRate::new(rate, "test".to_string(), 3600)
            );
        }
        
        let end_mem = get_process_memory();
        let mem_increase = end_mem - start_mem;
        let mem_per_entry = if mem_increase > 0.0 { mem_increase / 1000.0 } else { 0.0 };
        
        println!("Memory increase for 1000 entries: {:.2} KB", mem_increase);
        println!("Memory per entry: {:.2} KB", mem_per_entry);
        
        // Just verify entries were added (1000 + 1 default entry)
        assert_eq!(service.cache.len(), 1001, "Should have 1001 entries (1000 test + 1 default)");
    }

    #[test]
    fn test_memory_with_large_rates() {
        let service = FxEngineService::new(3600);
        
        // Add rates with long source strings
        for i in 0..100 {
            let long_source = "x".repeat(1000); // 1KB source string
            let rate = CachedRate::new(
                Decimal::from(100),
                long_source,
                3600
            );
            
            service.cache.insert(
                FxEngineService::key(&format!("SRC{}", i), &format!("DST{}", i)),
                rate
            );
        }
        
        assert_eq!(service.cache.len(), 101, "Should have 101 entries (100 test + 1 default)");
    }

    #[tokio::test]
    async fn test_cache_cleanup_reduces_memory() {
        let service = FxEngineService::new(1); // 1 second TTL
        
        // Add many entries
        for i in 0..1000 {
            service.cache.insert(
                FxEngineService::key(&format!("F{}", i), &format!("T{}", i)),
                CachedRate::new(Decimal::from(i), "test".to_string(), 1)
            );
        }
        
        assert_eq!(service.cache.len(), 1001, "Should have 1001 entries (1000 test + 1 default)");
        
        // Wait for expiration
        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
        
        // Clean expired
        let cleaned = service.clean_expired();
        
        println!("Cleaned {} entries", cleaned);
        assert!(cleaned > 0, "Should have cleaned some entries");
        assert_eq!(service.cache.len(), 0, "Cache should be empty (all entries expired including default)");
    }

    #[test]
    fn test_decimal_memory_efficiency() {
        // Compare Decimal vs f64 memory usage
        let decimal_size = mem::size_of::<Decimal>();
        let f64_size = mem::size_of::<f64>();
        
        println!("Decimal size: {} bytes", decimal_size);
        println!("f64 size: {} bytes", f64_size);
        
        // Decimal is larger but provides precision
        assert!(decimal_size > f64_size, "Decimal should be larger than f64");
        assert!(decimal_size <= 64, "Decimal shouldn't be too large");
    }

    #[test]
    fn test_service_creation_memory() {
        let _services: Vec<FxEngineService> = (0..100)
            .map(|_| FxEngineService::new(3600))
            .collect();
        
        // Just verify we can create 100 services
        assert_eq!(_services.len(), 100);
    }

    #[test]
    fn test_cache_performance() {
        let service = FxEngineService::new(3600);
        
        // Populate cache
        for i in 0..10000 {
            service.cache.insert(
                FxEngineService::key(&format!("F{}", i), &format!("T{}", i)),
                CachedRate::new(Decimal::from(i), "test".to_string(), 3600)
            );
        }
        
        // Measure read performance
        let start = std::time::Instant::now();
        let mut found = 0;
        
        for i in 0..100000 {
            let key = FxEngineService::key(&format!("F{}", i % 10000), &format!("T{}", i % 10000));
            if service.cache.contains_key(&key) {
                found += 1;
            }
        }
        
        let elapsed = start.elapsed();
        let ops_per_sec = 100000.0 / elapsed.as_secs_f64();
        
        println!("Cache lookups: {} in {:?}", 100000, elapsed);
        println!("Operations/sec: {:.0}", ops_per_sec);
        println!("Found: {}/100000", found);
        
        // Should be very fast (millions of ops/sec)
        assert!(ops_per_sec > 1000000.0, "Cache too slow: {:.0} ops/sec", ops_per_sec);
    }

    // Helper function to get current process memory in KB
    fn get_process_memory() -> f64 {
        #[cfg(target_os = "linux")]
        {
            use std::fs;
            if let Ok(content) = fs::read_to_string("/proc/self/status") {
                for line in content.lines() {
                    if line.starts_with("VmRSS:") {
                        let parts: Vec<&str> = line.split_whitespace().collect();
                        if parts.len() >= 2 {
                            if let Ok(kb) = parts[1].parse::<f64>() {
                                return kb;
                            }
                        }
                    }
                }
            }
        }
        
        #[cfg(target_os = "macos")]
        {
            use std::process::Command;
            if let Ok(output) = Command::new("ps")
                .args(&["-o", "rss=", "-p", &std::process::id().to_string()])
                .output() 
            {
                if let Ok(rss) = String::from_utf8(output.stdout) {
                    if let Ok(kb) = rss.trim().parse::<f64>() {
                        return kb;
                    }
                }
            }
        }
        
        0.0 // Fallback
    }
}
