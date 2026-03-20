//! High-Performance Payout Engine
//!
//! Processes payouts to external accounts (PromptPay, etc.) with:
//! - 🚀 Optimized database operations
//! - 🛡️ Idempotency protection
//! - 📊 Real-time balance updates
//! - 🔒 Fraud detection

use sqlx::PgPool;
use uuid::Uuid;
use tracing::{info, instrument};

use std::sync::Arc;
use crate::accounting::{PayoutRequest, PayoutResponse};

pub struct PayoutEngine {
    pool: PgPool,
}

impl PayoutEngine {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    #[instrument(skip(self), fields(user_id = %req.user_id, amount = %req.amount))]
    pub async fn execute_payout(&self, req: &PayoutRequest) -> anyhow::Result<PayoutResponse> {
        let start = std::time::Instant::now();
        
        let _user_id = Uuid::parse_str(&req.user_id)?;
        let wallet_id = Uuid::parse_str(&req.wallet_id)?;
        
        // Validation
        if req.amount <= 0 {
            return Ok(PayoutResponse {
                success: false,
                transaction_id: "".to_string(),
                status: "FAILED".to_string(),
                message: "Amount must be positive".to_string(),
                new_balance: 0,
            });
        }

        // Begin transaction
        let mut tx = self.pool.begin().await?;
        
        sqlx::query("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
            .execute(&mut *tx)
            .await?;

        // 1. Check idempotency
        let existing: Option<(String,)> = sqlx::query_as(
            "SELECT id::text FROM transactions WHERE reference_id = $1"
        )
        .bind(&req.idempotency_key)
        .fetch_optional(&mut *tx)
        .await?;

        if let Some((existing_id,)) = existing {
            // Return success for duplicate request
            let balance: (i64,) = sqlx::query_as("SELECT balance FROM wallets WHERE id = $1")
                .bind(wallet_id)
                .fetch_one(&mut *tx)
                .await?;
            
            return Ok(PayoutResponse {
                success: true,
                transaction_id: existing_id,
                status: "ALREADY_PROCESSED".to_string(),
                message: "Payout already processed".to_string(),
                new_balance: balance.0,
            });
        }

        // 2. Lock wallet and check balance
        let wallet: Option<(i64, String, String)> = sqlx::query_as(
            "SELECT balance, currency::text, status FROM wallets WHERE id = $1 FOR UPDATE"
        )
        .bind(wallet_id)
        .fetch_optional(&mut *tx)
        .await?;

        let (current_balance, _currency, status) = match wallet {
            Some(w) => w,
            None => {
                return Ok(PayoutResponse {
                    success: false,
                    transaction_id: "".to_string(),
                    status: "FAILED".to_string(),
                    message: "Wallet not found".to_string(),
                    new_balance: 0,
                });
            }
        };

        if status != "ACTIVE" {
            return Ok(PayoutResponse {
                success: false,
                transaction_id: "".to_string(),
                status: "FAILED".to_string(),
                message: "Wallet not active".to_string(),
                new_balance: current_balance,
            });
        }

        if current_balance < req.amount {
            return Ok(PayoutResponse {
                success: false,
                transaction_id: "".to_string(),
                status: "FAILED".to_string(),
                message: "Insufficient balance".to_string(),
                new_balance: current_balance,
            });
        }

        // 3. Check daily limits
        let daily_total: (Option<i64>,) = sqlx::query_as(
            r#"
            SELECT COALESCE(SUM(ABS(le.amount)), 0) 
            FROM ledger_entries le
            JOIN transactions t ON le.transaction_id = t.id
            WHERE le.wallet_id = $1 
            AND le.amount < 0 
            AND t.created_at >= CURRENT_DATE
            "#
        )
        .bind(wallet_id)
        .fetch_one(&mut *tx)
        .await?;

        let max_daily = 2000000i64; // ฿20,000 in satang
        if daily_total.0.unwrap_or(0) + req.amount > max_daily {
            return Ok(PayoutResponse {
                success: false,
                transaction_id: "".to_string(),
                status: "FAILED".to_string(),
                message: "Daily payout limit exceeded".to_string(),
                new_balance: current_balance,
            });
        }

        // 4. Execute payout
        let new_balance = current_balance - req.amount;
        let txn_id = Uuid::new_v4();

        // Update wallet
        sqlx::query("UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2")
            .bind(new_balance)
            .bind(wallet_id)
            .execute(&mut *tx)
            .await?;

        // Create transaction
        sqlx::query(
            "INSERT INTO transactions (id, reference_id, description, settlement_status) VALUES ($1, $2, $3, 'PENDING')"
        )
        .bind(txn_id)
        .bind(&req.idempotency_key)
        .bind(format!("Payout to {}", req.recipient_name))
        .execute(&mut *tx)
        .await?;

        // Create ledger entry
        sqlx::query(
            "INSERT INTO ledger_entries (id, transaction_id, wallet_id, amount, balance_after) VALUES ($1, $2, $3, $4, $5)"
        )
        .bind(Uuid::new_v4())
        .bind(txn_id)
        .bind(wallet_id)
        .bind(-req.amount)
        .bind(new_balance)
        .execute(&mut *tx)
        .await?;

        // Create outbox event for async processing
        sqlx::query(
            "INSERT INTO outbox_events (id, event_type, payload, status) VALUES ($1, $2, $3, 'PENDING')"
        )
        .bind(Uuid::new_v4())
        .bind("PAYOUT_INITIATED")
        .bind(format!(
            r#"{{"transaction_id":"{}","amount":{},"recipient":"{}","promptpay_id":"{}"}}"#,
            txn_id, req.amount, req.recipient_name, req.promptpay_id
        ))
        .execute(&mut *tx)
        .await?;

        // Commit
        tx.commit().await?;

        let duration = start.elapsed();
        info!(
            transaction_id = %txn_id,
            duration_ms = duration.as_millis(),
            "Payout initiated successfully"
        );

        Ok(PayoutResponse {
            success: true,
            transaction_id: txn_id.to_string(),
            status: "INITIATED".to_string(),
            message: "Payout initiated successfully".to_string(),
            new_balance,
        })
    }

    /// Batch process payouts using true parallel tasks (for high-volume scenarios)
    #[allow(dead_code)]
    pub async fn batch_payout(self: Arc<Self>, requests: Vec<PayoutRequest>) -> Vec<PayoutResponse> {
        let mut set: tokio::task::JoinSet<anyhow::Result<PayoutResponse>> = tokio::task::JoinSet::new();
        
        for req in requests {
            let engine = self.clone();
            set.spawn(async move {
                engine.execute_payout(&req).await
            });
        }
        
        let mut responses = Vec::new();
        while let Some(res) = set.join_next().await {
            match res {
                Ok(Ok(resp)) => responses.push(resp),
                Ok(Err(e)) => {
                    responses.push(PayoutResponse {
                        success: false,
                        transaction_id: "".to_string(),
                        status: "ERROR".to_string(),
                        message: e.to_string(),
                        new_balance: 0,
                    });
                }
                Err(e) => {
                    responses.push(PayoutResponse {
                        success: false,
                        transaction_id: "".to_string(),
                        status: "PANIC".to_string(),
                        message: format!("Task panic: {}", e),
                        new_balance: 0,
                    });
                }
            }
        }
        
        responses
    }
}
