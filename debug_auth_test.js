const jwt = require('jsonwebtoken');

// Test JWT token decoding and validation
const testToken = 'test_jwt_token_here'; // User would need to provide actual token

function decodeJwt(token) {
  try {
    const decoded = jwt.decode(token, { complete: true });
    console.log('JWT Header:', decoded.header);
    console.log('JWT Payload:', decoded.payload);
    console.log('Token expires at:', new Date(decoded.payload.exp * 1000));
    console.log('Current time:', new Date());
    console.log('Token is expired:', Date.now() >= decoded.payload.exp * 1000);
    return decoded;
  } catch (e) {
    console.error('Error decoding JWT:', e.message);
    return null;
  }
}

console.log('Authentication Debug Test');
console.log('========================');

if (testToken !== 'test_jwt_token_here') {
  decodeJwt(testToken);
} else {
  console.log('Please provide an actual JWT token to test');
}
