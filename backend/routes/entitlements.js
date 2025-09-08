// routes/entitlements.js - User entitlements API endpoints

const express = require('express');
const router = express.Router();
const entitlementsService = require('../services/entitlements');
const authMiddleware = require('../middleware/auth');

/**
 * Get user's current entitlements
 */
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
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
router.get('/contact-details', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
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
router.get('/messaging', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
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
router.get('/respond', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
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

/**
 * Check notification eligibility for request type
 */
router.get('/notifications/:requestType', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const { requestType } = req.params;
    
    const shouldReceive = await entitlementsService.shouldReceiveNotifications(userId, requestType);
    
    res.json({
      success: true,
      data: { shouldReceiveNotifications: shouldReceive }
    });
  } catch (error) {
    console.error('Error checking notification entitlement:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check entitlement'
    });
  }
});

module.exports = router;
