(async () => {
  let db;
  try {
    db = require('/app/backend/services/database');
  } catch (e1) {
    try { db = require('/app/services/database'); } catch (e2) { console.error('Cannot require database module', e1.message, e2.message); process.exit(1); }
  }
  try {
    console.log('Ensuring sms_provider_configs table...');
    await db.query(`
      CREATE TABLE IF NOT EXISTS sms_provider_configs (
        id SERIAL PRIMARY KEY,
        country_code VARCHAR(5) NOT NULL,
        provider VARCHAR(50) NOT NULL,
        config JSONB DEFAULT '{}'::jsonb,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(country_code, provider)
      )
    `);

    const hutchConfig = {
      mode: 'oauth',
      oauthBase: 'https://bsms.hutch.lk',
      username: process.env.HUTCH_USERNAME || 'rimas@alphabet.lk',
      password: process.env.HUTCH_PASSWORD || 'HT3l0b&LH6819',
      senderId: 'ALPHABET'
    };

    console.log('Upserting LK/hutch_mobile config...');
    const res = await db.query(`
      INSERT INTO sms_provider_configs (country_code, provider, config, is_active)
      VALUES ($1, $2, $3::jsonb, $4)
      ON CONFLICT (country_code, provider)
      DO UPDATE SET config = EXCLUDED.config, is_active = EXCLUDED.is_active, updated_at = NOW()
      RETURNING country_code, provider, is_active
    `, ['LK', 'hutch_mobile', JSON.stringify(hutchConfig), true]);
    console.log('Upserted:', res.rows[0]);
  } catch (e) {
    console.error('Seed error:', e);
    process.exitCode = 1;
  } finally {
    process.exit();
  }
})();
