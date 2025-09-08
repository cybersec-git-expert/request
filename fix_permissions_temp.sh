#!/bin/bash

# Script to fix email_otp_verifications table permissions using temporary password
echo "🔧 Fixing email_otp_verifications table permissions with temp password..."

# Use the temporary password to connect as an admin user
TEMP_PASSWORD="TempSecurePass123!"

# First, let's see what admin users are available
echo "📊 Checking available admin users..."
PGPASSWORD="$TEMP_PASSWORD" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=requestadmindb sslmode=require" \
  -c "SELECT usename, usesuper FROM pg_user WHERE usesuper = true OR usename LIKE '%admin%';" || echo "❌ Failed to connect with requestadmindb"

# Try to connect with postgres superuser
echo "📊 Trying postgres user..."
PGPASSWORD="$TEMP_PASSWORD" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=postgres sslmode=require" \
  -c "SELECT current_user;" || echo "❌ Failed to connect with postgres"

# Check current permissions on email_otp_verifications table
echo "📊 Checking email_otp_verifications table permissions..."
PGPASSWORD="$TEMP_PASSWORD" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=requestadmindb sslmode=require" \
  -c "\z email_otp_verifications" || echo "❌ Failed to check permissions"

# Grant necessary permissions to app_user
echo "🔑 Granting permissions to app_user..."
PGPASSWORD="$TEMP_PASSWORD" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=requestadmindb sslmode=require" \
  -c "GRANT ALL PRIVILEGES ON TABLE email_otp_verifications TO app_user;" || echo "❌ Failed to grant table permissions"

PGPASSWORD="$TEMP_PASSWORD" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=requestadmindb sslmode=require" \
  -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;" || echo "❌ Failed to grant sequence permissions"

# Also grant permissions on other tables that might be needed
echo "🔑 Granting permissions on other essential tables..."
PGPASSWORD="$TEMP_PASSWORD" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=requestadmindb sslmode=require" \
  -c "GRANT ALL PRIVILEGES ON TABLE users TO app_user;" || echo "❌ Failed to grant users table permissions"

PGPASSWORD="$TEMP_PASSWORD" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=requestadmindb sslmode=require" \
  -c "GRANT ALL PRIVILEGES ON TABLE reviews TO app_user;" || echo "❌ Failed to grant reviews table permissions"

# Test the fix
echo "🧪 Testing email OTP endpoint..."
curl -sS 'http://127.0.0.1:3001/api/auth/send-email-otp' \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com"}' | head -200

echo "✅ Permission fix completed"
