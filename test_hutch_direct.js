const axios = require('axios');

async function testHutchDirectly() {
  try {
    console.log('🧪 Testing Hutch SMS API directly...');
    
    // Use the same credentials from the database
    const config = {
      apiUrl: 'https://webbsms.hutch.lk/',
      username: 'rimas@alphabet.lk',
      password: 'HT3l0b&LH6819',
      senderId: 'ALPHABET',
      messageType: 'text'
    };

    const testPhone = '725742238'; // Your number without +94
    const testMessage = 'TEST: Direct Hutch API call from Request Marketplace';

    const params = new URLSearchParams({
      username: config.username,
      password: config.password,
      to: testPhone,
      message: testMessage,
      sender_id: config.senderId,
      message_type: config.messageType
    });

    const fullUrl = `${config.apiUrl}?${params.toString()}`;
    console.log(`📱 Hutch API URL: ${config.apiUrl}?username=${config.username}&to=${testPhone}&message=[HIDDEN]&sender_id=${config.senderId}`);

    const response = await axios.get(fullUrl, {
      timeout: 15000
    });

    console.log('📱 Hutch API Response Status:', response.status);
    console.log('📱 Hutch API Response Data:', response.data);

    if (response.data && (response.data.status === 'success' || response.status === 200)) {
      console.log('✅ Hutch API call successful!');
      console.log('📱 Check your phone for the test message');
    } else {
      console.log('❌ Hutch API call failed');
    }

  } catch (error) {
    console.error('❌ Hutch API Error:', error.response?.data || error.message);
  }
}

testHutchDirectly();
