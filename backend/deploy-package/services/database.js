const { Pool } = require('pg');
const { RDSAuthTokenGenerator } = require('@aws-sdk/rds-signer');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');

// Attempt to load .env files from several candidate locations
const envCandidates = [
  path.join(process.cwd(), '.env.rds'),
  path.join(__dirname, '..', '.env.rds'),
  path.join(__dirname, '..', '..', '.env.rds'),
];
let loadedEnvPath = null;
for (const p of envCandidates) {
  if (fs.existsSync(p)) {
    dotenv.config({ path: p });
    loadedEnvPath = p;
    break;
  }
}
if (!loadedEnvPath) {
  console.warn('[ENV] .env.rds not found in candidates:', envCandidates);
} else {
  console.log(`[ENV] Loaded environment from: ${loadedEnvPath}`);
}

const REQUIRED_VARS = ['DB_HOST','DB_PORT','DB_NAME','DB_USERNAME'];
const missing = REQUIRED_VARS.filter(v => !process.env[v]);
if (missing.length) {
  console.warn('[ENV] Missing required DB vars:', missing.join(', '));
}

class DatabaseService {
  constructor() {
    const useIam = String(process.env.DB_IAM_AUTH || '').toLowerCase() === 'true';
    const host = process.env.DB_HOST;
    const port = Number(process.env.DB_PORT);
    const database = process.env.DB_NAME;
    const user = process.env.DB_USERNAME;
    const region = process.env.AWS_REGION || 'us-east-1';
    const ssl = process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false;

    const getPassword = async () => {
      if (!useIam) return process.env.DB_PASSWORD;
      const signer = new RDSAuthTokenGenerator({ region });
      return await signer.getAuthToken({ hostname: host, port, username: user });
    };

    this.pool = new Pool({
      host,
      port,
      database,
      user,
      password: getPassword,
      ssl,
      max: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
      idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
      connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 60000,
    });

    this.pool.on('error', (err) => {
      console.error('Unexpected error on idle client', err);
      process.exit(-1);
    });
  }

  /**
     * Execute a query with parameters
     */
  async query(text, params = []) {
    const start = Date.now();
    const client = await this.pool.connect();
        
    try {
      const result = await client.query(text, params);
      const duration = Date.now() - start;
            
      console.log('Executed query', { 
        text: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
        duration,
        rows: result.rowCount 
      });
            
      return result;
    } catch (error) {
      console.error('Database query error:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
     * Execute a query and return only the first row
     */
  async queryOne(text, params = []) {
    const result = await this.query(text, params);
    return result.rows[0] || null;
  }

  /**
     * Begin a database transaction
     */
  async beginTransaction() {
    const client = await this.pool.connect();
    await client.query('BEGIN');
    return client;
  }

  /**
     * Commit a database transaction
     */
  async commitTransaction() {
    // Note: This is a simplified implementation
    // In practice, you'd want to pass the client around
    await this.query('COMMIT');
  }

  /**
     * Rollback a database transaction
     */
  async rollbackTransaction() {
    // Note: This is a simplified implementation
    // In practice, you'd want to pass the client around
    await this.query('ROLLBACK');
  }

  /**
     * Execute a transaction
     */
  async transaction(callback) {
    const client = await this.pool.connect();
        
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Transaction error:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
     * Get a single row by ID
     */
  async findById(table, id, columns = '*') {
    const query = `SELECT ${columns} FROM ${table} WHERE id = $1::uuid`;
    const result = await this.query(query, [id]);
    return result.rows[0] || null;
  }

  /**
     * Get a single row by Firebase ID
     */
  async findByFirebaseId(table, firebaseId, columns = '*') {
    const query = `SELECT ${columns} FROM ${table} WHERE firebase_id = $1`;
    const result = await this.query(query, [firebaseId]);
    return result.rows[0] || null;
  }

  /**
     * Get multiple rows with filtering
     */
  async findMany(table, conditions = {}, options = {}) {
    let query = `SELECT * FROM ${table}`;
    const params = [];
    const whereClauses = [];

    // Build WHERE conditions
    Object.entries(conditions).forEach(([key, value], index) => {
      whereClauses.push(`${key} = $${index + 1}`);
      params.push(value);
    });

    if (whereClauses.length > 0) {
      query += ` WHERE ${whereClauses.join(' AND ')}`;
    }

    // Add ordering
    if (options.orderBy) {
      query += ` ORDER BY ${options.orderBy}`;
      if (options.orderDirection) {
        query += ` ${options.orderDirection}`;
      }
    }

    // Add pagination
    if (options.limit) {
      query += ` LIMIT ${options.limit}`;
    }
    if (options.offset) {
      query += ` OFFSET ${options.offset}`;
    }

    const result = await this.query(query, params);
    return result.rows;
  }

  /**
     * Insert a new record
     */
  async insert(table, data) {
    const columns = Object.keys(data);
    const values = Object.values(data);
    const placeholders = values.map((_, index) => `$${index + 1}`);

    const query = `
            INSERT INTO ${table} (${columns.join(', ')})
            VALUES (${placeholders.join(', ')})
            RETURNING *
        `;

    const result = await this.query(query, values);
    return result.rows[0];
  }

  /**
     * Update a record by ID
     */
  async update(table, id, data) {
    const columns = Object.keys(data);
    const values = Object.values(data);
    const setClauses = columns.map((col, index) => `${col} = $${index + 2}`);

    const query = `
            UPDATE ${table}
            SET ${setClauses.join(', ')}, updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `;

    const result = await this.query(query, [id, ...values]);
    return result.rows[0];
  }

  /**
     * Delete a record by ID
     */
  async delete(table, id) {
    const query = `DELETE FROM ${table} WHERE id = $1 RETURNING *`;
    const result = await this.query(query, [id]);
    return result.rows[0];
  }

  /**
     * Count records with conditions
     */
  async count(table, conditions = {}) {
    let query = `SELECT COUNT(*) as count FROM ${table}`;
    const params = [];
    const whereClauses = [];

    Object.entries(conditions).forEach(([key, value], index) => {
      whereClauses.push(`${key} = $${index + 1}`);
      params.push(value);
    });

    if (whereClauses.length > 0) {
      query += ` WHERE ${whereClauses.join(' AND ')}`;
    }

    const result = await this.query(query, params);
    return parseInt(result.rows[0].count);
  }

  /**
     * Check database connection
     */
  async healthCheck() {
    try {
      const result = await this.query('SELECT NOW()');
      return {
        status: 'healthy',
        timestamp: result.rows[0].now,
        connectionCount: this.pool.totalCount,
        idleCount: this.pool.idleCount,
        waitingCount: this.pool.waitingCount
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
      };
    }
  }

  /**
     * Diagnose connectivity issues
     */
  async diagnoseConnectivity() {
    const summary = {
      loadedEnvPath,
      env: REQUIRED_VARS.reduce((acc, k) => { acc[k] = process.env[k] ? 'SET' : 'MISSING'; return acc; }, {}),
      ssl: process.env.DB_SSL,
      testQuery: null,
      error: null
    };
    try {
      const r = await this.query('SELECT 1 as ok');
      summary.testQuery = r.rows[0];
    } catch (e) {
      summary.error = e.message;
    }
    return summary;
  }

  /**
     * Close all connections
     */
  async close() {
    await this.pool.end();
    console.log('Database connections closed');
  }
}

// Create singleton instance
const dbService = new DatabaseService();

module.exports = dbService;
