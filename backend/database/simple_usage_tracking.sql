-- Simple User Usage Tracking for 3 Responses Per Month System
-- This table tracks how many responses each user has made per month

CREATE TABLE IF NOT EXISTS user_usage (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    month_year VARCHAR(7) NOT NULL, -- Format: YYYY-MM (e.g., "2025-09")
    responses_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, month_year)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_usage_user_month ON user_usage(user_id, month_year);
CREATE INDEX IF NOT EXISTS idx_user_usage_month ON user_usage(month_year);

-- Add a function to get current month_year
CREATE OR REPLACE FUNCTION get_current_month_year() 
RETURNS VARCHAR(7) AS $$
BEGIN
    RETURN TO_CHAR(CURRENT_DATE, 'YYYY-MM');
END;
$$ LANGUAGE plpgsql;

-- Insert initial data for existing users (if any)
INSERT INTO user_usage (user_id, month_year, responses_used)
SELECT 
    u.id,
    get_current_month_year(),
    0
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_usage uu 
    WHERE uu.user_id = u.id 
    AND uu.month_year = get_current_month_year()
)
ON CONFLICT (user_id, month_year) DO NOTHING;
