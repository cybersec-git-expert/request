/**
 * 🧪 Detailed analysis of Hutch authentication response
 */
const axios = require('axios');

async function analyzeHutchAuth() {
  try {
    console.log('🧪 Analyzing Hutch authentication response...');
    
    const username = 'rimas@alphabet.lk';
    const password = 'HT3l0b&LH6819';
    
    // Step 1: Get login page
    const loginPageResponse = await axios.get('https://webbsms.hutch.lk/login');
    const csrfMatch = loginPageResponse.data.match(/name="_token" type="hidden" value="([^"]+)"/);
    const csrfToken = csrfMatch[1];
    const cookies = loginPageResponse.headers['set-cookie'];
    const cookieHeader = cookies ? cookies.map(cookie => cookie.split(';')[0]).join('; ') : '';
    
    console.log('\n🔐 Submitting login credentials...');
    
    // Step 2: Submit login with detailed response analysis
    const loginData = new URLSearchParams({
      _token: csrfToken,
      email: username,
      password: password
    });
    
    const loginResponse = await axios.post('https://webbsms.hutch.lk/login', loginData, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': cookieHeader,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      },
      timeout: 15000,
      maxRedirects: 5, // Follow redirects
      validateStatus: () => true // Accept all status codes
    });
    
    console.log(`📊 Final status: ${loginResponse.status}`);
    console.log(`📍 Final URL: ${loginResponse.request.res.responseUrl}`);
    
    // Check if we're back at login page (authentication failed)
    if (loginResponse.request.res.responseUrl.includes('/login')) {
      console.log(`❌ Redirected back to login - checking for error messages...`);
      
      // Look for error messages in the response
      if (loginResponse.data.includes('error') || loginResponse.data.includes('invalid') || loginResponse.data.includes('incorrect')) {
        const errorMatch = loginResponse.data.match(/<div[^>]*error[^>]*>([^<]+)</i);
        if (errorMatch) {
          console.log(`🚨 Error found: ${errorMatch[1]}`);
        } else {
          console.log(`🚨 Page contains error indicators but no specific message found`);
        }
      }
      
      // Check if there are validation error fields
      if (loginResponse.data.includes('is-invalid') || loginResponse.data.includes('has-error')) {
        console.log(`🚨 Form validation errors detected`);
      }
      
      // Check for specific login failure patterns
      if (loginResponse.data.includes('These credentials do not match our records')) {
        console.log(`🚨 Invalid credentials error`);
      }
      
    } else {
      console.log(`✅ Successfully authenticated - redirected to: ${loginResponse.request.res.responseUrl}`);
      
      // Look for SMS-related functionality
      if (loginResponse.data.includes('dashboard') || loginResponse.data.includes('home')) {
        console.log(`📊 Reached dashboard/home page`);
      }
      
      if (loginResponse.data.includes('sms') || loginResponse.data.includes('message')) {
        console.log(`📱 SMS functionality found on page`);
      }
    }
    
    // Also check the current credentials by trying a wrong password
    console.log('\n🧪 Testing with wrong password to confirm credential validation...');
    
    const wrongPasswordData = new URLSearchParams({
      _token: csrfToken,
      email: username,
      password: 'wrongpassword'
    });
    
    const wrongResponse = await axios.post('https://webbsms.hutch.lk/login', wrongPasswordData, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': cookieHeader,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      },
      timeout: 10000,
      maxRedirects: 5,
      validateStatus: () => true
    });
    
    if (wrongResponse.request.res.responseUrl.includes('/login')) {
      console.log(`✅ Wrong password correctly rejected - credential validation working`);
    }
    
  } catch (error) {
    console.error('❌ Analysis failed:', error.message);
  }
}

analyzeHutchAuth();
