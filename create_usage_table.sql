CREATE TABLE IF NOT EXISTS usage_monthly (
    user_id UUID,
    year_month VARCHAR(6),
    response_count INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT now(),
    PRIMARY KEY (user_id, year_month)
);
