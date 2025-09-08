-- Migration: create OTP verification tables for email and phone
-- Idempotent (IF NOT EXISTS) so safe to re-run.

CREATE TABLE IF NOT EXISTS email_otp_verifications (
  email VARCHAR(255) PRIMARY KEY,
  otp VARCHAR(6) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  attempts INT NOT NULL DEFAULT 0,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS phone_otp_verifications (
  phone VARCHAR(32) PRIMARY KEY,
  otp VARCHAR(6) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  attempts INT NOT NULL DEFAULT 0,
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at TIMESTAMPTZ
);

-- Helpful indexes for expiry cleanup (primary key covers lookups by email/phone)
CREATE INDEX IF NOT EXISTS idx_email_otp_expires ON email_otp_verifications(expires_at);
CREATE INDEX IF NOT EXISTS idx_phone_otp_expires ON phone_otp_verifications(expires_at);
