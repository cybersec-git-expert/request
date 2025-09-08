const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');

// ===========================================
// PRODUCT SELLER PRICING MANAGEMENT
// ===========================================

// Get all product seller plans
router.get('/product-seller-plans', async (req, res) => {
  try {
    const plans = await db.query('SELECT * FROM product_seller_plans WHERE is_active = true ORDER BY billing_type, name');
    res.json({ success: true, data: plans.rows });
  } catch (e) {
    console.error('Load product seller plans failed', e);
    res.status(500).json({ success: false, error: 'Failed to load plans' });
  }
});

// Create product seller plan (super admin only)
router.post('/product-seller-plans', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { code, name, billing_type, description } = req.body;
    if (!code || !name || !billing_type) {
      return res.status(400).json({ success: false, error: 'code, name, billing_type are required' });
    }
    
    const plan = await db.queryOne(`
      INSERT INTO product_seller_plans (code, name, billing_type, description)
      VALUES ($1, $2, $3, $4) RETURNING *
    `, [code, name, billing_type, description]);
    
    res.status(201).json({ success: true, data: plan });
  } catch (e) {
    console.error('Create product seller plan failed', e);
    res.status(500).json({ success: false, error: 'Failed to create plan' });
  }
});

// Get product seller pricing for a plan
router.get('/product-seller-plans/:id/pricing', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const { country } = req.query;
    
    let where = 'plan_id = $1';
    let params = [id];
    
    if (country) {
      where += ' AND country_code = $2';
      params.push(country);
    }
    
    const pricing = await db.query(`SELECT * FROM product_seller_pricing WHERE ${where} ORDER BY country_code`, params);
    res.json({ success: true, data: pricing.rows });
  } catch (e) {
    console.error('Load product seller pricing failed', e);
    res.status(500).json({ success: false, error: 'Failed to load pricing' });
  }
});

// Set product seller pricing (country admin creates, super admin approves)
router.post('/product-seller-plans/:id/pricing', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const { country_code, price_per_click, monthly_fee } = req.body;
    
    if (!country_code) {
      return res.status(400).json({ success: false, error: 'country_code is required' });
    }
    
    // Get currency for this country
    let currency = 'USD';
    try {
      const countryRow = await db.queryOne('SELECT default_currency FROM countries WHERE code = $1', [country_code]);
      if (countryRow?.default_currency) currency = countryRow.default_currency;
    } catch {}
    
    // Country admin submissions are pending approval
    const isActive = req.user.role === 'super_admin';
    
    const pricing = await db.queryOne(`
      INSERT INTO product_seller_pricing (plan_id, country_code, price_per_click, monthly_fee, currency, is_active)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (plan_id, country_code)
      DO UPDATE SET 
        price_per_click = EXCLUDED.price_per_click,
        monthly_fee = EXCLUDED.monthly_fee,
        currency = EXCLUDED.currency,
        is_active = CASE WHEN $7 = 'super_admin' THEN EXCLUDED.is_active ELSE product_seller_pricing.is_active END,
        updated_at = NOW()
      RETURNING *
    `, [id, country_code, price_per_click || null, monthly_fee || null, currency, isActive, req.user.role]);
    
    res.status(201).json({ success: true, data: pricing });
  } catch (e) {
    console.error('Set product seller pricing failed', e);
    res.status(500).json({ success: false, error: 'Failed to set pricing' });
  }
});

// Approve/reject product seller pricing (super admin only)
router.put('/product-seller-plans/:id/pricing/:country', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { id, country } = req.params;
    const { is_active } = req.body;
    
    const pricing = await db.queryOne(`
      UPDATE product_seller_pricing 
      SET is_active = $1, updated_at = NOW()
      WHERE plan_id = $2 AND country_code = $3
      RETURNING *
    `, [!!is_active, id, country]);
    
    if (!pricing) {
      return res.status(404).json({ success: false, error: 'Pricing not found' });
    }
    
    res.json({ success: true, data: pricing });
  } catch (e) {
    console.error('Update product seller pricing approval failed', e);
    res.status(500).json({ success: false, error: 'Failed to update approval' });
  }
});

// ===========================================
// USER RESPONSE PRICING MANAGEMENT
// ===========================================

// Get all user response plans
router.get('/user-response-plans', async (req, res) => {
  try {
    const plans = await db.query('SELECT * FROM user_response_plans WHERE is_active = true ORDER BY response_type, name');
    res.json({ success: true, data: plans.rows });
  } catch (e) {
    console.error('Load user response plans failed', e);
    res.status(500).json({ success: false, error: 'Failed to load plans' });
  }
});

// Create user response plan (super admin only)
router.post('/user-response-plans', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { code, name, response_type, response_limit, description, features } = req.body;
    if (!code || !name || !response_type) {
      return res.status(400).json({ success: false, error: 'code, name, response_type are required' });
    }
    
    const plan = await db.queryOne(`
      INSERT INTO user_response_plans (code, name, response_type, response_limit, description, features)
      VALUES ($1, $2, $3, $4, $5, $6::jsonb) RETURNING *
    `, [code, name, response_type, response_limit, description, JSON.stringify(features || [])]);
    
    res.status(201).json({ success: true, data: plan });
  } catch (e) {
    console.error('Create user response plan failed', e);
    res.status(500).json({ success: false, error: 'Failed to create plan' });
  }
});

