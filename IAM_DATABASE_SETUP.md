# 🔐 IAM Database Authentication Setup Guide

## Current Issue Analysis
✅ **Confirmed**: Your RDS instance uses IAM authentication with 15-minute rotating tokens
❌ **Problem**: Backend is configured for static password authentication
🔧 **Solution**: Update backend to generate and refresh IAM tokens every 15 minutes

## Required Setup Steps

### Step 1: Enable IAM Authentication on RDS Instance
Run this from your local machine with AWS CLI configured:

```bash
# Enable IAM DB authentication on your RDS instance
aws rds modify-db-instance \
  --db-instance-identifier requestdb \
  --enable-iam-database-authentication \
  --apply-immediately

# Verify it's enabled
aws rds describe-db-instances \
  --db-instance-identifier requestdb \
  --query 'DBInstances[0].IAMDatabaseAuthenticationEnabled'
```

### Step 2: Create Database User for IAM Authentication

Connect to your PostgreSQL database and run:

```sql
-- Create a user for IAM authentication
CREATE USER app_user;

-- Grant necessary permissions
GRANT rds_iam TO app_user;
GRANT CONNECT ON DATABASE request TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;
```

### Step 3: Update IAM Policy

Add this policy to your EC2 instance's IAM role:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds-db:connect"
            ],
            "Resource": [
                "arn:aws:rds-db:us-east-1:*:dbuser:requestdb/app_user"
            ]
        }
    ]
}
```

### Step 4: Backend Implementation

Your Node.js backend needs to implement token generation:

```javascript
const AWS = require('aws-sdk');
const { Pool } = require('pg');

// Configure AWS SDK to use IAM role
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1'
});

const rds = new AWS.RDS();

// Generate IAM database authentication token
async function generateAuthToken() {
  const params = {
    hostname: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT) || 5432,
    username: process.env.DB_USERNAME,
    region: process.env.AWS_REGION || 'us-east-1'
  };
  
  return rds.generateDbAuthToken(params);
}

// Create database connection with IAM token
async function createConnection() {
  const authToken = await generateAuthToken();
  
  return new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USERNAME,
    password: authToken, // Use token as password
    ssl: { rejectUnauthorized: false },
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 60000
  });
}

// Refresh connection every 14 minutes
let dbPool;

async function refreshConnection() {
  if (dbPool) {
    await dbPool.end();
  }
  dbPool = await createConnection();
  console.log('Database connection refreshed with new IAM token');
}

// Initialize and set up refresh timer
refreshConnection();
setInterval(refreshConnection, 14 * 60 * 1000); // 14 minutes

module.exports = { dbPool: () => dbPool };
```

### Step 5: Environment Configuration

Update your production environment file to use IAM authentication:

```env
# Database Configuration
DB_HOST=your-rds-endpoint.amazonaws.com
DB_PORT=5432
DB_NAME=request
DB_USERNAME=app_user
DB_IAM_AUTH=true
DB_SSL=true

# AWS Configuration (No access keys needed - using IAM role)
AWS_REGION=us-east-1

# Application Configuration
NODE_ENV=production
PORT=3001
```

### Step 6: Deploy with IAM Authentication

```bash
# Deploy container with IAM role authentication
docker run -d \
  --name request-backend \
  --restart unless-stopped \
  --env-file /home/ubuntu/production.env \
  -e DB_HOST=your-rds-endpoint.amazonaws.com \
  -e DB_USERNAME=app_user \
  -e DB_NAME=request \
  -e DB_PORT=5432 \
  -e DB_SSL=true \
  -e NODE_ENV=production \
  -e PORT=3001 \
  -e AWS_REGION=us-east-1 \
  -p 0.0.0.0:3001:3001 \
  ghcr.io/cybersec-git-expert/request-backend:latest
```

## Testing IAM Authentication

```bash
# Test database connection
docker exec request-backend npm run test:db

# Check container logs for authentication
docker logs request-backend

# Test API health endpoint
curl http://localhost:3001/health
```

## Troubleshooting

### Common Issues

1. **"password authentication failed"**
   - Ensure IAM authentication is enabled on RDS
   - Verify the database user has `rds_iam` role
   - Check EC2 instance has proper IAM permissions

2. **"Token expired"**
   - Tokens expire every 15 minutes
   - Ensure your backend refreshes connections
   - Check system time synchronization

3. **"Connection timeout"**
   - Verify security groups allow database access
   - Check VPC and subnet configuration
   - Ensure RDS is accessible from EC2

### Verification Commands

```bash
# Check IAM role attached to EC2
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Test AWS CLI access
aws sts get-caller-identity

# Generate test token
aws rds generate-db-auth-token \
  --hostname your-rds-endpoint.amazonaws.com \
  --port 5432 \
  --username app_user \
  --region us-east-1
```

## Security Benefits

✅ **No hardcoded passwords** in environment files
✅ **Automatic token rotation** every 15 minutes
✅ **IAM-based access control** for database
✅ **Audit trail** through AWS CloudTrail
✅ **Fine-grained permissions** via IAM policies

## Production Checklist

- [ ] IAM authentication enabled on RDS instance
- [ ] Database user created with `rds_iam` role
- [ ] EC2 IAM role has `rds-db:connect` permission
- [ ] Backend implements token refresh logic
- [ ] Environment variables configured for IAM auth
- [ ] Health checks passing with database connection
- [ ] No AWS access keys in environment files
