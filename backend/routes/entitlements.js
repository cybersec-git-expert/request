const express = require('express');
const router = express.Router();
const entitlementsService = require('../entitlements');

// Simple proxy route to existing entitlements service
router.get('/user/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    const entitlements = await entitlementsService.getUserEntitlements(userId);
    res.json({ success: true, data: entitlements });
  } catch (error) {
    console.error('Entitlements route error:', error);
    res.status(500).json({ success: false, error: 'Failed to get entitlements' });
  }
});

module.exports = router;
