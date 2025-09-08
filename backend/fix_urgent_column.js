const database = require('./services/database');

async function fixUrgentColumn() {
  try {
    console.log('🔧 Adding missing is_urgent columns to requests table...');
    
    // Check if is_urgent column exists
    const checkResult = await database.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'requests' AND column_name = 'is_urgent'
    `);
    
    if (checkResult.rows.length === 0) {
      console.log('is_urgent column does not exist. Adding it...');
      
      // Add the columns from the migration
      await database.query(`
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
    const testResult = await database.query('SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE is_urgent = true) as urgent_count FROM requests');
    console.log('📊 Test query result:', testResult.rows[0]);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error fixing urgent column:', error);
    process.exit(1);
  }
}

fixUrgentColumn();
