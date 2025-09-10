const { Pool } = require('pg');
const pool = new Pool();

async function createTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS usage_monthly (
        user_id UUID,
        year_month VARCHAR(6),
        response_count INTEGER DEFAULT 0,
        updated_at TIMESTAMP DEFAULT now(),
        PRIMARY KEY (user_id, year_month)
      )
    `);
    console.log('usage_monthly table created successfully');
    process.exit(0);
  } catch (error) {
    console.error('Error creating table:', error.message);
    process.exit(1);
  }
}

createTable();
