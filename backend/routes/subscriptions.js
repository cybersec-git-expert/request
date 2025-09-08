const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');

// Helpers to support both legacy (business_types int) and restructured (country_business_types uuid) schemas
async function tableExists(table) {
  try {
    const res = await database.query('SELECT to_regclass($1) as reg', [table]);
    return !!res.rows?.[0]?.reg;
  } catch {
    return false;
  }
}

async function getMappingBtIdType() {
  try {
    const q = await database.query(
      `SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='business_type_plan_mappings' AND column_name='business_type_id'`
    );
    return q.rows?.[0]?.data_type || null; // 'uuid' | 'integer' | 'bigint' | null
  } catch {
    return null;
  }
}

// If mapping column expects integer (business_types.id), but UI sends UUID from country_business_types,
// resolve to a numeric business_types.id using global linkage or name match.
async function resolveBusinessTypeIdForMapping(inputId, countryCode) {
  // Detect if input looks like UUID (36-char with hyphens)
  const isUuid = typeof inputId === 'string' && /[a-f0-9-]{36}/i.test(inputId);
  const type = await getMappingBtIdType();
  if (type === 'uuid') {
    // Mapping expects UUID; if caller passed integer, try to find a matching cbt via global id
    if (!isUuid) {
      // Try map integer business_types.id -> country_business_types by global reference and/or name
      const hasCbt = await tableExists('country_business_types');
      if (!hasCbt) return inputId; // nothing we can do, let DB enforce
      // Find business_types row name & optional country
      const bt = await database.query('SELECT id, name FROM business_types WHERE id = $1', [inputId]);
      const btRow = bt.rows?.[0];
      if (!btRow) return inputId;
      // Prefer match by global ref if present
      const byGlobal = await database.query(
        `SELECT id FROM country_business_types WHERE (global_business_type_id = $1 OR LOWER(name) = LOWER($2)) AND ($3::text IS NULL OR country_code = $3) ORDER BY country_code IS NULL`,
        [btRow.id, btRow.name, (countryCode || null)]
      );
      return byGlobal.rows?.[0]?.id || inputId;
    }
    return inputId; // uuid -> uuid
  }
  // Mapping expects integer/bigint (business_types). If caller passed UUID, resolve to business_types.id
  if (isUuid) {
    const hasCbt = await tableExists('country_business_types');
    if (hasCbt) {
      const cbt = await database.query('SELECT id, name, description, icon, display_order, is_active, country_code, global_business_type_id FROM country_business_types WHERE id = $1', [inputId]);
      const row = cbt.rows?.[0];
      if (row?.global_business_type_id) {
        return row.global_business_type_id;
      }
      if (row?.name) {
        // Fallback: match by name (optionally by country if business_types has it)
        const match = await database.query('SELECT id FROM business_types WHERE LOWER(name) = LOWER($1) AND country_code = $2', [row.name, (row.country_code || countryCode || null)]);
        if (match.rows?.[0]?.id) return match.rows[0].id;

        // If still not found, auto-create a global row from the CBT and link it
        const insertSql = `INSERT INTO business_types (name, description, icon, country_code, display_order, is_active, created_at, updated_at)
                           VALUES ($1,$2,$3,$4,$5,$6,NOW(),NOW()) RETURNING id`;
        try {
          const ins = await database.query(insertSql, [
            row.name,
            row.description || null,
            row.icon || null,
            (row.country_code || countryCode || null),
            row.display_order || 999,
            !!row.is_active
          ]);
          const newId = ins.rows?.[0]?.id;
          if (newId) {
            await database.query('UPDATE country_business_types SET global_business_type_id = $1, updated_at = NOW() WHERE id = $2', [newId, row.id]);
            return newId;
          }
        } catch (err) {
          // If unique/constraint violation, reselect by name+country
          if (err && (err.code === '23505' || err.code === '23503')) {
            const re = await database.query('SELECT id FROM business_types WHERE LOWER(name) = LOWER($1) AND country_code = $2', [row.name, (row.country_code || countryCode || null)]);
            if (re.rows?.[0]?.id) {
              await database.query('UPDATE country_business_types SET global_business_type_id = $1, updated_at = NOW() WHERE id = $2', [re.rows[0].id, row.id]);
              return re.rows[0].id;
            }
          } else {
            throw err;
          }
        }
      }
    }
  }
  return inputId; // already correct type or no mapping possible
}

