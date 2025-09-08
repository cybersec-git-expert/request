const database = require('./services/database');

async function seedDefaultSMSConfig() {
  try {
    console.log('🔧 Checking SMS configurations...');
    
    const result = await database.query('SELECT COUNT(*) as count FROM sms_configurations WHERE country_code = $1', ['LK']);
    const count = parseInt(result.rows[0].count);
    
    if (count === 0) {
      console.log('📱 Creating default SMS configuration for LK...');
      await database.query(`
        INSERT INTO sms_configurations 
        (country_code, active_provider, approval_status, is_active, local_config, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
      `, ['LK', 'local', 'approved', true, JSON.stringify({
        endpoint: 'http://localhost:3001/api/dev/sms',
        apiKey: 'dev_key',
        method: 'POST'
      })]);
      console.log('✅ Default SMS configuration created');
    } else {
      console.log('✅ SMS configuration already exists');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding SMS config:', error.message);
    process.exit(1);
  }
}

seedDefaultSMSConfig();
