#!/bin/bash

# RDS PostgreSQL Setup Script
echo "🗄️ Setting up RDS PostgreSQL Database..."

# Create RDS instance (adjust parameters as needed)
aws rds create-db-instance \
  --db-instance-identifier request-marketplace-prod \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username request_user \
  --master-user-password "YourSecurePassword123!" \
  --allocated-storage 20 \
  --max-allocated-storage 100 \
  --storage-type gp2 \
  --storage-encrypted \
  --vpc-security-group-ids sg-xxxxxxxxx \
  --db-subnet-group-name default \
  --backup-retention-period 7 \
  --monitoring-interval 60 \
  --monitoring-role-arn arn:aws:iam::account:role/rds-monitoring-role \
  --enable-performance-insights \
  --deletion-protection \
  --copy-tags-to-snapshot

echo "⏳ RDS instance creation initiated..."
echo "📋 It will take 10-15 minutes to complete"
echo "🔗 After creation, update the DB_HOST in production.env"

# Wait for RDS instance to be available
echo "⏳ Waiting for RDS instance to be available..."
aws rds wait db-instance-available --db-instance-identifier request-marketplace-prod

# Get the RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier request-marketplace-prod \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "✅ RDS Instance created successfully!"
echo "🔗 Endpoint: $RDS_ENDPOINT"
echo "📋 Update your production.env with:"
echo "DB_HOST=$RDS_ENDPOINT"
