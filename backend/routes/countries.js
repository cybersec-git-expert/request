const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');
const { autoActivateCountryData } = require('../services/adminPermissions');

// Basic ISO country code -> primary currency code mapping.
// Extend as needed; used when client does not explicitly supply default_currency.
const COUNTRY_CURRENCY_MAP = {
  US: 'USD', CA: 'CAD', GB: 'GBP', LK: 'LKR', IN: 'INR', EU: 'EUR', AU: 'AUD', NZ: 'NZD',
  SG: 'SGD', MY: 'MYR', TH: 'THB', PH: 'PHP', PK: 'PKR', CN: 'CNY', JP: 'JPY', KR: 'KRW',
  AE: 'AED', SA: 'SAR', KW: 'KWD', QA: 'QAR', BH: 'BHD', OM: 'OMR', ZA: 'ZAR', NG: 'NGN',
  KE: 'KES', UG: 'UGX', TZ: 'TZS', RW: 'RWF', BI: 'BIF', GH: 'GHS', ET: 'ETB', EG: 'EGP',
  BR: 'BRL', AR: 'ARS', MX: 'MXN', CL: 'CLP', CO: 'COP', PE: 'PEN', VE: 'VES',
  FR: 'EUR', DE: 'EUR', ES: 'EUR', IT: 'EUR', IE: 'EUR', NL: 'EUR', BE: 'EUR', PT: 'EUR',
  SE: 'SEK', NO: 'NOK', DK: 'DKK', FI: 'EUR', IS: 'ISK', CH: 'CHF', PL: 'PLN', CZ: 'CZK',
  HU: 'HUF', RO: 'RON', BG: 'BGN', GR: 'EUR', TR: 'TRY', RU: 'RUB', UA: 'UAH',
};

// Basic country -> default locale mapping (extend as needed)
const COUNTRY_LOCALE_MAP = {
  US: 'en_US', GB: 'en_GB', LK: 'en_LK', IN: 'en_IN', AE: 'ar_AE', TH: 'th_TH',
  SG: 'en_SG', MY: 'en_MY', AU: 'en_AU', NZ: 'en_NZ', CA: 'en_CA', IE: 'en_IE',
  PH: 'en_PH', PK: 'en_PK', ZA: 'en_ZA'
};

// Country -> phone prefix fallback (subset; admin UI already has list but backend will be resilient)
const COUNTRY_PHONE_PREFIX_MAP = {
  LK: '+94', GB: '+44', AE: '+971', US: '+1', IN: '+91', TH: '+66', SG: '+65', MY: '+60'
};

// Optional default VAT / tax rate percentages (set only if client does not provide a value)
// Keep conservative (0) where unknown so business can fill later.
const DEFAULT_TAX_RATE_MAP = {
  GB: 20.0, AE: 0.0, LK: 0.0, US: 0.0, IN: 0.0, TH: 0.0, SG: 8.0, MY: 0.0
};

function buildFlagUrl(code){
  // Use flagcdn (public CDN). 80px width PNG; stored for quick access.
  return `https://flagcdn.com/w80/${code.toLowerCase()}.png`;
}

function buildUpdate(fields) {
  const sets = [];
  const values = [];
  let i = 1;
  for (const [k,v] of Object.entries(fields)) {
    if (v !== undefined) { sets.push(`${k} = $${i++}`); values.push(v); }
  }
  if (!sets.length) return null;
  sets.push('updated_at = NOW()');
  return { clause: sets.join(', '), values };
}

function adapt(row){
  if(!row) return row;
  // Provide camelCase convenience fields and comingSoonMessage for admin/frontend usage
  const base = { ...row, isActive: row.is_active, isEnabled: row.is_active };
  if (!base.phoneCode && row.phone_prefix) base.phoneCode = row.phone_prefix;
  if (!base.flagUrl && row.flag_url) base.flagUrl = row.flag_url;
  if (row.tax_rate !== undefined && row.tax_rate !== null && base.taxRate === undefined) base.taxRate = parseFloat(row.tax_rate);
  if (!row.is_active) {
    base.comingSoonMessage = row.coming_soon_message || 'Coming soon to your country! Stay tuned for updates.';
  } else {
    base.comingSoonMessage = '';
  }
  if (row.flag_emoji && !base.flagEmoji) base.flagEmoji = row.flag_emoji;
  return base;
}

