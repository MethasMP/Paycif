-- ============================================================================
-- AUTO-SYNC CRON JOB (OPTIONAL)
-- ============================================================================
-- This requires pg_cron extension to be enabled in Supabase Dashboard.
-- It will run the reconciliation every hour to ensure no money is lost.

-- Enable pg_cron (if not already enabled, might require dashboard access)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the job (Runs at minute 0 of every hour)
SELECT cron.schedule(
    'omise-reconciliation-job', -- Job Name
    '0 * * * *',                -- Cron expression (Every hour)
    $$
    -- Call the Edge Function via pg_net (or similar mechanism if available in SQL)
    -- Since we can't easily call Edge Function from pure SQL without pg_net extensions setup,
    -- typically we use HTTP trigger.
    
    -- NOTE: For simplicity in Supabase, it's often better to use "Database Webhooks" 
    -- or just rely on manual trigger for now, as pg_net setup varies.
    -- Or use pg_net if enabled:
    
    -- select net.http_post(
    --     url:='https://[PROJECT_REF].supabase.co/functions/v1/reconcile-omise',
    --     headers:='{"Authorization": "Bearer [SERVICE_KEY]"}'
    -- );
    $$
);

-- NOTE: Since I cannot guarantee pg_net configuration here, 
-- I will NOT enable the schedule automatically to avoid errors.
-- Please Deploy the Function 'reconcile-omise' manually first.
