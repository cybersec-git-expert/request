const express = require('express');
const router = express.Router();
const database = require('../services/database');
const smsService = require('../services/smsService');
const auth = require('../services/auth');

console.log('🔧 Admin SMS routes loaded');

/**
 * @route GET /api/admin/sms-configurations
 * @desc Get all SMS configurations with approval status
 * @access Admin only
 */
router.get('/sms-configurations', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    console.log('📋 Fetching SMS configurations for:', req.user?.role);
    
    const { role } = req.user;
    
    // Super admin sees all configurations, country admin sees only their own
    let query = `
      SELECT 
        sc.id,
        sc.country_code,
        sc.country_name,
        sc.active_provider,
        sc.is_active,
        sc.approval_status,
        sc.approved_at,
        sc.submitted_at,
        sc.approval_notes,
        sc.twilio_config,
        sc.aws_config,
        sc.vonage_config,
        sc.local_config,
        sc.hutch_mobile_config,
        sc.total_sms_sent,
        sc.total_cost,
        sc.cost_per_sms,
        sc.created_at,
        sc.updated_at,
        approver.email as approved_by_email,
        submitter.email as submitted_by_email
      FROM sms_configurations sc
      LEFT JOIN admin_users approver ON sc.approved_by = approver.id
      LEFT JOIN admin_users submitter ON sc.submitted_by = submitter.id
    `;
    
    let params = [];
    
    if (role === 'country_admin') {
      // Country admin only sees their own country configurations
      query += ' WHERE sc.country_code = $1';
      params = [req.user.country || 'US']; // Default to US for now
    }
    
    query += ' ORDER BY sc.country_name, sc.submitted_at DESC';

    const result = await database.query(query, params);

    res.json({
      success: true,
      data: result.rows
    });

  } catch (error) {
    console.error('Error fetching SMS configurations:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch SMS configurations'
    });
  }
});

/**
 * @route POST /api/admin/sms-configurations
 * @desc Create or update SMS configuration (Country Admin submits for approval)
 * @access Country Admin or Super Admin
 */
router.post('/sms-configurations', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    console.log('💾 Creating/updating SMS configuration by:', req.user?.role);
    
    const {
      countryCode,
      activeProvider,
      twilioConfig,
      awsConfig,
      vonageConfig,
      localConfig,
      hutchMobileConfig,
      isActive
    } = req.body;

    const { id: adminId, role } = req.user;

    // Validation
    if (!countryCode || !activeProvider) {
      return res.status(400).json({
        success: false,
        message: 'Country code and active provider are required'
      });
    }

    // Check if configuration exists
    const existingConfig = await database.query(
      'SELECT id, approval_status FROM sms_configurations WHERE country_code = $1',
      [countryCode]
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
        countryCode,
        activeProvider,
        isActive,
        twilioConfig ? JSON.stringify(twilioConfig) : null,
        awsConfig ? JSON.stringify(awsConfig) : null,
        vonageConfig ? JSON.stringify(vonageConfig) : null,
        localConfig ? JSON.stringify(localConfig) : null,
        hutchMobileConfig ? JSON.stringify(hutchMobileConfig) : null,
        status,
        adminId,
        approvedBy,
        approvedAt
      ]);

      // Log approval history if table exists
      try {
        await database.query(`
          INSERT INTO sms_approval_history (
            configuration_id, action, previous_status, new_status, admin_id, notes
          ) VALUES ($1, $2, $3, $4, $5, $6)
        `, [
          existingConfig.rows[0].id,
          'updated',
          existingConfig.rows[0].approval_status,
          status,
          adminId,
          role === 'super_admin' ? 'Auto-approved by super admin' : 'Updated by country admin, pending approval'
        ]);
      } catch (historyError) {
        console.log('Note: approval history table not available');
      }
    } else {
      // Get country name from countries table
      const countryResult = await database.query(
        'SELECT name FROM countries WHERE code = $1',
        [countryCode]
      );
      
      const countryName = countryResult.rows.length > 0 ? countryResult.rows[0].name : countryCode;

      // Create new configuration
      result = await database.query(`
        INSERT INTO sms_configurations (
          country_code, country_name, active_provider, is_active,
          twilio_config, aws_config, vonage_config, local_config, hutch_mobile_config,
          approval_status, submitted_by, submitted_at, approved_by, approved_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), $12, $13)
        RETURNING *
      `, [
        countryCode,
        countryName,
        activeProvider,
        isActive,
        twilioConfig ? JSON.stringify(twilioConfig) : null,
        awsConfig ? JSON.stringify(awsConfig) : null,
        vonageConfig ? JSON.stringify(vonageConfig) : null,
        localConfig ? JSON.stringify(localConfig) : null,
        hutchMobileConfig ? JSON.stringify(hutchMobileConfig) : null,
        status,
        adminId,
        approvedBy,
        approvedAt
      ]);

      // Log approval history if table exists
      try {
        await database.query(`
          INSERT INTO sms_approval_history (
            configuration_id, action, new_status, admin_id, notes
          ) VALUES ($1, $2, $3, $4, $5)
        `, [
          result.rows[0].id,
          'created',
          status,
          adminId,
          role === 'super_admin' ? 'Created and auto-approved by super admin' : 'Created by country admin, pending approval'
        ]);
      } catch (historyError) {
        console.log('Note: approval history table not available');
      }
    }

    res.json({
      success: true,
      message: role === 'super_admin' ? 
        'SMS configuration saved and approved' : 
        'SMS configuration submitted for approval',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('Error saving SMS configuration:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save SMS configuration'
    });
  }
});

