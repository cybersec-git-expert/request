#!/bin/bash

# Script to fix email_otp_verifications table permissions for app_user
echo "🔧 Fixing email_otp_verifications table permissions..."

# Get IAM token for app_user
DB_TOKEN=$(aws rds generate-db-auth-token \
  --hostname requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com \
  --port 5432 \
  --username app_user \
  --region us-east-1)

# Check current permissions
echo "📊 Checking current permissions on email_otp_verifications table..."
PGPASSWORD="$DB_TOKEN" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=app_user sslmode=require" \
  -c "\z email_otp_verifications" || echo "❌ Failed to check permissions"

# Since app_user doesn't have admin rights, we need to use a different approach
# Let's try to see what the current error is when the backend tries to create the table
echo "🧪 Testing backend API to see the exact error..."
curl -sS 'http://127.0.0.1:3001/api/auth/send-email-otp' \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com"}' | jq '.'

echo "✅ Check completed"
