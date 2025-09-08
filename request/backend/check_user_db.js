const { Pool } = require('pg');

// Database configuration
const pool = new Pool({
  user: 'postgres',
  host: 'database-2.cdtdm9kf6n6w.us-east-1.rds.amazonaws.com',
  database: 'postgres',
  password: '1qaz2wsx3edc',
  port: 5432,
  ssl: {
    rejectUnauthorized: false
  }
});

async function checkUser() {
  try {
    console.log('🔍 Checking database for users...');
    
    // Check all users
    const allUsersResult = await pool.query('SELECT id, email, phone, first_name, last_name, is_active, created_at FROM users ORDER BY created_at DESC');
    console.log('\n📊 All users in database:');
    console.log(allUsersResult.rows);
    
    // Check for specific user
    const email = 'rimaz.m.flyil@gmail.com';
    console.log(`\n🔍 Checking for user: ${email}`);
    
    const userResult = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR phone = $1',
      [email]
    );
    
    if (userResult.rows.length > 0) {
      console.log('✅ User found:');
      console.log(userResult.rows[0]);
    } else {
      console.log('❌ User not found');
    }
    
    // Test the exact query from the backend
    console.log('\n🧪 Testing backend query logic:');
    const backendQuery = await pool.query(
      'SELECT id, email, phone, first_name, last_name FROM users WHERE (email = $1 OR phone = $1) AND is_active = true',
      [email.toLowerCase().trim()]
    );
    
    console.log('Backend query result:');
    console.log(backendQuery.rows);
    
  } catch (error) {
    console.error('❌ Database error:', error);
  } finally {
    await pool.end();
  }
}

checkUser();
