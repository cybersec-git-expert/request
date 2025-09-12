// Simple subscription system test script
const baseUrl = 'http://localhost:3002/api';

// Mock auth token for testing (replace with real token)
const authToken = 'test-token';

async function testSubscriptionEndpoints() {
  console.log('🧪 Testing Simple Subscription System Endpoints\n');

  try {
    // Test 1: Get all plans
    console.log('1. Testing GET /api/simple-subscription/plans');
    const plansResponse = await fetch(`${baseUrl}/simple-subscription/plans`);
    const plans = await plansResponse.json();
    console.log('✅ Plans Response:', JSON.stringify(plans, null, 2));
    console.log();

    // Test 2: Get plans for specific country (Sri Lanka)
    console.log('2. Testing GET /api/simple-subscription/plans?country=LK');
    const lkPlansResponse = await fetch(`${baseUrl}/simple-subscription/plans?country=LK`);
    const lkPlans = await lkPlansResponse.json();
    console.log('✅ Sri Lanka Plans Response:', JSON.stringify(lkPlans, null, 2));
    console.log();

    // Test 3: Get admin analytics (will fail without auth)
    console.log('3. Testing GET /api/admin/subscription/analytics (will fail without auth)');
    try {
      const analyticsResponse = await fetch(`${baseUrl}/admin/subscription/analytics`);
      const analytics = await analyticsResponse.json();
      console.log('✅ Analytics Response:', JSON.stringify(analytics, null, 2));
    } catch (err) {
      console.log('❌ Expected failure (no auth):', err.message);
    }
    console.log();

    // Test 4: Check if admin endpoints exist
    console.log('4. Testing admin endpoints availability');
    const adminTests = [
      '/admin/subscription/plans',
      '/admin/subscription/pending-approvals',
      '/admin/subscription/users'
    ];

    for (const endpoint of adminTests) {
      try {
        const response = await fetch(`${baseUrl}${endpoint}`, {
          headers: { 'Authorization': `Bearer ${authToken}` }
        });
        console.log(`${endpoint}: ${response.status} ${response.statusText}`);
      } catch (err) {
        console.log(`${endpoint}: Connection error - ${err.message}`);
      }
    }

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

// Run tests
testSubscriptionEndpoints().then(() => {
  console.log('\n🏁 Testing completed');
}).catch(err => {
  console.error('💥 Test suite failed:', err.message);
});
