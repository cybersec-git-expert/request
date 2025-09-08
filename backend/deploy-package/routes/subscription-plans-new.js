const express = require('express');
const router = express.Router();
const db = require('../services/database');
const authService = require('../services/auth');

// Basic list
router.get('/', async (req,res)=>{
  try {
    const { type, active } = req.query;
    const conditions = {};
    if(type) conditions.type = type;
    if(active !== undefined) conditions.is_active = active === 'true';
    const rows = await db.findMany('subscription_plans_new', conditions, { orderBy: 'created_at', orderDirection: 'DESC' });
    res.json(rows);
  } catch(e){ res.status(500).json({ error:e.message }); }
});

// Get one
router.get('/:id', async (req,res)=>{
  try { const row = await db.findById('subscription_plans_new', req.params.id); if(!row) return res.status(404).json({error:'Not found'}); res.json(row);} catch(e){ res.status(500).json({ error:e.message }); }
});

// Create
router.post('/', authService.authMiddleware(), authService.roleMiddleware(['admin','super_admin']), async (req,res)=>{
  try {
    const data = req.body || {};
    if(!data.code || !data.name) return res.status(400).json({error:'code and name required'});
    data.features = data.features || [];
    data.limitations = data.limitations || {};
    const existing = await db.findMany('subscription_plans_new', { code: data.code });
    if(existing.length) return res.status(409).json({ error:'Code already exists'});
    const row = await db.insert('subscription_plans_new', data);
    res.status(201).json(row);
  } catch(e){ res.status(500).json({ error:e.message }); }
});

// Update
router.put('/:id', authService.authMiddleware(), authService.roleMiddleware(['admin','super_admin']), async (req,res)=>{
  try {
    const data = req.body || {};
    if(data.code){ // ensure uniqueness
      const dup = await db.query('SELECT 1 FROM subscription_plans_new WHERE code=$1 AND id<>$2 LIMIT 1',[data.code, req.params.id]);
      if(dup.rowCount) return res.status(409).json({ error:'Code already exists'});
    }
    const row = await db.update('subscription_plans_new', req.params.id, data);
    if(!row) return res.status(404).json({error:'Not found'});
    res.json(row);
  } catch(e){ res.status(500).json({ error:e.message }); }
});

// Delete
router.delete('/:id', authService.authMiddleware(), authService.roleMiddleware(['admin','super_admin']), async (req,res)=>{
  try { const row = await db.delete('subscription_plans_new', req.params.id); if(!row) return res.status(404).json({error:'Not found'}); res.json({ success:true }); } catch(e){ res.status(500).json({ error:e.message }); }
});

// Seed default plans (idempotent)
router.post('/defaults/seed', authService.authMiddleware(), authService.roleMiddleware(['super_admin']), async (req,res)=>{
  const defaults = [
    { code:'rider_free', name:'Rider Free Plan', type:'rider', plan_type:'monthly', description:'Limited free plan for riders with basic features', price:0, currency:'USD', duration_days:30, features:['Browse service requests','Up to 2 responses per month','Basic profile creation','View contact information after selection'], limitations:{ maxResponsesPerMonth:2, riderRequestNotifications:false, unlimitedResponses:false }, is_active:true, is_default_plan:true, requires_country_pricing:false },
    { code:'rider_premium', name:'Rider Premium Plan', type:'rider', plan_type:'monthly', description:'Unlimited plan for active riders', price:10, currency:'USD', duration_days:30, features:['Browse all service requests','Unlimited responses per month','Priority listing in search results','Instant rider request notifications','Advanced profile features','Analytics and insights'], limitations:{ maxResponsesPerMonth:-1, riderRequestNotifications:true, unlimitedResponses:true }, is_active:true, is_default_plan:true, requires_country_pricing:true },
    { code:'business_pay_per_click', name:'Business Pay Per Click', type:'business', plan_type:'pay_per_click', description:'Pay only when someone responds to your requests', price:2, currency:'USD', duration_days:30, features:['Post unlimited service requests','Pay only for responses received','Business profile verification','Priority customer support','Request analytics and reporting'], limitations:{ payPerResponse:true, unlimitedRequests:true }, is_active:true, is_default_plan:true, requires_country_pricing:true }
  ];
  const created=[]; const skipped=[]; try {
    for(const def of defaults){
      const existing = await db.findMany('subscription_plans_new',{ code:def.code });
      if(existing.length){ skipped.push(def.code); continue; }
      const row = await db.insert('subscription_plans_new', def); created.push(row.code);
    }
    res.json({ success:true, created, skipped });
  } catch(e){ res.status(500).json({ error:e.message, created, skipped }); }
});

module.exports = router;
