const { Pool } = require('pg');

// Using the admin credentials to apply the fix
const pool = new Pool({
  host: 'requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com',
  port: 5432,
  database: 'request',
  user: 'requestadmindb',
  password: 'RequestMarketplace2024!',
  ssl: { rejectUnauthorized: false }
});

async function fixUrgentColumn() {
  try {
    console.log('🔧 Checking and fixing is_urgent column in requests table...');
    
    // Check if is_urgent column exists
    const checkResult = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'requests' AND column_name = 'is_urgent'
    `);
    
    if (checkResult.rows.length === 0) {
      console.log('❌ is_urgent column does not exist. Adding it...');
      
      // Add the columns from the migration
      await pool.query(`
        BEGIN;
        
        -- Add urgent boost fields to requests
        ALTER TABLE requests
          ADD COLUMN is_urgent BOOLEAN NOT NULL DEFAULT false,
          ADD COLUMN urgent_until TIMESTAMPTZ,
          ADD COLUMN urgent_paid_tx_id UUID;
        
        -- Helpful index for active urgent sorting/filtering
        CREATE INDEX IF NOT EXISTS idx_requests_urgent_active ON requests ((is_urgent AND urgent_until > now()));
        
        COMMIT;
      `);
      
      console.log('✅ Successfully added is_urgent columns to requests table');
    } else {
      console.log('✅ is_urgent column already exists');
    }
    
    // Test a simple query to make sure it works
    const testResult = await pool.query('SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE is_urgent = true) as urgent_count FROM requests LIMIT 1');
    console.log('📊 Test query result:', testResult.rows[0]);
    
    // Test the exact query that was failing
    console.log('🧪 Testing the exact query from the API...');
    const apiTestQuery = `
      SELECT 
        r.id, r.title, r.is_urgent, r.urgent_until,
        u.display_name as user_name
      FROM requests r
      LEFT JOIN users u ON r.user_id = u.id
      WHERE r.status = 'active'
      ORDER BY 
        CASE WHEN r.is_urgent = true AND (r.urgent_until IS NULL OR r.urgent_until > NOW()) THEN 0 ELSE 1 END,
        r.created_at DESC
      LIMIT 5
    `;
    
    const apiTest = await pool.query(apiTestQuery);
    console.log('📊 API test query returned', apiTest.rows.length, 'rows');
    if (apiTest.rows.length > 0) {
      console.log('Sample row:', apiTest.rows[0]);
    }
    
    console.log('🎉 Fix completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error fixing urgent column:', error);
    console.error('Error details:', error.message);
    process.exit(1);
  }
}

fixUrgentColumn();
