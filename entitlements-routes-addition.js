// Add unified entitlements routes
const entitlementsRoutes = entitlementSvc.createRoutes();
app.use('/api/entitlements-simple', entitlementsRoutes);
app.use('/api/entitlements', entitlementsRoutes);
