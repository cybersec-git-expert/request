// Unified migration runner: executes all SQL files in database/migrations in order
// Tracks applied migrations in schema_migrations table
// SECURITY: Uses the shared DB service (supports RDS IAM auth via .env.rds)

const dbService = require('./services/database');
const fs = require('fs');
const path = require('path');

const pool = dbService.pool;

async function ensureMigrationsTable() {
  await pool.query('CREATE TABLE IF NOT EXISTS schema_migrations (\n    id SERIAL PRIMARY KEY,\n    filename TEXT UNIQUE NOT NULL,\n    applied_at TIMESTAMP NOT NULL DEFAULT NOW()\n  )');
}

async function getApplied() {
  const res = await pool.query('SELECT filename FROM schema_migrations');
  return new Set(res.rows.map(r => r.filename));
}

async function applyMigration(filePath, filename) {
  const sql = fs.readFileSync(filePath, 'utf8');
  console.log(`\n▶ Applying migration: ${filename}`);
  try {
    await pool.query('BEGIN');
    await pool.query(sql);
    await pool.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [filename]);
    await pool.query('COMMIT');
    console.log(`✅ Applied: ${filename}`);
  } catch (err) {
    await pool.query('ROLLBACK');
    // Treat idempotent 'already exists' style errors as success so we can baseline
    const nonFatalPatterns = [
      'already exists',
      'duplicates an existing object'
    ];
    if (nonFatalPatterns.some(p => err.message.toLowerCase().includes(p))) {
      console.warn(`⚠️  Non-fatal (object exists) for ${filename}: ${err.message}`);
      try {
        await pool.query('INSERT INTO schema_migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING', [filename]);
        console.log(`↷ Marked as applied (baseline): ${filename}`);
        return; // continue with next migration
      } catch (e2) {
        console.error(`❌ Failed to record baseline for ${filename}: ${e2.message}`);
        throw err;
      }
    }
    console.error(`❌ Failed: ${filename} -> ${err.message}`);
    throw err; // stop further migrations
  }
}

async function listUsersColumns() {
  const res = await pool.query('SELECT column_name FROM information_schema.columns WHERE table_name=\'users\' ORDER BY ordinal_position');
  console.log('\n📋 Users table columns:', res.rows.map(r => r.column_name).join(', '));
}

async function main() {
  try {
    console.log('🔄 Starting migration process...');
    await ensureMigrationsTable();
    const applied = await getApplied();

    const migrationsDir = path.join(__dirname, 'database', 'migrations');
    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    if (files.length === 0) {
      console.log('⚠️  No migration files found.');
      return;
    }

    let appliedCount = 0;
    for (const file of files) {
      if (applied.has(file)) {
        console.log(`↷ Skipping already applied: ${file}`);
        continue;
      }
      await applyMigration(path.join(migrationsDir, file), file);
      appliedCount++;
    }

    console.log(`\n🎉 Migration run complete. New migrations applied: ${appliedCount}`);
    await listUsersColumns();
  } catch (e) {
    console.error('Migration run aborted:', e.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
