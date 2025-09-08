const db = require('./backend/services/database');

async function checkOTPTables() {
  try {
    // Find OTP tables
    const otpTables = await db.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%otp%'");
    console.log('🔍 OTP Tables:', otpTables.rows);

    // Find phone verification tables
    const phoneTables = await db.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%phone%'");
    console.log('📱 Phone Tables:', phoneTables.rows);

    // Check phone_otp_verifications table (from SMS service code)
    try {
      const phoneOtps = await db.query("SELECT * FROM phone_otp_verifications WHERE phone = '+94725742238' ORDER BY created_at DESC LIMIT 5");
      console.log('\n📱 Recent phone OTP records:', phoneOtps.rows);
    } catch (err) {
      console.log('\n❌ phone_otp_verifications table does not exist');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkOTPTables();
