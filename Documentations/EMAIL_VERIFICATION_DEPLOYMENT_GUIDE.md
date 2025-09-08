# Email Verification System Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the unified email verification system to production environments. It covers AWS SES setup, database migrations, environment configuration, monitoring, and maintenance procedures.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [AWS SES Configuration](#2-aws-ses-configuration)
3. [Database Setup](#3-database-setup)
4. [Environment Configuration](#4-environment-configuration)
5. [Backend Deployment](#5-backend-deployment)
6. [Frontend Deployment](#6-frontend-deployment)
7. [Testing and Validation](#7-testing-and-validation)
8. [Monitoring and Logging](#8-monitoring-and-logging)
9. [Maintenance Procedures](#9-maintenance-procedures)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites

### System Requirements
- **Node.js**: 18.x or higher
- **PostgreSQL**: 13.x or higher
- **Flutter**: 3.13.x or higher
- **AWS Account**: With SES service access
- **Redis**: For session management (optional but recommended)

### Required Permissions
- AWS SES full access
- PostgreSQL database admin access
- Server deployment access
- Domain DNS management access

### Development Environment
```bash
# Verify Node.js version
node --version

# Verify PostgreSQL
psql --version

# Verify Flutter
flutter --version

# Verify AWS CLI
aws --version
```

---

## 2. AWS SES Configuration

### 2.1 Create AWS SES Service

#### Step 1: Setup AWS SES
```bash
# Install AWS CLI if not already installed
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

#### Step 2: Verify Domain
```bash
# Add domain to SES
aws ses verify-domain-identity --domain requestmarketplace.com

# Get verification DNS records
aws ses get-identity-verification-attributes --identities requestmarketplace.com
```

#### Step 3: Create DNS Records
Add the following DNS records to your domain:

**TXT Record for Domain Verification:**
```
_amazonses.requestmarketplace.com TXT "verification-token-from-aws"
```

**MX Record for Email Receiving (optional):**
```
requestmarketplace.com MX 10 inbound-smtp.us-east-1.amazonaws.com
```

**DKIM Records:**
```bash
# Enable DKIM
aws ses put-identity-dkim-attributes --identity requestmarketplace.com --dkim-enabled

# Get DKIM tokens
aws ses get-identity-dkim-attributes --identities requestmarketplace.com
```

Add DKIM CNAME records:
```
token1._domainkey.requestmarketplace.com CNAME token1.dkim.amazonses.com
token2._domainkey.requestmarketplace.com CNAME token2.dkim.amazonses.com
token3._domainkey.requestmarketplace.com CNAME token3.dkim.amazonses.com
```

#### Step 4: Request Production Access
```bash
# Check current sending limits
aws ses get-send-quota

# Request production access through AWS Console
# Go to SES > Account dashboard > Request production access
```

### 2.2 Create IAM User for SES

#### Create IAM Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ses:SendEmail",
        "ses:SendRawEmail",
        "ses:GetSendQuota",
        "ses:GetSendStatistics",
        "ses:GetIdentityVerificationAttributes",
        "ses:GetIdentityDkimAttributes"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Create IAM User
```bash
# Create IAM user
aws iam create-user --user-name ses-email-service

# Attach policy
aws iam attach-user-policy --user-name ses-email-service --policy-arn arn:aws:iam::account:policy/SESEmailPolicy

# Create access keys
aws iam create-access-key --user-name ses-email-service
```

---

## 3. Database Setup

### 3.1 Production Database Configuration

#### PostgreSQL Installation (Ubuntu/Debian)
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create production database
sudo -u postgres createdb request_marketplace_prod

# Create database user
sudo -u postgres psql
CREATE USER request_app WITH PASSWORD 'secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE request_marketplace_prod TO request_app;
ALTER USER request_app CREATEDB;
\q
```

#### Database Security Configuration
```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/13/main/postgresql.conf

# Update the following settings:
listen_addresses = 'localhost'
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
```

```bash
# Edit pg_hba.conf for authentication
sudo nano /etc/postgresql/13/main/pg_hba.conf

# Add the following line for app access:
local   request_marketplace_prod   request_app   md5
```

### 3.2 Run Database Migrations

#### Migration Scripts
```sql
-- 001_create_user_email_addresses.sql
CREATE TABLE IF NOT EXISTS user_email_addresses (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    email_address VARCHAR(255) NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP DEFAULT NULL,
    purpose VARCHAR(50) DEFAULT 'verification',
    verification_method VARCHAR(50) DEFAULT 'otp',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, email_address, purpose)
);

CREATE INDEX idx_user_email_addresses_user_id ON user_email_addresses(user_id);
CREATE INDEX idx_user_email_addresses_email ON user_email_addresses(email_address);
CREATE INDEX idx_user_email_addresses_verified ON user_email_addresses(is_verified);

-- 002_create_email_otp_verifications.sql
CREATE TABLE IF NOT EXISTS email_otp_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    email VARCHAR(255) NOT NULL,
    otp VARCHAR(10) NOT NULL,
    purpose VARCHAR(50) DEFAULT 'verification',
    verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP DEFAULT NULL,
    expires_at TIMESTAMP NOT NULL,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_email_otp_verifications_email ON email_otp_verifications(email);
CREATE INDEX idx_email_otp_verifications_user_id ON email_otp_verifications(user_id);
CREATE INDEX idx_email_otp_verifications_expires_at ON email_otp_verifications(expires_at);

-- 003_create_triggers.sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_email_addresses_updated_at 
    BEFORE UPDATE ON user_email_addresses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_otp_verifications_updated_at 
    BEFORE UPDATE ON email_otp_verifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Run Migrations
```bash
# Create migration script
cat > run_migrations.sh << 'EOF'
#!/bin/bash
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="request_marketplace_prod"
DB_USER="request_app"

echo "Running database migrations..."

for migration in migrations/*.sql; do
    echo "Running $migration"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$migration"
    
    if [ $? -eq 0 ]; then
        echo "✓ $migration completed successfully"
    else
        echo "✗ $migration failed"
        exit 1
    fi
done

echo "All migrations completed successfully!"
EOF

chmod +x run_migrations.sh

# Set database password and run migrations
export DB_PASSWORD="secure_password_here"
./run_migrations.sh
```

---

## 4. Environment Configuration

### 4.1 Backend Environment Variables

#### Create Production .env File
```bash
# Create production environment file
cat > .env.production << 'EOF'
# Server Configuration
NODE_ENV=production
PORT=3001
HOST=0.0.0.0

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=request_marketplace_prod
DB_USER=request_app
DB_PASSWORD=secure_password_here
DB_SSL=true

# JWT Configuration
JWT_SECRET=super_secure_jwt_secret_for_production_use_256_bits
JWT_EXPIRES_IN=24h
REFRESH_TOKEN_SECRET=super_secure_refresh_token_secret_for_production
REFRESH_TOKEN_EXPIRES_IN=7d

# AWS SES Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
SES_FROM_EMAIL=noreply@requestmarketplace.com
SES_FROM_NAME=Request Marketplace

# Email Configuration
EMAIL_OTP_EXPIRES_IN=600
EMAIL_OTP_MAX_ATTEMPTS=3
EMAIL_RATE_LIMIT_PER_HOUR=5

# Redis Configuration (if using)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis_password_here

# Logging
LOG_LEVEL=info
LOG_FILE=/var/log/request-marketplace/app.log

# CORS Configuration
CORS_ORIGIN=https://app.requestmarketplace.com,https://admin.requestmarketplace.com
CORS_CREDENTIALS=true

# Security
BCRYPT_ROUNDS=12
SESSION_SECRET=super_secure_session_secret_for_production

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
EOF
```

#### Environment Validation Script
```bash
cat > validate_env.js << 'EOF'
const requiredEnvVars = [
  'NODE_ENV',
  'PORT',
  'DB_HOST',
  'DB_NAME',
  'DB_USER',
  'DB_PASSWORD',
  'JWT_SECRET',
  'AWS_ACCESS_KEY_ID',
  'AWS_SECRET_ACCESS_KEY',
  'SES_FROM_EMAIL'
];

console.log('Validating environment variables...');

const missing = requiredEnvVars.filter(envVar => !process.env[envVar]);

if (missing.length > 0) {
  console.error('❌ Missing required environment variables:');
  missing.forEach(envVar => console.error(`  - ${envVar}`));
  process.exit(1);
}

console.log('✅ All required environment variables are set');

// Validate AWS credentials
const AWS = require('aws-sdk');
const ses = new AWS.SES({ region: process.env.AWS_REGION || 'us-east-1' });

ses.getIdentityVerificationAttributes({ 
  Identities: [process.env.SES_FROM_EMAIL] 
}, (err, data) => {
  if (err) {
    console.error('❌ AWS SES validation failed:', err.message);
  } else {
    console.log('✅ AWS SES configuration is valid');
  }
});
EOF

node validate_env.js
```

### 4.2 Frontend Environment Configuration

#### Flutter Environment Configuration
```dart
// lib/config/environment.dart
class Environment {
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isDevelopment => _environment == 'development';
  static bool get isProduction => _environment == 'production';

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  static String get baseUrl => _baseUrl;

  // Email verification configuration
  static const int otpLength = 6;
  static const int resendCooldown = 60;
  static const int maxAttempts = 3;

  // Logging configuration
  static bool get enableLogging => isDevelopment;
}
```

#### Build Configuration
```yaml
# flutter_build_config.yaml
targets:
  $default:
    builders:
      build_runner:build_to:
        generate_for:
          - lib/**
          - test/**

  production:
    builders:
      build_runner:build_to:
        options:
          environment:
            ENVIRONMENT: production
            API_BASE_URL: https://api.requestmarketplace.com
```

---

## 5. Backend Deployment

### 5.1 Server Setup

#### Install Dependencies
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 for process management
sudo npm install -g pm2

# Install Nginx for reverse proxy
sudo apt install nginx

# Install certbot for SSL certificates
sudo apt install certbot python3-certbot-nginx
```

#### Application Deployment
```bash
# Create application directory
sudo mkdir -p /opt/request-marketplace
sudo chown $USER:$USER /opt/request-marketplace

# Clone repository
git clone https://github.com/your-repo/request-marketplace.git /opt/request-marketplace
cd /opt/request-marketplace

# Install dependencies
npm ci --production

# Copy environment file
cp .env.production .env

# Build application (if needed)
npm run build

# Create log directory
sudo mkdir -p /var/log/request-marketplace
sudo chown $USER:$USER /var/log/request-marketplace
```

### 5.2 PM2 Configuration

#### PM2 Ecosystem File
```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'request-marketplace-api',
    script: './server.js',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    instances: 'max',
    exec_mode: 'cluster',
    max_memory_restart: '1G',
    node_args: '--max-old-space-size=1024',
    error_file: '/var/log/request-marketplace/error.log',
    out_file: '/var/log/request-marketplace/access.log',
    log_file: '/var/log/request-marketplace/combined.log',
    time: true,
    autorestart: true,
    max_restarts: 10,
    min_uptime: '10s',
    watch: false,
    ignore_watch: ['node_modules', 'logs', '*.log'],
    env_production: {
      NODE_ENV: 'production',
      PORT: 3001
    }
  }]
};
```

#### Start Application
```bash
# Start application with PM2
pm2 start ecosystem.config.js --env production

# Save PM2 configuration
pm2 save

# Setup PM2 startup script
pm2 startup
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME

# Verify application is running
pm2 status
pm2 logs request-marketplace-api
```

### 5.3 Nginx Configuration

#### Create Nginx Configuration
```nginx
# /etc/nginx/sites-available/request-marketplace
upstream backend {
    server 127.0.0.1:3001;
}

server {
    listen 80;
    server_name api.requestmarketplace.com;

    # Redirect all HTTP requests to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.requestmarketplace.com;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/api.requestmarketplace.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.requestmarketplace.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;

    # Main location
    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_redirect off;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://backend;
    }

    # Static files (if any)
    location /static/ {
        alias /opt/request-marketplace/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

#### Enable Configuration and SSL
```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/request-marketplace /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Obtain SSL certificate
sudo certbot --nginx -d api.requestmarketplace.com

# Restart Nginx
sudo systemctl restart nginx

# Enable auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

---

## 6. Frontend Deployment

### 6.1 Flutter Web Build

#### Build for Production
```bash
cd flutter_app

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for web
flutter build web --release --base-href "/" --web-renderer html

# Build Android APK
flutter build apk --release --target-platform android-arm64

# Build iOS (on macOS)
flutter build ios --release
```

### 6.2 Web Deployment

#### Deploy to Static Hosting (Nginx)
```bash
# Create web directory
sudo mkdir -p /var/www/request-marketplace
sudo chown $USER:$USER /var/www/request-marketplace

# Copy build files
cp -r build/web/* /var/www/request-marketplace/

# Configure Nginx for Flutter web
cat > /etc/nginx/sites-available/request-marketplace-web << 'EOF'
server {
    listen 80;
    server_name app.requestmarketplace.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name app.requestmarketplace.com;

    ssl_certificate /etc/letsencrypt/live/app.requestmarketplace.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.requestmarketplace.com/privkey.pem;

    root /var/www/request-marketplace;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/request-marketplace-web /etc/nginx/sites-enabled/
sudo certbot --nginx -d app.requestmarketplace.com
sudo systemctl reload nginx
```

### 6.3 Mobile App Deployment

#### Android Play Store
```bash
# Generate signed APK
flutter build appbundle --release

# Upload to Google Play Console
# File: build/app/outputs/bundle/release/app-release.aab
```

#### iOS App Store
```bash
# Build for iOS (on macOS)
flutter build ios --release

# Open Xcode and archive
open ios/Runner.xcworkspace

# Upload to App Store Connect through Xcode
```

---

## 7. Testing and Validation

### 7.1 API Testing

#### Health Check
```bash
# Test API health
curl https://api.requestmarketplace.com/health

# Test authentication
curl -X POST https://api.requestmarketplace.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass"}'

# Test email verification
curl -X POST https://api.requestmarketplace.com/api/email-verification/send-otp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"email":"test@example.com","purpose":"business"}'
```

#### Automated Testing Script
```bash
cat > test_deployment.sh << 'EOF'
#!/bin/bash

API_BASE="https://api.requestmarketplace.com"
ADMIN_EMAIL="admin@requestmarketplace.com"
TEST_EMAIL="test@example.com"

echo "🧪 Testing API deployment..."

# Test health endpoint
echo "Testing health endpoint..."
if curl -s "$API_BASE/health" | grep -q "OK"; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Test database connection
echo "Testing database connection..."
if curl -s "$API_BASE/api/admin/email-management/stats" -H "Authorization: Bearer $ADMIN_TOKEN" | grep -q "total_emails"; then
    echo "✅ Database connection working"
else
    echo "❌ Database connection failed"
    exit 1
fi

# Test AWS SES
echo "Testing AWS SES integration..."
if curl -s -X POST "$API_BASE/api/email-verification/send-otp" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TEST_TOKEN" \
    -d "{\"email\":\"$TEST_EMAIL\"}" | grep -q "success"; then
    echo "✅ AWS SES integration working"
else
    echo "❌ AWS SES integration failed"
    exit 1
fi

echo "🎉 All tests passed!"
EOF

chmod +x test_deployment.sh
./test_deployment.sh
```

### 7.2 Load Testing

#### Artillery Load Test
```bash
# Install Artillery
npm install -g artillery

# Create load test configuration
cat > load-test.yml << 'EOF'
config:
  target: 'https://api.requestmarketplace.com'
  phases:
    - duration: 60
      arrivalRate: 10
    - duration: 120
      arrivalRate: 20
    - duration: 60
      arrivalRate: 10
  processor: "./load-test-functions.js"

scenarios:
  - name: "Email verification flow"
    weight: 100
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "{{ $randomEmail() }}"
            password: "testpassword"
          capture:
            - json: "$.token"
              as: "authToken"
      - post:
          url: "/api/email-verification/send-otp"
          headers:
            Authorization: "Bearer {{ authToken }}"
          json:
            email: "{{ $randomEmail() }}"
            purpose: "business"
      - think: 5
EOF

# Run load test
artillery run load-test.yml
```

---

## 8. Monitoring and Logging

### 8.1 Application Monitoring

#### PM2 Monitoring
```bash
# Install PM2 monitoring
pm2 install pm2-logrotate

# Configure log rotation
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 30
pm2 set pm2-logrotate:compress true

# Monitor application
pm2 monit
```

#### Health Check Script
```bash
cat > health_check.sh << 'EOF'
#!/bin/bash

API_URL="https://api.requestmarketplace.com/health"
LOG_FILE="/var/log/request-marketplace/health-check.log"

# Check API health
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL")

if [ "$RESPONSE" -eq 200 ]; then
    echo "$(date): API health check passed" >> "$LOG_FILE"
else
    echo "$(date): API health check failed with status $RESPONSE" >> "$LOG_FILE"
    # Send alert (implement your notification system)
    echo "API health check failed" | mail -s "Alert: API Down" admin@requestmarketplace.com
fi
EOF

# Schedule health checks
chmod +x health_check.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /path/to/health_check.sh") | crontab -
```

### 8.2 Database Monitoring

#### PostgreSQL Monitoring
```sql
-- Create monitoring view
CREATE VIEW email_verification_stats AS
SELECT 
    DATE(created_at) as date,
    purpose,
    COUNT(*) as total_attempts,
    COUNT(CASE WHEN verified = true THEN 1 END) as successful_verifications,
    ROUND(
        COUNT(CASE WHEN verified = true THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as success_rate
FROM email_otp_verifications 
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at), purpose
ORDER BY date DESC, purpose;

-- Monitor daily stats
SELECT * FROM email_verification_stats 
WHERE date >= CURRENT_DATE - INTERVAL '7 days';
```

#### Automated Database Backups
```bash
cat > backup_database.sh << 'EOF'
#!/bin/bash

DB_NAME="request_marketplace_prod"
DB_USER="request_app"
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_backup_$DATE.sql"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create database backup
PGPASSWORD=$DB_PASSWORD pg_dump -h localhost -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"

# Compress backup
gzip "$BACKUP_FILE"

# Remove backups older than 30 days
find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +30 -delete

echo "Database backup created: ${BACKUP_FILE}.gz"
EOF

chmod +x backup_database.sh

# Schedule daily backups
(crontab -l 2>/dev/null; echo "0 2 * * * /path/to/backup_database.sh") | crontab -
```

### 8.3 AWS SES Monitoring

#### SES Statistics Script
```javascript
// ses_monitoring.js
const AWS = require('aws-sdk');
const ses = new AWS.SES({ region: process.env.AWS_REGION });

async function getSESStatistics() {
    try {
        const stats = await ses.getSendStatistics().promise();
        const quota = await ses.getSendQuota().promise();
        
        console.log('SES Send Statistics:');
        console.log(`Daily sending quota: ${quota.Max24HourSend}`);
        console.log(`Emails sent in last 24 hours: ${quota.SentLast24Hours}`);
        console.log(`Maximum send rate: ${quota.MaxSendRate} emails/second`);
        
        const recentStats = stats.SendDataPoints.slice(-5);
        recentStats.forEach(point => {
            console.log(`${point.Timestamp}: Sent: ${point.DeliveryAttempts}, Bounces: ${point.Bounces}, Complaints: ${point.Complaints}`);
        });
        
        return {
            quota,
            recentStats
        };
    } catch (error) {
        console.error('Error getting SES statistics:', error);
        throw error;
    }
}

// Run if called directly
if (require.main === module) {
    getSESStatistics().catch(console.error);
}

module.exports = { getSESStatistics };
```

---

## 9. Maintenance Procedures

### 9.1 Regular Maintenance Tasks

#### Weekly Tasks
```bash
cat > weekly_maintenance.sh << 'EOF'
#!/bin/bash

echo "Starting weekly maintenance..."

# Update system packages
sudo apt update && sudo apt upgrade -y

# Restart PM2 processes
pm2 restart all

# Clean up old logs
find /var/log/request-marketplace -name "*.log" -type f -mtime +7 -delete

# Clean up expired OTP records
psql -h localhost -U request_app -d request_marketplace_prod -c "
DELETE FROM email_otp_verifications 
WHERE expires_at < NOW() - INTERVAL '1 day';
"

# Check SSL certificate expiry
certbot certificates

echo "Weekly maintenance completed"
EOF

chmod +x weekly_maintenance.sh
```

#### Monthly Tasks
```bash
cat > monthly_maintenance.sh << 'EOF'
#!/bin/bash

echo "Starting monthly maintenance..."

# Analyze database performance
psql -h localhost -U request_app -d request_marketplace_prod -c "
ANALYZE;
VACUUM;
"

# Update database statistics
psql -h localhost -U request_app -d request_marketplace_prod -c "
UPDATE pg_stat_user_tables SET n_tup_ins = 0, n_tup_upd = 0, n_tup_del = 0;
"

# Clean up old verified email records (keep last 6 months)
psql -h localhost -U request_app -d request_marketplace_prod -c "
DELETE FROM user_email_addresses 
WHERE verified_at < NOW() - INTERVAL '6 months'
AND is_verified = false;
"

# Generate monthly usage report
node generate_monthly_report.js

echo "Monthly maintenance completed"
EOF

chmod +x monthly_maintenance.sh
```

### 9.2 Backup and Recovery

#### Complete Backup Script
```bash
cat > full_backup.sh << 'EOF'
#!/bin/bash

BACKUP_ROOT="/var/backups/request-marketplace"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/full_backup_$DATE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Starting full backup..."

# Backup database
echo "Backing up database..."
PGPASSWORD=$DB_PASSWORD pg_dump -h localhost -U request_app request_marketplace_prod > "$BACKUP_DIR/database.sql"

# Backup application files
echo "Backing up application files..."
tar -czf "$BACKUP_DIR/application.tar.gz" -C /opt request-marketplace

# Backup configuration files
echo "Backing up configuration files..."
mkdir -p "$BACKUP_DIR/config"
cp /etc/nginx/sites-available/request-marketplace* "$BACKUP_DIR/config/"
cp /opt/request-marketplace/.env "$BACKUP_DIR/config/"

# Backup SSL certificates
echo "Backing up SSL certificates..."
mkdir -p "$BACKUP_DIR/ssl"
cp -r /etc/letsencrypt/live/ "$BACKUP_DIR/ssl/" 2>/dev/null || true

# Create backup manifest
echo "Creating backup manifest..."
cat > "$BACKUP_DIR/manifest.txt" << EOL
Backup created: $(date)
Database: PostgreSQL dump of request_marketplace_prod
Application: /opt/request-marketplace
Configuration: Nginx configs and environment files
SSL: Let's Encrypt certificates
EOL

# Compress entire backup
tar -czf "$BACKUP_ROOT/full_backup_$DATE.tar.gz" -C "$BACKUP_ROOT" "full_backup_$DATE"
rm -rf "$BACKUP_DIR"

echo "Full backup completed: $BACKUP_ROOT/full_backup_$DATE.tar.gz"
EOF

chmod +x full_backup.sh
```

#### Recovery Procedures
```bash
cat > restore_backup.sh << 'EOF'
#!/bin/bash

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    exit 1
fi

echo "Starting restore from $BACKUP_FILE..."

# Extract backup
TEMP_DIR="/tmp/restore_$(date +%s)"
mkdir -p "$TEMP_DIR"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

BACKUP_DIR=$(find "$TEMP_DIR" -name "full_backup_*" -type d)

# Stop services
pm2 stop all
sudo systemctl stop nginx

# Restore database
echo "Restoring database..."
dropdb request_marketplace_prod
createdb request_marketplace_prod
psql -h localhost -U request_app -d request_marketplace_prod < "$BACKUP_DIR/database.sql"

# Restore application
echo "Restoring application..."
sudo rm -rf /opt/request-marketplace.backup
sudo mv /opt/request-marketplace /opt/request-marketplace.backup
sudo tar -xzf "$BACKUP_DIR/application.tar.gz" -C /opt/

# Restore configuration
echo "Restoring configuration..."
sudo cp "$BACKUP_DIR/config/"* /etc/nginx/sites-available/
sudo cp "$BACKUP_DIR/config/.env" /opt/request-marketplace/

# Restore SSL certificates
echo "Restoring SSL certificates..."
sudo cp -r "$BACKUP_DIR/ssl/"* /etc/letsencrypt/live/ 2>/dev/null || true

# Start services
sudo systemctl start nginx
pm2 start all

# Cleanup
rm -rf "$TEMP_DIR"

echo "Restore completed successfully"
EOF

chmod +x restore_backup.sh
```

---

## 10. Troubleshooting

### 10.1 Common Issues

#### API Connection Issues
```bash
# Check if API is running
curl -I https://api.requestmarketplace.com/health

# Check PM2 status
pm2 status

# Check logs
pm2 logs request-marketplace-api

# Check Nginx status
sudo systemctl status nginx
sudo nginx -t

# Check SSL certificate
sudo certbot certificates
```

#### Database Connection Issues
```bash
# Test database connection
psql -h localhost -U request_app -d request_marketplace_prod -c "SELECT 1;"

# Check PostgreSQL status
sudo systemctl status postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-13-main.log
```

#### AWS SES Issues
```bash
# Test SES configuration
node -e "
const AWS = require('aws-sdk');
const ses = new AWS.SES({region: 'us-east-1'});
ses.getIdentityVerificationAttributes({
  Identities: ['noreply@requestmarketplace.com']
}, console.log);
"

# Check SES sending limits
aws ses get-send-quota

# Check SES sending statistics
aws ses get-send-statistics
```

### 10.2 Performance Issues

#### Database Performance Tuning
```sql
-- Check slow queries
SELECT query, mean_time, calls, total_time 
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;

-- Check index usage
SELECT schemaname, tablename, attname, n_distinct, correlation 
FROM pg_stats 
WHERE tablename IN ('user_email_addresses', 'email_otp_verifications');

-- Create additional indexes if needed
CREATE INDEX CONCURRENTLY idx_email_otp_purpose_created 
ON email_otp_verifications(purpose, created_at) 
WHERE verified = false;
```

#### Application Performance Monitoring
```javascript
// Add to server.js for performance monitoring
const responseTime = require('response-time');

app.use(responseTime((req, res, time) => {
    if (time > 1000) { // Log slow requests
        console.warn(`Slow request: ${req.method} ${req.url} - ${time}ms`);
    }
}));

// Memory usage monitoring
setInterval(() => {
    const usage = process.memoryUsage();
    if (usage.heapUsed > 500 * 1024 * 1024) { // 500MB
        console.warn('High memory usage:', usage);
    }
}, 60000);
```

### 10.3 Emergency Procedures

#### Quick Recovery Steps
```bash
cat > emergency_recovery.sh << 'EOF'
#!/bin/bash

echo "🚨 Starting emergency recovery procedures..."

# Step 1: Check basic connectivity
echo "Checking basic connectivity..."
if ! curl -s https://api.requestmarketplace.com/health > /dev/null; then
    echo "❌ API is not responding"
    
    # Restart PM2 processes
    pm2 restart all
    sleep 10
    
    # Check again
    if ! curl -s https://api.requestmarketplace.com/health > /dev/null; then
        echo "❌ API still not responding after PM2 restart"
        
        # Restart Nginx
        sudo systemctl restart nginx
        sleep 5
        
        # Final check
        if ! curl -s https://api.requestmarketplace.com/health > /dev/null; then
            echo "❌ Critical: Manual intervention required"
            exit 1
        fi
    fi
fi

echo "✅ API is responding"

# Step 2: Check database
echo "Checking database connectivity..."
if ! psql -h localhost -U request_app -d request_marketplace_prod -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Database connection failed"
    sudo systemctl restart postgresql
    sleep 10
fi

echo "✅ Database is accessible"

# Step 3: Check AWS SES
echo "Checking AWS SES..."
if ! aws ses get-send-quota > /dev/null 2>&1; then
    echo "⚠️ AWS SES check failed - check credentials"
fi

echo "🎉 Emergency recovery completed"
EOF

chmod +x emergency_recovery.sh
```

---

## Summary

This deployment guide provides comprehensive instructions for setting up the unified email verification system in production. Key points:

1. **AWS SES Setup**: Domain verification, DKIM configuration, production access
2. **Database Configuration**: PostgreSQL setup, migrations, security
3. **Environment Configuration**: Production-ready environment variables
4. **Application Deployment**: PM2 process management, Nginx reverse proxy
5. **SSL/Security**: Let's Encrypt certificates, security headers
6. **Monitoring**: Health checks, logging, performance monitoring
7. **Maintenance**: Regular backups, cleanup procedures, updates
8. **Troubleshooting**: Common issues, emergency recovery procedures

The system is designed for high availability, security, and scalability with proper monitoring and maintenance procedures in place.
