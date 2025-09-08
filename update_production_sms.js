const db = require('./backend/services/database');

(async () => {
  try {
    console.log('🌍 Applying SMS fixes to PRODUCTION (AWS) database...');
    
    // First, let's check current production status
    console.log('\n1️⃣ Checking current production SMS configuration:');
    const currentConfig = await db.query('SELECT provider, is_active FROM sms_provider_configs WHERE country_code = $1', ['LK']);
    console.log('   Current providers for LK:');
    currentConfig.rows.forEach(row => {
      console.log(`   ${row.provider}: ${row.is_active ? '✅ ACTIVE' : '❌ INACTIVE'}`);
    });
    
    // Switch to LOCAL provider for production testing
    console.log('\n2️⃣ Switching production to LOCAL provider (safer for testing):');
    
    // Deactivate Hutch (since it's not working properly)
    await db.query('UPDATE sms_provider_configs SET is_active = false WHERE country_code = $1 AND provider = $2', ['LK', 'hutch_mobile']);
    console.log('   ❌ Deactivated hutch_mobile');
    
    // Activate local provider
    await db.query('UPDATE sms_provider_configs SET is_active = true WHERE country_code = $1 AND provider = $2', ['LK', 'local']);
    console.log('   ✅ Activated local provider');
    
    // Update SMS configurations table
    await db.query('UPDATE sms_configurations SET active_provider = $1 WHERE country_code = $2', ['local', 'LK']);
    console.log('   ⚙️ Updated sms_configurations table');
    
    // Verify changes
    console.log('\n3️⃣ Verification - Final production SMS configuration:');
    const finalConfig = await db.query('SELECT provider, is_active FROM sms_provider_configs WHERE country_code = $1', ['LK']);
    finalConfig.rows.forEach(row => {
      console.log(`   ${row.provider}: ${row.is_active ? '✅ ACTIVE' : '❌ INACTIVE'}`);
    });
    
    console.log('\n🎯 Production SMS configuration updated!');
    console.log('📱 Mobile app should now work with LOCAL provider');
    console.log('🔍 Check server logs at api.alphabet.lk for OTP codes');
    
    console.log('\n📋 Next steps:');
    console.log('1. Test mobile app OTP flow');
    console.log('2. Check AWS server logs for OTP codes');
    console.log('3. Use logged OTP codes for verification');
    
  } catch (error) {
    console.error('❌ Error updating production:', error.message);
  } finally {
    process.exit(0);
  }
})();
