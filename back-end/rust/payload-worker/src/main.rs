//! High-Performance Payload Worker using SIMD-JSON
//!
//! This worker processes outbox events and queue messages with:
//! - SIMD-accelerated JSON parsing (10-15x faster than standard)
//! - Zero-copy deserialization where possible
//! - Batch processing for throughput

use anyhow::Result;

use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use std::time::{Duration, Instant};
use tracing::{error, info, warn};


/// Outbox event structure matching the Go backend
#[derive(Debug, Serialize, Deserialize)]
pub struct OutboxEvent {
    pub id: String,
    pub event_type: String,
    pub payload: String,
    pub status: String,
    pub created_at: String,
    pub processed_at: Option<String>,
    pub retry_count: i32,
}

/// Parsed payload for transfer events
#[derive(Debug, Serialize, Deserialize)]
pub struct TransferPayload {
    pub transaction_id: String,
    pub from_wallet: String,
    pub to_wallet: String,
    pub amount: i64,
    pub currency: String,
}

/// Parsed payload for notification events
#[derive(Debug, Serialize, Deserialize)]
pub struct NotificationPayload {
    pub user_id: String,
    pub title: String,
    pub body: String,
    pub channel: String,
}

/// Worker configuration
pub struct WorkerConfig {
    pub batch_size: usize,
    pub poll_interval: Duration,
    pub max_retries: i32,
}

impl Default for WorkerConfig {
    fn default() -> Self {
        Self {
            batch_size: 100,
            poll_interval: Duration::from_millis(100),
            max_retries: 3,
        }
    }
}

/// Main worker struct
pub struct PayloadWorker {
    db: PgPool,
    redis: redis::aio::ConnectionManager,
    config: WorkerConfig,
}

impl PayloadWorker {
    pub async fn new(db: PgPool, redis_url: &str, config: WorkerConfig) -> Result<Self> {
        let redis_client = redis::Client::open(redis_url)?;
        let redis = redis_client.get_connection_manager().await?;

        Ok(Self { db, redis, config })
    }

    /// Process pending outbox events using SIMD-JSON
    pub async fn process_outbox_batch(&mut self) -> Result<usize> {
        // Fetch pending events from the correct table matching Go backend
        let events: Vec<(String, String, String, i32)> = sqlx::query_as(
            r#"
            SELECT id::text, event_type, payload::text, retry_count
            FROM transaction_outbox
            WHERE status = 'PENDING' AND retry_count < $1
            ORDER BY created_at ASC
            LIMIT $2
            FOR UPDATE SKIP LOCKED
            "#,
        )
        .bind(self.config.max_retries)
        .bind(self.config.batch_size as i64)
        .fetch_all(&self.db)
        .await?;

        if events.is_empty() {
            return Ok(0);
        }

        let start = Instant::now();
        let mut processed = 0;
        let mut failed = 0;

        for (id, event_type, payload, retry_count) in events {
            match self.process_single_event(&id, &event_type, &payload).await {
                Ok(_) => {
                    // Mark as processed
                    sqlx::query(
                        "UPDATE transaction_outbox SET status = 'PROCESSED', processed_at = NOW() WHERE id = $1::uuid",
                    )
                    .bind(&id)
                    .execute(&self.db)
                    .await?;
                    processed += 1;
                }
                Err(e) => {
                    error!(event_id = %id, error = %e, "Failed to process event");
                    // Increment retry count
                    sqlx::query(
                        "UPDATE transaction_outbox SET retry_count = $1, last_attempt_at = NOW(), error_message = $2, status = CASE WHEN $1 >= $3 THEN 'FAILED' ELSE 'PENDING' END WHERE id = $4::uuid",
                    )
                    .bind(retry_count + 1)
                    .bind(e.to_string())
                    .bind(self.config.max_retries)
                    .bind(&id)
                    .execute(&self.db)
                    .await?;
                    failed += 1;
                }
            }
        }

        let elapsed = start.elapsed();
        info!(
            processed = processed,
            failed = failed,
            elapsed_ms = elapsed.as_millis(),
            "Batch processed"
        );

        Ok(processed)
    }

