-- 012_create_promo_and_verifications.sql
-- Promo codes and (email/phone) verification audit tables.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS promo_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(60) NOT NULL UNIQUE,
  description VARCHAR(255),
  discount_type VARCHAR(20) NOT NULL DEFAULT 'percent', -- percent | fixed
  discount_value NUMERIC(12,2) NOT NULL DEFAULT 0,
  max_uses INT,
  per_user_limit INT,
  starts_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_promo_codes_active ON promo_codes(is_active);
CREATE INDEX IF NOT EXISTS idx_promo_codes_window ON promo_codes(starts_at, expires_at);

CREATE TABLE IF NOT EXISTS promo_code_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_code_id UUID NOT NULL REFERENCES promo_codes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  request_id UUID NULL REFERENCES requests(id) ON DELETE SET NULL,
  redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  amount NUMERIC(12,2),
  metadata JSONB,
  UNIQUE(promo_code_id, user_id, request_id)
);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_user ON promo_code_redemptions(user_id);

-- Verification audit already partially covered by 009_create_verification_audit_log (assuming). Add lightweight tables if needed.
CREATE TABLE IF NOT EXISTS phone_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  phone VARCHAR(40) NOT NULL,
  country_code VARCHAR(10),
  otp_code VARCHAR(10),
  attempts INT NOT NULL DEFAULT 0,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_phone_verifications_phone ON phone_verifications(phone);

CREATE TABLE IF NOT EXISTS email_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  email VARCHAR(160) NOT NULL,
  otp_code VARCHAR(10),
  attempts INT NOT NULL DEFAULT 0,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_email_verifications_email ON email_verifications(email);

-- Touch triggers
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_promo_codes_updated_at') THEN
    CREATE OR REPLACE FUNCTION touch_promo_codes_updated_at() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at=NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;
    CREATE TRIGGER trg_promo_codes_updated_at BEFORE UPDATE ON promo_codes FOR EACH ROW EXECUTE FUNCTION touch_promo_codes_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_phone_verifications_updated_at') THEN
    CREATE OR REPLACE FUNCTION touch_phone_verifications_updated_at() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at=NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;
    CREATE TRIGGER trg_phone_verifications_updated_at BEFORE UPDATE ON phone_verifications FOR EACH ROW EXECUTE FUNCTION touch_phone_verifications_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_email_verifications_updated_at') THEN
    CREATE OR REPLACE FUNCTION touch_email_verifications_updated_at() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at=NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;
    CREATE TRIGGER trg_email_verifications_updated_at BEFORE UPDATE ON email_verifications FOR EACH ROW EXECUTE FUNCTION touch_email_verifications_updated_at();
  END IF;
END $$;
