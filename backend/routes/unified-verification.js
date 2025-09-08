const express = require('express');
const router = express.Router();
const auth = require('../services/auth');
const { getUnifiedVerificationStatus } = require('../utils/unifiedVerification');

/**
 * Unified Verification API
 * 
 * Provides verification status checking across all three tables:
 * - users
 * - business_verifications  
 * - driver_verifications
 * 
 * This API should be used by:
 * - Admin React panel for user management
 * - Flutter apps for verification status display
 * - Any other application needing unified verification status
 */

// Get unified verification status for a user
router.get('/user/:userId', auth.authMiddleware(), async (req, res) => {
  try {
    const { userId } = req.params;
    const { 
      phone, 
      email, 
      debug = false 
    } = req.query;

    console.log(`🔍 [UNIFIED API] Getting verification status for user ${userId}`);

    const result = await getUnifiedVerificationStatus(userId, {
      checkPhone: phone,
      checkEmail: email,
      includeDebugInfo: debug === 'true'
    });

    if (!result.success) {
      return res.status(404).json({
        success: false,
        message: result.error
      });
    }

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    console.error('❌ [UNIFIED API] Error getting verification status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get verification status',
      error: error.message
    });
  }
});

// Bulk verification status check (for admin panel)
router.post('/bulk-check', auth.authMiddleware(), async (req, res) => {
  try {
    const { userIds, includeDebugInfo = false } = req.body;

    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'userIds must be a non-empty array'
      });
    }

    if (userIds.length > 100) {
      return res.status(400).json({
        success: false,
        message: 'Maximum 100 users per request'
      });
    }

    console.log(`🔍 [UNIFIED API] Bulk verification check for ${userIds.length} users`);

    const results = {};
    
    // Process users in parallel (but limit concurrency)
    const batchSize = 10;
    for (let i = 0; i < userIds.length; i += batchSize) {
      const batch = userIds.slice(i, i + batchSize);
      const batchPromises = batch.map(async (userId) => {
        try {
          const result = await getUnifiedVerificationStatus(userId, {
            includeDebugInfo
          });
          return { userId, result };
        } catch (error) {
          return { 
            userId, 
            result: { 
              success: false, 
              error: error.message,
              userId 
            } 
          };
        }
      });

      const batchResults = await Promise.all(batchPromises);
      batchResults.forEach(({ userId, result }) => {
        results[userId] = result;
      });
    }

    res.json({
      success: true,
      data: results,
      totalUsers: userIds.length,
      processedUsers: Object.keys(results).length
    });

  } catch (error) {
    console.error('❌ [UNIFIED API] Error in bulk verification check:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to perform bulk verification check',
      error: error.message
    });
  }
});

// Health check endpoint
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Unified Verification Service is running',
    timestamp: new Date().toISOString(),
    services: [
      'phone verification (across 3 tables)',
      'email verification (across 3 tables)', 
      'business verification status',
      'driver verification status',
      'user verification status'
    ]
  });
});

module.exports = router;
