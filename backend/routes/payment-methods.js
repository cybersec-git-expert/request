const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');

// Utility: normalize payload from admin-react (camelCase) to db (snake_case)
function normalizePayload(body) {
  return {
    country_code: body.country || body.country_code,
    name: body.name,
    description: body.description || null,
    category: body.category || 'digital',
    image_url: body.imageUrl || body.image_url || null,
    link_url: body.linkUrl || body.link_url || null,
    fees: body.fees || null,
    processing_time: body.processingTime || body.processing_time || null,
    min_amount: body.minAmount || body.min_amount || null,
    max_amount: body.maxAmount || body.max_amount || null,
    is_active: typeof body.isActive === 'boolean' ? body.isActive : (typeof body.is_active === 'boolean' ? body.is_active : true)
  };
}

// GET /api/payment-methods?country=LK&active=true
router.get('/', async (req, res) => {
  try {
    const { country, active } = req.query;
    const params = [];
    const where = [];
    if (country) { params.push(country); where.push(`country_code = $${params.length}`); }
    if (active === 'true') { where.push('is_active = true'); }
    const sql = `
      SELECT id, country_code AS country, name, description, category,
             image_url AS "imageUrl", link_url AS "linkUrl", fees,
             processing_time AS "processingTime", min_amount AS "minAmount",
             max_amount AS "maxAmount", is_active AS "isActive",
             created_at, updated_at
      FROM country_payment_methods
      ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY name
    `;
    const result = await db.query(sql, params);
    res.json(result.rows);
  } catch (e) {
    console.error('Error fetching payment methods', e);
    res.status(500).json({ success: false, error: 'Failed to fetch payment methods' });
  }
});

// Public endpoint: list active payment methods by country (for apps)
router.get('/public/list', async (req, res) => {
  try {
    const { country } = req.query;
    if (!country) return res.status(400).json({ success: false, error: 'country is required' });
    const r = await db.query(`
      SELECT id, country_code AS country, name, description, category,
             image_url AS "imageUrl", link_url AS "linkUrl", fees,
             processing_time AS "processingTime", min_amount AS "minAmount",
             max_amount AS "maxAmount"
      FROM country_payment_methods
      WHERE country_code = $1 AND is_active = true
      ORDER BY name
    `, [country]);
    res.json(r.rows);
  } catch (e) {
    console.error('Error fetching public payment methods', e);
    res.status(500).json({ success: false, error: 'Failed to fetch payment methods' });
  }
});

// GET one
router.get('/:id', async (req, res) => {
  try {
    const r = await db.query(`
      SELECT id, country_code AS country, name, description, category,
             image_url AS "imageUrl", link_url AS "linkUrl", fees,
             processing_time AS "processingTime", min_amount AS "minAmount",
             max_amount AS "maxAmount", is_active AS "isActive",
             created_at, updated_at
      FROM country_payment_methods WHERE id = $1
    `, [req.params.id]);
    if (!r.rows.length) return res.status(404).json({ success: false, error: 'Not found' });
    res.json(r.rows[0]);
  } catch (e) {
    console.error('Error fetching payment method', e);
    res.status(500).json({ success: false, error: 'Failed to fetch payment method' });
  }
});

// Create
router.post('/', auth.authMiddleware(), async (req, res) => {
  try {
    const payload = normalizePayload(req.body);
    if (!payload.country_code || !payload.name) {
      return res.status(400).json({ success: false, error: 'country and name are required' });
    }
    const sql = `
      INSERT INTO country_payment_methods (
        country_code, name, description, category, image_url, link_url,
        fees, processing_time, min_amount, max_amount, is_active
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
      RETURNING id, country_code AS country, name, description, category,
                image_url AS "imageUrl", link_url AS "linkUrl", fees,
                processing_time AS "processingTime", min_amount AS "minAmount",
                max_amount AS "maxAmount", is_active AS "isActive",
                created_at, updated_at
    `;
    const vals = [
      payload.country_code, payload.name, payload.description, payload.category,
      payload.image_url, payload.link_url, payload.fees, payload.processing_time,
      payload.min_amount, payload.max_amount, payload.is_active
    ];
    const r = await db.query(sql, vals);
    res.status(201).json(r.rows[0]);
  } catch (e) {
    console.error('Error creating payment method', e);
    res.status(500).json({ success: false, error: 'Failed to create payment method' });
  }
});

