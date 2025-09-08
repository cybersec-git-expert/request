const dbService = require('./services/database');
const authService = require('./services/auth');
const { getDefaultPermissionsForRole, autoActivateCountryData } = require('./services/adminPermissions');

async function createCountryAdminComplete() {
  const args = process.argv.slice(2);
  
  if (args.length !== 5) {
    console.log('❌ Usage: node create-country-admin.js <EMAIL> <PASSWORD> <NAME> <COUNTRY_CODE> <COUNTRY_NAME>');
    console.log('📝 Example: node create-country-admin.js admin@us.request.com MyPassword123 "John Doe" US "United States"');
    process.exit(1);
  }
  
  const [email, password, name, countryCode, countryName] = args;
  
  console.log(`🚀 Creating complete country admin setup for ${countryName} (${countryCode})`);
  console.log(`👤 Admin: ${name} <${email}>`);
  console.log('=' .repeat(60));
  
  try {
    // Step 1: Check if user already exists
    console.log('🔍 Step 1: Checking for existing user...');
    const existing = await dbService.query('SELECT id FROM admin_users WHERE LOWER(email) = LOWER($1)', [email]);
    if (existing.rows.length > 0) {
      console.log('❌ User already exists with this email');
      process.exit(1);
    }
    console.log('✅ Email is available');
    
    // Step 2: Create admin user with full permissions
    console.log('👥 Step 2: Creating admin user with full permissions...');
    const passwordHash = await authService.hashPassword(password);
    const permissions = getDefaultPermissionsForRole('country_admin');
    
    const result = await dbService.query(
      `INSERT INTO admin_users (email, password_hash, name, role, country_code, permissions, is_active, created_at, updated_at) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) 
       RETURNING id, email, name, role, country_code`,
      [email, passwordHash, name, 'country_admin', countryCode, permissions, true]
    );
    
    const newUser = result.rows[0];
    console.log('✅ Admin user created successfully');
    console.log(`   📧 Email: ${newUser.email}`);
    console.log(`   👤 Name: ${newUser.name}`);
    console.log(`   🌍 Country: ${newUser.country_code}`);
    console.log(`   🔑 Permissions: ${Object.keys(permissions).length} permissions assigned`);
    
    // Step 3: Auto-activate all country data
    console.log('🎯 Step 3: Auto-activating country data...');
    await autoActivateCountryData(countryCode, countryName, newUser.id, newUser.name);
    
    // Step 4: Summary
    console.log('🎉 SETUP COMPLETE!');
    console.log('=' .repeat(60));
    console.log(`✅ Country Admin Created: ${email}`);
    console.log(`✅ Password Set: ${password}`);
    console.log(`✅ Permissions: All ${Object.keys(permissions).length} permissions assigned`);
    console.log(`✅ Country Data: Auto-activated for ${countryName}`);
    console.log('');
    console.log('🔗 Next Steps:');
    console.log('1. User can login immediately at the admin panel');
    console.log('2. All menu items will be visible');
    console.log('3. All country data is pre-activated and ready');
    console.log('4. No additional setup required!');
    
  } catch (error) {
    console.error('❌ Setup failed:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

createCountryAdminComplete();
