-- Create sms_provider_configs table to store country-specific SMS provider settings
CREATE TABLE IF NOT EXISTS sms_provider_configs (
  id SERIAL PRIMARY KEY,
  country_code VARCHAR(4) NOT NULL REFERENCES countries(code) ON DELETE CASCADE,
  provider VARCHAR(32) NOT NULL, -- e.g. twilio | aws_sns | vonage | local_http | dev
  config JSONB NOT NULL DEFAULT '{}'::jsonb, -- provider specific credentials/settings (encrypted externally if needed)
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(country_code, provider)
);

CREATE INDEX IF NOT EXISTS idx_sms_provider_configs_country_active ON sms_provider_configs(country_code) WHERE is_active = TRUE;

-- Optional seed dev fallback for LK if not present
INSERT INTO sms_provider_configs (country_code, provider, config, is_active)
SELECT 'LK', 'dev', '{"note":"Dev fallback – logs OTP only"}'::jsonb, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM sms_provider_configs WHERE country_code = 'LK' AND provider = 'dev'
);

-- Helper function + trigger for updated_at
DO $mig$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'update_timestamp'
  ) THEN
    CREATE OR REPLACE FUNCTION update_timestamp()
    RETURNS trigger AS $func$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $func$ LANGUAGE plpgsql;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_sms_provider_configs_updated_at'
  ) THEN
    CREATE TRIGGER trg_sms_provider_configs_updated_at
      BEFORE UPDATE ON sms_provider_configs
      FOR EACH ROW
      EXECUTE FUNCTION update_timestamp();
  END IF;
END $mig$;
