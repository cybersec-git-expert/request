const db = require('./backend/services/database');

async function findOTPTables() {
  try {
    // Find all tables with 'otp' in name
    const otpTables = await db.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name LIKE '%otp%'
    `);
    console.log('🔍 OTP-related tables:', otpTables.rows);

    // Find all tables with 'phone' in name
    const phoneTables = await db.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name LIKE '%phone%'
    `);
    console.log('📱 Phone-related tables:', phoneTables.rows);

    // List all tables to see what's available
    const allTables = await db.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);
    console.log('📋 All tables:', allTables.rows.map(r => r.table_name));

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

findOTPTables();
