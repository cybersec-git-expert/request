#!/usr/bin/env bash
set -euo pipefail

# Deploy only Firestore indexes for request marketplace
if ! command -v firebase >/dev/null 2>&1; then
  echo "ERROR: firebase CLI not installed. Install with: npm i -g firebase-tools" >&2
  exit 1
fi

PROJECT_ID="request-marketplace"

echo "Using project: $PROJECT_ID"
firebase use $PROJECT_ID || firebase use --add $PROJECT_ID

echo "Deploying Firestore indexes..."
firebase deploy --only firestore:indexes

echo "Done. Visit: https://console.firebase.google.com/project/$PROJECT_ID/firestore/indexes to confirm status becomes Ready."
