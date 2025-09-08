require('dotenv').config();
const { Client } = require('pg');
(async () => {
  const tables = [
    'master_products','business_products','requests','content_pages','promo_codes',
    'promo_code_redemptions','conversations','conversation_messages',
    'phone_otp_verifications','email_otp_verifications'
  ];
  const c = new Client({
    host: process.env.PGHOST || process.env.DB_HOST,
    user: process.env.PGUSER || process.env.DB_USERNAME,
    password: process.env.PGPASSWORD || process.env.DB_PASSWORD,
    database: process.env.PGDATABASE || process.env.DB_NAME,
    port: process.env.PGPORT || process.env.DB_PORT,
    ssl: (process.env.PGSSL==='true'||process.env.DB_SSL==='true')? {rejectUnauthorized:false}: undefined
  });
  await c.connect();
  for(const t of tables){
    try {
      const cols = await c.query('SELECT column_name,data_type FROM information_schema.columns WHERE table_schema=\'public\' AND table_name=$1 ORDER BY ordinal_position', [t]);
      if(cols.rowCount===0){ console.log(`\nTable ${t} (not found)`); continue; }
      console.log(`\nTable ${t}`); console.table(cols.rows);
    } catch(e){ console.log(`Error reading table ${t}:`, e.message); }
  }
  await c.end();
})();