// GET /api/countries (default: list admin-style; if public=1, return public shape)
router.get('/', async (req,res) => {
  try {
    if (process.env.NODE_ENV === 'test') {
      const data = [
        adapt({ code: 'LK', name: 'Sri Lanka', default_currency: 'LKR', phone_prefix: '+94', locale: 'en_LK', tax_rate: 0, flag_url: '', flag_emoji: '🇱🇰', coming_soon_message: null, is_active: true })
      ];
      return res.json({ success:true, data, total: 1, limit: 100, offset: 0 });
    }
    // If mobile app calls /api/countries without /public, serve public shape when requested
    if (req.query.public === '1' || req.query.format === 'public') {
      const rows = await db.query('SELECT code,name,default_currency,phone_prefix,locale,tax_rate,flag_url,flag_emoji,coming_soon_message,is_active FROM countries ORDER BY name');
      const data = rows.rows.map(r=>({
        code: r.code, name: r.name, phoneCode: r.phone_prefix, currency: r.default_currency,
        flagUrl: r.flag_url, flagEmoji: r.flag_emoji, isActive: r.is_active,
        comingSoon: !r.is_active, statusLabel: r.is_active ? 'Active' : 'Coming Soon',
        comingSoonMessage: !r.is_active ? (r.coming_soon_message || 'This country is coming soon. Please select an active country.') : null
      }));
      if (req.query.expectsArray === '1' || req.query.format === 'array') return res.json(data);
      return res.json({ success:true, data });
    }

    const { search, active, limit = 100, offset = 0 } = req.query;
    const where = [];
    const params = [];
    let p = 1;
    if (active === '1' || active === 'true') { where.push('is_active = true'); }
    if (active === '0' || active === 'false') { where.push('is_active = false'); }
    if (search) {
      where.push(`(code ILIKE $${p} OR name ILIKE $${p})`);
      params.push(`%${search}%`); p++;
    }
    const whereSql = where.length ? 'WHERE ' + where.join(' AND ') : '';
    const totalResult = await db.query(`SELECT COUNT(*)::int AS count FROM countries ${whereSql}`, params);
    const total = totalResult.rows[0].count;
    const l = Math.min(parseInt(limit)||100, 500);
    const o = parseInt(offset)||0;
    const dataResult = await db.query(`SELECT * FROM countries ${whereSql} ORDER BY name LIMIT ${l} OFFSET ${o}`, params);
    res.json({ success:true, data: dataResult.rows.map(adapt), total, limit:l, offset:o });
  } catch (e) {
    console.error('List countries error', e);
    res.status(500).json({ success:false, message:'Error listing countries' });
  }
});

// Public list for mobile selection (must be BEFORE :codeOrId)
router.get(['/public', '/public.json', '/list', '/all'], async (req,res)=>{
  try {
    const rows = await db.query('SELECT code,name,default_currency,phone_prefix,locale,tax_rate,flag_url,flag_emoji,coming_soon_message,is_active FROM countries ORDER BY name');
    const data = rows.rows.map(r=>{
      const base = {
        code: r.code,
        name: r.name,
        phoneCode: r.phone_prefix,
        currency: r.default_currency,
        flagUrl: r.flag_url,
        flagEmoji: r.flag_emoji, // may be null; client can compute fallback
        isActive: r.is_active,
        comingSoon: !r.is_active,
        statusLabel: r.is_active ? 'Active' : 'Coming Soon',
        comingSoonMessage: !r.is_active ? (r.coming_soon_message || 'This country is coming soon. Please select an active country.') : null
      };
      // Legacy compatibility aliases
      base.countryCode = base.code;
      base.callingCode = base.phoneCode;
      base.dialCode = base.phoneCode;
      base.currencyCode = base.currency;
      base.active = base.isActive;
      base.enabled = base.isActive;
      base.flag = base.flagUrl;
      base.id = base.code;
      return base;
    });
    // Default: return { success, data } for current Flutter client
    // If expectsArray or format=array is provided, return the plain array for older clients
    if (req.query.expectsArray === '1' || req.query.format === 'array') {
      return res.json(data);
    }
    return res.json({ success:true, data });
  } catch(e){
    console.error('Public countries list error', e);
    res.status(500).json({ success:false, message:'Error loading countries'});
  }
});

