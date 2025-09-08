#!/bin/bash

# Simplified AWS RDS Creation Script
# For use with AWS account that has RDS permissions

set -e

# Configuration
DB_INSTANCE_IDENTIFIER="request-marketplace-db"
DB_NAME="request_marketplace"
DB_USERNAME="admin"
DB_PASSWORD="RequestMarketplace2025!"
DB_INSTANCE_CLASS="db.t3.micro"
DB_ENGINE="postgres"
DB_ENGINE_VERSION="15.14"

echo "🚀 Creating Amazon RDS PostgreSQL instance..."
echo "Instance: $DB_INSTANCE_IDENTIFIER"
echo "Database: $DB_NAME"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Check if RDS instance already exists
if aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" &>/dev/null; then
    echo "⚠️  RDS instance already exists!"
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query "DBInstances[0].Endpoint.Address" --output text)
    echo "Endpoint: $DB_ENDPOINT"
else
    echo "📦 Creating RDS instance (this takes 10-15 minutes)..."
    
    aws rds create-db-instance \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
        --db-instance-class "$DB_INSTANCE_CLASS" \
        --engine "$DB_ENGINE" \
        --engine-version "$DB_ENGINE_VERSION" \
        --master-username "$DB_USERNAME" \
        --master-user-password "$DB_PASSWORD" \
        --allocated-storage 20 \
        --storage-type gp2 \
        --db-name "$DB_NAME" \
        --publicly-accessible \
        --backup-retention-period 7 \
        --storage-encrypted \
        --enable-performance-insights \
        --no-deletion-protection \
        --tags Key=Project,Value=RequestMarketplace

    echo "⏳ Waiting for RDS instance to be available..."
    aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_IDENTIFIER"
    
    # Get endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query "DBInstances[0].Endpoint.Address" --output text)
fi

# Create environment file
cat > .env.rds << EOF
# AWS RDS Configuration
DB_HOST=$DB_ENDPOINT
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_SSL=true
EOF

echo ""
echo "✅ RDS instance ready!"
echo "📋 Connection details saved to .env.rds"
echo "🔗 Endpoint: $DB_ENDPOINT"
echo ""
echo "🔜 Next steps:"
echo "1. Test connection: npm install pg && node test-connection.js"
echo "2. Create schema: psql -h $DB_ENDPOINT -U $DB_USERNAME -d $DB_NAME -f 01-database-schema.sql"
echo "3. Export Firebase data: node firebase-export.js"
