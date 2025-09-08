const express = require('express');
const db = require('../services/database');
const auth = require('../services/auth');
const router = express.Router();

// GET /api/entity-activations
router.get('/', async (req,res)=>{
  try {
    const { country, entity_type, includeInactive = 'false' } = req.query;
    if (!country || !entity_type) return res.status(400).json({ success:false, error:'country and entity_type required'});
    const where = { country_code: country, entity_type };
    const rows = await db.findMany('entity_activations', where, { orderBy:'created_at', orderDirection:'DESC' });
    const filtered = includeInactive==='true' ? rows : rows.filter(r=>r.is_active);
    res.json({ success:true, data: filtered });
  } catch(e){ console.error('List entity activations error',e); res.status(500).json({success:false,error:e.message}); }
});

// POST create activation
router.post('/', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req,res)=>{
  try {
    const { entity_type, entity_id, country_code, is_active = true, config } = req.body;
    if (!entity_type || !entity_id || !country_code) return res.status(400).json({ success:false, error:'entity_type, entity_id, country_code required'});
    const existing = await db.findMany('entity_activations', { entity_type, entity_id, country_code });
    if (existing.length) return res.status(409).json({ success:false, error:'Activation already exists'});
    const row = await db.insert('entity_activations', { entity_type, entity_id, country_code, is_active, config: config || null });
    res.status(201).json({ success:true, data: row });
  } catch(e){ console.error('Create entity activation error',e); res.status(400).json({success:false,error:e.message}); }
});

// PUT update activation
router.put('/:id', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req,res)=>{
  try {
    const { is_active, config } = req.body;
    const update = {};
    if (is_active !== undefined) update.is_active = is_active;
    if (config !== undefined) update.config = config;
    if (!Object.keys(update).length) return res.status(400).json({ success:false, error:'No fields to update'});
    const row = await db.update('entity_activations', req.params.id, update);
    if (!row) return res.status(404).json({ success:false, error:'Not found'});
    res.json({ success:true, data: row });
  } catch(e){ console.error('Update entity activation error',e); res.status(400).json({success:false,error:e.message}); }
});

module.exports = router;