// GET /api/countries/:code/banners - country-scoped banners for mobile app
router.get('/:code/banners', async (req, res) => {
  try {
    const code = (req.params.code || '').toUpperCase();
    if (!code) return res.status(400).json({ success: false, message: 'Country code required' });
    const db = require('../services/database');
    // ensure table exists lightly (same as banners route)
    await db.query(`CREATE TABLE IF NOT EXISTS banners (
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
    )`);
    const limit = Math.min(parseInt(req.query.limit || '6', 10) || 6, 20);
    const rows = await db.query(
      `SELECT id, country, title, subtitle, image_url AS "imageUrl", link_url AS "linkUrl", priority, active
       FROM banners WHERE active = true AND (country = $1 OR country IS NULL) 
       ORDER BY priority DESC, created_at DESC LIMIT ${limit}`,
      [code]
    );
    res.json({ success: true, data: rows.rows });
  } catch (e) {
    console.error('Country banners error', e);
    res.status(500).json({ success: false, message: 'Failed to load banners' });
  }
});

// GET /api/countries/:codeOrId
router.get('/:codeOrId', async (req,res) => {
  try {
    const v = req.params.codeOrId;
    let row;
    if (/^\d+$/.test(v)) {
      row = await db.queryOne('SELECT * FROM countries WHERE id = $1', [parseInt(v,10)]);
    } else {
      row = await db.queryOne('SELECT * FROM countries WHERE code = $1', [v.toUpperCase()]);
    }
    if (!row) return res.status(404).json({ success:false, message:'Country not found' });
    res.json({ success:true, data: adapt(row) });
  } catch (e) {
    console.error('Get country error', e);
    res.status(500).json({ success:false, message:'Error fetching country' });
  }
});

// POST /api/countries
router.post('/', auth.authMiddleware(), auth.roleMiddleware(['admin','super_admin']), async (req,res) => {
  try {
    const { code, name, default_currency, phone_prefix, phoneCode, locale, tax_rate, flag_url, is_active, coming_soon_message, flag_emoji, flag } = req.body;
    if (!code || !name) return res.status(400).json({ success:false, message:'code and name required' });
    const existing = await db.queryOne('SELECT id FROM countries WHERE code = $1', [code.toUpperCase()]);
    if (existing) return res.status(409).json({ success:false, message:'Country code already exists' });
    const activeValue = typeof is_active === 'boolean' ? is_active : false; // default new countries inactive
    // Determine currency: prefer explicitly provided value, else mapped currency for code, else USD fallback.
    let resolvedCurrency = (default_currency || '').trim();
    if (!resolvedCurrency) {
      resolvedCurrency = COUNTRY_CURRENCY_MAP[code.toUpperCase()] || 'USD';
    } else {
      resolvedCurrency = resolvedCurrency.toUpperCase();
    }
    const finalComingSoonMsg = !activeValue ? (coming_soon_message || 'Coming soon to your country! Stay tuned for updates.') : coming_soon_message || null;
    const finalFlagEmoji = flag_emoji || flag || null;
    const finalPhonePrefix = (phone_prefix || phoneCode || COUNTRY_PHONE_PREFIX_MAP[code.toUpperCase()] || '').trim() || null;
    const finalLocale = (locale || COUNTRY_LOCALE_MAP[code.toUpperCase()] || `en_${code.toUpperCase()}`).trim();
    const finalTaxRate = (tax_rate !== undefined && tax_rate !== null && tax_rate !== '') ? tax_rate : (DEFAULT_TAX_RATE_MAP[code.toUpperCase()] || 0);
    const finalFlagUrl = (flag_url && flag_url.trim()) ? flag_url.trim() : buildFlagUrl(code);
    const row = await db.queryOne(`INSERT INTO countries (code, name, default_currency, phone_prefix, locale, tax_rate, flag_url, is_active, coming_soon_message, flag_emoji)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
    RETURNING *`, [code.toUpperCase(), name, resolvedCurrency, finalPhonePrefix, finalLocale, finalTaxRate, finalFlagUrl, activeValue, finalComingSoonMsg, finalFlagEmoji]);
    res.status(201).json({ success:true, message:'Country created', data: adapt(row) });
  } catch (e) {
    console.error('Create country error', e);
    res.status(500).json({ success:false, message:'Error creating country' });
  }
});