/**
 * @route PUT /api/admin/sms-configurations/:id/approve
 * @desc Approve SMS configuration (Super Admin only)
 * @access Super Admin only
 */
router.put('/sms-configurations/:id/approve', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    console.log('✅ Approving SMS configuration:', req.params.id);
    
    const { id } = req.params;
    const { notes } = req.body;
    const { id: adminId } = req.user;

    // Get current configuration
    const currentConfig = await database.query(
      'SELECT approval_status FROM sms_configurations WHERE id = $1',
      [id]
    );

    if (currentConfig.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'SMS configuration not found'
      });
    }

    // Update configuration to approved
    const result = await database.query(`
      UPDATE sms_configurations SET
        approval_status = 'approved',
        approved_by = $2,
        approved_at = NOW(),
        approval_notes = $3,
        is_active = true
      WHERE id = $1
      RETURNING *
    `, [id, adminId, notes]);

    // Log approval history if table exists
    try {
      await database.query(`
        INSERT INTO sms_approval_history (
          configuration_id, action, previous_status, new_status, admin_id, notes
        ) VALUES ($1, $2, $3, $4, $5, $6)
      `, [
        id,
        'approved',
        currentConfig.rows[0].approval_status,
        'approved',
        adminId,
        notes || 'Approved by super admin'
      ]);
    } catch (historyError) {
      console.log('Note: approval history table not available');
    }

    res.json({
      success: true,
      message: 'SMS configuration approved successfully',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('Error approving SMS configuration:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to approve SMS configuration'
    });
  }
});

/**
 * @route PUT /api/admin/sms-configurations/:id/reject
 * @desc Reject SMS configuration (Super Admin only)
 * @access Super Admin only
 */
router.put('/sms-configurations/:id/reject', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    console.log('❌ Rejecting SMS configuration:', req.params.id);
    
    const { id } = req.params;
    const { notes } = req.body;
    const { id: adminId } = req.user;

    if (!notes) {
      return res.status(400).json({
        success: false,
        message: 'Rejection notes are required'
      });
    }

    // Get current configuration
    const currentConfig = await database.query(
      'SELECT approval_status FROM sms_configurations WHERE id = $1',
      [id]
    );

    if (currentConfig.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'SMS configuration not found'
      });
    }

    // Update configuration to rejected
    const result = await database.query(`
      UPDATE sms_configurations SET
        approval_status = 'rejected',
        approved_by = $2,
        approved_at = NOW(),
        approval_notes = $3,
        is_active = false
      WHERE id = $1
      RETURNING *
    `, [id, adminId, notes]);

    // Log approval history if table exists
    try {
      await database.query(`
        INSERT INTO sms_approval_history (
          configuration_id, action, previous_status, new_status, admin_id, notes
        ) VALUES ($1, $2, $3, $4, $5, $6)
      `, [
        id,
        'rejected',
        currentConfig.rows[0].approval_status,
        'rejected',
        adminId,
        notes
      ]);
    } catch (historyError) {
      console.log('Note: approval history table not available');
    }

    res.json({
      success: true,
      message: 'SMS configuration rejected',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('Error rejecting SMS configuration:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to reject SMS configuration'
    });
  }
});

/**
 * @route GET /api/admin/sms-configurations/pending
 * @desc Get pending SMS configurations for approval (Super Admin only)
 * @access Super Admin only
 */
router.get('/sms-configurations/pending', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    console.log('📋 Fetching pending SMS configurations');
    
    const result = await database.query(`
      SELECT 
        sc.id,
        sc.country_code,
        sc.country_name,
        sc.active_provider,
        sc.submitted_at,
        sc.twilio_config,
        sc.aws_config,
        sc.vonage_config,
        sc.local_config,
        sc.hutch_mobile_config,
        submitter.email as submitted_by_email
      FROM sms_configurations sc
      LEFT JOIN admin_users submitter ON sc.submitted_by = submitter.id
      WHERE sc.approval_status = 'pending'
      ORDER BY sc.submitted_at ASC
    `);

    res.json({
      success: true,
      data: result.rows
    });

  } catch (error) {
    console.error('Error fetching pending SMS configurations:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch pending configurations'
    });
  }
});

/**
 * @route POST /api/admin/test-sms-provider
 * @desc Test SMS provider configuration
 * @access Admin only
 */
router.post('/test-sms-provider', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { countryCode, provider, testNumber } = req.body;

    if (!countryCode || !provider || !testNumber) {
      return res.status(400).json({
        success: false,
        message: 'Country code, provider, and test number are required'
      });
    }

    // Test the SMS provider
    const testResult = await smsService.testProvider(countryCode, provider, testNumber);

    res.json({
      success: true,
      message: 'SMS test completed',
      data: testResult
    });

  } catch (error) {
    console.error('Error testing SMS provider:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to test SMS provider',
      error: error.message
    });
  }
});

module.exports = router;