// Get user response pricing for a plan
router.get('/user-response-plans/:id/pricing', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const { country } = req.query;
    
    let where = 'plan_id = $1';
    let params = [id];
    
    if (country) {
      where += ' AND country_code = $2';
      params.push(country);
    }
    
    const pricing = await db.query(`SELECT * FROM user_response_pricing WHERE ${where} ORDER BY country_code`, params);
    res.json({ success: true, data: pricing.rows });
  } catch (e) {
    console.error('Load user response pricing failed', e);
    res.status(500).json({ success: false, error: 'Failed to load pricing' });
  }
});

// Set user response pricing (country admin creates, super admin approves)
router.post('/user-response-plans/:id/pricing', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const { country_code, monthly_price } = req.body;
    
    if (!country_code) {
      return res.status(400).json({ success: false, error: 'country_code is required' });
    }
    
    // Get currency for this country
    let currency = 'USD';
    try {
      const countryRow = await db.queryOne('SELECT default_currency FROM countries WHERE code = $1', [country_code]);
      if (countryRow?.default_currency) currency = countryRow.default_currency;
    } catch {}
    
    // Country admin submissions are pending approval
    const isActive = req.user.role === 'super_admin';
    
    const pricing = await db.queryOne(`
      INSERT INTO user_response_pricing (plan_id, country_code, monthly_price, currency, is_active)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (plan_id, country_code)
      DO UPDATE SET 
        monthly_price = EXCLUDED.monthly_price,
        currency = EXCLUDED.currency,
        is_active = CASE WHEN $6 = 'super_admin' THEN EXCLUDED.is_active ELSE user_response_pricing.is_active END,
        updated_at = NOW()
      RETURNING *
    `, [id, country_code, monthly_price || 0, currency, isActive, req.user.role]);
    
    res.status(201).json({ success: true, data: pricing });
  } catch (e) {
    console.error('Set user response pricing failed', e);
    res.status(500).json({ success: false, error: 'Failed to set pricing' });
  }
});

// Approve/reject user response pricing (super admin only)
router.put('/user-response-plans/:id/pricing/:country', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { id, country } = req.params;
    const { is_active } = req.body;
    
    const pricing = await db.queryOne(`
      UPDATE user_response_pricing 
      SET is_active = $1, updated_at = NOW()
      WHERE plan_id = $2 AND country_code = $3
      RETURNING *
    `, [!!is_active, id, country]);
    
    if (!pricing) {
      return res.status(404).json({ success: false, error: 'Pricing not found' });
    }
    
    res.json({ success: true, data: pricing });
  } catch (e) {
    console.error('Update user response pricing approval failed', e);
    res.status(500).json({ success: false, error: 'Failed to update approval' });
  }
});

// ===========================================
// PENDING APPROVALS
// ===========================================

// Get all pending pricing approvals
router.get('/pending-approvals', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const role = req.user?.role;
    const { country } = req.query;
    
    let whereClause = '';
    let params = [];
    
    if (role === 'country_admin') {
      const cc = req.user?.country_code || country;
      if (cc) {
        whereClause = 'WHERE country_code = $1';
        params.push(cc);
      }
    } else if (country) {
      whereClause = 'WHERE country_code = $1';
      params.push(country);
    }
    
    // Get pending product seller pricing
    const productPending = await db.query(`
      SELECT 
        psp.id as pricing_id,
        psp.country_code,
        psp.price_per_click,
        psp.monthly_fee,
        psp.currency,
        psp.updated_at,
        psl.id as plan_id,
        psl.name as plan_name,
        psl.billing_type,
        'product_seller' as pricing_type
      FROM product_seller_pricing psp
      JOIN product_seller_plans psl ON psl.id = psp.plan_id
      ${whereClause ? whereClause.replace('country_code', 'psp.country_code') : ''}
        ${whereClause ? 'AND' : 'WHERE'} psp.is_active = false
      ORDER BY psp.updated_at DESC
    `, params);
    
    // Get pending user response pricing
    const userPending = await db.query(`
      SELECT 
        urp.id as pricing_id,
        urp.country_code,
        urp.monthly_price,
        urp.currency,
        urp.updated_at,
        urs.id as plan_id,
        urs.name as plan_name,
        urs.response_type,
        'user_response' as pricing_type
      FROM user_response_pricing urp
      JOIN user_response_plans urs ON urs.id = urp.plan_id
      ${whereClause ? whereClause.replace('country_code', 'urp.country_code') : ''}
        ${whereClause ? 'AND' : 'WHERE'} urp.is_active = false
      ORDER BY urp.updated_at DESC
    `, params);
    
    const allPending = [...productPending.rows, ...userPending.rows]
      .sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));
    
    res.json({ success: true, data: allPending });
  } catch (e) {
    console.error('Load pending approvals failed', e);
    res.status(500).json({ success: false, error: 'Failed to load pending approvals' });
  }
});

module.exports = router;
