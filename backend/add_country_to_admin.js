require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: process.env.PGPORT,
  ssl: { rejectUnauthorized: false }
});

async function addCountryCodeToAdmin() {
  try {
    // Check if country_code column exists
    const checkColumn = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'admin_users' AND column_name = 'country_code'
    `);
    
    if (checkColumn.rows.length === 0) {
      console.log('Adding country_code column to admin_users...');
      await pool.query('ALTER TABLE admin_users ADD COLUMN country_code VARCHAR(2)');
      console.log('Column added successfully');
    } else {
      console.log('country_code column already exists');
    }
    
    // Check current admin_users structure
    const adminUsers = await pool.query('SELECT * FROM admin_users LIMIT 1');
    console.log('Admin users columns:', Object.keys(adminUsers.rows[0] || {}));
    
    pool.end();
  } catch (error) {
    console.error('Error:', error.message);
    pool.end();
  }
}

addCountryCodeToAdmin();