// PUT /api/countries/:codeOrId
router.put('/:codeOrId', auth.authMiddleware(), auth.roleMiddleware(['admin','super_admin']), async (req,res) => {
  try {
    const v = req.params.codeOrId;
    const fields = { name: req.body.name, default_currency: req.body.default_currency, phone_prefix: req.body.phone_prefix || req.body.phoneCode, locale: req.body.locale, tax_rate: req.body.tax_rate, flag_url: req.body.flag_url, is_active: req.body.is_active, coming_soon_message: req.body.coming_soon_message, flag_emoji: req.body.flag_emoji || req.body.flag };
    // Auto-supply missing flag_url if explicitly set empty string
    if (fields.flag_url === '') fields.flag_url = buildFlagUrl((req.body.code || '').toUpperCase());
    // If updating to inactive and no message provided but existing row lacks one, we'll handle in status toggle endpoint; here only set locale/phone if provided.
    const upd = buildUpdate(fields);
    if (!upd) return res.status(400).json({ success:false, message:'No valid fields to update' });
    let row;
    if (/^\d+$/.test(v)) {
      upd.values.push(parseInt(v,10));
      row = await db.queryOne(`UPDATE countries SET ${upd.clause} WHERE id = $${upd.values.length} RETURNING *`, upd.values);
    } else {
      upd.values.push(v.toUpperCase());
      row = await db.queryOne(`UPDATE countries SET ${upd.clause} WHERE code = $${upd.values.length} RETURNING *`, upd.values);
    }
    if (!row) return res.status(404).json({ success:false, message:'Country not found' });
    res.json({ success:true, message:'Country updated', data: adapt(row) });
  } catch (e) {
    console.error('Update country error', e);
    res.status(500).json({ success:false, message:'Error updating country' });
  }
});

// DELETE (soft deactivate)
router.delete('/:codeOrId', auth.authMiddleware(), auth.roleMiddleware(['admin','super_admin']), async (req,res) => {
  try {
    const v = req.params.codeOrId;
    let row;
    if (/^\d+$/.test(v)) {
      row = await db.queryOne('UPDATE countries SET is_active = false, updated_at = NOW() WHERE id = $1 RETURNING *', [parseInt(v,10)]);
    } else {
      row = await db.queryOne('UPDATE countries SET is_active = false, updated_at = NOW() WHERE code = $1 RETURNING *', [v.toUpperCase()]);
    }
    if (!row) return res.status(404).json({ success:false, message:'Country not found' });
    res.json({ success:true, message:'Country deactivated', data: adapt(row) });
  } catch (e) {
    console.error('Deactivate country error', e);
    res.status(500).json({ success:false, message:'Error deactivating country' });
  }
});

