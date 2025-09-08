const express = require('express');
const router = express.Router();
const db = require('../services/database');

// List responses across all requests (admin view)
// Query params: country, status(accepted|pending), search, page, limit
router.get('/', async (req, res) => {
  try {
    const { country, status, search, page = 1, limit = 50 } = req.query;
    const pageNum = parseInt(page) || 1;
    const lim = Math.min(parseInt(limit) || 50, 100);
    const offset = (pageNum - 1) * lim;

    const where = [];
    const values = [];
    let p = 1;

    if (country) {
      where.push(`req.country_code = $${p++}`);
      values.push(country);
    }
    if (status === 'accepted') {
      where.push('req.accepted_response_id = r.id');
    } else if (status === 'pending') {
      where.push('(req.accepted_response_id IS NULL OR req.accepted_response_id <> r.id)');
    }
    if (search) {
      where.push(`(r.message ILIKE $${p} OR req.title ILIKE $${p})`);
      values.push(`%${search}%`);
      p++;
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const sql = `
      SELECT
        r.id,
        r.request_id,
        r.user_id,
        r.message,
        r.price,
        COALESCE(r.currency, req.currency, countries.default_currency) AS currency,
        r.image_urls,
        r.metadata,
        -- Availability (stored inside metadata JSONB typical keys)
        COALESCE(r.metadata->>'available_from', r.metadata->>'availableFrom') AS available_from,
        COALESCE(r.metadata->>'available_until', r.metadata->>'availableUntil') AS available_until,
        r.status AS raw_status,
        r.created_at,
        r.updated_at,
        req.title AS request_title,
        req.country_code,
        req.accepted_response_id,
        (req.accepted_response_id = r.id) AS accepted,
        u.display_name AS responder_name,
        u.email AS responder_email,
        u.phone AS responder_phone,
        req_owner.display_name AS requester_name,
        req_owner.email AS requester_email,
        req_owner.phone AS requester_phone,
        countries.default_currency AS country_default_currency
      FROM responses r
      JOIN requests req ON r.request_id = req.id
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN users req_owner ON req.user_id = req_owner.id
      LEFT JOIN countries ON countries.code = req.country_code
      ${whereSql}
      ORDER BY r.created_at DESC
      LIMIT ${lim} OFFSET ${offset}`;

    const rows = await db.query(sql, values);
    const countRow = await db.queryOne(`SELECT COUNT(*)::int AS total FROM responses r JOIN requests req ON r.request_id = req.id ${whereSql}`, values);

    res.json({
      success: true,
      data: rows.rows,
      pagination: {
        page: pageNum,
        limit: lim,
        total: countRow.total,
        totalPages: Math.ceil(countRow.total / lim)
      }
    });
  } catch (error) {
    console.error('Error listing global responses:', error);
    res.status(500).json({ success: false, message: 'Error listing responses', error: error.message });
  }
});

module.exports = router;
