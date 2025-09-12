# Setup and Installation Guide - Subscription & Payment Gateway System

## System Requirements

### Server Requirements
- **Node.js**: v18.0+ 
- **PostgreSQL**: v13.0+
- **Memory**: 4GB RAM minimum, 8GB recommended
- **Storage**: 20GB available space
- **Network**: HTTPS/SSL certificate for production

### Development Environment
- **Git**: Latest version
- **Code Editor**: VS Code recommended
- **Database Client**: pgAdmin, DBeaver, or psql
- **API Testing**: Postman or Insomnia

### Mobile Development
- **Flutter**: v3.0+
- **Dart**: v2.17+
- **Android Studio**: For Android development
- **Xcode**: For iOS development (macOS only)

---

## Installation Steps

### 1. Clone Repository

```bash
git clone https://github.com/cybersec-git-expert/request.git
cd request
```

### 2. Backend Setup

#### Install Dependencies
```bash
cd backend
npm install
```

#### Environment Configuration
Create `.env.rds` file:
```env
# Database Configuration
DATABASE_URL=postgresql://username:password@host:port/database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=request_marketplace
DB_USER=your_username
DB_PASSWORD=your_password

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRY=24h

# Payment Gateway Encryption
GATEWAY_ENCRYPTION_KEY=your-256-bit-encryption-key-change-in-production

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
SES_FROM_EMAIL=no-reply@yourdomain.com
SES_FROM_NAME=Request Marketplace

# S3 Configuration
S3_BUCKET_NAME=your-s3-bucket
S3_REGION=us-east-1

# Payment Gateway Configuration (Example for Stripe)
STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key
STRIPE_SECRET_KEY=sk_test_your_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# PayPal Configuration
PAYPAL_CLIENT_ID=your_paypal_client_id
PAYPAL_CLIENT_SECRET=your_paypal_client_secret
PAYPAL_ENVIRONMENT=sandbox  # or 'live' for production

# SMS Configuration
SMS_API_KEY=your_sms_api_key
SMS_SENDER_ID=RequestApp

# Server Configuration
PORT=3001
NODE_ENV=development  # or 'production'
```

#### Database Setup
```bash
# Create database
createdb request_marketplace

# Run migrations
node -e "
const db = require('./services/database');
const fs = require('fs');
async function runMigrations() {
  // Run subscription system migration
  const subscriptionSql = fs.readFileSync('./database/migrations/enhance_subscription_tracking.sql', 'utf8');
  await db.query(subscriptionSql);
  
  // Run payment gateway migration
  const gatewaysSql = fs.readFileSync('./database/migrations/create_payment_gateways.sql', 'utf8');
  await db.query(gatewaysSql);
  
  console.log('✅ All migrations completed');
  process.exit(0);
}
runMigrations().catch(console.error);
"
```

#### Start Backend Server
```bash
npm start
# or for development with auto-reload
npm run dev
```

The server will start on `http://localhost:3001`

### 3. Admin React App Setup

#### Install Dependencies
```bash
cd ../admin-react
npm install
```

#### Environment Configuration
Create `.env.local` file:
```env
REACT_APP_API_BASE_URL=http://localhost:3001
REACT_APP_STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key
REACT_APP_PAYPAL_CLIENT_ID=your_paypal_client_id
REACT_APP_ENVIRONMENT=development
```

#### Start Admin Interface
```bash
npm start
```

The admin panel will start on `http://localhost:3000`

### 4. Flutter Mobile App Setup

#### Install Dependencies
```bash
cd ../request
flutter pub get
```

#### Configuration
Update `lib/src/config/app_config.dart`:
```dart
class AppConfig {
  static const String baseUrl = 'http://localhost:3001/api';
  static const String emulatorBaseUrl = 'http://10.0.2.2:3001/api';
  static const String productionBaseUrl = 'http://3.92.216.149:3001/api';
  
  static const bool isProduction = false;
  static const bool enableLogging = true;
  
  // Payment Configuration
  static const String stripePublishableKey = 'pk_test_your_publishable_key';
  static const String paypalClientId = 'your_paypal_client_id';
}
```

#### Run Flutter App
```bash
# For Android emulator
flutter run

# For iOS simulator (macOS only)
flutter run -d ios

# For web
flutter run -d chrome
```

---

## Database Schema Setup

### Required Tables

The system requires several database tables. Run these SQL scripts in order:

