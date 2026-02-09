SELECT id, created_at, event_type, status, payload FROM transaction_outbox WHERE created_at > NOW() - INTERVAL '1 day';
