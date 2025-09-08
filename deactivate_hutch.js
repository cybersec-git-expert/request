const database = require('./backend/services/database');

(async () => {
  try {
    await database.query('UPDATE sms_provider_configs SET is_active = false WHERE provider = $1', ['hutch_mobile']);
    console.log('✅ Deactivated hutch_mobile provider');
    
    const result = await database.query('SELECT * FROM sms_provider_configs WHERE country_code = $1', ['LK']);
    console.log('📋 Updated LK SMS provider configs:', result.rows);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    process.exit(0);
  }
})();
