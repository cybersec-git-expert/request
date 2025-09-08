require('dotenv').config();
const { Client } = require('pg');
(async () => {
  const c = new Client({
    host: process.env.PGHOST || process.env.DB_HOST,
    user: process.env.PGUSER || process.env.DB_USERNAME,
    password: process.env.PGPASSWORD || process.env.DB_PASSWORD,
    database: process.env.PGDATABASE || process.env.DB_NAME,
    port: process.env.PGPORT || process.env.DB_PORT,
    ssl: (process.env.PGSSL==='true'||process.env.DB_SSL==='true')?{rejectUnauthorized:false}:undefined
  });
  await c.connect();
  const tables = ['variable_types','subscription_plans','cities','vehicle_types'];
  for(const t of tables){
    const reg = await c.query('SELECT to_regclass(\'public.'+t+'\') as r');
    console.log('\nTable', t, 'exists:', !!reg.rows[0].r);
    if(!reg.rows[0].r) continue;
    const cols = await c.query('SELECT column_name,data_type FROM information_schema.columns WHERE table_schema=\'public\' AND table_name=$1 ORDER BY ordinal_position', [t]);
    console.table(cols.rows);
  }
  await c.end();
})();
