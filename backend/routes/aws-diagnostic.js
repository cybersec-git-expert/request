const express = require('express');
const router = express.Router();

// Temporary diagnostic endpoint to check AWS configuration
router.get('/aws-config-test', async (req, res) => {
  try {
    const awsConfig = {
      region: process.env.AWS_REGION || 'Not set',
      usingStaticKeys: Boolean(process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY),
      nodeEnv: process.env.NODE_ENV || 'Not set',
      sesFromEmail: process.env.SES_FROM_EMAIL || 'Not set'
    };

    // Test AWS SES configuration
    const { SESClient } = require('@aws-sdk/client-ses');
        
    let sesClientStatus = 'Not configured';
    try {
      const ses = new SESClient({
        region: process.env.AWS_REGION || 'us-east-1',
        // Use default credential provider chain (IAM role preferred)
      });
      sesClientStatus = 'Client created';
    } catch (error) {
      sesClientStatus = `Error: ${error.message}`;
    }

    res.json({
      success: true,
      timestamp: new Date().toISOString(),
      awsConfig,
      sesClientStatus,
      note: 'This is a temporary diagnostic endpoint'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

module.exports = router;
