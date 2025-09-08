const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');

// Map incoming UI type to DB page_type
function toDbType(t){
  if(!t) return 'centralized';
  if(t === 'country-specific') return 'country_specific';
  return t; // centralized | template already fine
}

function fromDbType(t){
  if(t === 'country_specific') return 'country-specific';
  return t;
}

// Helper to adapt DB row to API shape expected by frontend
function adapt(row){
  if(!row) return null;
  const metadata = row.metadata || {};
  return {
    id: row.id,
    slug: row.slug,
    title: row.title,
    category: metadata.category || 'info',
    type: fromDbType(row.page_type),
    content: row.content,
    countries: row.page_type === 'centralized' ? ['global'] : (row.country_code ? [row.country_code] : []),
    country: row.country_code || null,
    keywords: metadata.keywords || [],
    metaDescription: metadata.metaDescription || metadata.meta_description || null,
    requiresApproval: metadata.requiresApproval ?? true,
    status: row.status,
    isTemplate: row.page_type === 'template' || metadata.isTemplate === true,
    displayOrder: metadata.displayOrder || null,
    metadata,
    targetCountry: row.country_code || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    createdBy: metadata.createdBy || null,
    updatedBy: metadata.updatedBy || null
  };
}

// List with filters
router.get('/', async (req,res)=>{
  try {
    const { type, country, status, slug, search } = req.query;
    const clauses = [];
    const params = [];
    if(type){ params.push(toDbType(type)); clauses.push(`page_type = $${params.length}`); }
    if(status){ params.push(status); clauses.push(`status = $${params.length}`); }
    if(slug){ params.push(slug); clauses.push(`slug = $${params.length}`); }
    if(country){
      // centralized pages (page_type centralized and country_code IS NULL) OR specific country_code match
      params.push(country);
      clauses.push(`(page_type='centralized' OR country_code = $${params.length})`);
    }
    if(search){
      params.push(`%${search.toLowerCase()}%`);
      clauses.push(`(LOWER(title) LIKE $${params.length} OR LOWER(content) LIKE $${params.length})`);
    }
    let sql = 'SELECT * FROM content_pages';
    if(clauses.length) sql += ' WHERE ' + clauses.join(' AND ');
    sql += ' ORDER BY created_at DESC';
    const result = await db.query(sql, params);
    res.json(result.rows.map(adapt));
  } catch(e){
    console.error('GET /content-pages error:', e);
    res.status(500).json({ error:e.message });
  }
});

// Get by id or slug
router.get('/:idOrSlug', async (req,res)=>{
  try {
    const { idOrSlug } = req.params;
    let row;
    if(/^[0-9a-fA-F-]{36}$/.test(idOrSlug)){
      row = await db.findById('content_pages', idOrSlug);
    } else {
      row = await db.queryOne('SELECT * FROM content_pages WHERE slug=$1',[idOrSlug]);
    }
    if(!row) return res.status(404).json({ error:'Not found'});
    res.json(adapt(row));
  } catch(e){
    console.error('GET /content-pages/:idOrSlug error:', e);
    res.status(500).json({ error:e.message });
  }
});

// Create page (country admin or super admin) -> if requiresApproval then status pending else draft/approved
router.post('/', auth.authMiddleware(), async (req,res)=>{
  try {
    const b = req.body || {};
    if(!b.slug || !b.title) return res.status(400).json({ error:'slug and title required' });
    const existing = await db.queryOne('SELECT id FROM content_pages WHERE slug=$1',[b.slug]);
    if(existing) return res.status(409).json({ error:'Slug exists' });
    const user = req.user || {}; 
    const page_type = toDbType(b.type);
    const requiresApproval = b.requiresApproval !== false; // default true for workflow
    let status = b.status || (requiresApproval ? 'pending' : 'draft');
    if(user.role === 'super_admin' && b.status) status = b.status;

    // Merge any caller-provided metadata (arbitrary JSON) with standardized fields
    const extraMeta = (b.metadata && typeof b.metadata === 'object') ? b.metadata : {};
    const metadata = {
      ...extraMeta,
      category: b.category ?? extraMeta.category,
      keywords: (b.keywords ?? (extraMeta.keywords || [])),
      metaDescription: b.metaDescription ?? extraMeta.metaDescription,
      requiresApproval,
      isTemplate: b.isTemplate === true || extraMeta.isTemplate === true,
      displayOrder: b.displayOrder ?? extraMeta.displayOrder,
      createdBy: user.id || extraMeta.createdBy || null,
      updatedBy: user.id || extraMeta.updatedBy || null
    };

    const row = await db.insert('content_pages', {
      slug: b.slug.toLowerCase(),
      title: b.title,
      page_type,
      country_code: page_type === 'country_specific' ? (b.country || b.country_code || (b.countries && b.countries[0]) || null) : null,
      status,
      metadata,
      content: b.content || ''
    });
    res.status(201).json(adapt(row));
  } catch(e){
    console.error('POST /content-pages error:', e, { body: req.body });
    res.status(500).json({ error:e.message });
  }
});

