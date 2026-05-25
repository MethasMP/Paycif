-- Add status column to wallets table
ALTER TABLE wallets ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE';
-- Statuses: 'ACTIVE', 'HALTED', 'SUSPENDED'

-- Add status column to transactions table for finer tracking if needed?
-- transactions already has 'settlement_status'. 
-- We will use settlement_status 'FAILED_INTEGRITY' for breaches.