    /// Process a single event using SIMD-JSON for fast parsing
    async fn process_single_event(
        &mut self,
        id: &str,
        event_type: &str,
        payload: &str,
    ) -> Result<()> {
        // Convert to mutable bytes for SIMD-JSON (requires mutable slice)
        let mut payload_bytes = payload.as_bytes().to_vec();

        match event_type {
            "TRANSFER_COMPLETED" | "TRANSFER_INITIATED" => {
                // SIMD-JSON parsing (10-15x faster than serde_json)
                let transfer: TransferPayload = simd_json::from_slice(&mut payload_bytes)?;

                // Publish to Redis for real-time notifications
                let channel = format!("wallet:{}", transfer.from_wallet);
                let _: () = self
                    .redis
                    .publish(&channel, payload)
                    .await?;

                info!(
                    event_id = %id,
                    transaction_id = %transfer.transaction_id,
                    "Transfer event processed"
                );
            }
            "PROMPTPAY_PAYOUT" | "PAYOUT_REQUESTED" | "PAYOUT_INITIATED" => {
                // Here we would call the actual Payout Provider API
                // For now, we broadcast the status update
                let _: () = self
                    .redis
                    .publish("payout:updates", payload)
                    .await?;

                info!(
                    event_id = %id,
                    event_type = %event_type,
                    "Payout event processed/forwarded"
                );
            }
            "NOTIFICATION" => {
                let notification: NotificationPayload = simd_json::from_slice(&mut payload_bytes)?;

                // Route to appropriate channel
                match notification.channel.as_str() {
                    "push" => {
                        // Queue for push notification service
                        let _: () = self
                            .redis
                            .lpush("notifications:push", payload)
                            .await?;
                    }
                    "sms" => {
                        let _: () = self
                            .redis
                            .lpush("notifications:sms", payload)
                            .await?;
                    }
                    "email" => {
                        let _: () = self
                            .redis
                            .lpush("notifications:email", payload)
                            .await?;
                    }
                    _ => {
                        warn!(channel = %notification.channel, "Unknown notification channel");
                    }
                }

                info!(
                    event_id = %id,
                    user_id = %notification.user_id,
                    channel = %notification.channel,
                    "Notification queued"
                );
            }
            "TOPUP_COMPLETED" | "WITHDRAWAL_COMPLETED" => {
                // Publish for real-time balance updates
                let _: () = self
                    .redis
                    .publish("balance:updates", payload)
                    .await?;
            }
            _ => {
                warn!(event_type = %event_type, "Unknown event type, skipping");
            }
        }

        Ok(())
    }

    /// Run the worker loop
    pub async fn run(&mut self) -> Result<()> {
        info!("🚀 Payload Worker starting...");
        info!(
            batch_size = self.config.batch_size,
            poll_interval_ms = self.config.poll_interval.as_millis(),
            "Configuration"
        );

        let mut fail_count = 0;

        loop {
            // Process batch
            match self.process_outbox_batch().await {
                Ok(processed_count) => {
                    fail_count = 0; // Reset failure count on success
                    
                    if processed_count == 0 {
                        // No events, wait nominal time
                        tokio::time::sleep(self.config.poll_interval).await;
                    } 
                    // If processed events, continue immediately to drain queue (no sleep)
                }
                Err(e) => {
                    fail_count += 1;
                    // Exponential backoff: 1s, 2s, 4s, 8s, max 30s
                    let backoff_secs = std::cmp::min(2u64.pow(fail_count.min(5)), 30);
                    let backoff = Duration::from_secs(backoff_secs);
                    
                    error!(
                        error = %e, 
                        fail_count = fail_count,
                        backoff_secs = backoff_secs,
                        "Error processing batch, backing off"
                    );
                    
                    // Force a database connection check/reset if persistent
                    if fail_count > 3 {
                        warn!("Failures persisting. Checking DB connection...");
                        // Simple probe
                        if let Err(ping_err) = sqlx::query("SELECT 1").execute(&self.db).await {
                             error!("DB Connection check failed: {}", ping_err);
                        }
                    }

                    tokio::time::sleep(backoff).await;
                }
            }
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .init();

    dotenv::dotenv().ok();

    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://postgres:postgres@localhost/paycif".to_string());
    let redis_url = std::env::var("REDIS_URL")
        .unwrap_or_else(|_| "redis://localhost:6379".to_string());

    info!("Connecting to database...");
    use sqlx::postgres::PgConnectOptions;
    use std::str::FromStr;
    let connection_options = PgConnectOptions::from_str(&database_url)?
        .statement_cache_capacity(0); // ⚡ CRITICAL: Fix for Supabase Transaction Pooler

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect_with(connection_options)
        .await?;

    let config = WorkerConfig {
        batch_size: std::env::var("BATCH_SIZE")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(100),
        poll_interval: Duration::from_millis(
            std::env::var("POLL_INTERVAL_MS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(100),
        ),
        max_retries: 3,
    };

    info!("⚡ SIMD-JSON Payload Worker v1.0.0");
    info!("Starting worker loop...");

    let mut worker = PayloadWorker::new(pool, &redis_url, config).await?;
    worker.run().await
}
