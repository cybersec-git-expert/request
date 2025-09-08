const express = require('express');
const db = require('../services/database');
const auth = require('../services/auth');
const router = express.Router();

async function countTable(table, whereSql = '', params = []) {
  const sql = `SELECT COUNT(*)::int AS count FROM ${table} ${whereSql}`;
  const res = await db.query(sql, params);
  return res.rows[0]?.count || 0;
}

// Check if a table exists without throwing/logging noisy errors
async function tableExists(table) {
  try {
    // to_regclass returns null if relation does not exist
    const res = await db.query('SELECT to_regclass($1) as reg', [table]);
    return !!res.rows?.[0]?.reg;
  } catch (e) {
    return false;
  }
}

// Safe counter that returns 0 when table is missing
async function safeCount(table, whereSql = '', params = []) {
  const exists = await tableExists(table);
  if (!exists) return 0;
  try {
    return await countTable(table, whereSql, params);
  } catch {
    return 0;
  }
}

// Legacy dashboard expectation: /api/products/master/count
router.get('/products/master/count', auth.authMiddleware(), async (req, res) => {
  try {
    const count = await countTable('master_products', 'WHERE is_active = true');
    res.json({ success: true, count });
  } catch (e) {
    console.error('Dashboard products count error', e);
    res.status(500).json({ success: false, error: e.message });
  }
});

// /api/admin-users/count
router.get('/admin-users/count', auth.authMiddleware(), async (req, res) => {
  try {
    let whereSql = 'WHERE is_active = true';
    const params = [];
    let paramIndex = 1;

    // Apply country filtering
    if (req.user.role === 'country_admin') {
      // Country admin can only see admins from their country
      // Exclude super admins from the count for country admins
      whereSql += ` AND country_code = $${paramIndex} AND role = 'country_admin'`;
      params.push(req.user.country_code || req.user.country || '');
      paramIndex++;
    } else if (req.query.country) {
      // Super admin requesting specific country - count only country admins from that country
      whereSql += ` AND country_code = $${paramIndex} AND role = 'country_admin'`;
      params.push(req.query.country);
      paramIndex++;
    }
    // If super admin with no country filter, count all admin users

    const count = await countTable('admin_users', whereSql, params);
    res.json({ success: true, count });
  } catch (e) {
    console.error('Dashboard admin users count error', e);
    res.status(500).json({ success: false, error: e.message });
  }
});

// /api/dashboard/stats aggregate
router.get('/dashboard/stats', auth.authMiddleware(), async (req, res) => {
  try {
    const user = req.user;
    const scoped = user.role !== 'super_admin';
    const countryCode = user.country_code;

    // NOTE: For now we do not have country-specific tables for all entities; using global counts.
    // If later we introduce per-country tables or columns, adjust filters accordingly.

    const [businesses, drivers, requests, responses, users] = await Promise.all([
      safeCount('businesses'),
      safeCount('drivers'),
      safeCount('requests'),
      safeCount('responses'),
      safeCount('users')
    ]);

    res.json({
      success: true,
      businesses: { total: businesses },
      drivers: { total: drivers },
      requests: { total: requests },
      responses: { total: responses },
      users: { total: users }
    });
  } catch (e) {
    console.error('Dashboard stats error', e);
    res.status(500).json({ success: false, error: e.message });
  }
});

module.exports = router;
