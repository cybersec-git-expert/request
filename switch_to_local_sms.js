const db = require('./backend/services/database');

(async () => {
  try {
    console.log('🔄 Temporarily switching to LOCAL provider for testing...');
    
    // Switch back to local provider for immediate testing
    await db.query('UPDATE sms_provider_configs SET is_active = false WHERE country_code = $1 AND provider = $2', ['LK', 'hutch_mobile']);
    await db.query('UPDATE sms_provider_configs SET is_active = true WHERE country_code = $1 AND provider = $2', ['LK', 'local']);
    await db.query('UPDATE sms_configurations SET active_provider = $1 WHERE country_code = $2', ['local', 'LK']);
    
    console.log('✅ Switched to LOCAL provider (console logging)');
    console.log('📱 This will show SMS content in server logs instead of sending real SMS');
    console.log('🔄 You can now test OTP flow without waiting for real SMS delivery');
    
    // Show current status
    const result = await db.query('SELECT provider, is_active FROM sms_provider_configs WHERE country_code = $1', ['LK']);
    console.log('\n📋 Current SMS providers for LK:');
    result.rows.forEach(row => {
      console.log(`   ${row.provider}: ${row.is_active ? '✅ ACTIVE' : '❌ INACTIVE'}`);
    });
    
    console.log('\n🧪 To test:');
    console.log('1. Try sending OTP from mobile app');
    console.log('2. Check server console logs for the OTP code');
    console.log('3. Use that OTP code to verify');
    
    console.log('\n🔄 To switch back to Hutch later:');
    console.log('node activate_hutch.js');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    process.exit(0);
  }
})();
