const db = require('./services/database.js');

(async () => {
  try {
    console.log('Clearing OTP records for test phone...');
    const result = await db.query('DELETE FROM phone_otp_verifications WHERE phone = $1', ['+94771234567']);
    console.log(`✅ Cleared ${result.rowCount} OTP records`);
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await db.close();
  }
})();
