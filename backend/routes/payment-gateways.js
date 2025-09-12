const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Migration endpoint for setting up payment gateway tables
router.post('/migrate', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    // Read the migration file
    const migrationPath = path.join(__dirname, '../database/migrations/create_payment_gateways.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    
    // Execute the migration
    await db.query(migrationSQL);
    
    // Insert default payment gateways
    const defaultGateways = `
      INSERT INTO payment_gateways (name, code, description, supported_countries, configuration_fields) VALUES
      ('Stripe', 'stripe', 'Global payment processing platform', ARRAY['US', 'CA', 'GB', 'AU', 'SG', 'IN', 'LK'], 
       '{"api_key": {"type": "text", "label": "Publishable Key", "required": true}, 
         "secret_key": {"type": "password", "label": "Secret Key", "required": true},
         "webhook_secret": {"type": "password", "label": "Webhook Secret", "required": false}}'),
      
      ('PayPal', 'paypal', 'Global digital payments platform', ARRAY['US', 'CA', 'GB', 'AU', 'IN', 'LK'],
       '{"client_id": {"type": "text", "label": "Client ID", "required": true},
         "client_secret": {"type": "password", "label": "Client Secret", "required": true},
         "environment": {"type": "select", "label": "Environment", "options": ["sandbox", "live"], "required": true}}'),
      
      ('PayHere', 'payhere', 'Sri Lankan payment gateway', ARRAY['LK'],
       '{"merchant_id": {"type": "text", "label": "Merchant ID", "required": true},
         "merchant_secret": {"type": "password", "label": "Merchant Secret", "required": true},
         "environment": {"type": "select", "label": "Environment", "options": ["sandbox", "live"], "required": true}}')
      
      ON CONFLICT (code) DO NOTHING;
    `;
    
    await db.query(defaultGateways);
    
    res.json({
      success: true,
      message: 'Payment gateway tables and default gateways created successfully'
    });
  } catch (error) {
    console.error('Migration error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to run migration',
      details: error.message
    });
  }
});

// Encryption key for sensitive data (should be in environment variables)
const ENCRYPTION_KEY = process.env.GATEWAY_ENCRYPTION_KEY || 'default-key-change-in-production';

// Simple encryption/decryption functions
function encrypt(text) {
  if (!text) return null;
  const cipher = crypto.createCipher('aes-256-cbc', ENCRYPTION_KEY);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return encrypted;
}

