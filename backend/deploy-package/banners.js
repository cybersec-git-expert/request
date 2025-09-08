const express = require('express');
const db = require('../services/database');

const router = express.Router();

// Table name
const TABLE = 'banners';

// Ensure table exists (lightweight guard)
async function ensureTable() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS ${TABLE} (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      country VARCHAR(10),
      title TEXT,
      subtitle TEXT,
      image_url TEXT NOT NULL,
      link_url TEXT,
      priority INT DEFAULT 0,
      active BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_${TABLE}_country ON ${TABLE}(country)`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_${TABLE}_active ON ${TABLE}(active)`);
}

// List banners (optional country filter)
router.get('/', async (req, res) => {
  try {
    await ensureTable();
    const { country, active, limit } = req.query;
    const params = [];
    const where = [];
    if (country) { params.push(country); where.push(`country = $${params.length}`); }
    if (active !== undefined) { params.push(active === 'true'); where.push(`active = $${params.length}`); }
    let sql = `SELECT id, country, title, subtitle, image_url AS "imageUrl", link_url AS "linkUrl", priority, active, created_at, updated_at FROM ${TABLE}`;
    if (where.length) sql += ` WHERE ${where.join(' AND ')}`;
    sql += ' ORDER BY priority DESC, created_at DESC';
    const lim = parseInt(limit, 10);
    if (!isNaN(lim) && lim > 0) sql += ` LIMIT ${lim}`;
    const result = await db.query(sql, params);
    res.json({ success: true, data: result.rows });
  } catch (e) {
    console.error('[banners] list error', e);
    res.status(500).json({ success: false, message: 'Failed to fetch banners' });
  }
});

// Create banner
router.post('/', async (req, res) => {
  try {
    await ensureTable();
    const { country = null, title = null, subtitle = null, imageUrl, linkUrl = null, priority = 0, active = true } = req.body || {};
    if (!imageUrl) return res.status(400).json({ success: false, message: 'imageUrl is required' });
    const row = await db.insert(TABLE, {
      country,
      title,
      subtitle,
      image_url: imageUrl,
      link_url: linkUrl,
      priority: Number(priority) || 0,
      active: !!active,
      created_at: new Date(),
      updated_at: new Date(),
    });
    // Normalize keys to camelCase
    const out = { ...row, imageUrl: row.image_url, linkUrl: row.link_url };
    delete out.image_url; delete out.link_url;
    res.json({ success: true, data: out });
  } catch (e) {
    console.error('[banners] create error', e);
    res.status(500).json({ success: false, message: 'Failed to create banner' });
  }
});

// Update banner
router.put('/:id', async (req, res) => {
  try {
    await ensureTable();
    const { id } = req.params;
    const { country, title, subtitle, imageUrl, linkUrl, priority, active } = req.body || {};
    const data = {};
    if (country !== undefined) data.country = country;
    if (title !== undefined) data.title = title;
    if (subtitle !== undefined) data.subtitle = subtitle;
    if (imageUrl !== undefined) data.image_url = imageUrl;
    if (linkUrl !== undefined) data.link_url = linkUrl;
    if (priority !== undefined) data.priority = Number(priority) || 0;
    if (active !== undefined) data.active = !!active;
    // Note: updated_at is automatically handled by DatabaseService.update()
    const row = await db.update(TABLE, id, data);
    const out = { ...row, imageUrl: row.image_url, linkUrl: row.link_url };
    delete out.image_url; delete out.link_url;
    res.json({ success: true, data: out });
  } catch (e) {
    console.error('[banners] update error', e);
    res.status(500).json({ success: false, message: 'Failed to update banner' });
  }
});

// Delete banner
router.delete('/:id', async (req, res) => {
  try {
    await ensureTable();
    const { id } = req.params;
    const row = await db.delete(TABLE, id);
    if (!row) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true });
  } catch (e) {
    console.error('[banners] delete error', e);
    res.status(500).json({ success: false, message: 'Failed to delete banner' });
  }
});

module.exports = router;
