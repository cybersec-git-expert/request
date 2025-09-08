/**
 * 🧪 Test Hutch SMS API with new authentication flow
 */
const axios = require('axios');

async function testHutchAuthentication() {
  try {
    console.log('🧪 Testing Hutch SMS API with authentication flow...');
    
    // Test credentials (from database)
    const username = 'rimas@alphabet.lk';
    const password = 'HT3l0b&LH6819';
    const testPhone = '725742238';
    const testMessage = 'Test OTP: 123456. This is a test message from Request App.';
    
    console.log(`\n🔐 Step 1: Authenticating with Hutch API...`);
    console.log(`📧 Username: ${username}`);
    
    // Step 1: Authenticate
    const loginResponse = await axios.post('https://bsms.hutch.lk/api/login', {
      email: username,
      password: password
    }, {
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      timeout: 15000
    });
    
    console.log(`✅ Login Response Status: ${loginResponse.status}`);
    console.log(`📝 Login Response Data:`, loginResponse.data);
    
    if (loginResponse.data && loginResponse.data.access_token) {
      const authToken = loginResponse.data.access_token;
      console.log(`🔑 Access Token received: ${authToken.substring(0, 20)}...`);
      
      console.log(`\n📱 Step 2: Sending SMS...`);
      
      // Step 2: Send SMS
      const smsData = {
        recipient: testPhone,
        message: testMessage,
        sender_id: 'ALPHABET',
        message_type: 'text'
      };
      
      console.log(`📞 Sending to: ${testPhone}`);
      console.log(`💬 Message: ${testMessage}`);
      
      const smsResponse = await axios.post('https://bsms.hutch.lk/api/sms/send', smsData, {
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': `Bearer ${authToken}`
        },
        timeout: 15000
      });
      
      console.log(`✅ SMS Response Status: ${smsResponse.status}`);
      console.log(`📱 SMS Response Data:`, smsResponse.data);
      
      if (smsResponse.status === 200 || smsResponse.status === 201) {
        console.log(`\n🎉 SUCCESS! SMS sent successfully!`);
        console.log(`📱 Check your phone (+94${testPhone}) for the test message`);
      } else {
        console.log(`\n❌ SMS sending failed`);
      }
    } else {
      console.log(`\n❌ Authentication failed - no access token received`);
    }
    
  } catch (error) {
    console.error('\n❌ Test failed:');
    console.error('Error:', error.message);
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Data:', error.response.data);
    }
  }
}

// Run the test
testHutchAuthentication();
