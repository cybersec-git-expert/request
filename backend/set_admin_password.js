require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: process.env.PGPORT,
  ssl: { rejectUnauthorized: false }
});

async function setAdminPassword() {
  try {
    // Hash the password
    const password = 'admin123';
    const saltRounds = 12;
    const hashedPassword = await bcrypt.hash(password, saltRounds);
    
    console.log('Setting password hash for superadmin@request.lk...');
    console.log('Hashed password:', hashedPassword);
    
    // Update admin user with password hash
    const result = await pool.query(
      'UPDATE admin_users SET password_hash = $1 WHERE email = $2 RETURNING email, password_hash',
      [hashedPassword, 'superadmin@request.lk']
    );
    
    console.log('Updated admin user:', result.rows[0]);
    console.log('Password successfully set!');
    
    pool.end();
  } catch (error) {
    console.error('Error:', error.message);
    pool.end();
  }
}

setAdminPassword();
