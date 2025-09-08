require('dotenv').config();
const dbService = require('./services/database');

async function getRecentOTPs() {
  try {
    console.log('Fetching recent OTPs from database...');
    
    // Check for email_otps table
    const emailOtps = await dbService.query(`
      SELECT email, otp, created_at, expires_at, used 
      FROM email_otps 
      WHERE created_at > NOW() - INTERVAL '1 hour'
      ORDER BY created_at DESC 
      LIMIT 10
    `);
    
    console.log('\n📧 Recent Email OTPs:');
    if (emailOtps.rows.length === 0) {
      console.log('No recent email OTPs found');
    } else {
      emailOtps.rows.forEach(otp => {
        const status = otp.used ? '✅ USED' : 
          new Date() > new Date(otp.expires_at) ? '❌ EXPIRED' : '🟢 VALID';
        console.log(`${status} | ${otp.email} | OTP: ${otp.otp} | Created: ${otp.created_at}`);
      });
    }
    
    // Check for phone_otps table too
    try {
      const phoneOtps = await dbService.query(`
        SELECT phone, otp, created_at, expires_at, used 
        FROM phone_otps 
        WHERE created_at > NOW() - INTERVAL '1 hour'
        ORDER BY created_at DESC 
        LIMIT 10
      `);
      
      console.log('\n📱 Recent Phone OTPs:');
      if (phoneOtps.rows.length === 0) {
        console.log('No recent phone OTPs found');
      } else {
        phoneOtps.rows.forEach(otp => {
          const status = otp.used ? '✅ USED' : 
            new Date() > new Date(otp.expires_at) ? '❌ EXPIRED' : '🟢 VALID';
          console.log(`${status} | ${otp.phone} | OTP: ${otp.otp} | Created: ${otp.created_at}`);
        });
      }
    } catch (e) {
      console.log('Phone OTPs table not found or error:', e.message);
    }
    
  } catch (error) {
    console.error('Error fetching OTPs:', error);
  } finally {
    process.exit(0);
  }
}

getRecentOTPs();
