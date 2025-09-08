/**
 * 🧪 Test Hutch web-based authentication flow
 */
const axios = require('axios');

async function testHutchWebAuth() {
  try {
    console.log('🧪 Testing Hutch web-based authentication...');
    
    const username = 'rimas@alphabet.lk';
    const password = 'HT3l0b&LH6819';
    
    console.log('\n📄 Step 1: Get login page to extract CSRF token...');
    
    // Step 1: Get the login page to extract CSRF token
    const loginPageResponse = await axios.get('https://webbsms.hutch.lk/login', {
      timeout: 10000
    });
    
    console.log(`✅ Login page loaded: ${loginPageResponse.status}`);
    
    // Extract CSRF token from the HTML
    const csrfMatch = loginPageResponse.data.match(/name="_token" type="hidden" value="([^"]+)"/);
    if (!csrfMatch) {
      throw new Error('Could not find CSRF token in login page');
    }
    
    const csrfToken = csrfMatch[1];
    console.log(`🔑 CSRF Token: ${csrfToken.substring(0, 20)}...`);
    
    // Extract cookies for session
    const cookies = loginPageResponse.headers['set-cookie'];
    const cookieHeader = cookies ? cookies.map(cookie => cookie.split(';')[0]).join('; ') : '';
    console.log(`🍪 Session cookies: ${cookieHeader.substring(0, 50)}...`);
    
    console.log('\n🔐 Step 2: Submit login form...');
    
    // Step 2: Submit the login form
    const loginData = new URLSearchParams({
      _token: csrfToken,
      email: username,
      password: password,
      remember: '' // Empty value for unchecked checkbox
    });
    
    const loginResponse = await axios.post('https://webbsms.hutch.lk/login', loginData, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': cookieHeader,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      },
      timeout: 15000,
      maxRedirects: 0, // Don't follow redirects automatically
      validateStatus: status => status < 400 // Accept redirects as success
    });
    
    console.log(`📊 Login response status: ${loginResponse.status}`);
    console.log(`📍 Location header: ${loginResponse.headers.location || 'None'}`);
    
    if (loginResponse.status === 302 && loginResponse.headers.location) {
      console.log(`✅ Login successful - redirected to: ${loginResponse.headers.location}`);
      
      // Get new cookies after login
      const newCookies = loginResponse.headers['set-cookie'];
      const authCookieHeader = newCookies ? newCookies.map(cookie => cookie.split(';')[0]).join('; ') : cookieHeader;
      console.log(`🍪 Auth cookies: ${authCookieHeader.substring(0, 50)}...`);
      
      console.log('\n📱 Step 3: Access SMS sending functionality...');
      
      // Step 3: Try to access the dashboard or SMS sending page
      const dashboardResponse = await axios.get(loginResponse.headers.location, {
        headers: {
          'Cookie': authCookieHeader,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 10000
      });
      
      console.log(`📊 Dashboard response: ${dashboardResponse.status}`);
      
      if (dashboardResponse.data.includes('SMS') || dashboardResponse.data.includes('send')) {
        console.log(`✅ Successfully accessed authenticated area`);
        
        // Look for SMS sending endpoints or forms
        if (dashboardResponse.data.includes('action=')) {
          const actionMatch = dashboardResponse.data.match(/action="([^"]*sms[^"]*)"/i);
          if (actionMatch) {
            console.log(`📱 Found SMS form action: ${actionMatch[1]}`);
          }
        }
      }
      
    } else {
      console.log(`❌ Login failed`);
      if (typeof loginResponse.data === 'string' && loginResponse.data.includes('error')) {
        console.log(`📄 Error page returned`);
      }
    }
    
  } catch (error) {
    console.error('\n❌ Web auth test failed:');
    console.error('Error:', error.message);
    if (error.response) {
      console.error('Status:', error.response.status);
      if (error.response.data && typeof error.response.data === 'string' && error.response.data.includes('error')) {
        console.error('Page contains error message');
      }
    }
  }
}

testHutchWebAuth();
