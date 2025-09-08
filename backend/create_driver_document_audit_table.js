// Script to create driver_document_audit table
const database = require('./services/database');

async function run(){
  const sql = `CREATE TABLE IF NOT EXISTS driver_document_audit (
    id SERIAL PRIMARY KEY,
    driver_verification_id INTEGER REFERENCES driver_verifications(id) ON DELETE CASCADE,
    user_id UUID,
    document_type TEXT NOT NULL,
    action TEXT NOT NULL,
    old_url TEXT,
    new_url TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
  );`;
  await database.query(sql, []);
  console.log('driver_document_audit table ensured.');
  process.exit(0);
}
run().catch(e=>{console.error(e);process.exit(1);});
