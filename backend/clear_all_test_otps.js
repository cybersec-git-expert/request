const db = require('./services/database.js');

(async () => {
  try {
    console.log('Clearing all OTP records for recent test phones...');
    
    // Clear OTP records for common test phone numbers
    const testPhones = [
      '+94740111111',
      '+94 740111111', 
      '+94770123456',
      '+94771234567',
      '+94112345678'
    ];
    
    let totalCleared = 0;
    
    for (const phone of testPhones) {
      const result = await db.query('DELETE FROM phone_otp_verifications WHERE phone = $1', [phone]);
      console.log(`✅ Cleared ${result.rowCount} OTP records for ${phone}`);
      totalCleared += result.rowCount;
    }
    
    // Also clear very recent records (last 2 hours) to help with testing
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
    const recentResult = await db.query(
      'DELETE FROM phone_otp_verifications WHERE created_at > $1', 
      [twoHoursAgo]
    );
    console.log(`✅ Cleared ${recentResult.rowCount} recent OTP records from last 2 hours`);
    totalCleared += recentResult.rowCount;
    
    console.log(`\n🎉 Total cleared: ${totalCleared} OTP records`);
    console.log('✅ Rate limiting should now be reset for testing');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await db.close();
  }
})();
