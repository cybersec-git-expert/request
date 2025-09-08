const db = require('./services/database');

(async () => {
  try {
    console.log('🏢 Adding Hutch Mobile configuration to sms_provider_configs table...');
    
    const hutchConfig = {
      mode: 'oauth',
      oauthBase: 'https://bsms.hutch.lk',
      username: 'rimas@alphabet.lk',
      password: 'HT3l0b&LH6819',
      senderId: 'ALPHABET'
    };
    
    // Insert Hutch Mobile configuration
    const result = await db.query(`
      INSERT INTO sms_provider_configs (country_code, provider, config, is_active)
      VALUES ($1, $2, $3::jsonb, $4)
      ON CONFLICT (country_code, provider) 
      DO UPDATE SET 
        config = EXCLUDED.config,
        is_active = EXCLUDED.is_active,
        updated_at = NOW()
      RETURNING *
    `, ['LK', 'hutch_mobile', JSON.stringify(hutchConfig), true]);
    
    console.log('✅ Hutch Mobile configuration added successfully!');
    console.log('📋 Configuration details:');
    console.log(`   Country: ${result.rows[0].country_code}`);
    console.log(`   Provider: ${result.rows[0].provider}`);
    console.log(`   Active: ${result.rows[0].is_active}`);
    console.log(`   Config: ${JSON.stringify(result.rows[0].config, null, 2)}`);
    
    // Verify the configuration
    console.log('\n🔍 Verifying configuration...');
    const verify = await db.query('SELECT * FROM sms_provider_configs WHERE country_code = $1 AND provider = $2', ['LK', 'hutch_mobile']);
    
    if (verify.rows.length > 0) {
      console.log('✅ Configuration verified in database');
    } else {
      console.log('❌ Configuration not found after insert');
    }
    
    // Show all LK configurations
    console.log('\n📊 All SMS configurations for LK:');
    const allConfigs = await db.query('SELECT * FROM sms_provider_configs WHERE country_code = $1', ['LK']);
    allConfigs.rows.forEach(config => {
      console.log(`   ${config.provider}: ${config.is_active ? '✅ Active' : '❌ Inactive'}`);
    });
    
  } catch(e) {
    console.error('❌ Error adding Hutch Mobile configuration:', e.message);
    console.error('💡 Details:', e);
  } finally {
    process.exit(0);
  }
})();
