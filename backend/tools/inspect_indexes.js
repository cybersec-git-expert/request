require('dotenv').config();
const { Client } = require('pg');
(async () => {
  const c=new Client({host:process.env.PGHOST||process.env.DB_HOST,user:process.env.PGUSER||process.env.DB_USERNAME,password:process.env.PGPASSWORD||process.env.DB_PASSWORD,database:process.env.PGDATABASE||process.env.DB_NAME,port:process.env.PGPORT||process.env.DB_PORT,ssl:(process.env.PGSSL==='true'||process.env.DB_SSL==='true')?{rejectUnauthorized:false}:undefined});
  await c.connect();
  for(const t of ['users','categories','subcategories']){
    const idx = await c.query('SELECT indexname,indexdef FROM pg_indexes WHERE schemaname=\'public\' AND tablename=$1', [t]);
    console.log('\nIndexes for', t);
    console.table(idx.rows);
  }
  await c.end();
})();