// Update
router.put('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const payload = normalizePayload(req.body);
    const fields = [];
    const vals = [];
    Object.entries(payload).forEach(([k, v]) => {
      if (v !== undefined) { vals.push(v); fields.push(`${k} = $${vals.length}`); }
    });
    if (!fields.length) return res.status(400).json({ success: false, error: 'No fields to update' });
    vals.push(req.params.id);
    const sql = `UPDATE country_payment_methods SET ${fields.join(', ')}, updated_at = NOW() WHERE id = $${vals.length} 
         RETURNING id, country_code AS country, name, description, category,
               image_url AS "imageUrl", link_url AS "linkUrl", fees,
               processing_time AS "processingTime", min_amount AS "minAmount",
               max_amount AS "maxAmount", is_active AS "isActive",
               created_at, updated_at`;
    const r = await db.query(sql, vals);
    if (!r.rows.length) return res.status(404).json({ success: false, error: 'Not found' });
    res.json(r.rows[0]);
  } catch (e) {
    console.error('Error updating payment method', e);
    res.status(500).json({ success: false, error: 'Failed to update payment method' });
  }
});

// Delete
router.delete('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const r = await db.query('DELETE FROM country_payment_methods WHERE id = $1 RETURNING id', [req.params.id]);
    if (!r.rows.length) return res.status(404).json({ success: false, error: 'Not found' });
    res.json({ success: true });
  } catch (e) {
    console.error('Error deleting payment method', e);
    res.status(500).json({ success: false, error: 'Failed to delete payment method' });
  }
});

// Business mappings
// GET /api/business-payment-methods/:businessId
router.get('/business/:businessId', async (req, res) => {
  try {
    const sql = `
      SELECT bpm.id, bpm.business_id AS "businessId", bpm.is_active AS "isActive",
             cpm.id AS "paymentMethodId", cpm.name, cpm.category,
             cpm.image_url AS "imageUrl", cpm.fees, cpm.processing_time AS "processingTime"
      FROM business_payment_methods bpm
      JOIN country_payment_methods cpm ON cpm.id = bpm.payment_method_id
      WHERE bpm.business_id = $1 AND bpm.is_active = true AND cpm.is_active = true
      ORDER BY cpm.name`;
    const r = await db.query(sql, [req.params.businessId]);
    res.json(r.rows);
  } catch (e) {
    console.error('Error fetching business payment methods', e);
    res.status(500).json({ success: false, error: 'Failed to fetch business payment methods' });
  }
});

// POST /api/business-payment-methods (set list)
router.post('/business/:businessId', auth.authMiddleware(), async (req, res) => {
  try {
    const { businessId } = req.params;
    const { paymentMethodIds } = req.body;
    if (!Array.isArray(paymentMethodIds)) return res.status(400).json({ success: false, error: 'paymentMethodIds must be an array' });
    await db.query('BEGIN');
    // Soft-disable all existing
    await db.query('UPDATE business_payment_methods SET is_active = false, updated_at = NOW() WHERE business_id = $1', [businessId]);
    // Upsert new list as active
    for (const pmId of paymentMethodIds) {
      await db.query(`
        INSERT INTO business_payment_methods (business_id, payment_method_id, is_active)
        VALUES ($1, $2, true)
        ON CONFLICT (business_id, payment_method_id)
        DO UPDATE SET is_active = EXCLUDED.is_active, updated_at = NOW()
      `, [businessId, pmId]);
    }
    await db.query('COMMIT');
    res.json({ success: true });
  } catch (e) {
    await db.query('ROLLBACK');
    console.error('Error setting business payment methods', e);
    res.status(500).json({ success: false, error: 'Failed to set business payment methods' });
  }
});

// GET /api/payment-methods/image-url/:id - Get signed URL for payment method image
router.get('/image-url/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get the payment method image URL from database
    const result = await db.query(
      'SELECT image_url FROM country_payment_methods WHERE id = $1',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Payment method not found' });
    }
    
    const imageUrl = result.rows[0].image_url;
    
    if (!imageUrl) {
      return res.status(404).json({ success: false, error: 'No image found for this payment method' });
    }
    
    // If it's already a full URL, extract the S3 key
    if (imageUrl.startsWith('https://requestappbucket.s3.amazonaws.com/')) {
      const url = new URL(imageUrl);
      const s3Key = url.pathname.substring(1); // Remove leading slash
      
      try {
        const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
        const { GetObjectCommand } = require('@aws-sdk/client-s3');
        const { s3Client } = require('../services/s3Upload');
        
        const command = new GetObjectCommand({
          Bucket: 'requestappbucket',
          Key: s3Key,
        });
        
        const signedUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 }); // 1 hour
        
        res.json({ success: true, signedUrl });
      } catch (error) {
        console.error('Error generating signed URL:', error);
        res.status(500).json({ success: false, error: 'Failed to generate signed URL' });
      }
    } else {
      // Return original URL if it's not an S3 URL
      res.json({ success: true, signedUrl: imageUrl });
    }
  } catch (e) {
    console.error('Error getting payment method image URL', e);
    res.status(500).json({ success: false, error: 'Failed to get image URL' });
  }
});

module.exports = router;