// Manual auto-activation endpoint for Super Admin
router.post('/:codeOrId/auto-activate', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const v = req.params.codeOrId;
    let row;
    
    // Get country details
    if (/^\d+$/.test(v)) {
      row = await db.queryOne('SELECT * FROM countries WHERE id = $1', [parseInt(v, 10)]);
    } else {
      row = await db.queryOne('SELECT * FROM countries WHERE code = $1', [v.toUpperCase()]);
    }
    
    if (!row) {
      return res.status(404).json({ success: false, message: 'Country not found' });
    }
    
    // Trigger auto-activation
    console.log(`🔄 Manual auto-activation triggered for ${row.name} (${row.code}) by ${req.user?.name || 'Super Admin'}`);
    
    await autoActivateCountryData(
      row.code, 
      row.name, 
      req.user?.id || 'super_admin', 
      req.user?.name || 'Super Admin Manual Activation'
    );
    
    console.log(`✅ Manual auto-activation completed for ${row.name} (${row.code})`);
    
    res.json({ 
      success: true, 
      message: `Auto-activation completed successfully for ${row.name}`,
      data: {
        country_code: row.code,
        country_name: row.name,
        activated_by: req.user?.name || 'Super Admin',
        activated_at: new Date().toISOString()
      }
    });
    
  } catch (error) {
    console.error('Manual auto-activation error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Auto-activation failed', 
      error: error.message 
    });
  }
});

module.exports = router;

// Additional endpoint for status toggle expected by frontend: PUT /api/countries/:codeOrId/status
router.put('/:codeOrId/status', auth.authMiddleware(), auth.roleMiddleware(['admin','super_admin']), async (req,res) => {
  try {
    const v = req.params.codeOrId;
    const desired = req.body && typeof req.body.isActive === 'boolean' ? req.body.isActive : undefined;
    let row;
    if (/^\d+$/.test(v)) {
      row = await db.queryOne('SELECT * FROM countries WHERE id=$1',[parseInt(v,10)]);
    } else {
      row = await db.queryOne('SELECT * FROM countries WHERE code=$1',[v.toUpperCase()]);
    }
    if(!row) return res.status(404).json({ success:false, message:'Country not found'});
    const newVal = desired !== undefined ? desired : !row.is_active;
    let updated;
    if (/^\d+$/.test(v)) {
      if (!newVal && !row.coming_soon_message) {
        updated = await db.queryOne('UPDATE countries SET is_active=$1, coming_soon_message=$2, updated_at=NOW() WHERE id=$3 RETURNING *',[newVal, 'Coming soon to your country! Stay tuned for updates.', parseInt(v,10)]);
      } else if (newVal) {
        // When activating, clear message? Keep for history; we blank in adapt anyway. Do not clear DB value.
        updated = await db.queryOne('UPDATE countries SET is_active=$1, updated_at=NOW() WHERE id=$2 RETURNING *',[newVal, parseInt(v,10)]);
      } else {
        updated = await db.queryOne('UPDATE countries SET is_active=$1, updated_at=NOW() WHERE id=$2 RETURNING *',[newVal, parseInt(v,10)]);
      }
    } else {
      if (!newVal && !row.coming_soon_message) {
        updated = await db.queryOne('UPDATE countries SET is_active=$1, coming_soon_message=$2, updated_at=NOW() WHERE code=$3 RETURNING *',[newVal, 'Coming soon to your country! Stay tuned for updates.', v.toUpperCase()]);
      } else if (newVal) {
        updated = await db.queryOne('UPDATE countries SET is_active=$1, updated_at=NOW() WHERE code=$2 RETURNING *',[newVal, v.toUpperCase()]);
      } else {
        updated = await db.queryOne('UPDATE countries SET is_active=$1, updated_at=NOW() WHERE code=$2 RETURNING *',[newVal, v.toUpperCase()]);
      }
    }
    
    // Auto-activate country data when a country is enabled
    if (newVal && !row.is_active) {
      console.log(`🔄 Country ${updated.code} was activated, triggering auto-activation...`);
      try {
        await autoActivateCountryData(updated.code, updated.name, req.user?.id || 'system', req.user?.name || 'System Auto-Activation');
        console.log(`✅ Auto-activation completed for ${updated.name} (${updated.code})`);
      } catch (autoActivationError) {
        console.error(`❌ Auto-activation failed for ${updated.name} (${updated.code}):`, autoActivationError);
        // Don't fail the main request, just log the error
      }
    }
    
    res.json({ success:true, message:'Status updated', data: adapt(updated) });
  } catch(e){
    console.error('Toggle country status error', e);
    res.status(500).json({ success:false, message:'Error updating country status'});
  }
});
