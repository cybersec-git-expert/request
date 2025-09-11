const express = require('express');
const router = express.Router();
const simpleSubscriptionService = require('../services/simple-subscription-service');

/**
 * GET /api/subscription/status
 * Get user's current subscription status and usage
 */
router.get('/status', async (req, res) => {
    try {
        const userId = req.user?.id;
        
        if (!userId) {
            return res.status(401).json({
                success: false,
                error: 'User not authenticated'
            });
        }

        const status = await simpleSubscriptionService.getUserSubscriptionStatus(userId);
        
        res.json({
            success: true,
            data: status
        });
    } catch (error) {
        console.error('Error getting subscription status:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to get subscription status'
        });
    }
});

/**
 * POST /api/subscription/check-response-limit
 * Check if user can make a response
 */
router.post('/check-response-limit', async (req, res) => {
    try {
        const userId = req.user?.id;
        
        if (!userId) {
            return res.status(401).json({
                success: false,
                error: 'User not authenticated'
            });
        }

        const canRespond = await simpleSubscriptionService.canUserRespond(userId);
        const status = await simpleSubscriptionService.getUserSubscriptionStatus(userId);
        
        res.json({
            success: true,
            data: {
                canRespond,
                ...status
            }
        });
    } catch (error) {
        console.error('Error checking response limit:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to check response limit'
        });
    }
});

/**
 * GET /api/subscription/upgrade-info
 * Get information about upgrading to premium
 */
router.get('/upgrade-info', async (req, res) => {
    try {
        res.json({
            success: true,
            data: {
                currentPlan: 'free',
                freeLimit: 3,
                premiumPlan: {
                    name: 'Premium',
                    price: '$9.99/month',
                    features: [
                        'Unlimited responses',
                        'Priority support',
                        'Advanced analytics'
                    ],
                    comingSoon: true
                },
                message: 'Premium plan coming soon! For now, enjoy 3 free responses per month.'
            }
        });
    } catch (error) {
        console.error('Error getting upgrade info:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to get upgrade information'
        });
    }
});

module.exports = router;
