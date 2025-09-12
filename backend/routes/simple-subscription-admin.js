const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');

// ===========================================
// SIMPLE SUBSCRIPTION PLAN MANAGEMENT
// ===========================================

// Get all subscription plans (with country pricing)
router.get('/plans', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { country } = req.query;
    const { role } = req.user;
    
    let plans;
    
    if (role === 'super_admin') {
      // Super admin sees all plans
      plans = await db.query(`
        SELECT 
          ssp.*,
          COALESCE(
            json_agg(
              json_build_object(
                'country_code', sscp.country_code,
                'price', sscp.price,
                'currency', sscp.currency,
                'is_active', sscp.is_active,
                'pending_approval', NOT sscp.is_active
              )
            ) FILTER (WHERE sscp.id IS NOT NULL),
            '[]'::json
          ) as country_pricing
        FROM simple_subscription_plans ssp
        LEFT JOIN simple_subscription_country_pricing sscp ON ssp.code = sscp.plan_code
        GROUP BY ssp.id, ssp.code, ssp.name, ssp.description, ssp.price, ssp.currency, ssp.response_limit, ssp.features, ssp.is_active, ssp.created_at, ssp.updated_at
        ORDER BY ssp.price ASC
      `);
    } else {
      // Country admin sees plans for their country
      const countryCode = req.user.country_code || country;
      plans = await db.query(`
        SELECT 
          ssp.*,
          sscp.price as country_price,
          sscp.currency as country_currency,
          sscp.is_active as country_active,
          CASE WHEN sscp.is_active = false THEN true ELSE false END as pending_approval
        FROM simple_subscription_plans ssp
        LEFT JOIN simple_subscription_country_pricing sscp ON ssp.code = sscp.plan_code AND sscp.country_code = $1
        WHERE ssp.is_active = true
        ORDER BY ssp.price ASC
      `, [countryCode]);
    }
    
    res.json({ success: true, data: plans.rows });
  } catch (e) {
    console.error('Get subscription plans failed', e);
    res.status(500).json({ success: false, error: 'Failed to get plans' });
  }
});

// Create new subscription plan (super admin only)
// Create subscription plan template (super admin only)
router.post('/plans', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { code, name, description, features } = req.body;
    
    if (!code || !name) {
      return res.status(400).json({ 
        success: false, 
        error: 'code and name are required for plan template' 
      });
    }
    
    // Create template with null values for pricing (will be set by country pricing)
    const plan = await db.queryOne(`
      INSERT INTO simple_subscription_plans (code, name, description, price, currency, response_limit, features)
      VALUES ($1, $2, $3, NULL, NULL, NULL, $4::jsonb) 
      RETURNING *
    `, [code, name, description || '', JSON.stringify(features || [])]);
    
    res.status(201).json({ success: true, data: plan });
  } catch (e) {
    console.error('Create subscription plan template failed', e);
    if (e.code === '23505') { // Unique constraint violation
      res.status(400).json({ success: false, error: 'Plan code already exists' });
    } else {
      res.status(500).json({ success: false, error: 'Failed to create plan template' });
    }
  }
});

// Update subscription plan (super admin only)
router.put('/plans/:code', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { code } = req.params;
    const { name, description, price, currency, response_limit, features, is_active } = req.body;
    
    const plan = await db.queryOne(`
      UPDATE simple_subscription_plans 
      SET 
        name = COALESCE($2, name),
        description = COALESCE($3, description),
        price = COALESCE($4, price),
        currency = COALESCE($5, currency),
        response_limit = COALESCE($6, response_limit),
        features = COALESCE($7::jsonb, features),
        is_active = COALESCE($8, is_active),
        updated_at = CURRENT_TIMESTAMP
      WHERE code = $1
      RETURNING *
    `, [code, name, description, price, currency, response_limit, JSON.stringify(features), is_active]);
    
    if (!plan) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }
    
    res.json({ success: true, data: plan });
  } catch (e) {
    console.error('Update subscription plan failed', e);
    res.status(500).json({ success: false, error: 'Failed to update plan' });
  }
});

