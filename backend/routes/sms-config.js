const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');

console.log('🔧 SMS Config routes loaded');

/**
 * @route PUT /api/sms/config/:countryCode/:provider
 * @desc Save SMS provider configuration for a specific country
 * @access Admin only
 */
router.put('/config/:countryCode/:provider', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    console.log('💾 Saving SMS configuration:', req.params);
    
    const { countryCode, provider } = req.params;
    const { config, is_active = true, exclusive = true } = req.body;
    const { id: adminId, role } = req.user;

    // Validate inputs
    if (!countryCode || !provider) {
      return res.status(400).json({
        success: false,
        message: 'Country code and provider are required'
      });
    }

    if (!config) {
      return res.status(400).json({
        success: false,
        message: 'Configuration is required'
      });
    }

    // Validate provider
    const validProviders = ['twilio', 'aws_sns', 'vonage', 'local', 'hutch_mobile'];
    if (!validProviders.includes(provider)) {
      return res.status(400).json({
        success: false,
        message: `Unsupported provider. Valid providers: ${validProviders.join(', ')}`
      });
    }

    const countryCodeUpper = countryCode.toUpperCase();
    
    // Get country name
    const countryResult = await database.query(
      'SELECT name FROM countries WHERE code = $1',
      [countryCodeUpper]
    );
    
    const countryName = countryResult.rows.length > 0 ? countryResult.rows[0].name : countryCodeUpper;

    // Check if configuration exists
    const existingConfig = await database.query(
      'SELECT id, approval_status FROM sms_configurations WHERE country_code = $1',
      [countryCodeUpper]
    );

    let result;
    let status = 'pending'; // Default status for country admin submissions
    let approvedBy = null;
    let approvedAt = null;

    // Super admin can directly approve configurations
    if (role === 'super_admin') {
      status = 'approved';
      approvedBy = adminId;
      approvedAt = new Date();
    }

    // Prepare configuration columns based on provider
    const configColumns = {
      twilio_config: provider === 'twilio' ? JSON.stringify(config) : null,
      aws_config: provider === 'aws_sns' ? JSON.stringify(config) : null,
      vonage_config: provider === 'vonage' ? JSON.stringify(config) : null,
      local_config: provider === 'local' ? JSON.stringify(config) : null,
      hutch_mobile_config: provider === 'hutch_mobile' ? JSON.stringify(config) : null
    };

    if (existingConfig.rows.length > 0) {
      // Update existing configuration
      result = await database.query(`
        UPDATE sms_configurations SET
          active_provider = $2,
          is_active = $3,
          twilio_config = $4,
          aws_config = $5,
          vonage_config = $6,
          local_config = $7,
          hutch_mobile_config = $8,
          approval_status = $9,
          submitted_by = $10,
          submitted_at = NOW(),
          approved_by = $11,
          approved_at = $12,
          updated_at = NOW()
        WHERE country_code = $1
        RETURNING *
      `, [
        countryCodeUpper,
        provider,
        is_active,
        configColumns.twilio_config,
        configColumns.aws_config,
        configColumns.vonage_config,
        configColumns.local_config,
        configColumns.hutch_mobile_config,
        status,
        adminId,
        approvedBy,
        approvedAt
      ]);

      console.log('✅ Updated existing SMS configuration for', countryCodeUpper);
    } else {
      // Create new configuration
      result = await database.query(`
        INSERT INTO sms_configurations (
          country_code, country_name, active_provider, is_active,
          twilio_config, aws_config, vonage_config, local_config, hutch_mobile_config,
          approval_status, submitted_by, submitted_at, approved_by, approved_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), $12, $13)
        RETURNING *
      `, [
        countryCodeUpper,
        countryName,
        provider,
        is_active,
        configColumns.twilio_config,
        configColumns.aws_config,
        configColumns.vonage_config,
        configColumns.local_config,
        configColumns.hutch_mobile_config,
        status,
        adminId,
        approvedBy,
        approvedAt
      ]);

      console.log('✅ Created new SMS configuration for', countryCodeUpper);
    }

    // If exclusive mode and active, deactivate other configurations for this country
    if (exclusive && is_active) {
      await database.query(`
        UPDATE sms_configurations 
        SET is_active = false, updated_at = NOW() 
        WHERE country_code = $1 AND active_provider != $2
      `, [countryCodeUpper, provider]);
      
      console.log('📴 Deactivated other providers for', countryCodeUpper);
    }

    res.json({
      success: true,
      message: role === 'super_admin' ? 
        'SMS configuration saved and approved' : 
        'SMS configuration submitted for approval',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('❌ Error saving SMS configuration:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save SMS configuration',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * @route GET /api/sms/config/:countryCode
 * @desc Get SMS configurations for a specific country
 * @access Admin only
 */
router.get('/config/:countryCode', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { countryCode } = req.params;
    const countryCodeUpper = countryCode.toUpperCase();
    
    console.log('📋 Fetching SMS configuration for:', countryCodeUpper);
    
    const result = await database.query(`
      SELECT 
        id, country_code, country_name, active_provider, is_active,
        approval_status, approved_at, submitted_at,
        twilio_config, aws_config, vonage_config, local_config, hutch_mobile_config,
        total_sms_sent, total_cost, cost_per_sms,
        created_at, updated_at
      FROM sms_configurations 
      WHERE country_code = $1
      ORDER BY updated_at DESC
    `, [countryCodeUpper]);

    res.json({
      success: true,
      data: result.rows
    });

  } catch (error) {
    console.error('❌ Error fetching SMS configuration:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch SMS configuration',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

module.exports = router;
