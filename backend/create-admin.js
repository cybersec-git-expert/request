const dbService = require('./services/database');
const authService = require('./services/auth');
const { getDefaultPermissionsForRole } = require('./services/adminPermissions');

async function createCountryAdmin() {
  const args = process.argv.slice(2);
  
  if (args.length !== 4) {
    console.log('❌ Usage: node create-admin.js <EMAIL> <PASSWORD> <NAME> <COUNTRY_CODE>');
    console.log('📝 Example: node create-admin.js admin@us.request.com MyPass123 "John Doe" US');
    process.exit(1);
  }
  
  const [email, password, name, countryCode] = args;
  
  console.log(`🚀 Creating country admin for ${countryCode}`);
  console.log(`👤 ${name} <${email}>`);
  
  try {
    // Check if user exists
    const existing = await dbService.query('SELECT id FROM admin_users WHERE LOWER(email) = LOWER($1)', [email]);
    if (existing.rows.length > 0) {
      console.log('❌ User already exists');
      process.exit(1);
    }
    
    // Create user with all permissions
    const passwordHash = await authService.hashPassword(password);
    const permissions = getDefaultPermissionsForRole('country_admin');
    
    const result = await dbService.query(
      `INSERT INTO admin_users (email, password_hash, name, role, country_code, permissions, is_active) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [email, passwordHash, name, 'country_admin', countryCode, permissions, true]
    );
    
    console.log('✅ SUCCESS!');
    console.log(`📧 Email: ${email}`);
    console.log(`🔑 Password: ${password}`);
    console.log(`🌍 Country: ${countryCode}`);
    console.log(`📝 Permissions: ${Object.keys(permissions).length} assigned`);
    console.log('🎯 Ready to login with full menu access!');
    
  } catch (error) {
    console.error('❌ Failed:', error.message);
    process.exit(1);
  }
  
  process.exit(0);
}

createCountryAdmin();
