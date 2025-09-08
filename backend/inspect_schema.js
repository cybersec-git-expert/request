const { Pool } = require('pg');
const pool = new Pool({
  host: 'requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com',
  port: 5432,
  database: 'request',
  user: 'requestadmindb',
  password: 'RequestMarketplace2024!',
  ssl: { rejectUnauthorized: false }
});
(async () => {
  try {
    const tables = await pool.query('SELECT table_name FROM information_schema.tables WHERE table_schema=\'public\' ORDER BY 1');
    console.log('Tables:', tables.rows.map(r=>r.table_name));
    for (const t of ['users','requests']) {
      const cols = await pool.query('SELECT column_name, data_type FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position', [t]);
      console.log(`\n${t} columns:`, cols.rows);
    }
    const pkInfo = await pool.query('SELECT tc.table_name, kcu.column_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name=kcu.constraint_name AND tc.table_name=kcu.table_name WHERE tc.constraint_type=\'PRIMARY KEY\' AND tc.table_name IN (\'users\',\'requests\');');
    console.log('\nPrimary Keys:', pkInfo.rows);
  } catch(e){
    console.error('Schema inspect error', e);
  } finally { await pool.end(); }
})();
