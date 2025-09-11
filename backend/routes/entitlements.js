const express = require('express');
const router = express.Router();

// Simple proxy route - simplified entitlements system
router.get('/user/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    
    // Simplified - everyone has full access
    const entitlements = {
      canRespond: true,
      responseCountThisMonth: 0,
      remainingResponses: -1, // unlimited
      audience: 'normal',
      isSubscribed: false
    };
    
    res.json({ success: true, data: entitlements });
  } catch (error) {
    console.error('Entitlements route error:', error);
    res.status(500).json({ success: false, error: 'Failed to get entitlements' });
  }
});

module.exports = router;
