-- Create usage_monthly table for tracking user response counts
-- This table stores monthly response usage for entitlement checking

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

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_usage_monthly_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_usage_monthly_updated_at
    BEFORE UPDATE ON usage_monthly
    FOR EACH ROW
    EXECUTE FUNCTION update_usage_monthly_updated_at();

-- Insert comment
COMMENT ON TABLE usage_monthly IS 'Tracks monthly response counts for users to enforce free tier limits';
COMMENT ON COLUMN usage_monthly.year_month IS 'Format YYYYMM, e.g. 202509 for September 2025';
COMMENT ON COLUMN usage_monthly.response_count IS 'Number of responses created by user in this month';