function isSuperAdmin(user) {
  return user && (user.role === 'super_admin' || (user.roles && user.roles.includes('super_admin')));
}

function isCountryAdmin(user) {
  return user && (user.role === 'country_admin' || (user.roles && user.roles.includes('country_admin')));
}

// Get all global plans (super admin view)
router.get('/plans', auth.authMiddleware(), async (req, res) => {
  try {
    if (!isSuperAdmin(req.user)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
  const result = await database.query('SELECT * FROM subscription_plans ORDER BY id');
  res.json(result.rows);
  } catch (err) {
    console.error('GET /plans error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Create or update a global plan (super admin)
router.post('/plans', auth.authMiddleware(), async (req, res) => {
  try {
    if (!isSuperAdmin(req.user)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const { code, name, description, plan_type, default_responses_per_month } = req.body;
    if (!code || !name || !plan_type) return res.status(400).json({ error: 'Missing fields' });
  const upsert = await database.query(
      `INSERT INTO subscription_plans (code, name, description, plan_type, default_responses_per_month)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, plan_type=EXCLUDED.plan_type, default_responses_per_month=EXCLUDED.default_responses_per_month
       RETURNING *`,
      [code, name, description || null, plan_type, default_responses_per_month || null]
    );
    res.json(upsert.rows[0]);
  } catch (err) {
    console.error('POST /plans error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Approve plan (super admin)
router.post('/plans/:code/approve', auth.authMiddleware(), async (req, res) => {
  try {
    if (!isSuperAdmin(req.user)) return res.status(403).json({ error: 'Forbidden' });
    const { code } = req.params;
  const { rows } = await database.query(
      `UPDATE subscription_plans SET status='active', approved_by=$1, approved_at=NOW() WHERE code=$2 RETURNING *`,
      [req.user?.email || req.user?.id || 'system', code]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('POST /plans/:code/approve error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Country settings list or upsert (country admin)
router.get('/country-settings', auth.authMiddleware(), async (req, res) => {
  try {
    if (!isCountryAdmin(req.user) && !isSuperAdmin(req.user)) return res.status(403).json({ error: 'Forbidden' });
    const { country_code } = req.query;
    if (!country_code) return res.status(400).json({ error: 'country_code required' });
  const { rows } = await database.query(`
      SELECT scs.*, sp.code as plan_code, sp.name as plan_name, sp.plan_type
      FROM subscription_country_settings scs
      JOIN subscription_plans sp ON sp.id = scs.plan_id
      WHERE scs.country_code = $1
      ORDER BY scs.id
    `, [country_code]);
    res.json(rows);
  } catch (err) {
    console.error('GET /country-settings error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

router.post('/country-settings', auth.authMiddleware(), async (req, res) => {
  try {
    if (!isCountryAdmin(req.user) && !isSuperAdmin(req.user)) return res.status(403).json({ error: 'Forbidden' });
    const { country_code, plan_code, currency, price, responses_per_month, ppc_price, is_active } = req.body;
    if (!country_code || !plan_code || !currency) return res.status(400).json({ error: 'Missing fields' });
  const plan = await database.query('SELECT id FROM subscription_plans WHERE code=$1', [plan_code]);
    if (!plan.rows[0]) return res.status(404).json({ error: 'Plan not found' });
    const planId = plan.rows[0].id;
  const upsert = await database.query(`
      INSERT INTO subscription_country_settings (plan_id, country_code, currency, price, responses_per_month, ppc_price, is_active, created_by, updated_by)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$8)
      ON CONFLICT (plan_id, country_code)
      DO UPDATE SET currency=EXCLUDED.currency, price=EXCLUDED.price, responses_per_month=EXCLUDED.responses_per_month, ppc_price=EXCLUDED.ppc_price, is_active=EXCLUDED.is_active, updated_by=EXCLUDED.updated_by
      RETURNING *
    `, [planId, country_code, currency, price || null, responses_per_month || null, ppc_price || null, !!is_active, req.user?.email || req.user?.id || 'system']);
    res.json(upsert.rows[0]);
  } catch (err) {
    console.error('POST /country-settings error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

// Map plans to business types and allowed request types
router.get('/mappings', auth.authMiddleware(), async (req, res) => {
  try {
    if (!isCountryAdmin(req.user) && !isSuperAdmin(req.user)) return res.status(403).json({ error: 'Forbidden' });
    const { country_code } = req.query;
    if (!country_code) return res.status(400).json({ error: 'country_code required' });
    // Detect mapping column type to join correct table
    const btIdType = await getMappingBtIdType();
    const hasCbt = await tableExists('country_business_types');
    let rows;
    if (btIdType === 'uuid' && hasCbt) {
      const q = await database.query(`
        SELECT m.*, cbt.name as business_type_name, sp.code as plan_code
        FROM business_type_plan_mappings m
        JOIN country_business_types cbt ON cbt.id = m.business_type_id
        JOIN subscription_plans sp ON sp.id = m.plan_id
        WHERE m.country_code = $1
        ORDER BY m.id
      `, [country_code]);
      rows = q.rows;
    } else {
      const q = await database.query(`
        SELECT m.*, bt.name as business_type_name, sp.code as plan_code
        FROM business_type_plan_mappings m
        JOIN business_types bt ON bt.id = m.business_type_id
        JOIN subscription_plans sp ON sp.id = m.plan_id
        WHERE m.country_code = $1
        ORDER BY m.id
      `, [country_code]);
      rows = q.rows;
    }
    res.json(rows);
  } catch (err) {
    console.error('GET /mappings error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

router.post('/mappings', auth.authMiddleware(), async (req, res) => {
  const client = await database.getClient();
  try {
    if (!isCountryAdmin(req.user) && !isSuperAdmin(req.user)) return res.status(403).json({ error: 'Forbidden' });
    const { country_code, business_type_id, plan_code, is_active, mapping_id } = req.body;
    
    if (!country_code || !business_type_id || !plan_code) return res.status(400).json({ error: 'Missing fields' });
  const plan = await client.query('SELECT id FROM subscription_plans WHERE code=$1', [plan_code]);
    if (!plan.rows[0]) return res.status(404).json({ error: 'Plan not found' });
  // Normalize business_type_id according to mapping column type
  const btIdType = await getMappingBtIdType();
  const normalizedBtId = await resolveBusinessTypeIdForMapping(business_type_id, country_code);
  // If mappings expect integer but we still have a UUID (unresolvable), return a clear 400 instead of 500
  const uuidLike = typeof normalizedBtId === 'string' && /[a-f0-9-]{36}/i.test(normalizedBtId);
  if ((btIdType === 'integer' || btIdType === 'bigint' || btIdType === 'numeric') && uuidLike) {
    return res.status(400).json({
      error: 'Unsupported business type for mapping',
      details: 'Please select a global business type (e.g., Product Seller, Delivery, Tours, Events, Construction, Education, Hiring, Other). Country-specific types like Item/Rent/Ride are not mappable in the current configuration.'
    });
  }
  // Cast the ID explicitly based on mapping column type to avoid driver/type coercion issues
  let castBtId = normalizedBtId;
  if (btIdType === 'integer' || btIdType === 'bigint' || btIdType === 'numeric') {
    // Convert to a JS number if possible
    if (normalizedBtId === null || normalizedBtId === undefined || normalizedBtId === '') {
      return res.status(400).json({ error: 'business_type_id required' });
    }
    const n = Number(normalizedBtId);
    if (!Number.isFinite(n)) {
      return res.status(400).json({ error: 'Invalid business_type_id', details: 'Expected a numeric global business type id.' });
    }
    castBtId = n;
  } else if (btIdType === 'uuid') {
    if (typeof normalizedBtId !== 'string' || !/[a-f0-9-]{36}/i.test(normalizedBtId)) {
      return res.status(400).json({ error: 'Invalid business_type_id', details: 'Expected a UUID country business type id.' });
    }
  }
  
    await client.query('BEGIN');
    
    let upsert;
    
    if (mapping_id) {
      // Update existing mapping
      upsert = await client.query(`
        UPDATE business_type_plan_mappings 
        SET business_type_id=$1, plan_id=$2, is_active=$3, updated_at=NOW()
        WHERE id=$4 AND country_code=$5
        RETURNING *
      `, [castBtId, plan.rows[0].id, is_active !== false, mapping_id, country_code]);
      
      if (!upsert.rows[0]) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Mapping not found' });
      }
    } else {
      // Create new mapping
      upsert = await client.query(`
        INSERT INTO business_type_plan_mappings (country_code, business_type_id, plan_id, is_active)
        VALUES ($1,$2,$3,$4)
        ON CONFLICT (country_code, business_type_id, plan_id)
        DO UPDATE SET is_active=EXCLUDED.is_active
        RETURNING *
    `, [country_code, castBtId, plan.rows[0].id, is_active !== false]);
    }
    
    await client.query('COMMIT');
    res.json(upsert.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    // Provide clearer diagnostics for common DB errors while keeping details concise
    console.error('POST /mappings error', { code: err.code, message: err.message, detail: err.detail });
    if (err.code === '22P02') {
      // invalid_text_representation (e.g., uuid/integer parse)
      return res.status(400).json({ error: 'Invalid input', details: err.message });
    }
    if (err.code === '23503') {
      // foreign_key_violation
      return res.status(400).json({ error: 'Invalid reference', details: 'Provided business_type_id or plan_id does not exist.' });
    }
    if (err.code === '23505') {
      // unique_violation
      return res.status(409).json({ error: 'Mapping already exists', details: 'This country, business type and plan are already mapped.' });
    }
    res.status(500).json({ error: 'Internal error', details: err.message });
  } finally {
    client.release();
  }
});

// Lightweight business types list for subscription mapping (country_admin/super_admin)
router.get('/business-types', auth.authMiddleware(), async (req, res) => {
  try {
    if (!isCountryAdmin(req.user) && !isSuperAdmin(req.user)) return res.status(403).json({ error: 'Forbidden' });
    const requested = (req.query.country_code || '').toUpperCase();
    const country = isSuperAdmin(req.user) ? (requested || null) : (req.user.country_code || null);
    const source = (req.query.source || '').toLowerCase(); // 'country' | 'global' | ''

    // Choose the source table based on the mapping column type. If mappings expect UUIDs, use country_business_types; otherwise, use global business_types.
    const btIdType = await getMappingBtIdType();
    const hasCbt = await tableExists('country_business_types');

    // Explicit override: if caller asks for country list and table exists, honor it
    if (source === 'country' && hasCbt) {
      const params = [];
      let sql = `SELECT id, name, global_business_type_id FROM country_business_types WHERE is_active = TRUE`;
      if (country) { sql += ` AND country_code = $1`; params.push(country); }
      sql += ` ORDER BY display_order, name`;
      const { rows } = await database.query(sql, params);
      return res.json(rows);
    }

    if (btIdType === 'uuid' && hasCbt) {
      const params = [];
      let sql = `SELECT id, name, global_business_type_id FROM country_business_types WHERE is_active = TRUE`;
      if (country) { sql += ` AND country_code = $1`; params.push(country); }
      sql += ` ORDER BY display_order, name`;
      const { rows } = await database.query(sql, params);
      return res.json(rows);
    } else {
      if (source === 'global') {
        // force global table list
        const params = [];
        let sql = `SELECT id, name FROM business_types WHERE is_active = TRUE`;
        if (country) { sql += ` AND country_code = $1`; params.push(country); }
        sql += ` ORDER BY display_order, name`;
        const { rows } = await database.query(sql, params);
        return res.json(rows);
      }
      // Fallback to legacy/global business_types or when mappings expect integer
      const params = [];
      let sql = `SELECT id, name FROM business_types WHERE is_active = TRUE`;
      if (country) { sql += ` AND country_code = $1`; params.push(country); }
      sql += ` ORDER BY display_order, name`;
      const { rows } = await database.query(sql, params);
      return res.json(rows);
    }
  } catch (err) {
    console.error('GET /business-types error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

module.exports = router;
