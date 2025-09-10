const fs = require('fs');
const path = require('path');

// Use the same database configuration as the backend
const dbConfig = require('./database/config');
const { Pool } = require('pg');

async function createTable() {
  console.log('🗃️  Creating usage_monthly table...');
  
  const pool = new Pool(dbConfig);
  
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
      
      // Create indexes
      await client.query(`
        CREATE INDEX IF NOT EXISTS idx_usage_monthly_user_month 
        ON usage_monthly(user_id, year_month)
      `);
      
      await client.query(`
        CREATE INDEX IF NOT EXISTS idx_usage_monthly_year_month 
        ON usage_monthly(year_month)
      `);
      
      console.log('✅ Table usage_monthly created successfully!');
      
      // Verify table exists
      const result = await client.query(`
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'usage_monthly' 
        ORDER BY ordinal_position
      `);
      
      console.log('📋 Table columns:');
      result.rows.forEach(row => {
        console.log(`  - ${row.column_name}: ${row.data_type}`);
      });
      
    } finally {
      client.release();
    }
    
  } catch (error) {
    console.error('❌ Error creating table:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

createTable().catch(console.error);
