/**
 * 🧪 Test OTP sending with the updated backend
 */
const axios = require('axios');

async function testOTPSending() {
  try {
    console.log('🧪 Testing OTP sending with backend server...');
    
    const testPhone = '+94725742238';
    
    // Try the auth endpoint with correct parameter name
    console.log(`📱 Testing /api/auth/send-otp with emailOrPhone: ${testPhone}`);
    
    try {
      const authResponse = await axios.post('http://localhost:3001/api/auth/send-otp', {
        emailOrPhone: testPhone
      }, {
        headers: {
          'Content-Type': 'application/json'
        },
        timeout: 30000
      });
      
      console.log(`✅ Auth Response Status: ${authResponse.status}`);
      console.log(`📄 Auth Response Data:`, authResponse.data);
      
      if (authResponse.data.success) {
        console.log(`\n🎉 OTP sent successfully via Auth endpoint!`);
        console.log(`📱 OTP ID: ${authResponse.data.otpId}`);
        console.log(`📱 OTP Token: ${authResponse.data.otpToken || 'Not provided'}`);
        console.log(`📞 Check your phone (${testPhone}) for the OTP message`);
        return; // Success, no need to test other endpoints
      }
      
    } catch (authError) {
      console.log(`❌ Auth endpoint failed: ${authError.response?.status || authError.message}`);
      console.log(`Data:`, authError.response?.data);
    }
    
    // Try SMS endpoint with phoneNumber parameter
    console.log(`\n📱 Testing /api/sms/send-otp with phoneNumber: ${testPhone}`);
    
    try {
      const smsResponse = await axios.post('http://localhost:3001/api/sms/send-otp', {
        phoneNumber: testPhone,
        purpose: 'verification'
      }, {
        headers: {
          'Content-Type': 'application/json'
        },
        timeout: 30000
      });
      
      console.log(`✅ SMS Response Status: ${smsResponse.status}`);
      console.log(`📄 SMS Response Data:`, smsResponse.data);
      
      if (smsResponse.data.success) {
        console.log(`\n🎉 OTP sent successfully via SMS endpoint!`);
        console.log(`📱 OTP ID: ${smsResponse.data.otpId}`);
        console.log(`📱 OTP Token: ${smsResponse.data.otpToken || 'Not provided'}`);
        console.log(`📞 Check your phone (${testPhone}) for the OTP message`);
      }
      
    } catch (smsError) {
      console.log(`❌ SMS endpoint also failed: ${smsError.response?.status || smsError.message}`);
      console.log(`Error details:`, smsError.response?.data);
      
      console.log(`\n🔧 The issue is with Hutch SMS authentication. Let's check if local provider works...`);
    }
    
  } catch (error) {
    console.error('\n❌ Test failed:');
    console.error('Error:', error.message);
  }
}

testOTPSending();
