const db = require('./database');
/**
 * SMS Service enabling country-level provider configuration with a dev fallback.
 * Currently only a 'dev' provider is implemented (logs OTP). Other providers are stubs
 * and will gracefully fall back to logging while returning metadata.
 */
class SMSService {
  constructor() {
    this.supportedProviders = new Set(['dev', 'twilio', 'aws_sns', 'vonage', 'local_http']);
    this._initialized = false;
  }

  async ensureTable() {
    if (this._initialized) return;
    // Defensive DDL so code works even if migration not yet applied in a test environment
    await db.query(`CREATE TABLE IF NOT EXISTS sms_provider_configs (
        id SERIAL PRIMARY KEY,
        country_code VARCHAR(10) NOT NULL,
        provider VARCHAR(50) NOT NULL,
        config JSONB DEFAULT '{}'::jsonb,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );`);
    await db.query('CREATE UNIQUE INDEX IF NOT EXISTS idx_sms_provider_unique ON sms_provider_configs(country_code, provider);');
    await db.query('CREATE INDEX IF NOT EXISTS idx_sms_provider_active ON sms_provider_configs(country_code, is_active);');
    this._initialized = true;
  }

  async getActiveProvider(countryCode) {
    await this.ensureTable();
    const row = await db.queryOne(`SELECT provider, config FROM sms_provider_configs
      WHERE country_code = $1 AND is_active = TRUE ORDER BY provider='dev' DESC LIMIT 1`, [countryCode]);
    if (!row) return { provider: 'dev', config: { note: 'implicit fallback (no active provider configured)' } };
    return { provider: row.provider, config: row.config || {} };
  }

  async sendOTP({ phone, otp, countryCode }) {
    const { provider } = await this.getActiveProvider(countryCode || 'LK');
    if (provider === 'dev') {
      console.log(`[SMS][DEV] OTP for ${phone}: ${otp}`);
      return { success: true, provider: 'dev', messageId: null, fallback: true };
    }
    // Placeholder for real integrations (twilio, aws_sns, etc.)
    console.warn(`[SMS] Provider '${provider}' not yet implemented, falling back to dev log.`);
    console.log(`[SMS][FALLBACK] OTP for ${phone}: ${otp}`);
    return { success: true, provider, messageId: null, fallback: true, warning: 'provider_not_implemented' };
  }
}

module.exports = new SMSService();
