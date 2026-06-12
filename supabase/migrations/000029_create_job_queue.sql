-- Migration: Create Job Queue
-- Description: Creates the jobs table, notify function, and trigger for real-time queue processing.

CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(255) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    locked_at TIMESTAMPTZ,
    CONSTRAINT valid_status CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
);

-- Add index to speed up dequeuing
CREATE INDEX IF NOT EXISTS idx_jobs_status_created_at ON public.jobs (status, created_at) WHERE status = 'pending';

-- Function to notify on new jobs
CREATE OR REPLACE FUNCTION public.notify_new_job()
RETURNS trigger AS $$
BEGIN
  -- Notify channel 'new_job_channel'
  PERFORM pg_notify('new_job_channel', NEW.type);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to fire notify function after insert
DROP TRIGGER IF EXISTS trigger_new_job ON public.jobs;
CREATE TRIGGER trigger_new_job
AFTER INSERT ON public.jobs
FOR EACH ROW
EXECUTE FUNCTION public.notify_new_job();

-- Function to auto-update updated_at
CREATE OR REPLACE FUNCTION public.update_jobs_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_jobs_updated_at ON public.jobs;
CREATE TRIGGER trigger_jobs_updated_at
BEFORE UPDATE ON public.jobs
FOR EACH ROW
EXECUTE FUNCTION public.update_jobs_updated_at();

-- RLS setup (lock down for anon/authenticated, allow service_role)
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role has full access to jobs" 
ON public.jobs 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);
