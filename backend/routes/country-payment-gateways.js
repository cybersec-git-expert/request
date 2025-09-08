const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');

// List gateways by country (public for mobile to choose)
router.get('/', async (req, res) => {
  try {
    const { country } = req.query;
    const params = [];
    let where = 'is_active = true';
    if (country) { where += ' AND country_code = $1'; params.push(country); }
    const r = await db.query(`SELECT id, country_code, provider, display_name, public_config, is_active, updated_at FROM country_payment_gateways WHERE ${where} ORDER BY display_name`, params);
    res.json({ success:true, data:r.rows });
  } catch (e) { console.error('List gateways failed', e); res.status(500).json({ success:false, error:'Failed to load gateways' }); }
});

// Admin CRUD
router.post('/', auth.authMiddleware(), auth.roleMiddleware(['super_admin','country_admin']), async (req,res)=>{
  try {
    const { country_code, provider, display_name, public_config, secret_ref, is_active=true } = req.body || {};
    if (!country_code || !provider || !display_name) return res.status(400).json({ success:false, error:'country_code, provider, display_name required' });
    const row = await db.queryOne(`
      INSERT INTO country_payment_gateways (country_code, provider, display_name, public_config, secret_ref, is_active, created_by)
      VALUES ($1,$2,$3,$4::jsonb,$5,$6,$7)
      ON CONFLICT (country_code, provider)
      DO UPDATE SET display_name=EXCLUDED.display_name, public_config=EXCLUDED.public_config, secret_ref=EXCLUDED.secret_ref, is_active=EXCLUDED.is_active, updated_at=NOW()
      RETURNING *
    `, [country_code, provider, display_name, JSON.stringify(public_config||{}), secret_ref||null, !!is_active, req.user?.id || null]);
    res.status(201).json({ success:true, data:row });
  } catch (e) { console.error('Upsert gateway failed', e); res.status(500).json({ success:false, error:'Failed to upsert gateway' }); }
});

router.delete('/:id', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req,res)=>{
  try {
    const r = await db.queryOne('DELETE FROM country_payment_gateways WHERE id=$1 RETURNING id', [req.params.id]);
    if (!r) return res.status(404).json({ success:false, error:'Not found' });
    res.json({ success:true });
  } catch (e) { console.error('Delete gateway failed', e); res.status(500).json({ success:false, error:'Failed to delete gateway' }); }
});

module.exports = router;
