const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');
const { query } = require('../services/database');

// Get available subscription plans for a user's country
router.get('/plans/available', auth.authMiddleware(), async (req, res) => {
  try {
    const userCountry = req.user.country_code || 'LK';
    const result = await database.query(`
      SELECT 
        sp.code,
        sp.name,
        sp.description,
        sp.plan_type,
        sp.default_responses_per_month,
        scs.currency,
        scs.price,
        scs.ppc_price,
        scs.responses_per_month
      FROM subscription_plans sp
      LEFT JOIN subscription_country_settings scs ON sp.id = scs.plan_id AND scs.country_code = $1
      WHERE sp.status = 'active' AND (scs.is_active = true OR scs.is_active IS NULL)
      ORDER BY 
        CASE sp.plan_type 
          WHEN 'unlimited' THEN 1 
          WHEN 'ppc' THEN 2 
          ELSE 3 
        END,
        scs.price ASC
    `, [userCountry]);
    
    res.json(result.rows);
  } catch (err) {
    console.error('GET /plans/available error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Get user's current subscription status
router.get('/my-subscription', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get user's subscription info
    const subscription = await database.query(`
      SELECT 
        us.*,
        sp.name as plan_name,
        sp.description as plan_description,
        sp.plan_type
      FROM user_subscriptions us
      LEFT JOIN subscription_plans sp ON us.plan_code = sp.code
      WHERE us.user_id = $1
    `, [userId]);
    
    if (!subscription.rows[0]) {
      // Create default free subscription if doesn't exist
      await database.query(`
        INSERT INTO user_subscriptions (user_id, plan_code, registration_type, subscription_status, responses_limit)
        VALUES ($1, 'free', 'general', 'active', 3)
      `, [userId]);
      
      return res.json({
        plan_code: 'free',
        plan_name: 'Free Plan',
        registration_type: 'general',
        responses_used_this_month: 0,
        responses_limit: 3,
        contact_details_available: true,
        messaging_available: true,
        subscription_status: 'active'
      });
    }
    
    const sub = subscription.rows[0];
    
    // Check if we need to reset monthly counter
    const today = new Date();
    const lastReset = new Date(sub.last_reset_date);
    if (today.getMonth() !== lastReset.getMonth() || today.getFullYear() !== lastReset.getFullYear()) {
      await database.query(`
        UPDATE user_subscriptions 
        SET current_month_responses = 0, last_reset_date = CURRENT_DATE
        WHERE user_id = $1
      `, [userId]);
      sub.current_month_responses = 0;
    }
    
    // Determine access permissions
    const isUnlimited = sub.plan_type === 'unlimited';
    const withinLimit = sub.current_month_responses < sub.responses_limit;
    
    res.json({
      plan_code: sub.plan_code,
      plan_name: sub.plan_name || 'Free Plan',
      plan_description: sub.plan_description,
      registration_type: sub.registration_type,
      responses_used_this_month: sub.current_month_responses,
      responses_limit: isUnlimited ? null : sub.responses_limit,
      contact_details_available: isUnlimited || withinLimit,
      messaging_available: isUnlimited || withinLimit,
      subscription_status: sub.subscription_status,
      subscription_start_date: sub.subscription_start_date,
      subscription_end_date: sub.subscription_end_date,
      payment_status: sub.payment_status
    });
  } catch (err) {
    console.error('GET /my-subscription error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Check if user can view contact details for a response
router.get('/can-view-contact/:response_id', auth.authMiddleware(), async (req, res) => {
  try {
    const responseId = req.params.response_id;
    const userId = req.user.id;
    
    // Get user's subscription info
    const subscription = await database.query(`
      SELECT us.*, sp.plan_type
      FROM user_subscriptions us
      LEFT JOIN subscription_plans sp ON us.plan_code = sp.code
      WHERE us.user_id = $1
    `, [userId]);
    
    if (!subscription.rows[0]) {
      return res.json({
        can_view_contact: false,
        can_message: false,
        responses_used: 0,
        responses_limit: 3,
        plan_type: 'free',
        message: 'No subscription found'
      });
    }
    
    const sub = subscription.rows[0];
    const isUnlimited = sub.plan_type === 'unlimited';
    const withinLimit = sub.current_month_responses < sub.responses_limit;
    
    res.json({
      can_view_contact: isUnlimited || withinLimit,
      can_message: isUnlimited || withinLimit,
      responses_used: sub.current_month_responses,
      responses_limit: isUnlimited ? null : sub.responses_limit,
      plan_type: sub.plan_type || 'free',
      plan_code: sub.plan_code,
      upgrade_required: !isUnlimited && !withinLimit
    });
  } catch (err) {
    console.error('GET /can-view-contact error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Subscribe to a plan (placeholder for payment integration)
router.post('/subscribe', auth.authMiddleware(), async (req, res) => {
  try {
    const { plan_code, payment_method } = req.body;
    const userId = req.user.id;
    
    // Validate plan exists
    const plan = await database.query(
      'SELECT * FROM subscription_plans WHERE code = $1 AND status = $2',
      [plan_code, 'active']
    );
    
    if (!plan.rows[0]) {
      return res.status(404).json({ error: 'Plan not found' });
    }
    
    // For now, just return success - integrate with payment gateway later
    res.json({
      success: true,
      message: 'Subscription activated successfully',
      plan_code,
      plan_name: plan.rows[0].name,
      next_billing_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
      payment_amount: req.body.amount || 0
    });
  } catch (err) {
    console.error('POST /subscribe error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Get business registration types
router.get('/business-types', auth.authMiddleware(), async (req, res) => {
  try {
    // Return the 4 main registration types
    const businessTypes = [
      {
        type: 'general',
        name: 'General Business',
  description: 'Respond to common requests (item, service, rent, tour, construction, education, job, event, other)',
  allowed_request_types: ['item', 'service', 'rent', 'tours', 'construction', 'education', 'job', 'hiring', 'events', 'other'],
        requires_subscription: false
      },
      {
        type: 'driver',
        name: 'Driver',
  description: 'Respond to ride requests + common requests',
  allowed_request_types: ['ride', 'item', 'service', 'rent', 'tours', 'construction', 'education', 'job', 'hiring', 'events', 'other'],
        requires_subscription: false
      },
      {
        type: 'delivery',
        name: 'Delivery Business',
  description: 'Respond to delivery requests + common requests',
  allowed_request_types: ['delivery', 'item', 'service', 'rent', 'tours', 'construction', 'education', 'job', 'hiring', 'events', 'other'],
        requires_subscription: false
      },
      {
        type: 'product_seller',
        name: 'Product Seller',
  description: 'Access to price comparison module + all requests',
  allowed_request_types: ['item', 'service', 'rent', 'tours', 'construction', 'education', 'job', 'hiring', 'events', 'other', 'delivery'],
        requires_subscription: true,
        available_plans: ['pro_seller_monthly', 'pro_seller_ppc']
      }
    ];
    
    res.json(businessTypes);
  } catch (err) {
    console.error('GET /business-types error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Track user response submission (call this when user submits a response)
router.post('/track-response', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { request_id, response_text } = req.body;
    
    // Get user's subscription info
    const subscription = await database.query(`
      SELECT us.*, sp.plan_type
      FROM user_subscriptions us
      LEFT JOIN subscription_plans sp ON us.plan_code = sp.code
      WHERE us.user_id = $1
    `, [userId]);
    
    if (!subscription.rows[0]) {
      return res.status(400).json({ error: 'No subscription found' });
    }
    
    const sub = subscription.rows[0];
    const isUnlimited = sub.plan_type === 'unlimited';
    
    // Check if user has reached limit
    if (!isUnlimited && sub.current_month_responses >= sub.responses_limit) {
      return res.status(403).json({ 
        error: 'Response limit reached',
        upgrade_required: true,
        current_plan: sub.plan_code
      });
    }
    
    // Record the response
    await database.query(`
      INSERT INTO user_responses (user_id, request_id, response_text, contact_revealed)
      VALUES ($1, $2, $3, $4)
    `, [userId, request_id, response_text, !isUnlimited && sub.current_month_responses < sub.responses_limit]);
    
    // Increment counter for non-unlimited plans
    if (!isUnlimited) {
      await database.query(`
        UPDATE user_subscriptions 
        SET current_month_responses = current_month_responses + 1
        WHERE user_id = $1
      `, [userId]);
    }
    
    res.json({
      success: true,
      responses_used: sub.current_month_responses + 1,
      responses_limit: isUnlimited ? null : sub.responses_limit,
      contact_revealed: isUnlimited || sub.current_month_responses < sub.responses_limit
    });
    
  } catch (err) {
    console.error('POST /track-response error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Update user registration type
router.post('/update-registration-type', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { registration_type } = req.body;
    
    const validTypes = ['general', 'driver', 'delivery', 'product_seller'];
    if (!validTypes.includes(registration_type)) {
      return res.status(400).json({ error: 'Invalid registration type' });
    }
    
    // Update user subscription
    await database.query(`
      UPDATE user_subscriptions 
      SET registration_type = $1
      WHERE user_id = $2
    `, [registration_type, userId]);
    
    res.json({
      success: true,
      registration_type,
      message: `Registration type updated to ${registration_type}`
    });
    
  } catch (err) {
    console.error('POST /update-registration-type error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

module.exports = router;
// Capabilities endpoint: returns booleans for features based on registration type and plan
router.get('/capabilities', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const country = req.user.country_code || 'LK';
    // Load subscription
    const sub = await database.query(`
      SELECT us.*, sp.plan_type
      FROM user_subscriptions us
      LEFT JOIN subscription_plans sp ON sp.code = us.plan_code
      WHERE us.user_id = $1
    `, [userId]);
    const s = sub.rows?.[0] || null;
    const regType = s?.registration_type || 'general';
    // Defaults
    let canRespondToRide = regType === 'driver';
    let canRespondToDelivery = regType === 'delivery';
    // Product seller add price requires specific plans (from mappings if present)
    let canAddPrice = false;
    const allowedSellerPlans = new Set(['pro_seller_monthly','pro_seller_ppc']);
    try {
      // Try to fetch mapped plans for Product Seller for this country
      const bt = await database.query(`SELECT id FROM business_types WHERE LOWER(name) = LOWER('Product Seller') AND country_code=$1`, [country]);
      const btId = bt.rows?.[0]?.id;
      if (btId) {
        const maps = await database.query(`
          SELECT sp.code FROM business_type_plan_mappings m
          JOIN subscription_plans sp ON sp.id = m.plan_id
          WHERE m.country_code = $1 AND m.business_type_id = $2 AND m.is_active = true
        `, [country, btId]);
        if (maps.rows?.length) {
          allowedSellerPlans.clear();
          maps.rows.forEach(r => allowedSellerPlans.add(r.code));
        }
      }
    } catch (_) {}
    if (regType === 'product_seller' && s?.plan_code && allowedSellerPlans.has(s.plan_code)) {
      canAddPrice = true;
    }
    res.json({ canRespondToRide, canRespondToDelivery, canAddPrice, registration_type: regType, plan_code: s?.plan_code || 'free' });
  } catch (err) {
    console.error('GET /capabilities error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Determine eligibility for responding to a request type (ride, delivery, item, etc.)
// Query params: request_type
router.get('/eligibility', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const requestType = (req.query.request_type || '').toString().toLowerCase();

    // Load subscription
    const r = await database.query(`
      SELECT us.*, sp.plan_type
      FROM user_subscriptions us
      LEFT JOIN subscription_plans sp ON sp.code = us.plan_code
      WHERE us.user_id = $1
    `, [userId]);

    // Default fallback if no subscription row
    let sub = r.rows?.[0] || {
      plan_code: 'free',
      plan_type: 'free',
      registration_type: 'general',
      responses_limit: 3,
      current_month_responses: 0,
      last_reset_date: new Date()
    };

    // Compute current month usage (don't mutate DB here)
    let used = Number(sub.current_month_responses || 0);
    const lastReset = sub.last_reset_date ? new Date(sub.last_reset_date) : new Date();
    const now = new Date();
    if (now.getMonth() !== lastReset.getMonth() || now.getFullYear() !== lastReset.getFullYear()) {
      used = 0; // treat as reset for read-only eligibility
    }

    const isUnlimited = sub.plan_type === 'unlimited';
    const limit = isUnlimited ? null : Number(sub.responses_limit || 0);
    const withinLimit = isUnlimited || used < (limit ?? 0);

    const regType = (sub.registration_type || 'general').toLowerCase();
    // Role-based gating
    let roleAllows = true;
    let needs_role = false;
    let reason = undefined;
    if (requestType === 'ride') {
      roleAllows = regType === 'driver';
      if (!roleAllows) { needs_role = true; reason = 'driver_required'; }
    } else if (requestType === 'delivery') {
      roleAllows = regType === 'delivery';
      if (!roleAllows) { needs_role = true; reason = 'delivery_role_required'; }
    }

    const can_respond = roleAllows;
    const can_view_contact = roleAllows && (isUnlimited || withinLimit);
    const upgrade_required = roleAllows && !isUnlimited && !withinLimit;

    res.json({
      can_respond,
      can_view_contact,
      upgrade_required,
      needs_role,
      reason,
      registration_type: regType,
      plan_code: sub.plan_code || 'free',
      responses_used: used,
      responses_limit: limit
    });
  } catch (err) {
    console.error('GET /eligibility error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Initialize membership screen for Flutter: returns roles + available plans for user's country
router.get('/membership-init', auth.authMiddleware(), async (req, res) => {
  try {
    const country = req.user.country_code || 'LK';

    // Plans for user's country (publicly available + active)
    const plans = await database.query(`
      SELECT 
        sp.code,
        sp.name,
        sp.description,
        sp.plan_type,
        sp.default_responses_per_month,
        scs.currency,
        scs.price,
        scs.ppc_price,
        scs.responses_per_month
      FROM subscription_plans sp
      LEFT JOIN subscription_country_settings scs ON sp.id = scs.plan_id AND scs.country_code = $1
      WHERE sp.status = 'active' AND (scs.is_active = true OR scs.is_active IS NULL)
      ORDER BY 
        CASE sp.plan_type 
          WHEN 'unlimited' THEN 1 
          WHEN 'ppc' THEN 2 
          ELSE 3 
        END,
        scs.price ASC
    `, [country]);

    // Roles (registration types)
    const roles = [
      {
        type: 'general',
        name: 'General Business',
        description: 'Respond to common requests (item, service, rent, tour, construction, education, hiring, event, other)',
        allowed_request_types: ['item', 'service', 'rent', 'tours', 'construction', 'education', 'hiring', 'events', 'other'],
        requires_subscription: false
      },
      {
        type: 'driver',
        name: 'Driver',
        description: 'Respond to ride requests + common requests',
        allowed_request_types: ['ride', 'item', 'service', 'rent', 'tours', 'construction', 'education', 'hiring', 'events', 'other'],
        requires_subscription: false
      },
      {
        type: 'delivery',
        name: 'Delivery Business',
        description: 'Respond to delivery requests + common requests',
        allowed_request_types: ['delivery', 'item', 'service', 'rent', 'tours', 'construction', 'education', 'hiring', 'events', 'other'],
        requires_subscription: false
      },
      {
        type: 'product_seller',
        name: 'Product Seller',
        description: 'Access to price comparison module + all requests',
        allowed_request_types: ['item', 'service', 'rent', 'tours', 'construction', 'education', 'hiring', 'events', 'other', 'delivery'],
        requires_subscription: true
      }
    ];

    // Country-specific allowed plans for Product Seller via mappings (supports UUID/int id types)
    let sellerPlanCodes = new Set(['pro_seller_monthly', 'pro_seller_ppc']);
    try {
      const bt = await database.query(
        `SELECT id::text AS cbt_id, COALESCE(global_business_type_id, 0)::text AS gbt_id
         FROM country_business_types
         WHERE country_code = $1 AND LOWER(name) = LOWER('Product Seller')
         LIMIT 1`,
        [country]
      );
      const ids = [];
      const row = bt.rows?.[0];
      if (row?.cbt_id) ids.push(row.cbt_id);
      if (row?.gbt_id && row.gbt_id !== '0') ids.push(row.gbt_id);
      if (ids.length) {
        const maps = await database.query(`
          SELECT DISTINCT sp.code
          FROM business_type_plan_mappings m
          JOIN subscription_plans sp ON sp.id = m.plan_id
          WHERE m.country_code = $1 AND m.is_active = true AND m.business_type_id::text = ANY($2::text[])
        `, [country, ids]);
        if (maps.rows?.length) {
          sellerPlanCodes = new Set(maps.rows.map(r => r.code));
        }
      }
    } catch (_) {}

    res.json({
      country,
      roles,
      plans: plans.rows,
      seller_plan_codes: Array.from(sellerPlanCodes)
    });
  } catch (err) {
    console.error('GET /membership-init error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});
