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

async function addDobGenderColumns() {
  try {
    console.log('🔧 Adding date_of_birth and gender columns to users table...');
    
    // Check if columns already exist
    const checkColumns = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name IN ('date_of_birth', 'gender')
    `);
    
    const existingColumns = checkColumns.rows.map(row => row.column_name);
    
    // Add date_of_birth column if it doesn't exist
    if (!existingColumns.includes('date_of_birth')) {
      await pool.query(`
        ALTER TABLE users 
        ADD COLUMN date_of_birth DATE NULL
      `);
      console.log('✅ Added date_of_birth column');
    } else {
      console.log('ℹ️  date_of_birth column already exists');
    }
    
    // Add gender column if it doesn't exist
    if (!existingColumns.includes('gender')) {
      await pool.query(`
        ALTER TABLE users 
        ADD COLUMN gender VARCHAR(20) NULL 
        CHECK (gender IN ('Male', 'Female', 'Other', 'Prefer not to say'))
      `);
      console.log('✅ Added gender column with constraint');
    } else {
      console.log('ℹ️  gender column already exists');
    }
    
    // Show updated table structure
    const result = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default 
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name IN ('date_of_birth', 'gender')
      ORDER BY ordinal_position
    `);
    
    console.log('\n📋 New columns added:');
    result.rows.forEach(row => {
      console.log(`- ${row.column_name}: ${row.data_type} (nullable: ${row.is_nullable})`);
    });
    
    console.log('\n🎉 Migration completed successfully!');
    pool.end();
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    pool.end();
    process.exit(1);
  }
}

addDobGenderColumns();
