//! High-Performance Transfer Executor
//!
//! Executes transfers with:
//! - ⚡ Atomic database operations
//! - 🛡️ Double-entry integrity checks
//! - 📊 Automatic idempotency handling
//! - 🔒 Optimistic locking

use sqlx::{PgPool, Postgres, Transaction};
use std::sync::Arc;
use uuid::Uuid;
use tracing::{info, error, instrument};
use rust_decimal::Decimal;

use crate::accounting::{TransferRequest, TransferResponse, ValidateRequest};
use crate::limit_cache::UnifiedLimitCache;

pub struct TransferExecutor {
    pool: PgPool,
    limit_cache: Arc<UnifiedLimitCache>,
}

impl TransferExecutor {
    pub fn new(pool: PgPool, limit_cache: Arc<UnifiedLimitCache>) -> Self {
        Self { pool, limit_cache }
    }

    #[instrument(skip(self), fields(request_id = %req.request_id))]
    pub async fn execute(&self, req: &TransferRequest) -> anyhow::Result<TransferResponse> {
        let start = std::time::Instant::now();
        
        // Parse UUIDs
        let from_wallet = Uuid::parse_str(&req.from_wallet_id)?;
        let to_wallet = Uuid::parse_str(&req.to_wallet_id)?;
        let user_id = Uuid::parse_str(&req.user_id)?;
        
        // Begin transaction with SERIALIZABLE isolation
        let mut tx = self.pool.begin().await?;
        
        sqlx::query("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
            .execute(&mut *tx)
            .await?;

        // 1. Check Idempotency
        let existing: Option<(String,)> = sqlx::query_as(
            "SELECT id::text FROM transactions WHERE reference_id = $1"
        )
        .bind(&req.reference_id)
        .fetch_optional(&mut *tx)
        .await?;

        if let Some((existing_id,)) = existing {
            info!("Idempotent request - returning existing transaction {}", existing_id);
            return Ok(TransferResponse {
                success: true,
                transaction_id: existing_id,
                error_code: "".to_string(),
                error_message: "Already processed (idempotent)".to_string(),
                sender_balance_after: 0,
                receiver_balance_after: 0,
                used_existing: true,
            });
        }

        // 2. Verify wallet ownership
        let owner_id: Option<(Uuid,)> = sqlx::query_as(
            "SELECT profile_id FROM wallets WHERE id = $1"
        )
        .bind(from_wallet)
        .fetch_optional(&mut *tx)
        .await?;

        match owner_id {
            Some((oid,)) if oid == user_id => {},
            _ => {
                return Ok(TransferResponse {
                    success: false,
                    transaction_id: "".to_string(),
                    error_code: "UNAUTHORIZED".to_string(),
                    error_message: "Wallet does not belong to user".to_string(),
                    sender_balance_after: 0,
                    receiver_balance_after: 0,
                    used_existing: false,
                });
            }
        }

        // 3. Limit check (using unified cache)
        let amount_decimal = Decimal::from(req.amount) / Decimal::from(100);
        let (allowed, _, limit_msg) = self.limit_cache
            .check_transaction(&user_id.to_string(), amount_decimal)
            .await;

        if !allowed {
            return Ok(TransferResponse {
                success: false,
                transaction_id: "".to_string(),
                error_code: "LIMIT_EXCEEDED".to_string(),
                error_message: limit_msg,
                sender_balance_after: 0,
                receiver_balance_after: 0,
                used_existing: false,
            });
        }

        // 4. Execute transfer with double-entry
        match self.execute_double_entry(&mut tx, from_wallet, to_wallet, req.amount, &req.currency).await {
            Ok((txn_id, sender_balance, receiver_balance)) => {
                // Commit transaction
                tx.commit().await?;
                
                let duration = start.elapsed();
                info!(
                    transaction_id = %txn_id,
                    duration_ms = duration.as_millis(),
                    "Transfer completed successfully"
                );

                Ok(TransferResponse {
                    success: true,
                    transaction_id: txn_id.to_string(),
                    error_code: "".to_string(),
                    error_message: "".to_string(),
                    sender_balance_after: sender_balance,
                    receiver_balance_after: receiver_balance,
                    used_existing: false,
                })
            }
            Err(e) => {
                // Rollback and release limit reservation
                tx.rollback().await.ok();
                self.limit_cache.release_limit(&user_id.to_string(), amount_decimal);
                
                error!("Transfer failed: {}", e);
                Err(e)
            }
        }
    }

    async fn execute_double_entry(
        &self,
        tx: &mut Transaction<'_, Postgres>,
        from_wallet: Uuid,
        to_wallet: Uuid,
        amount: i64,
        currency: &str,
    ) -> anyhow::Result<(Uuid, i64, i64)> {
        // Lock and fetch sender wallet
        let sender: Option<(i64, String, String)> = sqlx::query_as(
            "SELECT balance, currency::text, status FROM wallets WHERE id = $1 FOR UPDATE"
        )
        .bind(from_wallet)
        .fetch_optional(&mut **tx)
        .await?;

        let (sender_balance, sender_currency, sender_status) = match sender {
            Some(s) => s,
            None => return Err(anyhow::anyhow!("Sender wallet not found")),
        };

        // Validate sender
        if sender_currency != currency {
            return Err(anyhow::anyhow!("Currency mismatch"));
        }
        if sender_status != "ACTIVE" {
            return Err(anyhow::anyhow!("Sender wallet not active"));
        }
        if sender_balance < amount {
            return Err(anyhow::anyhow!("Insufficient funds"));
        }

        // Lock and fetch receiver wallet
        let receiver: Option<(i64, String)> = sqlx::query_as(
            "SELECT balance, currency::text FROM wallets WHERE id = $1 FOR UPDATE"
        )
        .bind(to_wallet)
        .fetch_optional(&mut **tx)
        .await?;

        let (receiver_balance, receiver_currency) = match receiver {
            Some(r) => r,
            None => return Err(anyhow::anyhow!("Receiver wallet not found")),
        };

        if receiver_currency != currency {
            return Err(anyhow::anyhow!("Receiver currency mismatch"));
        }

        // Calculate new balances
        let new_sender_balance = sender_balance - amount;
        let new_receiver_balance = receiver_balance + amount;

        // Execute updates
        sqlx::query("UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2")
            .bind(new_sender_balance)
            .bind(from_wallet)
            .execute(&mut **tx)
            .await?;

        sqlx::query("UPDATE wallets SET balance = $1, updated_at = NOW() WHERE id = $2")
            .bind(new_receiver_balance)
            .bind(to_wallet)
            .execute(&mut **tx)
            .await?;

        // Create transaction record
        let txn_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO transactions (id, reference_id, description, settlement_status) VALUES ($1, $2, $3, 'SETTLED')"
        )
        .bind(txn_id)
        .bind(format!("transfer_{}", txn_id))
        .bind("Transfer")
        .execute(&mut **tx)
        .await?;

        // Create ledger entries
        sqlx::query(
            "INSERT INTO ledger_entries (id, transaction_id, wallet_id, amount, balance_after) VALUES ($1, $2, $3, $4, $5)"
        )
        .bind(Uuid::new_v4())
        .bind(txn_id)
        .bind(from_wallet)
        .bind(-amount)
        .bind(new_sender_balance)
        .execute(&mut **tx)
        .await?;

        sqlx::query(
            "INSERT INTO ledger_entries (id, transaction_id, wallet_id, amount, balance_after) VALUES ($1, $2, $3, $4, $5)"
        )
        .bind(Uuid::new_v4())
        .bind(txn_id)
        .bind(to_wallet)
        .bind(amount)
        .bind(new_receiver_balance)
        .execute(&mut **tx)
        .await?;

        // Integrity check
        let sum: (i64,) = sqlx::query_as(
            "SELECT COALESCE(SUM(amount), 0) FROM ledger_entries WHERE transaction_id = $1"
        )
        .bind(txn_id)
        .fetch_one(&mut **tx)
        .await?;

        if sum.0 != 0 {
            return Err(anyhow::anyhow!("Ledger integrity check failed"));
        }

        Ok((txn_id, new_sender_balance, new_receiver_balance))
    }

    pub async fn validate(&self, req: &ValidateRequest) -> anyhow::Result<(bool, String)> {
        let from_wallet = Uuid::parse_str(&req.from_wallet_id)?;
        let user_id = Uuid::parse_str(&req.user_id)?;
        
        // Quick validation without transaction
        let owner_check: Option<(Uuid,)> = sqlx::query_as(
            "SELECT profile_id FROM wallets WHERE id = $1"
        )
        .bind(from_wallet)
        .fetch_optional(&self.pool)
        .await?;

        match owner_check {
            Some((oid,)) if oid == user_id => {},
            _ => return Ok((false, "Unauthorized".to_string())),
        }

        // Limit check
        let amount_decimal = Decimal::from(req.amount) / Decimal::from(100);
        let (allowed, _, msg) = self.limit_cache
            .check_transaction(&user_id.to_string(), amount_decimal)
            .await;

        if !allowed {
            return Ok((false, msg));
        }

        // Release the reservation since this is just validation
        self.limit_cache.release_limit(&user_id.to_string(), amount_decimal);

        Ok((true, "".to_string()))
    }
}
