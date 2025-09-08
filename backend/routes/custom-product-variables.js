const express = require('express');
const db = require('../services/database');
const auth = require('../services/auth');
const router = express.Router();

// Actual table name in DB
const TABLE = 'variables';

function safeParse(json){
  if(!json) return null;
  if(typeof json === 'object') return json; // already parsed
  try { return JSON.parse(json); } catch { return null; }
}

function normalize(row){
  const parsed = safeParse(row.value);
  return {
    id: row.id,
    firebaseId: row.firebase_id || null,
    key: row.key,
    name: parsed?.name || row.name || row.key,
    // Provide label alias for legacy frontend expecting 'label'
    label: parsed?.name || row.name || row.key,
    description: row.description || parsed?.description || null,
    type: row.type || parsed?.type || 'text',
    possibleValues: Array.isArray(parsed?.options) ? parsed.options : [],
    // Unified aliases
    options: Array.isArray(parsed?.options) ? parsed.options : [],
    values: Array.isArray(parsed?.options) ? parsed.options : [],
    isRequired: parsed?.isRequired === true,
    isActive: row.is_active !== false,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

async function listVariables(req,res){
  try {
    const { includeInactive='false' } = req.query;
    const where = includeInactive==='true' ? '' : 'WHERE is_active = true';
    const sql = `SELECT * FROM ${TABLE} ${where} ORDER BY key ASC`;
    const result = await db.query(sql);
    res.json({ success:true, data: result.rows.map(normalize), count: result.rows.length });
  } catch(e){
    console.error('[VARIABLES] List error:', e.message, e.stack);
    res.status(500).json({ success:false, error: e.message });
  }
}

// Backwards compatibility with old snake endpoint, both require auth
router.get('/custom_product_variables', auth.authMiddleware(), listVariables);
router.get('/custom-product-variables', auth.authMiddleware(), listVariables);

router.get('/custom-product-variables/:id', auth.authMiddleware(), async (req,res)=>{
  try {
    const row = await db.findById(TABLE, req.params.id);
    if(!row) return res.status(404).json({success:false,error:'Not found'});
    res.json({success:true,data:normalize(row)});
  } catch(e){
    console.error('[VARIABLES] Get error:', e.message);
    res.status(500).json({success:false,error:e.message});
  }
});

router.post('/custom-product-variables', auth.authMiddleware(), async (req,res)=>{
  try {
    if(req.user.role !== 'super_admin') return res.status(403).json({success:false,error:'Only super admins can create variables'});
    const { key, name, description, type='text', possibleValues=[], isRequired=false, isActive=true } = req.body;
    if(!key && !name) return res.status(400).json({success:false,error:'key or name required'});
    const k = (key || name).toLowerCase().replace(/[^a-z0-9]+/g,'_');
    const value = JSON.stringify({ name: name || k, options: possibleValues, isRequired, type });
    const row = await db.insert(TABLE, { key:k, value, type, description, is_active:isActive });
    res.status(201).json({ success:true, message:'Variable created', data: normalize(row) });
  } catch(e){
    console.error('[VARIABLES] Create error:', e.message);
    res.status(400).json({ success:false, error:e.message });
  }
});

router.put('/custom-product-variables/:id', auth.authMiddleware(), async (req,res)=>{
  try {
    if(req.user.role !== 'super_admin') return res.status(403).json({success:false,error:'Only super admins can update variables'});
    const { name, description, type, possibleValues, isRequired, isActive } = req.body;
    const existing = await db.findById(TABLE, req.params.id);
    if(!existing) return res.status(404).json({success:false,error:'Not found'});
    const parsed = safeParse(existing.value) || {};
    if(name!==undefined) parsed.name = name;
    if(possibleValues!==undefined) parsed.options = possibleValues;
    if(isRequired!==undefined) parsed.isRequired = isRequired;
    if(type!==undefined) parsed.type = type;
    const update = { value: JSON.stringify(parsed) };
    if(description!==undefined) update.description = description;
    if(type!==undefined) update.type = type;
    if(isActive!==undefined) update.is_active = isActive;
    const row = await db.update(TABLE, req.params.id, update);
    res.json({ success:true, message:'Variable updated', data: normalize(row) });
  } catch(e){
    console.error('[VARIABLES] Update error:', e.message);
    res.status(400).json({ success:false, error:e.message });
  }
});

router.delete('/custom-product-variables/:id', auth.authMiddleware(), async (req,res)=>{
  try {
    if(req.user.role !== 'super_admin') return res.status(403).json({success:false,error:'Only super admins can delete variables'});
    const row = await db.update(TABLE, req.params.id, { is_active:false });
    if(!row) return res.status(404).json({success:false,error:'Not found'});
    res.json({ success:true, message:'Variable deactivated'});
  } catch(e){
    console.error('[VARIABLES] Delete error:', e.message);
    res.status(400).json({ success:false, error:e.message });
  }
});

module.exports = router;
