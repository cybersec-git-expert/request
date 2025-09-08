const express = require('express');
const db = require('../services/database');
const auth = require('../services/auth');
const router = express.Router();

// GET /api/brands
router.get('/', async (req, res) => {
  try {
    const { includeInactive = 'false' } = req.query;
    const rows = await db.findMany('brands', includeInactive === 'true' ? {} : { is_active: true }, { orderBy: 'name', orderDirection: 'ASC' });
    res.json({ success: true, data: rows });
  } catch (e) {
    console.error('List brands error', e); res.status(500).json({ success:false, error:e.message });
  }
});

// GET /api/brands/:id
router.get('/:id', async (req, res) => {
  try { const row = await db.findById('brands', req.params.id); if(!row) return res.status(404).json({success:false,error:'Not found'}); res.json({success:true,data:row}); } catch(e){ console.error('Get brand error',e); res.status(500).json({success:false,error:e.message}); }
});

// POST /api/brands
router.post('/', auth.authMiddleware(), auth.requirePermission('brandManagement'), async (req, res) => {
  try {
    const { name, slug, isActive = true } = req.body;
    if(!name) return res.status(400).json({ success:false, error:'Name required'});
    const existing = slug ? await db.findMany('brands', { slug }) : [];
    if (existing.length) return res.status(400).json({ success:false, error:'Slug already exists' });
    const row = await db.insert('brands', { name, slug, is_active: isActive });
    res.status(201).json({ success:true, message:'Brand created', data: row });
  } catch(e){ console.error('Create brand error',e); res.status(400).json({success:false,error:e.message}); }
});

// PUT /api/brands/:id
router.put('/:id', auth.authMiddleware(), auth.requirePermission('brandManagement'), async (req, res) => {
  try {
    const { name, slug, isActive } = req.body;
    const update = {};
    if (name !== undefined) update.name = name;
    if (slug !== undefined) update.slug = slug;
    if (isActive !== undefined) update.is_active = isActive;
    if (!Object.keys(update).length) return res.status(400).json({ success:false, error:'No fields to update'});
    const updated = await db.update('brands', req.params.id, update);
    if (!updated) return res.status(404).json({ success:false, error:'Not found'});
    res.json({ success:true, message:'Brand updated', data: updated });
  } catch(e){ console.error('Update brand error',e); res.status(400).json({success:false,error:e.message}); }
});

// DELETE /api/brands/:id (soft deactivate)
router.delete('/:id', auth.authMiddleware(), auth.requirePermission('brandManagement'), async (req, res) => {
  try {
    const updated = await db.update('brands', req.params.id, { is_active:false });
    if (!updated) return res.status(404).json({ success:false, error:'Not found'});
    res.json({ success:true, message:'Brand deactivated' });
  } catch(e){ console.error('Delete brand error',e); res.status(400).json({success:false,error:e.message}); }
});

module.exports = router;
