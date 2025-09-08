require('dotenv').config();
const axios = require('axios');

async function resendOTP() {
  try {
    const email = process.argv[2];
    if (!email) {
      console.log('Usage: node resend_otp.js <email>');
      console.log('Example: node resend_otp.js test@example.com');
      return;
    }

    console.log(`Sending OTP to: ${email}`);
    
    const response = await axios.post('http://localhost:3001/api/auth/send-email-otp', {
      email: email
    });
    
    console.log('✅ OTP sent successfully!');
    console.log('Response:', JSON.stringify(response.data, null, 2));
    
  } catch (error) {
    console.error('❌ Error sending OTP:', error.response?.data || error.message);
  }
}

resendOTP();
