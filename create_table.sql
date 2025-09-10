-- Simple SQL script to create usage_monthly table
-- Run this directly in the database

CREATE TABLE IF NOT EXISTS usage_monthly (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    year_month VARCHAR(6) NOT NULL, -- Format: 202509 (YYYYMM)
    response_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one record per user per month
    UNIQUE(user_id, year_month)
);

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_usage_monthly_user_month ON usage_monthly(user_id, year_month);

-- Create index for cleanup queries
CREATE INDEX IF NOT EXISTS idx_usage_monthly_year_month ON usage_monthly(year_month);
