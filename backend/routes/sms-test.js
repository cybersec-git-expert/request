console.log('🔧 Creating temporary test route without authentication...\n');

// This is a temporary solution to test SMS configuration without admin login
const express = require('express');
const router = express.Router();
const database = require('./services/database');

/**
 * TEMPORARY: SMS config test route without authentication
 * @route GET /api/sms-test/config/:countryCode
 */
router.get('/config/:countryCode', async (req, res) => {
  try {
    const { countryCode } = req.params;
    const countryCodeUpper = countryCode.toUpperCase();
    
    console.log('📋 Testing SMS config fetch for:', countryCodeUpper);
    
    // Try sms_provider_configs table first (what admin-react expects)
    const providerConfigs = await database.query(`
      SELECT * FROM sms_provider_configs 
      WHERE country_code = $1 
      ORDER BY is_active DESC, updated_at DESC
    `, [countryCodeUpper]);
    
    if (providerConfigs.rows.length > 0) {
      console.log('✅ Found configs in sms_provider_configs:', providerConfigs.rows.length);
      return res.json({
        success: true,
        data: providerConfigs.rows,
        source: 'sms_provider_configs'
      });
    }
    
    // Fallback to sms_configurations table
    const legacyConfigs = await database.query(`
      SELECT country_code, active_provider as provider, 
             CASE 
               WHEN active_provider = 'hutch_mobile' THEN hutch_mobile_config
               WHEN active_provider = 'twilio' THEN twilio_config
               ELSE '{}'::jsonb
             END as config,
             is_active, updated_at
      FROM sms_configurations 
      WHERE country_code = $1
    `, [countryCodeUpper]);
    
    console.log('✅ Found configs in sms_configurations:', legacyConfigs.rows.length);
    
    res.json({
      success: true,
      data: legacyConfigs.rows,
      source: 'sms_configurations'
    });

  } catch (error) {
    console.error('❌ Error fetching SMS config:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch SMS configuration',
      error: error.message
    });
  }
});

/**
 * TEMPORARY: SMS statistics test route without authentication
 */
router.get('/statistics/:countryCode', async (req, res) => {
  try {
    const { countryCode } = req.params;
    
    // Return mock statistics for now
    res.json({
      success: true,
      data: {
        totalSent: 0,
        successRate: 0,
        costSavings: 0,
        lastMonth: 0
      },
      message: 'Mock statistics - authentication required for real data'
    });

  } catch (error) {
    console.error('❌ Error fetching SMS statistics:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch SMS statistics',
      error: error.message
    });
  }
});

module.exports = router;

console.log('📁 Temporary SMS test routes created');
console.log('🚀 To use: Add this to app.js with app.use(\'/api/sms-test\', smsTestRoutes)');
console.log('⚠️  Remove this after fixing authentication!');
