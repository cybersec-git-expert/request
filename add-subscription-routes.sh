#!/bin/bash
# Script to add subscription-management routes to the running container

# Copy the subscription-management.js file
docker cp /tmp/subscription-management.js request-backend-container:/app/routes/

# Add the import and route mounting to server.js
docker exec request-backend-container sh -c "
# Add import after the existing subscription imports
sed -i '/subscriptionPlansNewRoutes.*subscription-plans-new/a const subscriptionManagementRoutes = require(\"./routes/subscription-management\");' /app/server.js

# Add route mounting after the existing subscription routes
sed -i '/app.use.*subscription-plans-new/a app.use(\"/api/subscription-management\", subscriptionManagementRoutes);' /app/server.js
"

# Restart the container to load the new routes
docker restart request-backend-container

echo "Subscription management routes added successfully!"
