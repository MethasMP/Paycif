-- Upgrading Paysif Schema for Sumsub Integration (V3)

-- 1. Extend KYC Status Enum
-- Note: 'IF NOT EXISTS' for enum values requires a DO block in some Postgres versions, 
-- but we'll try the direct approach or use a safe check.
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid WHERE t.typname = 'kyc_status_enum' AND e.enumlabel = 'PENDING_BIOMETRIC') THEN
        ALTER TYPE public.kyc_status_enum ADD VALUE 'PENDING_BIOMETRIC';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid WHERE t.typname = 'kyc_status_enum' AND e.enumlabel = 'VERIFIED') THEN
        ALTER TYPE public.kyc_status_enum ADD VALUE 'VERIFIED';
    END IF;
END $$;

-- 2. Add KYC Tier to Profiles
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS kyc_tier TEXT NOT NULL DEFAULT 'tier0'
  CHECK (kyc_tier IN ('tier0', 'tier2'));

-- 3. Add Sumsub specific fields to Identity Verification
ALTER TABLE public.identity_verification 
  ADD COLUMN IF NOT EXISTS sumsub_applicant_id TEXT,
  ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;

-- 4. Initial Migration of status
UPDATE public.profiles SET kyc_tier = 'tier2'
WHERE id IN (
  SELECT user_id FROM public.identity_verification WHERE kyc_status IN ('APPROVED', 'VERIFIED')
);