#### 1. Core Subscription Tables
```sql
-- Create subscription plans table
CREATE TABLE IF NOT EXISTS simple_subscription_plans (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    features JSONB DEFAULT '[]',
    default_price DECIMAL(10,2) DEFAULT 0,
    default_currency CHAR(3) DEFAULT 'USD',
    default_response_limit INTEGER DEFAULT 3,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create country pricing table
CREATE TABLE IF NOT EXISTS simple_subscription_country_pricing (
    id SERIAL PRIMARY KEY,
    plan_code VARCHAR(50) NOT NULL REFERENCES simple_subscription_plans(code),
    country_code CHAR(2) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    currency CHAR(3) NOT NULL,
    response_limit INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    approval_status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(plan_code, country_code)
);

-- Create user subscriptions table
CREATE TABLE IF NOT EXISTS user_simple_subscriptions (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    plan_code VARCHAR(50) NOT NULL REFERENCES simple_subscription_plans(code),
    country_code CHAR(2) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    last_payment_date TIMESTAMP,
    next_payment_date TIMESTAMP,
    payment_amount DECIMAL(10,2),
    payment_currency CHAR(3),
    payment_method VARCHAR(50),
    payment_gateway_id INTEGER,
    auto_renew BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);
```

#### 2. Payment Gateway Tables
```sql
-- Create payment gateways table
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

-- Create country payment gateways table
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

-- Create payment gateway fees table
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
```

#### 3. Usage Tracking Table
```sql
-- Create usage monthly table (if not exists)
CREATE TABLE IF NOT EXISTS usage_monthly (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    year_month VARCHAR(6) NOT NULL, -- Format: YYYYMM
    response_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, year_month)
);
```

### Initial Data Setup

#### 1. Insert Default Subscription Plans
```sql
INSERT INTO simple_subscription_plans (code, name, description, features, default_price, default_currency, default_response_limit) VALUES
('Free', 'Free Plan', 'Perfect for small businesses starting out', '[]', 0.00, 'USD', 3),
('Pro', 'Pro Plan', 'Unlimited Responses', '["unlimited_responses", "priority_support"]', 9.99, 'USD', -1)
ON CONFLICT (code) DO NOTHING;
```

#### 2. Insert Default Payment Gateways
```sql
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
```

#### 3. Set Up Country-Specific Pricing (Example for Sri Lanka)
```sql
INSERT INTO simple_subscription_country_pricing (plan_code, country_code, price, currency, response_limit, approval_status) VALUES
('Free', 'LK', 0.00, 'LKR', 3, 'approved'),
('Pro', 'LK', 3500.00, 'LKR', -1, 'approved')
ON CONFLICT (plan_code, country_code) DO NOTHING;
```

---

## Payment Gateway Configuration

### 1. Stripe Setup

