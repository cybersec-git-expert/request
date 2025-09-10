const express = require('express');
const router = express.Router();
const entitlementsService = require('../entitlements');

// Simple entitlements API endpoints
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const result = await entitlementsService.getUserEntitlements(userId);
    res.json(result);
  } catch (error) {
    console.error('Error getting user entitlements:', error);
    res.status(500).json({ error: 'Failed to get entitlements' });
  }
});

module.exports = router;
