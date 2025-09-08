const { autoActivateCountryData } = require('./services/adminPermissions');

async function runAutoActivation() {
  const args = process.argv.slice(2);
  
  if (args.length !== 4) {
    console.log('Usage: node auto_activate_country_data_postgres.js <COUNTRY_CODE> <COUNTRY_NAME> <ADMIN_USER_ID> <ADMIN_NAME>');
    console.log('Example: node auto_activate_country_data_postgres.js LK "Sri Lanka" admin_user_id "Admin Name"');
    process.exit(1);
  }
  
  const [countryCode, countryName, adminUserId, adminName] = args;
  
  try {
    await autoActivateCountryData(countryCode, countryName, adminUserId, adminName);
    console.log('\n✅ Auto-activation completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Auto-activation failed:', error);
    process.exit(1);
  }
}

runAutoActivation();
