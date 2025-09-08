const db = require('./services/database');

(async () => {
  try {
    console.log('🔧 Updating Hutch Mobile API URL to https://webbsms.hutch.lk/...');
    
    // First, let's check current configuration
    const current = await db.query('SELECT * FROM sms_provider_configs WHERE country_code = $1 AND provider = $2', ['LK', 'hutch_mobile']);
    
    if (current.rows.length === 0) {
      console.log('❌ No Hutch Mobile configuration found');
      return;
    }
    
    console.log('📋 Current configuration:');
    console.log(JSON.stringify(current.rows[0].config, null, 2));
    
    // Update the API URL
    const updatedConfig = {
      ...current.rows[0].config,
      apiUrl: 'https://webbsms.hutch.lk/'
    };
    
    const result = await db.query(
      'UPDATE sms_provider_configs SET config = $1, updated_at = NOW() WHERE country_code = $2 AND provider = $3 RETURNING *',
      [JSON.stringify(updatedConfig), 'LK', 'hutch_mobile']
    );
    
    if (result.rows.length > 0) {
      console.log('✅ Updated Hutch Mobile API URL successfully');
      console.log('📋 New configuration:');
      console.log(JSON.stringify(result.rows[0].config, null, 2));
      console.log('\n🔗 API URL changed from: https://bsms.hutch.lk/api/send');
      console.log('🔗 API URL changed to:   https://webbsms.hutch.lk/');
    } else {
      console.log('❌ Failed to update configuration');
    }
    
  } catch(e) {
    console.error('❌ Error updating Hutch Mobile API URL:', e.message);
  } finally {
    process.exit(0);
  }
})();
