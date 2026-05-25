//! Metrics and monitoring utilities
//!
//! This module provides simple wrappers around the metrics crate macros.
//! The macros are defined in the crate root and re-exported here for convenience.

/// Initialize Prometheus metrics exporter
#[allow(dead_code)]
pub fn init_metrics() {
    // This would set up the Prometheus exporter
    // For now, just using the metrics macros directly
}

/// Re-export the metrics macros for convenience
pub use metrics::{counter, histogram};
