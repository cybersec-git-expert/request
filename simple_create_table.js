const { Pool } = require('pg');

// Use environment variables like the backend does
const pool = new Pool();

async function createTable() {
  console.log('🗃️  Creating usage_monthly table...');
  
  try {
    const client = await pool.connect();
    
    try {
      // Create the table
      await client.query(`
        CREATE TABLE IF NOT EXISTS usage_monthly (
          id SERIAL PRIMARY KEY,
          user_id UUID NOT NULL,
          year_month VARCHAR(6) NOT NULL,
          response_count INTEGER NOT NULL DEFAULT 0,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          UNIQUE(user_id, year_month)
        )
      `);
      
      console.log('✅ Table usage_monthly created!');
      
      // Create indexes
      await client.query(`
        CREATE INDEX IF NOT EXISTS idx_usage_monthly_user_month 
        ON usage_monthly(user_id, year_month)
      `);
      
      await client.query(`
        CREATE INDEX IF NOT EXISTS idx_usage_monthly_year_month 
        ON usage_monthly(year_month)
      `);
      
      console.log('✅ Indexes created!');
      
      // Test insert/select
      const testUserId = '00000000-0000-0000-0000-000000000001';
      const testYearMonth = '202509';
      
      await client.query(`
        INSERT INTO usage_monthly (user_id, year_month, response_count)
        VALUES ($1, $2, 1)
        ON CONFLICT (user_id, year_month)
        DO UPDATE SET response_count = usage_monthly.response_count + 1
      `, [testUserId, testYearMonth]);
      
      const result = await client.query(
        'SELECT * FROM usage_monthly WHERE user_id = $1 AND year_month = $2',
        [testUserId, testYearMonth]
      );
      
      console.log('✅ Test record:', result.rows[0]);
      
      // Clean up test
      await client.query('DELETE FROM usage_monthly WHERE user_id = $1', [testUserId]);
      console.log('✅ Test cleanup complete');
      
    } finally {
      client.release();
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

createTable().catch(console.error);