// Delete subscription plan (super admin only)
router.delete('/plans/:code', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { code } = req.params;
    
    // Check if plan is in use
    const usageCount = await db.queryOne(`
      SELECT COUNT(*) as count FROM user_simple_subscriptions WHERE plan_code = $1
    `, [code]);
    
    if (usageCount.count > 0) {
      return res.status(400).json({ 
        success: false, 
        error: `Cannot delete plan. ${usageCount.count} users are currently using this plan.` 
      });
    }
    
    const result = await db.query(`DELETE FROM simple_subscription_plans WHERE code = $1`, [code]);
    
    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }
    
    res.json({ success: true, message: 'Plan deleted successfully' });
  } catch (e) {
    console.error('Delete subscription plan failed', e);
    res.status(500).json({ success: false, error: 'Failed to delete plan' });
  }
});

// ===========================================
// COUNTRY-SPECIFIC PRICING MANAGEMENT
// ===========================================

// Set country-specific pricing (country admin creates, super admin approves)
// Set country pricing (country admin or super admin)
router.post('/plans/:code/pricing', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { code } = req.params;
    const { country_code, price, currency, response_limit } = req.body;
    
    if (!country_code || price === undefined || !currency || response_limit === undefined) {
      return res.status(400).json({ 
        success: false, 
        error: 'country_code, price, currency, and response_limit are required' 
      });
    }
    
    // Country admins can only set pricing for their own country
    if (req.user.role === 'country_admin' && req.user.country_code !== country_code) {
      return res.status(403).json({ 
        success: false, 
        error: 'Country admins can only set pricing for their own country' 
      });
    }
    
    // Country admin submissions are pending approval (is_active = false)
    const isActive = req.user.role === 'super_admin';
    
    // First check if the plan exists
    const planExists = await db.queryOne('SELECT code FROM simple_subscription_plans WHERE code = $1', [code]);
    if (!planExists) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }
    
    const pricing = await db.queryOne(`
      INSERT INTO simple_subscription_country_pricing (plan_code, country_code, price, currency, response_limit, is_active)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (plan_code, country_code)
      DO UPDATE SET 
        price = EXCLUDED.price,
        currency = EXCLUDED.currency,
        response_limit = EXCLUDED.response_limit,
        is_active = CASE WHEN $7 = 'super_admin' THEN EXCLUDED.is_active ELSE false END,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `, [code, country_code, price, currency, response_limit, isActive, req.user.role]);
    
    res.status(201).json({ success: true, data: pricing });
  } catch (e) {
    console.error('Set country pricing failed', e);
    res.status(500).json({ success: false, error: 'Failed to set pricing' });
  }
});

// Get country pricing for a plan
router.get('/plans/:code/pricing', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { code } = req.params;
    const { country } = req.query;
    
    let where = 'plan_code = $1';
    let params = [code];
    
    if (country) {
      where += ' AND country_code = $2';
      params.push(country);
    }
    
    const pricing = await db.query(`
      SELECT sscp.*, c.name as country_name 
      FROM simple_subscription_country_pricing sscp
      LEFT JOIN countries c ON sscp.country_code = c.code
      WHERE ${where} 
      ORDER BY sscp.country_code
    `, params);
    
    res.json({ success: true, data: pricing.rows });
  } catch (e) {
    console.error('Get country pricing failed', e);
    res.status(500).json({ success: false, error: 'Failed to get pricing' });
  }
});

