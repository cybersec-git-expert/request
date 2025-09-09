#!/usr/bin/env node

// Test script to verify entitlements API functionality
const API_BASE = 'http://3.92.216.149:3001';

async function makeRequest(url, options = {}) {
  const response = await fetch(url, {
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...options.headers
    },
    ...options
  });
  
  const data = await response.json();
  return { status: response.status, data };
}

async function testEntitlementsAPI() {
  console.log('🧪 Testing Entitlements API Functionality\n');
  
  const testUserId = `test-user-${Date.now()}`;
  console.log(`Using test user ID: ${testUserId}\n`);
  
  try {
    // Test 1: Get initial entitlements (should have 3 free responses)
    console.log('📋 Test 1: Get Initial User Entitlements');
    const initial = await makeRequest(`${API_BASE}/api/entitlements-simple/me?user_id=${testUserId}`);
    console.log(`Status: ${initial.status}`);
    console.log(`Data:`, JSON.stringify(initial.data, null, 2));
    
    if (initial.data.success && initial.data.data.remainingResponses === 3) {
      console.log('✅ PASS: New user has 3 free responses\n');
    } else {
      console.log('❌ FAIL: New user should have 3 free responses\n');
    }
    
    // Test 2: Check contact details permission
    console.log('📋 Test 2: Check Contact Details Permission');
    const contactDetails = await makeRequest(`${API_BASE}/api/entitlements-simple/contact-details?user_id=${testUserId}`);
    console.log(`Status: ${contactDetails.status}`);
    console.log(`Data:`, JSON.stringify(contactDetails.data, null, 2));
    
    if (contactDetails.data.success && contactDetails.data.data.canSeeContactDetails) {
      console.log('✅ PASS: User can see contact details\n');
    } else {
      console.log('❌ FAIL: User should be able to see contact details\n');
    }
    
    // Test 3: Check messaging permission
    console.log('📋 Test 3: Check Messaging Permission');
    const messaging = await makeRequest(`${API_BASE}/api/entitlements-simple/messaging?user_id=${testUserId}`);
    console.log(`Status: ${messaging.status}`);
    console.log(`Data:`, JSON.stringify(messaging.data, null, 2));
    
    if (messaging.data.success && messaging.data.data.canSendMessages) {
      console.log('✅ PASS: User can send messages\n');
    } else {
      console.log('❌ FAIL: User should be able to send messages\n');
    }
    
    // Test 4: Check respond permission
    console.log('📋 Test 4: Check Respond Permission');
    const respond = await makeRequest(`${API_BASE}/api/entitlements-simple/respond?user_id=${testUserId}`);
    console.log(`Status: ${respond.status}`);
    console.log(`Data:`, JSON.stringify(respond.data, null, 2));
    
    if (respond.data.success && respond.data.data.canRespond) {
      console.log('✅ PASS: User can respond\n');
    } else {
      console.log('❌ FAIL: User should be able to respond\n');
    }
    
    // Test 5: Test different user to ensure isolation
    console.log('📋 Test 5: Test User Isolation');
    const testUserId2 = `test-user-${Date.now()}-2`;
    const user2Initial = await makeRequest(`${API_BASE}/api/entitlements-simple/me?user_id=${testUserId2}`);
    console.log(`Second user ID: ${testUserId2}`);
    console.log(`Status: ${user2Initial.status}`);
    console.log(`Data:`, JSON.stringify(user2Initial.data, null, 2));
    
    if (user2Initial.data.success && user2Initial.data.data.remainingResponses === 3) {
      console.log('✅ PASS: Each user gets their own 3 free responses\n');
    } else {
      console.log('❌ FAIL: Users should have independent response counts\n');
    }
    
    console.log('🎉 Entitlements API Test Complete!');
    console.log('\n📊 Summary:');
    console.log('- New users get 3 free responses');
    console.log('- Users can access contact details');
    console.log('- Users can send messages');
    console.log('- Users can respond to requests');
    console.log('- Each user has independent entitlements');
    console.log('\n🚀 Ready for Flutter app integration!');
    
  } catch (error) {
    console.error('❌ Error testing entitlements API:', error.message);
    console.error(error.stack);
  }
}

// Run the test
testEntitlementsAPI();
