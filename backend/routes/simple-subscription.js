const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');

// Get user's subscription status and remaining responses
router.get('/status', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get or create user subscription
    let subscription = await db.queryOne(`
      SELECT us.*, sp.name as plan_name, sp.response_limit, sp.features
      FROM user_simple_subscriptions us
      JOIN simple_subscription_plans sp ON us.plan_code = sp.code
      WHERE us.user_id = $1
    `, [userId]);
    
    if (!subscription) {
      // Create default free subscription
      await db.query(`
        INSERT INTO user_simple_subscriptions (user_id, plan_code)
        VALUES ($1, 'free')
      `, [userId]);
      
      subscription = await db.queryOne(`
        SELECT us.*, sp.name as plan_name, sp.response_limit, sp.features
        FROM user_simple_subscriptions us
        JOIN simple_subscription_plans sp ON us.plan_code = sp.code
        WHERE us.user_id = $1
      `, [userId]);
    }
    
    // Check if month has changed and reset if needed
    const now = new Date();
    const currentMonth = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0');
    const resetMonth = subscription.month_reset_date ? 
      new Date(subscription.month_reset_date).getFullYear() + '-' + 
      String(new Date(subscription.month_reset_date).getMonth() + 1).padStart(2, '0') : 
      currentMonth;
    
    if (currentMonth !== resetMonth) {
      await db.query(`
        UPDATE user_simple_subscriptions 
        SET responses_used_this_month = 0, 
            month_reset_date = CURRENT_DATE,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $1
      `, [userId]);
      subscription.responses_used_this_month = 0;
    }
    
    const responseLimit = subscription.response_limit === -1 ? null : subscription.response_limit;
    const responsesUsed = subscription.responses_used_this_month || 0;
    const responsesRemaining = responseLimit ? Math.max(0, responseLimit - responsesUsed) : null;
    const canRespond = responseLimit === null || responsesUsed < responseLimit;
    
    res.json({
      success: true,
      subscription: {
        plan_code: subscription.plan_code,
        plan_name: subscription.plan_name,
        responses_used: responsesUsed,
        responses_limit: responseLimit,
        responses_remaining: responsesRemaining,
        can_respond: canRespond,
        is_verified_business: subscription.is_verified_business,
        features: subscription.features || []
      }
    });
  } catch (error) {
    console.error('Get subscription status error:', error);
    res.status(500).json({ success: false, error: 'Failed to get subscription status' });
  }
});

// Check if user can respond to a request
router.get('/can-respond', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    
    const subscription = await db.queryOne(`
      SELECT us.*, sp.response_limit
      FROM user_simple_subscriptions us
      JOIN simple_subscription_plans sp ON us.plan_code = sp.code
      WHERE us.user_id = $1
    `, [userId]);
    
    if (!subscription) {
      return res.json({
        can_respond: false,
        reason: 'no_subscription',
        message: 'Please set up your subscription'
      });
    }
    
    // Unlimited plan
    if (subscription.response_limit === -1) {
      return res.json({
        can_respond: true,
        reason: 'unlimited_plan',
        responses_remaining: null
      });
    }
    
    // Check limit
    const responsesUsed = subscription.responses_used_this_month || 0;
    const canRespond = responsesUsed < subscription.response_limit;
    const responsesRemaining = Math.max(0, subscription.response_limit - responsesUsed);
    
    res.json({
      can_respond: canRespond,
      reason: canRespond ? 'within_limit' : 'limit_exceeded',
      responses_used: responsesUsed,
      responses_limit: subscription.response_limit,
      responses_remaining: responsesRemaining,
      message: canRespond ? 
        `${responsesRemaining} responses remaining this month` :
        'Monthly response limit reached. Upgrade to premium for unlimited responses.'
    });
  } catch (error) {
    console.error('Check can respond error:', error);
    res.status(500).json({ success: false, error: 'Failed to check response eligibility' });
  }
});