function decrypt(text) {
  if (!text) return null;
  try {
    const decipher = crypto.createDecipher('aes-256-cbc', ENCRYPTION_KEY);
    let decrypted = decipher.update(text, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (error) {
    console.error('Decryption error:', error);
    return null;
  }
}

// Get available payment gateways for a country
router.get('/gateways/:countryCode', auth.authMiddleware(), async (req, res) => {
  try {
    const { countryCode } = req.params;
    
    const result = await db.query(`
      SELECT 
        pg.id,
        pg.name,
        pg.code,
        pg.description,
        pg.configuration_fields,
        cpg.id as country_gateway_id,
        cpg.is_active as configured,
        cpg.is_primary,
        cpg.created_at as configured_at
      FROM payment_gateways pg
      LEFT JOIN country_payment_gateways cpg ON pg.id = cpg.payment_gateway_id 
        AND cpg.country_code = $1
      WHERE pg.is_active = true 
        AND (pg.supported_countries IS NULL OR $1 = ANY(pg.supported_countries))
      ORDER BY cpg.is_primary DESC NULLS LAST, pg.name
    `, [countryCode]);

    res.json({
      success: true,
      gateways: result.rows
    });
  } catch (error) {
    console.error('Error fetching payment gateways:', error);
    
    // Check if it's a missing table error
    if (error.message && error.message.includes('relation') && error.message.includes('does not exist')) {
      res.json({
        success: true,
        gateways: [],
        warning: 'Payment gateway tables not initialized. Please run database migrations.'
      });
    } else {
      res.status(500).json({
        success: false,
        error: 'Failed to fetch payment gateways',
        details: error.message
      });
    }
  }
});

// Configure payment gateway for country (Country Admin only)
router.post('/gateways/:countryCode/configure', 
  auth.authMiddleware(), 
  auth.roleMiddleware(['super_admin', 'country_admin']), 
  async (req, res) => {
    try {
      const { countryCode } = req.params;
      const { gatewayId, configuration, isPrimary } = req.body;
      const userId = req.user.id;

      // Verify user has permission for this country
      if (req.user.role === 'country_admin' && req.user.country_code !== countryCode) {
        return res.status(403).json({
          success: false,
          error: 'You can only configure payment gateways for your assigned country'
        });
      }

      // Encrypt sensitive configuration data
      const encryptedConfig = {};
      for (const [key, value] of Object.entries(configuration)) {
        if (key.includes('secret') || key.includes('key') || key.includes('password')) {
          encryptedConfig[key] = encrypt(value);
        } else {
          encryptedConfig[key] = value;
        }
      }

      // If setting as primary, remove primary flag from other gateways
      if (isPrimary) {
        await db.query(`
          UPDATE country_payment_gateways 
          SET is_primary = false 
          WHERE country_code = $1
        `, [countryCode]);
      }

      // Insert or update configuration
      const result = await db.query(`
        INSERT INTO country_payment_gateways 
        (country_code, payment_gateway_id, configuration, is_active, is_primary, created_by)
        VALUES ($1, $2, $3, true, $4, $5)
        ON CONFLICT (country_code, payment_gateway_id)
        DO UPDATE SET 
          configuration = $3,
          is_active = true,
          is_primary = $4,
          updated_at = CURRENT_TIMESTAMP
        RETURNING *
      `, [countryCode, gatewayId, JSON.stringify(encryptedConfig), isPrimary || false, userId]);

      res.json({
        success: true,
        message: 'Payment gateway configured successfully',
        gateway: result.rows[0]
      });
    } catch (error) {
      console.error('Error configuring payment gateway:', error);
      
      // Check if it's a missing table error
      if (error.message && error.message.includes('relation') && error.message.includes('does not exist')) {
        res.status(500).json({
          success: false,
          error: 'Payment gateway tables not initialized. Please run database migrations.',
          details: 'Missing payment gateway database tables'
        });
      } else {
        res.status(500).json({
          success: false,
          error: 'Failed to configure payment gateway',
          details: error.message
        });
      }
    }
  }
);

// Get gateway configuration (for editing)
router.get('/gateways/:countryCode/:gatewayId/config', 
  auth.authMiddleware(), 
  auth.roleMiddleware(['super_admin', 'country_admin']), 
  async (req, res) => {
    try {
      const { countryCode, gatewayId } = req.params;

      // Verify permissions
      if (req.user.role === 'country_admin' && req.user.country_code !== countryCode) {
        return res.status(403).json({
          success: false,
          error: 'Access denied'
        });
      }

      const result = await db.query(`
        SELECT 
          cpg.*,
          pg.name,
          pg.code,
          pg.configuration_fields
        FROM country_payment_gateways cpg
        JOIN payment_gateways pg ON cpg.payment_gateway_id = pg.id
        WHERE cpg.country_code = $1 AND cpg.payment_gateway_id = $2
      `, [countryCode, gatewayId]);

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Gateway configuration not found'
        });
      }

      const gateway = result.rows[0];
      
      // Decrypt configuration for editing (but mask sensitive values)
      const decryptedConfig = {};
      // Handle configuration - it might already be parsed as object by PostgreSQL driver
      const config = typeof gateway.configuration === 'string' 
        ? JSON.parse(gateway.configuration) 
        : gateway.configuration;
      
      for (const [key, value] of Object.entries(config)) {
        if (key.includes('secret') || key.includes('key') || key.includes('password')) {
          // Don't send back sensitive values, just indicate they exist
          decryptedConfig[key] = value ? '••••••••' : '';
        } else {
          decryptedConfig[key] = value;
        }
      }

      res.json({
        success: true,
        gateway: {
          ...gateway,
          configuration: decryptedConfig
        }
      });
    } catch (error) {
      console.error('Error fetching gateway configuration:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to fetch gateway configuration'
      });
    }
  }
);

