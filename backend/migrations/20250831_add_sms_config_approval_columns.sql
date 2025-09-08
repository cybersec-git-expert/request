-- Ensure sms_configurations has columns referenced by routes when saving configs
-- Idempotent migration: safe to run multiple times

-- Add approval status and notes
ALTER TABLE sms_configurations 
  ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS approval_notes TEXT;

-- Add submit/approve tracking
ALTER TABLE sms_configurations 
  ADD COLUMN IF NOT EXISTS submitted_by UUID,
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approved_by UUID,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- Ensure Hutch Mobile configuration column exists
ALTER TABLE sms_configurations 
  ADD COLUMN IF NOT EXISTS hutch_mobile_config JSONB;

-- Add foreign keys to admin_users if table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'admin_users'
  ) THEN
    -- Add constraint for approved_by if not exists
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE table_name = 'sms_configurations' AND constraint_name = 'fk_sms_conf_approved_by'
    ) THEN
      ALTER TABLE sms_configurations 
        ADD CONSTRAINT fk_sms_conf_approved_by FOREIGN KEY (approved_by) REFERENCES admin_users(id);
    END IF;

    -- Add constraint for submitted_by if not exists
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE table_name = 'sms_configurations' AND constraint_name = 'fk_sms_conf_submitted_by'
    ) THEN
      ALTER TABLE sms_configurations 
        ADD CONSTRAINT fk_sms_conf_submitted_by FOREIGN KEY (submitted_by) REFERENCES admin_users(id);
    END IF;
  END IF;
END
$$;

-- Update valid provider check constraint to include hutch_mobile (drop if exists and recreate)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'valid_provider_check' AND table_name = 'sms_configurations'
  ) THEN
    ALTER TABLE sms_configurations DROP CONSTRAINT valid_provider_check;
  END IF;
  ALTER TABLE sms_configurations 
    ADD CONSTRAINT valid_provider_check 
    CHECK (active_provider IN ('twilio', 'aws', 'vonage', 'local', 'hutch_mobile'));
END
$$;
