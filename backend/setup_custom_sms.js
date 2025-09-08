const db = require('./services/database');

async function setupCustomSriLankaAPI() {
  try {
    // Custom Sri Lanka SMS API configuration
    const hutchMobileConfig = {
      apiUrl: 'YOUR_CUSTOM_API_ENDPOINT_HERE', // e.g., "https://api.yoursmsservice.lk/v1/send"
      username: 'YOUR_API_USERNAME',
      password: 'YOUR_API_PASSWORD', 
      senderId: 'RequestApp', // Your app name or sender ID
      messageType: 'text'
    };

    console.log('Updating Sri Lanka SMS configuration to use custom API...');
    
    const result = await db.query(`
      UPDATE sms_configurations 
      SET 
        active_provider = 'hutch_mobile',
        hutch_mobile_config = $1,
        updated_at = NOW()
      WHERE country_code = 'LK'
    `, [JSON.stringify(hutchMobileConfig)]);
    
    console.log(`✅ Updated ${result.rowCount} configuration(s)`);
    
    // Verify the update
    const verification = await db.query('SELECT active_provider, hutch_mobile_config FROM sms_configurations WHERE country_code = \'LK\'');
    console.log('\n📋 Updated configuration:');
    console.log(JSON.stringify(verification.rows[0], null, 2));
    
    await db.close();
    
    console.log('\n🔧 Next steps:');
    console.log('1. Replace YOUR_CUSTOM_API_ENDPOINT_HERE with your actual API URL');
    console.log('2. Replace YOUR_API_USERNAME and YOUR_API_PASSWORD with real credentials');
    console.log('3. Test the SMS functionality');
    
  } catch (error) {
    console.error('❌ Error updating configuration:', error);
    await db.close();
  }
}

setupCustomSriLankaAPI();
