/**
 * 🧪 Test different Hutch API endpoints to find the correct one
 */
const axios = require('axios');

async function testHutchEndpoints() {
  const username = 'rimas@alphabet.lk';
  const password = 'HT3l0b&LH6819';
  
  // Different possible endpoints based on documentation
  const endpoints = [
    'https://bsms.hutch.lk/login',
    'https://bsms.hutch.lk/api/login',
    'https://webbsms.hutch.lk/login',
    'https://webbsms.hutch.lk/api/login'
  ];
  
  for (const endpoint of endpoints) {
    console.log(`\n🧪 Testing endpoint: ${endpoint}`);
    
    try {
      const response = await axios.post(endpoint, {
        email: username,
        password: password
      }, {
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        timeout: 10000,
        validateStatus: () => true // Don't throw on non-2xx status
      });
      
      console.log(`📊 Status: ${response.status}`);
      console.log(`📝 Content-Type: ${response.headers['content-type']}`);
      
      if (typeof response.data === 'string' && response.data.includes('<!DOCTYPE html>')) {
        console.log(`📄 Response: HTML page (login form)`);
      } else {
        console.log(`📄 Response:`, response.data);
      }
      
    } catch (error) {
      console.log(`❌ Error: ${error.message}`);
    }
  }
  
  console.log(`\n🔍 Testing GET method on web interface...`);
  try {
    const response = await axios.get('https://webbsms.hutch.lk/', {
      timeout: 10000
    });
    console.log(`📊 GET Status: ${response.status}`);
    if (response.data.includes('action="https://webbsms.hutch.lk/login"')) {
      console.log(`✅ Found login form action URL`);
    }
  } catch (error) {
    console.log(`❌ GET Error: ${error.message}`);
  }
}

testHutchEndpoints();
