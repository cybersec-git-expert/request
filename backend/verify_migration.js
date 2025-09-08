require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.PGHOST,
  port: process.env.PGPORT,
  database: process.env.PGDATABASE,
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkData() {
  try {
    console.log('=== Categories Sample ===');
    const cats = await pool.query('SELECT name, type, is_active FROM categories LIMIT 5');
    cats.rows.forEach(row => console.log(`- ${row.name} (${row.type}) - Active: ${row.is_active}`));
    
    console.log('\n=== Brands Sample ===');
    const brands = await pool.query('SELECT name, is_active FROM brands LIMIT 5');
    brands.rows.forEach(row => console.log(`- ${row.name} - Active: ${row.is_active}`));
    
    console.log('\n=== Vehicle Types Sample ===');
    const vehicles = await pool.query('SELECT name, capacity, is_active FROM vehicle_types LIMIT 5');
    vehicles.rows.forEach(row => console.log(`- ${row.name} (Capacity: ${row.capacity}) - Active: ${row.is_active}`));
    
    await pool.end();
  } catch (error) {
    console.error('Error:', error.message);
    await pool.end();
  }
}

checkData();
