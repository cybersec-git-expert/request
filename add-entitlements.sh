#!/bin/bash
# Script to add entitlements API to the running container

# Copy the entitlements service and routes
docker cp /tmp/entitlements.js request-backend-container:/app/services/entitlements.js

# Add the route import and mounting to server.js
docker exec request-backend-container sh -c "
# Add import after other route imports
sed -i '/const subscriptionManagementRoutes/a const entitlementsRoutes = require(\"./routes/entitlements\");' /app/server.js

# Add route mounting after other routes
sed -i '/app.use.*subscription-management/a app.use(\"/api/entitlements\", entitlementsRoutes);' /app/server.js
"

# Restart the container to load the new routes
docker restart request-backend-container

echo "Entitlements API added successfully!"
