// routes/entitlements.js - User entitlements API endpoints (simplified)

const express = require('express');
const router = express.Router();
const entitlementsService = require('../services/entitlements');

/**
 * Get user's current entitlements
 * Note: For now, using user_id from query param until auth middleware is available
 */
router.get('/me', async (req, res) => {
  try {
    const userId = req.query.user_id;
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'user_id parameter required'
      });
    }
    
    const entitlements = await entitlementsService.getUserEntitlements(userId);
    
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

/**
 * Check if user can see contact details
 */
router.get('/contact-details', async (req, res) => {
  try {
    const userId = req.query.user_id;
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'user_id parameter required'
      });
    }
    
    const canSee = await entitlementsService.canSeeContactDetails(userId);
    
    res.json({
      success: true,
      data: { canSeeContactDetails: canSee }
    });
  } catch (error) {
    console.error('Error checking contact details entitlement:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check entitlement'
    });
  }
});

/**
 * Check if user can send messages
 */
router.get('/messaging', async (req, res) => {
  try {
    const userId = req.query.user_id;
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'user_id parameter required'
      });
    }
    
    const canMessage = await entitlementsService.canSendMessages(userId);
    
    res.json({
      success: true,
      data: { canSendMessages: canMessage }
    });
  } catch (error) {
    console.error('Error checking messaging entitlement:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check entitlement'
    });
  }
});

/**
 * Check if user can respond to requests
 */
router.get('/respond', async (req, res) => {
  try {
    const userId = req.query.user_id;
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'user_id parameter required'
      });
    }
    
    const canRespond = await entitlementsService.canRespond(userId);
    
    res.json({
      success: true,
      data: { canRespond }
    });
  } catch (error) {
    console.error('Error checking response entitlement:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check entitlement'
    });
  }
});

module.exports = router;
