const db = require('./services/database');

async function checkTables() {
  try {
    const result = await db.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND (table_name LIKE '%subscription%' OR table_name LIKE '%plan%' OR table_name LIKE '%pricing%')
      ORDER BY table_name
    `);
    
    console.log('All relevant tables:', result.rows.map(r => r.table_name));
    process.exit(0);
  } catch (error) {
    console.error('Query failed:', error);
    process.exit(1);
  }
}

checkTables();
