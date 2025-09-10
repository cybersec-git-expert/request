// Entitlements API endpoints
app.get('/api/entitlements-simple/me', async (req, res) => {
  try {
    const userId = req.query.user_id;
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'user_id parameter required'
      });
    }
    const entitlements = await entitlementSvc.getUserEntitlements(userId);
    res.json({
      success: true,
      data: entitlements
    });
  } catch (error) {
    console.error('Error getting user entitlements:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get entitlements'
    });
  }
});

app.get('/api/entitlements/me', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }
    const entitlements = await entitlementSvc.getUserEntitlements(userId);
    res.json({
      success: true,
      data: entitlements
    });
  } catch (error) {
    console.error('Error getting user entitlements:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get entitlements'
    });
  }
});