// Approve/reject country pricing (super admin only)
router.put('/plans/:code/pricing/:country', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { code, country } = req.params;
    const { is_active } = req.body;
    
    const pricing = await db.queryOne(`
      UPDATE simple_subscription_country_pricing 
      SET is_active = $1, updated_at = CURRENT_TIMESTAMP
      WHERE plan_code = $2 AND country_code = $3
      RETURNING *
    `, [!!is_active, code, country]);
    
    if (!pricing) {
      return res.status(404).json({ success: false, error: 'Pricing not found' });
    }
    
    res.json({ success: true, data: pricing });
  } catch (e) {
    console.error('Update pricing approval failed', e);
    res.status(500).json({ success: false, error: 'Failed to update approval' });
  }
});

// ===========================================
// PENDING APPROVALS AND DASHBOARD
// ===========================================

// Get pending pricing approvals (super admin only)
router.get('/pending-approvals', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const pending = await db.query(`
      SELECT 
        sscp.*,
        ssp.name as plan_name,
        c.name as country_name,
        'simple_subscription' as pricing_type
      FROM simple_subscription_country_pricing sscp
      JOIN simple_subscription_plans ssp ON sscp.plan_code = ssp.code
      LEFT JOIN countries c ON sscp.country_code = c.code
      WHERE sscp.is_active = false
      ORDER BY sscp.updated_at DESC
    `);
    
    res.json({ success: true, data: pending.rows });
  } catch (e) {
    console.error('Get pending approvals failed', e);
    res.status(500).json({ success: false, error: 'Failed to get pending approvals' });
  }
});

// Get subscription analytics
router.get('/analytics', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { country } = req.query;
    const { role } = req.user;
    
    let whereClause = '';
    let params = [];
    
    if (role === 'country_admin') {
      const countryCode = req.user.country_code || country;
      if (countryCode) {
        // Note: We'll need to add country tracking to user_simple_subscriptions table
        whereClause = 'WHERE u.country_code = $1';
        params.push(countryCode);
      }
    } else if (country) {
      whereClause = 'WHERE u.country_code = $1';
      params.push(country);
    }
    
    // Total subscriptions by plan using new template-based structure
    const planStats = await db.query(`
      SELECT 
        uss.plan_code,
        spt.name as plan_name,
        COALESCE(scp.price, 0) as price,
        COALESCE(scp.currency, 'USD') as currency,
        COUNT(*) as total_users,
        SUM(CASE WHEN uss.is_verified_business THEN 1 ELSE 0 END) as verified_users
      FROM user_simple_subscriptions uss
      JOIN subscription_plan_templates spt ON uss.plan_code = spt.code
      LEFT JOIN subscription_country_pricing scp ON spt.code = scp.plan_code 
        AND scp.is_active = true
        ${role === 'country_admin' ? 'AND scp.country_code = $' + (params.length + 1) : ''}
      LEFT JOIN users u ON uss.user_id = u.id
      ${whereClause}
      GROUP BY uss.plan_code, spt.name, scp.price, scp.currency
      ORDER BY COALESCE(scp.price, 0) ASC
    `, role === 'country_admin' && req.user.country_code ? [...params, req.user.country_code] : params);
    
    // Monthly revenue (estimated) using new template-based structure
    const revenueStats = await db.query(`
      SELECT 
        DATE_TRUNC('month', uss.created_at) as month,
        SUM(COALESCE(scp.price, 0)) as estimated_revenue,
        string_agg(DISTINCT scp.currency, ', ') as currencies
      FROM user_simple_subscriptions uss
      JOIN subscription_plan_templates spt ON uss.plan_code = spt.code
      LEFT JOIN subscription_country_pricing scp ON spt.code = scp.plan_code 
        AND scp.is_active = true
        ${role === 'country_admin' ? 'AND scp.country_code = $' + (params.length + 1) : ''}
      LEFT JOIN users u ON uss.user_id = u.id
      ${whereClause}
      WHERE uss.created_at >= CURRENT_DATE - INTERVAL '12 months'
      GROUP BY DATE_TRUNC('month', uss.created_at)
      ORDER BY month DESC
    `, role === 'country_admin' && req.user.country_code ? [...params, req.user.country_code] : params);
    
    // Usage statistics using new template-based structure
    const usageStats = await db.query(`
      SELECT 
        AVG(uss.responses_used_this_month) as avg_responses_used,
        COUNT(CASE WHEN uss.responses_used_this_month >= COALESCE(scp.response_limit, 0) AND COALESCE(scp.response_limit, 0) > 0 THEN 1 END) as users_at_limit
      FROM user_simple_subscriptions uss
      JOIN subscription_plan_templates spt ON uss.plan_code = spt.code
      LEFT JOIN subscription_country_pricing scp ON spt.code = scp.plan_code 
        AND scp.is_active = true
        ${role === 'country_admin' ? 'AND scp.country_code = $' + (params.length + 1) : ''}
      LEFT JOIN users u ON uss.user_id = u.id
      ${whereClause}
    `, role === 'country_admin' && req.user.country_code ? [...params, req.user.country_code] : params);
    
    res.json({ 
      success: true, 
      data: {
        plan_statistics: planStats.rows,
        revenue_trends: revenueStats.rows,
        usage_statistics: usageStats.rows[0] || {}
      }
    });
  } catch (e) {
    console.error('Get analytics failed', e);
    res.status(500).json({ success: false, error: 'Failed to get analytics' });
  }
});

