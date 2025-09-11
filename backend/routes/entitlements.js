const express = require('express');
const router = express.Router();
const entitlementsService = require('../services/entitlements-service');

// Get entitlements for a specific user
router.get('/user/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    const entitlements = await entitlementsService.getEntitlements(userId);
    res.json({ success: true, data: entitlements });
  } catch (error) {
    console.error('Entitlements route error:', error);
    res.status(500).json({ success: false, error: 'Failed to get entitlements' });
  }
});

module.exports = router;
