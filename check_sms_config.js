const db = require('./backend/services/database');

async function checkSMSConfig() {
  try {
    // Check SMS provider configs table structure
    const providerCols = await db.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sms_provider_configs'");
    console.log('\n📋 sms_provider_configs columns:', providerCols.rows);

    // Check SMS provider configurations (likely contains Hutch details)
    const providerConfigs = await db.query("SELECT * FROM sms_provider_configs");
    console.log('\n📞 SMS Provider Configurations:', providerConfigs.rows);

    // Check SMS configurations table structure
    const configCols = await db.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sms_configurations'");
    console.log('\n📋 sms_configurations columns:', configCols.rows);

    // Check all SMS configurations
    const configs = await db.query("SELECT * FROM sms_configurations LIMIT 5");
    console.log('\n⚙️ SMS Configurations:', configs.rows);

    // Check recent OTP records for your number
    const otps = await db.query("SELECT * FROM otp_verifications WHERE phone_number = '+94725742238' ORDER BY created_at DESC LIMIT 5");
    console.log('\n📱 Recent OTP records for +94725742238:', otps.rows);

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkSMSConfig();
