// Database service with IAM authentication support
const { Pool } = require('pg');
const AWS = require('aws-sdk');

class DatabaseService {
  constructor() {
    this.pool = null;
    this.rds = new AWS.RDS.Signer({
      region: process.env.AWS_REGION || 'us-east-1'
    });
    this.initializePool();
  }

  async generateIAMToken() {
    const token = await this.rds.getAuthToken({
      hostname: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT) || 5432,
      username: process.env.DB_USERNAME,
      region: process.env.AWS_REGION || 'us-east-1'
    });
    return token;
  }

  async initializePool() {
    try {
      let config = {
        host: process.env.DB_HOST,
        port: parseInt(process.env.DB_PORT) || 5432,
        database: process.env.DB_NAME,
        user: process.env.DB_USERNAME,
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
        max: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
        idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
        connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 60000,
      };

      if (process.env.DB_IAM_AUTH === 'true') {
        // For IAM authentication, we'll generate tokens dynamically
        config.password = await this.generateIAMToken();
        console.log('🔐 Using IAM authentication for database');
      } else {
        config.password = process.env.DB_PASSWORD;
        console.log('🔑 Using password authentication for database');
      }

      this.pool = new Pool(config);

      // Test the connection
      const client = await this.pool.connect();
      console.log('✅ Database connection established successfully');
      client.release();
    } catch (error) {
      console.error('❌ Database connection failed:', error.message);
      // Fallback to password auth if IAM fails
      if (process.env.DB_IAM_AUTH === 'true' && process.env.DB_PASSWORD) {
        console.log('🔄 Falling back to password authentication...');
        try {
          const fallbackConfig = {
            host: process.env.DB_HOST,
            port: parseInt(process.env.DB_PORT) || 5432,
            database: process.env.DB_NAME,
            user: process.env.DB_USERNAME,
            password: process.env.DB_PASSWORD,
            ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
            max: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
            idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
            connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 60000,
          };
          this.pool = new Pool(fallbackConfig);
          const client = await this.pool.connect();
          console.log('✅ Database fallback connection established');
          client.release();
        } catch (fallbackError) {
          console.error('❌ Database fallback also failed:', fallbackError.message);
        }
      }
    }
  }

  async query(text, params) {
    if (!this.pool) {
      await this.initializePool();
    }
    
    try {
      const start = Date.now();
      const res = await this.pool.query(text, params);
      const duration = Date.now() - start;
      console.log('Executed query', { text: text.substring(0, 50), duration, rows: res.rowCount });
      return res;
    } catch (error) {
      // If IAM token expired, try to refresh it
      if (error.message.includes('password authentication failed') && process.env.DB_IAM_AUTH === 'true') {
        console.log('🔄 IAM token may have expired, refreshing...');
        await this.initializePool();
        const res = await this.pool.query(text, params);
        return res;
      }
      throw error;
    }
  }

  async getClient() {
    if (!this.pool) {
      await this.initializePool();
    }
    return await this.pool.connect();
  }

  async close() {
    if (this.pool) {
      await this.pool.end();
    }
  }
}

module.exports = new DatabaseService();
