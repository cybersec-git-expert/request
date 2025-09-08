const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.DB_USERNAME || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'request_db',
  password: process.env.DB_PASSWORD || 'your_password',
  port: process.env.DB_PORT || 5432,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

async function checkDatabase() {
  const client = await pool.connect();
  
  try {
    console.log('Checking countries table structure...');
    const countriesColumns = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'countries' 
      ORDER BY ordinal_position
    `);
    console.log('Countries table columns:', countriesColumns.rows);
    
    console.log('\nChecking business_types table structure...');
    const businessTypesColumns = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'business_types' 
      ORDER BY ordinal_position
    `);
    console.log('Business types table columns:', businessTypesColumns.rows);
    
    console.log('\nChecking sample countries data...');
    const countriesData = await client.query('SELECT * FROM countries LIMIT 5');
    console.log('Sample countries:', countriesData.rows);
    
    console.log('\nChecking sample business types data...');
    const businessTypesData = await client.query('SELECT * FROM business_types LIMIT 5');
    console.log('Sample business types:', businessTypesData.rows);
    
  } catch (error) {
    console.error('Error checking database:', error);
  } finally {
    client.release();
    pool.end();
  }
}

checkDatabase();
