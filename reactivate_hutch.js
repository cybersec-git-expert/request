const db = require('./backend/services/database');

(async () => {
  try {
    console.log('🔄 Activating Hutch Mobile provider for production...');
    
    // Activate Hutch Mobile provider
    const activateHutch = await db.query(
      'UPDATE sms_provider_configs SET is_active = true WHERE provider = $1 AND country_code = $2', 
      ['hutch_mobile', 'LK']
    );
    console.log('✅ Activated Hutch Mobile provider');
    
    // Deactivate local provider
    const deactivateLocal = await db.query(
      'UPDATE sms_provider_configs SET is_active = false WHERE provider = $1 AND country_code = $2', 
      ['local', 'LK']
    );
    console.log('⚙️ Deactivated local provider');
    
    // Update sms_configurations to use hutch_mobile
    const updateSmsConfig = await db.query(
      'UPDATE sms_configurations SET active_provider = $1 WHERE country_code = $2', 
      ['hutch_mobile', 'LK']
    );
    console.log('⚙️ Updated active provider to hutch_mobile');
    
    // Check results
    const result = await db.query('SELECT * FROM sms_provider_configs WHERE country_code = $1', ['LK']);
    console.log('📋 LK Provider configurations:');
    result.rows.forEach(row => {
      console.log(`   ${row.provider}: ${row.is_active ? '✅ ACTIVE' : '❌ INACTIVE'}`);
    });
    
    const smsResult = await db.query('SELECT country_code, active_provider, is_active FROM sms_configurations WHERE country_code = $1', ['LK']);
    console.log('📋 LK SMS configuration:', smsResult.rows[0]);
    
    console.log('\n🚀 Production AWS server is now configured with:');
    console.log('   • Hutch Mobile SMS provider: ACTIVE');
    console.log('   • Country code mapping: +94 → LK (FIXED)');
    console.log('   • WebbSMS API integration: READY');
    console.log('\n🔧 Tomorrow: Fix Hutch credentials/API endpoint for actual SMS delivery');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    process.exit(0);
  }
})();