// ===========================================
// USER SUBSCRIPTION MANAGEMENT
// ===========================================

// Get all user subscriptions
router.get('/users', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { country, plan_code } = req.query;
    const { role } = req.user;
    
    let whereClause = 'WHERE 1=1';
    let params = [];
    let paramCount = 0;
    
    if (role === 'country_admin') {
      const countryCode = req.user.country_code || country;
      if (countryCode) {
        whereClause += ` AND u.country_code = $${++paramCount}`;
        params.push(countryCode);
      }
    } else if (country) {
      whereClause += ` AND u.country_code = $${++paramCount}`;
      params.push(country);
    }
    
    if (plan_code) {
      whereClause += ` AND uss.plan_code = $${++paramCount}`;
      params.push(plan_code);
    }
    
    const subscriptions = await db.query(`
      SELECT 
        uss.*,
        ssp.name as plan_name,
        ssp.price as plan_price,
        ssp.response_limit,
        u.email,
        u.first_name,
        u.last_name,
        u.country_code,
        u.phone
      FROM user_simple_subscriptions uss
      JOIN simple_subscription_plans ssp ON uss.plan_code = ssp.code
      LEFT JOIN users u ON uss.user_id = u.id
      ${whereClause}
      ORDER BY uss.updated_at DESC
      LIMIT 1000
    `, params);
    
    res.json({ success: true, data: subscriptions.rows });
  } catch (e) {
    console.error('Get user subscriptions failed', e);
    res.status(500).json({ success: false, error: 'Failed to get user subscriptions' });
  }
});

// Update user subscription (admin override)
router.put('/users/:userId/subscription', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { userId } = req.params;
    const { plan_code, is_verified_business } = req.body;
    
    if (!plan_code) {
      return res.status(400).json({ success: false, error: 'plan_code is required' });
    }
    
    // Verify plan exists
    const plan = await db.queryOne(`
      SELECT * FROM simple_subscription_plans 
      WHERE code = $1 AND is_active = true
    `, [plan_code]);
    
    if (!plan) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }
    
    const subscription = await db.queryOne(`
      INSERT INTO user_simple_subscriptions (user_id, plan_code, is_verified_business)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id) 
      DO UPDATE SET 
        plan_code = $2,
        is_verified_business = COALESCE($3, user_simple_subscriptions.is_verified_business),
        updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `, [userId, plan_code, is_verified_business]);
    
    res.json({ success: true, data: subscription });
  } catch (e) {
    console.error('Update user subscription failed', e);
    res.status(500).json({ success: false, error: 'Failed to update subscription' });
  }
});

module.exports = router;