// Update page
router.put('/:id', auth.authMiddleware(), async (req,res)=>{
  try {
    const existing = await db.findById('content_pages', req.params.id);
    if(!existing) return res.status(404).json({ error:'Not found'});
    const user = req.user || {};
    const b = req.body || {};
    const update = {};

    if(b.title !== undefined) update.title = b.title;
    // Determine the resulting page_type for this update
    const targetPageType = b.type !== undefined ? toDbType(b.type) : existing.page_type;
    if(b.type !== undefined){ update.page_type = targetPageType; }
    if(b.content !== undefined) update.content = b.content;
    // Only set country_code for country_specific pages. For centralized/template pages ensure it's NULL.
    if(b.country !== undefined || b.country_code !== undefined || b.countries !== undefined){
      const candidate = b.country || b.country_code || (Array.isArray(b.countries) ? b.countries[0] : null);
      if(targetPageType === 'country_specific'){
        // Avoid setting special markers like 'global'
        update.country_code = (candidate && candidate.toLowerCase() !== 'global') ? candidate : null;
      } else {
        update.country_code = null;
      }
    }
    // Merge metadata: start with existing, overlay provided metadata object, then explicit known fields
    const metadata = { ...(existing.metadata || {}) };
    if (b.metadata && typeof b.metadata === 'object') {
      Object.assign(metadata, b.metadata);
    }
    if(b.category !== undefined) metadata.category = b.category;
    if(b.keywords !== undefined) metadata.keywords = Array.isArray(b.keywords) ? b.keywords : (typeof b.keywords === 'string' ? b.keywords.split(',').map(k=>k.trim()).filter(Boolean) : b.keywords);
    if(b.metaDescription !== undefined) metadata.metaDescription = b.metaDescription;
    if(b.requiresApproval !== undefined) metadata.requiresApproval = b.requiresApproval;
    if(b.isTemplate !== undefined) metadata.isTemplate = b.isTemplate;
    if(b.displayOrder !== undefined) metadata.displayOrder = b.displayOrder;
    metadata.updatedBy = user.id || null;
    update.metadata = metadata;

    if(b.status){
      if(user.role === 'super_admin') update.status = b.status;
      else if(['draft','pending'].includes(existing.status) && b.status === 'pending') update.status = 'pending';
    }

    const row = await db.update('content_pages', req.params.id, update);
    res.json(adapt(row));
  } catch(e){
    console.error('PUT /content-pages/:id error:', e, { id: req.params.id, body: req.body });
    res.status(500).json({ error:e.message });
  }
});

// Status update endpoint expected by frontend (/content-pages/:id/status)
router.put('/:id/status', auth.authMiddleware(), async (req,res)=>{
  try {
    const existing = await db.findById('content_pages', req.params.id);
    if(!existing) return res.status(404).json({ error:'Not found'});
    const user = req.user || {};
    const { status } = req.body || {};
    if(!status) return res.status(400).json({ error:'status required'});
    // Only super_admin can set approved/published/rejected
    if(['approved','published','rejected'].includes(status) && user.role !== 'super_admin'){
      return res.status(403).json({ error:'Forbidden'});
    }
    // Country admin can move draft->pending
    if(status === 'pending' || user.role === 'super_admin'){
      const row = await db.update('content_pages', req.params.id, { status });
      return res.json(adapt(row));
    }
    return res.status(403).json({ error:'Unauthorized status transition'});
  } catch(e){
    console.error('PUT /content-pages/:id/status error:', e, { id: req.params.id, body: req.body });
    res.status(500).json({ error:e.message });
  }
});

// Approve / Publish (super admin)
router.post('/:id/approve', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req,res)=>{
  try {
    const existing = await db.findById('content_pages', req.params.id);
    if(!existing) return res.status(404).json({ error:'Not found'});
    const row = await db.update('content_pages', req.params.id, { status:'approved' });
    res.json(adapt(row));
  } catch(e){
    console.error('POST /content-pages/:id/approve error:', e, { id: req.params.id });
    res.status(500).json({ error:e.message });
  }
});

router.post('/:id/publish', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req,res)=>{
  try {
    const existing = await db.findById('content_pages', req.params.id);
    if(!existing) return res.status(404).json({ error:'Not found'});
    const row = await db.update('content_pages', req.params.id, { status:'published' });
    res.json(adapt(row));
  } catch(e){
    console.error('POST /content-pages/:id/publish error:', e, { id: req.params.id });
    res.status(500).json({ error:e.message });
  }
});

// Soft delete (mark status=archived) requires super admin
router.delete('/:id', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req,res)=>{
  try {
    const existing = await db.findById('content_pages', req.params.id);
    if(!existing) return res.status(404).json({ error:'Not found'});
    await db.update('content_pages', req.params.id, { status:'archived' });
    res.json({ success:true });
  } catch(e){
    console.error('DELETE /content-pages/:id error:', e, { id: req.params.id });
    res.status(500).json({ error:e.message });
  }
});

module.exports = router;