// Record a response (increment usage counter)
router.post('/record-response', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { request_id } = req.body;
    
    // Check if user can respond
    const subscription = await db.queryOne(`
      SELECT us.*, sp.response_limit
      FROM user_simple_subscriptions us
      JOIN simple_subscription_plans sp ON us.plan_code = sp.code
      WHERE us.user_id = $1
    `, [userId]);
    
    if (!subscription) {
      return res.status(400).json({ success: false, error: 'No subscription found' });
    }
    
    // Skip increment for unlimited plans
    if (subscription.response_limit === -1) {
      return res.json({
        success: true,
        message: 'Response recorded (unlimited plan)',
        responses_remaining: null
      });
    }
    
    // Check if within limit
    const responsesUsed = subscription.responses_used_this_month || 0;
    if (responsesUsed >= subscription.response_limit) {
      return res.status(403).json({
        success: false,
        error: 'Response limit exceeded',
        upgrade_required: true
      });
    }
    
    // Increment usage
    await db.query(`
      UPDATE user_simple_subscriptions 
      SET responses_used_this_month = responses_used_this_month + 1,
          updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
    `, [userId]);
    
    const newUsed = responsesUsed + 1;
    const responsesRemaining = Math.max(0, subscription.response_limit - newUsed);
    
    res.json({
      success: true,
      message: 'Response recorded successfully',
      responses_used: newUsed,
      responses_limit: subscription.response_limit,
      responses_remaining: responsesRemaining
    });
  } catch (error) {
    console.error('Record response error:', error);
    res.status(500).json({ success: false, error: 'Failed to record response' });
  }
});

// Get available subscription plans
router.get('/plans', async (req, res) => {
  try {
    const { country } = req.query;
    
    let plans;
    
    if (country) {
      // Get plans with country-specific pricing
      plans = await db.query(`
        SELECT 
          ssp.*,
          COALESCE(sscp.price, ssp.price) as price,
          COALESCE(sscp.currency, ssp.currency) as currency,
          sscp.is_active as country_pricing_active
        FROM simple_subscription_plans ssp
        LEFT JOIN simple_subscription_country_pricing sscp 
          ON ssp.code = sscp.plan_code 
          AND sscp.country_code = $1 
          AND sscp.is_active = true
        WHERE ssp.is_active = true 
        ORDER BY COALESCE(sscp.price, ssp.price) ASC
      `, [country]);
    } else {
      // Get default plans
      plans = await db.query(`
        SELECT * FROM simple_subscription_plans 
        WHERE is_active = true 
        ORDER BY price ASC
      `);
    }
    
    res.json({
      success: true,
      plans: plans.rows
    });
  } catch (error) {
    console.error('Get plans error:', error);
    res.status(500).json({ success: false, error: 'Failed to get plans' });
  }
});

// Subscribe to a plan
router.post('/subscribe', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { plan_code } = req.body;
    
    if (!plan_code) {
      return res.status(400).json({ success: false, error: 'Plan code is required' });
    }
    
    // Verify plan exists
    const plan = await db.queryOne(`
      SELECT * FROM simple_subscription_plans 
      WHERE code = $1 AND is_active = true
    `, [plan_code]);
    
    if (!plan) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }
    
    // Update user subscription
    await db.query(`
      INSERT INTO user_simple_subscriptions (user_id, plan_code)
      VALUES ($1, $2)
      ON CONFLICT (user_id) 
      DO UPDATE SET 
        plan_code = $2,
        updated_at = CURRENT_TIMESTAMP
    `, [userId, plan_code]);
    
    // For paid plans, you would integrate payment processing here
    // For now, we'll just activate it immediately
    
    res.json({
      success: true,
      message: 'Subscription updated successfully',
      plan_code: plan_code
    });
  } catch (error) {
    console.error('Subscribe error:', error);
    res.status(500).json({ success: false, error: 'Failed to subscribe' });
  }
});

// Mark user as verified business (admin only)
router.post('/verify-business', auth.authMiddleware(), auth.roleMiddleware(['admin', 'super_admin']), async (req, res) => {
  try {
    const { user_id } = req.body;
    
    if (!user_id) {
      return res.status(400).json({ success: false, error: 'User ID is required' });
    }
    
    await db.query(`
      UPDATE user_simple_subscriptions 
      SET is_verified_business = true,
          updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
    `, [user_id]);
    
    res.json({
      success: true,
      message: 'User verified as business successfully'
    });
  } catch (error) {
    console.error('Verify business error:', error);
    res.status(500).json({ success: false, error: 'Failed to verify business' });
  }
});

module.exports = router;
