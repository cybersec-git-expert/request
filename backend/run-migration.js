// Generic single migration runner
// Usage: node run-migration.js <migration_filename_or_stem>
// Example: node run-migration.js add_countries_table

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  host: 'requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com',
  port: 5432,
  database: 'request',
  user: 'requestadmindb',
  password: 'RequestMarketplace2024!',
  ssl: { rejectUnauthorized: false }
});

async function main() {
  const arg = process.argv[2];
  if (!arg) {
    console.error('❌ Missing migration name.');
    console.log('Usage: node run-migration.js <migration_filename_or_stem>');
    process.exit(1);
  }

  const migrationsDir = path.join(__dirname, 'database', 'migrations');
  if (!fs.existsSync(migrationsDir)) {
    console.error('❌ Migrations directory not found:', migrationsDir);
    process.exit(1);
  }

  // Allow passing either full filename or stem without .sql
  const targetFile = arg.endsWith('.sql') ? arg : `${arg}.sql`;
  const fullPath = path.join(migrationsDir, targetFile);

  if (!fs.existsSync(fullPath)) {
    // Try fuzzy match (first file that starts with arg)
    const match = fs.readdirSync(migrationsDir).find(f => f.startsWith(arg) && f.endsWith('.sql'));
    if (match) {
      console.log(`ℹ️  Using fuzzy matched migration: ${match}`);
      return runSingle(path.join(migrationsDir, match), match);
    }
    console.error('❌ Migration file not found:', targetFile);
    process.exit(1);
  }
  await runSingle(fullPath, targetFile);
}

async function runSingle(filePath, filename) {
  const sql = fs.readFileSync(filePath, 'utf8');
  console.log(`� Running migration: ${filename}`);
  try {
    await pool.query('BEGIN');
    await pool.query(sql);
    await pool.query('COMMIT');
    console.log(`✅ Migration applied: ${filename}`);
  } catch (err) {
    await pool.query('ROLLBACK');
    const msg = err.message.toLowerCase();
    if (msg.includes('already exists') || msg.includes('duplicate object') || msg.includes('already defined')) {
      console.warn(`⚠️  Objects already exist (idempotent): ${err.message}`);
    } else {
      console.error(`❌ Migration failed: ${err.message}`);
      process.exit(1);
    }
  } finally {
    await pool.end();
  }
}

main().catch(e => { console.error('Fatal migration error:', e); process.exit(1); });
