const fs = require('fs');
const path = require('path');
const db = require('./services/database');

async function run() {
  try {
    const sqlPath = path.join(__dirname, 'database', 'migrations', 'add_country_business_capabilities.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await db.query(sql);
    console.log('✅ Added capability columns to country_business_types');
    process.exit(0);
  } catch (e) {
    console.error('❌ Migration failed:', e.message);
    process.exit(1);
  }
}

run();
