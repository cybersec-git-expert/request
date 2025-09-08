/**
 * 🔧 Configure local SMS provider as fallback for testing
 */
const database = require('./backend/services/database');

async function configureLocalFallback() {
  try {
    console.log('🔧 Configuring local SMS provider as fallback...');
    
    // Update SMS configuration to use local provider temporarily
    await database.query(`
      UPDATE sms_configurations 
      SET active_provider = 'local',
          local_config = '{"enabled": true, "logOnly": true}'
      WHERE country_code = 'LK'
    `);
    
    console.log('✅ Updated LK configuration to use local provider');
    
    // Also add local provider config to sms_provider_configs
    await database.query(`
      INSERT INTO sms_provider_configs (country_code, provider, config, is_active)
      VALUES ('LK', 'local', '{"enabled": true, "logOnly": true}', true)
      ON CONFLICT (country_code, provider) 
      DO UPDATE SET 
        config = EXCLUDED.config,
        is_active = EXCLUDED.is_active,
        updated_at = NOW()
    `);
    
    console.log('✅ Added/updated local provider config');
    
    // Check current configurations
    const result = await database.query('SELECT * FROM sms_provider_configs WHERE country_code = $1', ['LK']);
    console.log('📋 Current LK SMS provider configs:', result.rows);
    
    const configResult = await database.query('SELECT * FROM sms_configurations WHERE country_code = $1', ['LK']);
    console.log('📋 Current LK SMS configuration:', configResult.rows[0]);
    
    console.log('\n✅ Local SMS provider configured successfully!');
    console.log('🧪 You can now test SMS sending - it will log to console instead of sending real SMS');
    
  } catch (error) {
    console.error('❌ Failed to configure local provider:', error.message);
  } finally {
    process.exit(0);
  }
}

configureLocalFallback();
