#!/bin/bash
# Add entitlements route to server.js

# Add the import line after the subscription management import
docker exec request-backend-container sh -c "
sed -i '/const subscriptionManagementRoutes/a const entitlementsRoutes = require(\"./routes/entitlements\");' /app/server.js
"

# Add the route mounting after the subscription management route
docker exec request-backend-container sh -c "
sed -i '/app.use.*subscription-management/a app.use(\"/api/entitlements\", entitlementsRoutes);' /app/server.js
"

# Restart the container
docker restart request-backend-container

echo "Entitlements route added to server.js successfully!"
