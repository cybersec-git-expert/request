-- Payment Gateway Management for Country Admins
-- This allows each country to configure their preferred payment methods

-- Main payment gateways table
CREATE TABLE IF NOT EXISTS payment_gateways (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL, -- e.g., 'Stripe', 'PayPal', 'Razorpay', 'Payhere'
    code VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'stripe', 'paypal', 'razorpay', 'payhere'
    description TEXT,
    supported_countries TEXT[], -- Array of country codes
    requires_api_key BOOLEAN DEFAULT true,
    requires_secret_key BOOLEAN DEFAULT true,
    requires_webhook_url BOOLEAN DEFAULT false,
    configuration_fields JSONB, -- Dynamic fields required for each gateway
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Country-specific payment gateway configurations
CREATE TABLE IF NOT EXISTS country_payment_gateways (
    id SERIAL PRIMARY KEY,
    country_code CHAR(2) NOT NULL,
    payment_gateway_id INTEGER NOT NULL REFERENCES payment_gateways(id),
    configuration JSONB NOT NULL, -- Encrypted configuration data
    is_active BOOLEAN DEFAULT true,
    is_primary BOOLEAN DEFAULT false, -- One primary gateway per country
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(country_code, payment_gateway_id)
);

-- Payment gateway transaction fees
CREATE TABLE IF NOT EXISTS payment_gateway_fees (
    id SERIAL PRIMARY KEY,
    country_payment_gateway_id INTEGER NOT NULL REFERENCES country_payment_gateways(id),
    transaction_type VARCHAR(50) NOT NULL, -- 'subscription', 'one_time', 'refund'
    fee_type VARCHAR(20) NOT NULL, -- 'percentage', 'fixed', 'combined'
    percentage_fee DECIMAL(5,2) DEFAULT 0, -- e.g., 2.90 for 2.9%
    fixed_fee DECIMAL(10,2) DEFAULT 0, -- e.g., 0.30 for $0.30
    currency CHAR(3) NOT NULL,
    minimum_amount DECIMAL(10,2) DEFAULT 0,
    maximum_amount DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_country_payment_gateways_country ON country_payment_gateways(country_code);
CREATE INDEX IF NOT EXISTS idx_country_payment_gateways_active ON country_payment_gateways(country_code, is_active);
CREATE INDEX IF NOT EXISTS idx_payment_gateway_fees_gateway ON payment_gateway_fees(country_payment_gateway_id);

-- Insert default payment gateways
INSERT INTO payment_gateways (name, code, description, supported_countries, configuration_fields) VALUES
('Stripe', 'stripe', 'Global payment processing platform', ARRAY['US', 'CA', 'GB', 'AU', 'SG', 'IN', 'LK'], 
 '{"api_key": {"type": "text", "label": "Publishable Key", "required": true}, 
   "secret_key": {"type": "password", "label": "Secret Key", "required": true},
   "webhook_secret": {"type": "password", "label": "Webhook Secret", "required": false}}'),

('PayPal', 'paypal', 'Global digital payments platform', ARRAY['US', 'CA', 'GB', 'AU', 'IN', 'LK'],
 '{"client_id": {"type": "text", "label": "Client ID", "required": true},
   "client_secret": {"type": "password", "label": "Client Secret", "required": true},
   "environment": {"type": "select", "label": "Environment", "options": ["sandbox", "live"], "required": true}}'),

('Razorpay', 'razorpay', 'Payment gateway for India', ARRAY['IN'],
 '{"key_id": {"type": "text", "label": "Key ID", "required": true},
   "key_secret": {"type": "password", "label": "Key Secret", "required": true},
   "webhook_secret": {"type": "password", "label": "Webhook Secret", "required": false}}'),

('PayHere', 'payhere', 'Sri Lankan payment gateway', ARRAY['LK'],
 '{"merchant_id": {"type": "text", "label": "Merchant ID", "required": true},
   "merchant_secret": {"type": "password", "label": "Merchant Secret", "required": true},
   "environment": {"type": "select", "label": "Environment", "options": ["sandbox", "live"], "required": true}}'),

('Bank Transfer', 'bank_transfer', 'Manual bank transfer', ARRAY['LK', 'IN', 'US', 'CA', 'GB'],
 '{"bank_name": {"type": "text", "label": "Bank Name", "required": true},
   "account_number": {"type": "text", "label": "Account Number", "required": true},
   "account_holder": {"type": "text", "label": "Account Holder Name", "required": true},
   "branch_code": {"type": "text", "label": "Branch/Routing Code", "required": false}}')

ON CONFLICT (code) DO NOTHING;
