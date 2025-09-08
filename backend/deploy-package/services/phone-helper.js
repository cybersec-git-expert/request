const db = require('./database');

function normalizeE164(phone, defaultCountry = 'LK') {
  if (!phone) return null;
  let p = ('' + phone).trim();
  // Sri Lanka quick rules; can be extended per country if needed
  if (p.startsWith('+')) return p.replace(/\s|-/g, '');
  if (defaultCountry === 'LK') {
    p = p.replace(/[^\d]/g, '');
    if (p.startsWith('94') && p.length === 11) return '+' + p;
    if (p.startsWith('0') && p.length === 10) return '+94' + p.substring(1);
    if (p.length === 9) return '+94' + p;
  }
  return '+' + p.replace(/\s|-/g, '');
}

async function getUserPrimary(userId) {
  const row = await db.queryOne('SELECT phone, country_code, phone_verified FROM users WHERE id=$1', [userId]);
  if (!row) return null;
  return { phone: normalizeE164(row.phone, row.country_code || 'LK'), source: 'users.phone', verified: !!row.phone_verified };
}

// Cache detected schema once per process
let phoneBookSchemaCache = null;

async function detectPhoneBookSchema() {
  if (phoneBookSchemaCache) return phoneBookSchemaCache;
  // Check table exists and columns
  const cols = await db
    .query(
      'SELECT column_name FROM information_schema.columns WHERE table_name = \'user_phone_numbers\''
    )
    .then(r => r.rows.map(x => x.column_name))
    .catch(() => []);

  const exists = cols.length > 0;
  const has = name => cols.includes(name);
  phoneBookSchemaCache = {
    exists,
    colVerified: has('is_verified') ? 'is_verified' : has('verified') ? 'verified' : null,
    colPhoneType: has('phone_type') ? 'phone_type' : has('label') ? 'label' : null,
    hasVerifiedAt: has('verified_at'),
    hasPurpose: has('purpose'),
    hasCreatedAt: has('created_at'),
    hasIsPrimary: has('is_primary'),
    hasCountryCode: has('country_code')
  };
  return phoneBookSchemaCache;
}

async function getNumbersFromBook(userId) {
  const schema = await detectPhoneBookSchema();
  if (!schema.exists) return [];

  // Build a SELECT that only references existing columns
  const selectCols = [
    'phone_number'
  ];
  if (schema.colPhoneType) selectCols.push(`${schema.colPhoneType} AS phone_type`);
  if (schema.colVerified) selectCols.push(`${schema.colVerified} AS is_verified`);
  if (schema.hasVerifiedAt) selectCols.push('verified_at');
  if (schema.hasPurpose) selectCols.push('purpose');
  if (schema.hasCreatedAt) selectCols.push('created_at');
  if (schema.hasIsPrimary) selectCols.push('is_primary');
  if (schema.hasCountryCode) selectCols.push('country_code');

  const sql = `SELECT ${selectCols.join(', ')} FROM user_phone_numbers WHERE user_id=$1`;
  let res;
  try {
    res = await db.query(sql, [userId]);
  } catch (e) {
    // If anything goes wrong, fail soft and act like no phone book
    console.warn('[phone-helper] getNumbersFromBook failed, proceeding without phone book:', e.message);
    return [];
  }

  return res.rows.map(r => ({
    phone: normalizeE164(r.phone_number, r.country_code || 'LK'),
    phone_type: r.phone_type || null,
    verified: !!(r.is_verified),
    verified_at: r.verified_at,
    purpose: r.purpose || null,
    is_primary: typeof r.is_primary === 'boolean' ? r.is_primary : false,
    source: 'user_phone_numbers'
  }));
}

async function getBusinessVerificationPhone(userId) {
  // try final/approved business verification phone when available
  try {
    const r = await db.queryOne(`
      SELECT business_phone AS phone_number, status,
             COALESCE(phone_verified, false) AS phone_verified,
             COALESCE(is_verified, false)   AS is_verified
      FROM business_verifications
      WHERE user_id=$1
      ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
      LIMIT 1
    `, [userId]);
    if (!r) return null;
    const st = (r.status || '').toLowerCase();
    const ok = !!(r.is_verified || r.phone_verified || st === 'approved' || st === 'verified');
    return { phone: normalizeE164(r.phone_number), source: 'business_verifications', verified: ok };
  } catch { return null; }
}

async function getDriverVerificationPhone(userId) {
  try {
    const r = await db.queryOne(`
      SELECT phone_number, status,
             COALESCE(phone_verified, false) AS phone_verified,
             COALESCE(is_verified, false)    AS is_verified
      FROM driver_verifications
      WHERE user_id=$1
      ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
      LIMIT 1
    `, [userId]);
    if (!r) return null;
    const st = (r.status || '').toLowerCase();
    const ok = !!(r.is_verified || r.phone_verified || st === 'approved' || st === 'verified' || st === 'complete');
    return { phone: normalizeE164(r.phone_number), source: 'driver_verifications', verified: ok };
  } catch { return null; }
}

/**
 * Pick best contact phone for a user and context.
 * context: 'personal' | 'business' | 'driver'
 * Returns: { phone, source, verified } or null
 */
async function selectContactPhone(userId, context = 'personal') {
  const ctx = (context || 'personal').toLowerCase();
  const book = await getNumbersFromBook(userId);
  const primary = await getUserPrimary(userId);
  const biz = await getBusinessVerificationPhone(userId);
  const drv = await getDriverVerificationPhone(userId);

  // Prefer verified and is_primary when sifting
  const score = (x) => {
    if (!x || !x.phone) return -Infinity;
    let s = 0;
    if (x.verified) s += 10;
    if (x.is_primary) s += 5;
    return s;
  };
  const pick = (...candidates) => candidates
    .filter(Boolean)
    .filter(x => x.phone)
    .sort((a,b) => score(b) - score(a))[0];

  // Helper to sift from phone book by purpose and verification
  const fromBook = (purposes = []) => {
    const items = book.filter(b => !purposes.length || (b.purpose && purposes.includes(b.purpose.toLowerCase())));
    // Prefer verified first, then most recent verified_at/created_at
    items.sort((a,b)=>{
      if (a.verified !== b.verified) return a.verified ? -1 : 1;
      if (a.is_primary !== b.is_primary) return a.is_primary ? -1 : 1;
      const at = a.verified_at ? new Date(a.verified_at).getTime() : 0;
      const bt = b.verified_at ? new Date(b.verified_at).getTime() : 0;
      if (at !== bt) return bt - at;
      const ac = a.created_at ? new Date(a.created_at).getTime() : 0;
      const bc = b.created_at ? new Date(b.created_at).getTime() : 0;
      return bc - ac;
    });
    return items[0] || null;
  };

  if (ctx === 'business') {
    return pick(biz, fromBook(['business','work','professional']), primary, drv, fromBook([]));
  }
  if (ctx === 'driver') {
    return pick(drv, fromBook(['driver','ride']), primary, biz, fromBook([]));
  }
  // personal/default
  return pick(fromBook(['personal']), primary, biz, drv, fromBook([]));
}

module.exports = {
  normalizeE164,
  selectContactPhone,
};