#### Create Stripe Account
1. Visit [Stripe Dashboard](https://dashboard.stripe.com)
2. Create account or login
3. Navigate to Developers > API Keys
4. Copy Publishable Key and Secret Key

#### Configure Webhooks
1. Go to Developers > Webhooks
2. Add endpoint: `https://yourdomain.com/api/webhooks/stripe`
3. Select events: `payment_intent.succeeded`, `payment_intent.payment_failed`
4. Copy webhook signing secret

#### Environment Configuration
```env
STRIPE_PUBLISHABLE_KEY=pk_test_51234567890
STRIPE_SECRET_KEY=sk_test_09876543210
STRIPE_WEBHOOK_SECRET=whsec_abcdef123456
```

### 2. PayPal Setup

#### Create PayPal App
1. Visit [PayPal Developer](https://developer.paypal.com)
2. Create new app
3. Select features: Accept Payments
4. Copy Client ID and Client Secret

#### Environment Configuration
```env
PAYPAL_CLIENT_ID=your_client_id
PAYPAL_CLIENT_SECRET=your_client_secret
PAYPAL_ENVIRONMENT=sandbox  # or 'live'
```

### 3. PayHere Setup (Sri Lanka)

#### Create PayHere Account
1. Visit [PayHere](https://www.payhere.lk)
2. Register merchant account
3. Get Merchant ID and Merchant Secret from dashboard

#### Environment Configuration
```env
PAYHERE_MERCHANT_ID=your_merchant_id
PAYHERE_MERCHANT_SECRET=your_merchant_secret
PAYHERE_ENVIRONMENT=sandbox  # or 'live'
```

---

## Production Deployment

### 1. Server Setup (Ubuntu/EC2)

#### Update System
```bash
sudo apt update && sudo apt upgrade -y
```

#### Install Node.js
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
```

#### Install PostgreSQL
```bash
sudo apt install postgresql postgresql-contrib
sudo -u postgres createuser --interactive
sudo -u postgres createdb request_marketplace
```

#### Install PM2 (Process Manager)
```bash
sudo npm install -g pm2
```

### 2. Application Deployment

#### Clone and Setup
```bash
cd /var/www
sudo git clone https://github.com/cybersec-git-expert/request.git
cd request/backend
sudo npm install --production
```

#### Environment Configuration
```bash
sudo nano .env.rds
# Add production environment variables
```

#### Start with PM2
```bash
sudo pm2 start server.js --name "request-backend"
sudo pm2 startup
sudo pm2 save
```

### 3. Nginx Configuration

#### Install Nginx
```bash
sudo apt install nginx
```

#### Configure Nginx
```bash
sudo nano /etc/nginx/sites-available/request-marketplace
```

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

#### Enable Site
```bash
sudo ln -s /etc/nginx/sites-available/request-marketplace /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 4. SSL Certificate

#### Install Certbot
```bash
sudo apt install certbot python3-certbot-nginx
```

#### Get Certificate
```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### 5. Database Backup

#### Setup Automated Backups
```bash
sudo nano /etc/cron.daily/postgres-backup
```

```bash
#!/bin/bash
pg_dump request_marketplace | gzip > /backup/request_marketplace_$(date +%Y%m%d).sql.gz
find /backup -name "request_marketplace_*.sql.gz" -mtime +7 -delete
```

```bash
sudo chmod +x /etc/cron.daily/postgres-backup
```

---

## Security Configuration

### 1. Firewall Setup
```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 3001  # For direct API access if needed
```

### 2. Environment Security
- Use strong, unique passwords
- Enable 2FA on all service accounts
- Rotate API keys regularly
- Use environment variables for all secrets
- Never commit sensitive data to git

### 3. Database Security
```sql
-- Create read-only user for reporting
CREATE USER report_user WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE request_marketplace TO report_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO report_user;

-- Revoke unnecessary permissions
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO app_user;
```

---

## Monitoring and Maintenance

### 1. Application Monitoring

#### Install Monitoring Tools
```bash
sudo npm install -g @pm2/monitor
pm2 monitor
```

#### Health Check Endpoint
The application provides a health check at `/health`:
```bash
curl http://localhost:3001/health
```

### 2. Log Management

#### Configure Log Rotation
```bash
sudo nano /etc/logrotate.d/request-marketplace
```

```
/var/log/request-marketplace/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

### 3. Database Maintenance

#### Vacuum and Analyze
```sql
-- Run weekly
VACUUM ANALYZE;

-- Update table statistics
ANALYZE usage_monthly;
ANALYZE user_simple_subscriptions;
```

#### Monitor Performance
```sql
-- Check slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
```

---

## Troubleshooting

### Common Issues

#### 1. Database Connection Error
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check database exists
sudo -u postgres psql -l

# Test connection
psql -h localhost -U username -d request_marketplace
```

#### 2. Payment Gateway Errors
```bash
# Check gateway configuration
curl -X GET "http://localhost:3001/api/admin/payment-gateways/gateways/LK" \
  -H "Authorization: Bearer admin-token"

# Test webhook endpoint
curl -X POST "http://localhost:3001/api/webhooks/stripe" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

#### 3. Subscription Issues
```bash
# Check subscription status
curl -X GET "http://localhost:3001/api/simple-subscription/status" \
  -H "Authorization: Bearer user-token"

# Check available plans
curl -X GET "http://localhost:3001/api/simple-subscription/plans?country=LK"
```

#### 4. Flutter App Issues
```bash
# Clear cache
flutter clean
flutter pub get

# Check API connectivity
flutter run --debug
# Check debug logs for API calls
```

### Log Analysis

#### Backend Logs
```bash
# View PM2 logs
pm2 logs request-backend

# View application logs
tail -f /var/log/request-marketplace/app.log
```

#### Database Logs
```bash
# View PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-13-main.log
```

#### Nginx Logs
```bash
# Access logs
sudo tail -f /var/log/nginx/access.log

# Error logs
sudo tail -f /var/log/nginx/error.log
```

---

## Support and Contact

### Development Team
- **Email**: dev@requestmarketplace.com
- **Slack**: #development-team
- **GitHub**: https://github.com/cybersec-git-expert/request

### Documentation
- **API Docs**: https://docs.requestmarketplace.com/api
- **Admin Guide**: https://docs.requestmarketplace.com/admin
- **Developer Portal**: https://developer.requestmarketplace.com

### Emergency Contact
- **Phone**: +94-XXX-XXX-XXXX (24/7 support)
- **Email**: emergency@requestmarketplace.com

---

This setup guide should get your subscription and payment gateway system running smoothly. For additional help or custom configuration, please contact our development team.