// Toggle gateway active status
router.patch('/gateways/:countryCode/:gatewayId/toggle', 
  auth.authMiddleware(), 
  auth.roleMiddleware(['super_admin', 'country_admin']), 
  async (req, res) => {
    try {
      const { countryCode, gatewayId } = req.params;
      const { isActive } = req.body;

      // Verify permissions
      if (req.user.role === 'country_admin' && req.user.country_code !== countryCode) {
        return res.status(403).json({
          success: false,
          error: 'Access denied'
        });
      }

      await db.query(`
        UPDATE country_payment_gateways 
        SET is_active = $1, updated_at = CURRENT_TIMESTAMP
        WHERE country_code = $2 AND payment_gateway_id = $3
      `, [isActive, countryCode, gatewayId]);

      res.json({
        success: true,
        message: `Payment gateway ${isActive ? 'activated' : 'deactivated'} successfully`
      });
    } catch (error) {
      console.error('Error toggling gateway status:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to update gateway status'
      });
    }
  }
);

// Get gateway for payment processing (internal use)
router.get('/gateways/:countryCode/primary', async (req, res) => {
  try {
    const { countryCode } = req.params;

    const result = await db.query(`
      SELECT 
        cpg.*,
        pg.name,
        pg.code
      FROM country_payment_gateways cpg
      JOIN payment_gateways pg ON cpg.payment_gateway_id = pg.id
      WHERE cpg.country_code = $1 
        AND cpg.is_active = true 
        AND cpg.is_primary = true
    `, [countryCode]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'No primary payment gateway configured for this country'
      });
    }

    const gateway = result.rows[0];
    
    // Decrypt configuration for payment processing
    const decryptedConfig = {};
    const config = JSON.parse(gateway.configuration);
    
    for (const [key, value] of Object.entries(config)) {
      if (key.includes('secret') || key.includes('key') || key.includes('password')) {
        decryptedConfig[key] = decrypt(value);
      } else {
        decryptedConfig[key] = value;
      }
    }

    res.json({
      success: true,
      gateway: {
        ...gateway,
        configuration: decryptedConfig
      }
    });
  } catch (error) {
    console.error('Error fetching primary gateway:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch payment gateway'
    });
  }
});

// Configure gateway fees
router.post('/gateways/:countryCode/:gatewayId/fees', 
  auth.authMiddleware(), 
  auth.roleMiddleware(['super_admin', 'country_admin']), 
  async (req, res) => {
    try {
      const { countryCode, gatewayId } = req.params;
      const { fees } = req.body; // Array of fee configurations

      // Verify permissions
      if (req.user.role === 'country_admin' && req.user.country_code !== countryCode) {
        return res.status(403).json({
          success: false,
          error: 'Access denied'
        });
      }

      // Get country gateway ID
      const gatewayResult = await db.query(`
        SELECT id FROM country_payment_gateways 
        WHERE country_code = $1 AND payment_gateway_id = $2
      `, [countryCode, gatewayId]);

      if (gatewayResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Gateway configuration not found'
        });
      }

      const countryGatewayId = gatewayResult.rows[0].id;

      // Delete existing fees
      await db.query(`
        DELETE FROM payment_gateway_fees 
        WHERE country_payment_gateway_id = $1
      `, [countryGatewayId]);

      // Insert new fees
      for (const fee of fees) {
        await db.query(`
          INSERT INTO payment_gateway_fees 
          (country_payment_gateway_id, transaction_type, fee_type, percentage_fee, fixed_fee, currency, minimum_amount, maximum_amount)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `, [
          countryGatewayId,
          fee.transactionType,
          fee.feeType,
          fee.percentageFee || 0,
          fee.fixedFee || 0,
          fee.currency,
          fee.minimumAmount || 0,
          fee.maximumAmount
        ]);
      }

      res.json({
        success: true,
        message: 'Gateway fees configured successfully'
      });
    } catch (error) {
      console.error('Error configuring gateway fees:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to configure gateway fees'
      });
    }
  }
);

module.exports = router;
