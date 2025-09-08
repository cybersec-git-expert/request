const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const dotenv = require('dotenv');

// Load env like services/database.js
const envCandidates = [
  path.join(process.cwd(), '.env.rds'),
  path.join(__dirname, '.env.rds'),
  path.join(__dirname, '..', '.env.rds'),
];
for (const p of envCandidates) { if (fs.existsSync(p)) { dotenv.config({ path: p }); break; } }

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USERNAME || process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

async function run() {
  const client = await pool.connect();
  try {
    const sqlPath = path.join(__dirname, 'database', 'migrations', 'create_country_business_types.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    await client.query('BEGIN');
    await client.query(sql);
    await client.query('COMMIT');
    console.log('✅ country_business_types created/verified successfully');
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

if (require.main === module) run();
