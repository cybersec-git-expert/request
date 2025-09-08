const axios = require('axios');

// Safety guard: prevent accidental test data creation unless explicitly allowed
if (process.env.ALLOW_TEST_SCRIPTS !== 'true') {
  console.error('Refusing to run: set ALLOW_TEST_SCRIPTS=true to enable test registration script.');
  process.exit(1);
}

async function testRegistration() {
  try {
    console.log('🔧 Testing Flutter registration endpoint...');
    
    const registrationData = {
      emailOrPhone: 'test.user@example.com',
      firstName: 'Test',
      lastName: 'User',
      displayName: 'Test User',
      password: 'SecurePassword123!',
      isEmail: true
    };

    console.log('📤 Sending registration request...');
    
    const response = await axios.post('http://localhost:3001/api/flutter/auth/register-complete', registrationData, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

    console.log('✅ Registration successful!');
    console.log('Response:', JSON.stringify(response.data, null, 2));

  } catch (error) {
    console.error('❌ Registration failed:');
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Data:', JSON.stringify(error.response.data, null, 2));
    } else {
      console.error('Error:', error.message);
    }
  }
}

// Run the test
testRegistration();
