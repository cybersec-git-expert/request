#!/bin/bash

# Script to fix missing is_urgent column in requests table
# Run this on the production server where IAM auth is available

echo "🔧 Checking and fixing is_urgent column in requests table..."

# Get IAM token
DB_TOKEN=$(aws rds generate-db-auth-token \
  --hostname requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com \
  --port 5432 \
  --username app_user \
  --region us-east-1)

# Check if column exists
echo "📊 Checking if is_urgent column exists..."
COLUMN_EXISTS=$(PGPASSWORD="$DB_TOKEN" psql \
  "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=app_user sslmode=require" \
  -t -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'requests' AND column_name = 'is_urgent'")

if [ "$COLUMN_EXISTS" -eq 0 ]; then
  echo "❌ is_urgent column does not exist. Adding it..."
  
  # Add the missing columns
  PGPASSWORD="$DB_TOKEN" psql \
    "host=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com port=5432 dbname=request user=app_user sslmode=require" \
    -c "BEGIN; 
        ALTER TABLE requests 
          ADD COLUMN is_urgent BOOLEAN NOT NULL DEFAULT false,
          ADD COLUMN urgent_until TIMESTAMPTZ,
          ADD COLUMN urgent_paid_tx_id UUID;
        CREATE INDEX IF NOT EXISTS idx_requests_urgent_active ON requests ((is_urgent AND urgent_until > now()));
        COMMIT;"
  
  if [ $? -eq 0 ]; then
    echo "✅ Successfully added is_urgent columns to requests table"
  else
    echo "❌ Failed to add is_urgent columns"
    exit 1
  fi
else
  echo "✅ is_urgent column already exists"
fi

# Test the fix by querying requests
echo "🧪 Testing requests API query..."
curl -sS 'http://127.0.0.1:3001/api/requests?limit=5' | jq '.'

echo "🎉 Fix completed successfully!"
