-- Migration: add_countries_table
-- Creates countries master table and supporting index

CREATE TABLE IF NOT EXISTS countries (
    id SERIAL PRIMARY KEY,
    code VARCHAR(5) NOT NULL UNIQUE,         -- ISO alpha-2 or internal code
    name VARCHAR(100) NOT NULL,
    default_currency VARCHAR(10) DEFAULT 'USD',
    phone_prefix VARCHAR(10),
    locale VARCHAR(20),
    tax_rate NUMERIC(6,3),                   -- optional VAT/GST etc
    flag_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_countries_active ON countries(is_active);
CREATE INDEX IF NOT EXISTS idx_countries_code ON countries(code);

-- Seed a default LK record if not exists
INSERT INTO countries (code, name, default_currency, phone_prefix, locale)
SELECT 'LK', 'Sri Lanka', 'LKR', '+94', 'en-LK'
WHERE NOT EXISTS (SELECT 1 FROM countries WHERE code = 'LK');
