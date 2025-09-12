# Payment Gateway Migration Script for Windows/PowerShell
# This script sets up the payment gateway tables

Write-Host "🚀 Running Payment Gateway Migration..." -ForegroundColor Green

# Database connection details (update these for your setup)
$DB_HOST = "localhost"
$DB_PORT = "5432"
$DB_NAME = "request_marketplace"
$DB_USER = "your_db_user"

Write-Host "📊 Creating payment gateway tables..." -ForegroundColor Yellow

# Create the SQL content
$migrationSQL = @"
-- Payment Gateway Management for Country Admins

-- Main payment gateways table
CREATE TABLE IF NOT EXISTS payment_gateways (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    supported_countries TEXT[],
    requires_api_key BOOLEAN DEFAULT true,
    requires_secret_key BOOLEAN DEFAULT true,
    requires_webhook_url BOOLEAN DEFAULT false,
    configuration_fields JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Country-specific payment gateway configurations
CREATE TABLE IF NOT EXISTS country_payment_gateways (
    id SERIAL PRIMARY KEY,
    country_code CHAR(2) NOT NULL,
    payment_gateway_id INTEGER NOT NULL REFERENCES payment_gateways(id),
    configuration JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_primary BOOLEAN DEFAULT false,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(country_code, payment_gateway_id)
);

-- Payment gateway transaction fees
CREATE TABLE IF NOT EXISTS payment_gateway_fees (
    id SERIAL PRIMARY KEY,
    country_payment_gateway_id INTEGER NOT NULL REFERENCES country_payment_gateways(id),
    transaction_type VARCHAR(50) NOT NULL,
    fee_type VARCHAR(20) NOT NULL,
    percentage_fee DECIMAL(5,2) DEFAULT 0,
    fixed_fee DECIMAL(10,2) DEFAULT 0,
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

('PayHere', 'payhere', 'Sri Lankan payment gateway', ARRAY['LK'],
 '{"merchant_id": {"type": "text", "label": "Merchant ID", "required": true},
   "merchant_secret": {"type": "password", "label": "Merchant Secret", "required": true},
   "environment": {"type": "select", "label": "Environment", "options": ["sandbox", "live"], "required": true}}')

ON CONFLICT (code) DO NOTHING;
"@

# Save to temporary file
$tempFile = [System.IO.Path]::GetTempFileName() + ".sql"
$migrationSQL | Out-File -FilePath $tempFile -Encoding UTF8

try {
    # Run the migration
    $env:PGPASSWORD = "your_password"  # Set this to your database password
    psql -h $DB_HOST -p $DB_PORT -d $DB_NAME -U $DB_USER -f $tempFile
    
    Write-Host "✅ Payment gateway tables and default gateways created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 To verify the migration:" -ForegroundColor Cyan
    Write-Host "   psql -h $DB_HOST -p $DB_PORT -d $DB_NAME -U $DB_USER -c `"SELECT name FROM payment_gateways;`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔗 You can now configure payment gateways through the admin panel" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Migration failed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # Clean up temporary file
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "🎉 Migration script completed!" -ForegroundColor Green
