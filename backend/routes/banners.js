const express = require('express');
const db = require('../services/database');
const { getSignedUrl } = require('../services/s3Upload');

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

function absoluteBase(req) {
  // Use SERVER_URL environment variable if available (for production deployment)
  if (process.env.SERVER_URL) {
    return process.env.SERVER_URL;
  }
  const proto = (req.protocol || 'http').toLowerCase();
  const host = req.get('host');
  const finalProto = process.env.NODE_ENV === 'production' ? 'https' : proto;
  return `${finalProto}://${host}`;
}

function normalizeImageUrl(req, url) {
  if (!url) return url;
  try {
    // If already absolute https/http, check if we need to migrate to S3
    if (/^https?:\/\//i.test(url)) {
      // Convert old local storage URLs to S3 URLs
      if (url.includes('/uploads/images/') || url.includes('ec2-54-144-9-226') || url.includes('localhost')) {
        const filename = url.split('/').pop();
        const s3Bucket = process.env.AWS_S3_BUCKET || 'requestappbucket';
        return `https://${s3Bucket}.s3.amazonaws.com/banners/${filename}`;
      }
      return url;
    }
    // If path-like (e.g. /uploads/images/...), convert to S3 URL
    if (url.startsWith('/uploads/images/')) {
      const filename = url.split('/').pop();
      const s3Bucket = process.env.AWS_S3_BUCKET || 'requestappbucket';
      return `https://${s3Bucket}.s3.amazonaws.com/banners/${filename}`;
    }
    // If path-like, convert to S3
    if (url.startsWith('/')) {
      const filename = url.split('/').pop();
      const s3Bucket = process.env.AWS_S3_BUCKET || 'requestappbucket';
      return `https://${s3Bucket}.s3.amazonaws.com/banners/${filename}`;
    }
    // Otherwise treat as filename and convert to S3 URL
    const s3Bucket = process.env.AWS_S3_BUCKET || 'requestappbucket';
    return `https://${s3Bucket}.s3.amazonaws.com/banners/${url}`;
  } catch {
    return url;
  }
}

// Helper function to check if URL is S3 and needs signing
function isS3Url(url) {
  return url && (
    url.includes('requestappbucket.s3') ||
    url.includes('s3.amazonaws.com') ||
    url.includes('.s3.us-east-1.amazonaws.com')
  );
}

// Helper function to generate signed URL for S3 images
async function processImageUrl(imageUrl) {
  if (!imageUrl || !isS3Url(imageUrl)) {
    return imageUrl; // Return as-is if not S3
  }
  
  try {
    const signedUrl = await getSignedUrl(imageUrl, 3600); // 1 hour expiry
    console.log('✅ Generated signed URL for banner image');
    return signedUrl;
  } catch (error) {
    console.error('❌ Failed to generate signed URL for banner:', error.message);
    return imageUrl; // Fallback to original URL
  }
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
    const base = absoluteBase(req);
    
    // Process each banner to generate signed URLs for S3 images
    const processedRows = await Promise.all(
      result.rows.map(async (r) => {
        // Ensure imageUrl is absolute and not pointing to localhost
        const normalizedUrl = normalizeImageUrl(req, r.imageUrl || r.image_url);
        const finalImageUrl = await processImageUrl(normalizedUrl);
        return { ...r, imageUrl: finalImageUrl };
      })
    );
    
    res.json({ success: true, data: processedRows });
  } catch (e) {
    console.error('[banners] list error', e);
    res.status(500).json({ success: false, message: 'Failed to fetch banners' });
  }
});

// Create banner
router.post('/', async (req, res) => {
  try {
    await ensureTable();
    let { country = null, title = null, subtitle = null, imageUrl, linkUrl = null, priority = 0, active = true } = req.body || {};
    if (!imageUrl) return res.status(400).json({ success: false, message: 'imageUrl is required' });
    imageUrl = normalizeImageUrl(req, imageUrl);
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
    // Normalize keys to camelCase and generate signed URL
    const processedImageUrl = await processImageUrl(row.image_url);
    const out = { ...row, imageUrl: processedImageUrl, linkUrl: row.link_url };
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
    if (imageUrl !== undefined) data.image_url = normalizeImageUrl(req, imageUrl);
    if (linkUrl !== undefined) data.link_url = linkUrl;
    if (priority !== undefined) data.priority = Number(priority) || 0;
    if (active !== undefined) data.active = !!active;
    // Note: updated_at is automatically handled by DatabaseService.update()
    const row = await db.update(TABLE, id, data);
    const processedImageUrl = await processImageUrl(row.image_url);
    const out = { ...row, imageUrl: processedImageUrl, linkUrl: row.link_url };
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
