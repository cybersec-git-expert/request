const express = require('express');
const router = express.Router();
const auth = require('../services/auth');
const database = require('../services/database');

/**
 * Get all user emails for admin management
 * GET /api/admin/email-management/user-emails
 */
router.get('/user-emails', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { page = 1, limit = 50, search = '' } = req.query;
    const offset = (page - 1) * limit;

    let query = `
      SELECT 
        uea.id,
        uea.user_id,
        uea.email_address,
        uea.is_verified,
        uea.verified_at,
        uea.purpose,
        uea.verification_method,
        uea.created_at,
        u.first_name,
        u.last_name,
        u.display_name,
        (u.first_name || ' ' || u.last_name) as user_name
      FROM user_email_addresses uea
      LEFT JOIN users u ON uea.user_id = u.id
      WHERE 1=1
    `;

    const params = [];
    let paramCount = 0;

    // Add search filter
    if (search) {
      paramCount++;
      query += ` AND (
        uea.email_address ILIKE $${paramCount} 
        OR u.first_name ILIKE $${paramCount}
        OR u.last_name ILIKE $${paramCount}
        OR u.display_name ILIKE $${paramCount}
        OR uea.purpose ILIKE $${paramCount}
      )`;
      params.push(`%${search}%`);
    }

    query += ` ORDER BY uea.created_at DESC LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}`;
    params.push(limit, offset);

    const result = await database.query(query, params);

    // Get total count
    let countQuery = `
      SELECT COUNT(*) as total
      FROM user_email_addresses uea
      LEFT JOIN users u ON uea.user_id = u.id
      WHERE 1=1
    `;

    if (search) {
      countQuery += ` AND (
        uea.email_address ILIKE $1 
        OR u.first_name ILIKE $1
        OR u.last_name ILIKE $1
        OR u.display_name ILIKE $1
        OR uea.purpose ILIKE $1
      )`;
    }

    const countResult = await database.query(
      countQuery, 
      search ? [`%${search}%`] : []
    );

    const total = parseInt(countResult.rows[0].total);

    res.json({
      success: true,
      emails: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        totalPages: Math.ceil(total / limit),
      }
    });

  } catch (error) {
    console.error('Error fetching user emails:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch user emails',
      error: error.message
    });
  }
});

/**
 * Get email verification statistics
 * GET /api/admin/email-management/stats
 */
router.get('/stats', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const statsQuery = `
      SELECT 
        COUNT(*) as total_emails,
        COUNT(CASE WHEN is_verified = true THEN 1 END) as verified_emails,
        COUNT(CASE WHEN is_verified = false THEN 1 END) as pending_emails,
        COUNT(CASE WHEN verification_method = 'registration' THEN 1 END) as registration_verified,
        COUNT(CASE WHEN verification_method = 'otp' THEN 1 END) as otp_verified,
        COUNT(CASE WHEN purpose = 'business' THEN 1 END) as business_emails,
        COUNT(CASE WHEN purpose = 'driver' THEN 1 END) as driver_emails
      FROM user_email_addresses
    `;

    const result = await database.query(statsQuery);
    const stats = result.rows[0];

    // Get recent verifications
    const recentQuery = `
      SELECT 
        uea.email_address,
        uea.verified_at,
        uea.verification_method,
        u.display_name
      FROM user_email_addresses uea
      LEFT JOIN users u ON uea.user_id = u.id
      WHERE uea.is_verified = true 
        AND uea.verified_at >= NOW() - INTERVAL '7 days'
      ORDER BY uea.verified_at DESC
      LIMIT 10
    `;

    const recentResult = await database.query(recentQuery);

    res.json({
      success: true,
      stats: {
        ...stats,
        total_emails: parseInt(stats.total_emails),
        verified_emails: parseInt(stats.verified_emails),
        pending_emails: parseInt(stats.pending_emails),
        registration_verified: parseInt(stats.registration_verified),
        otp_verified: parseInt(stats.otp_verified),
        business_emails: parseInt(stats.business_emails),
        driver_emails: parseInt(stats.driver_emails),
      },
      recentVerifications: recentResult.rows
    });

  } catch (error) {
    console.error('Error fetching email stats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch email statistics',
      error: error.message
    });
  }
});

/**
 * Toggle email verification status
 * POST /api/admin/email-management/toggle-verification
 */
router.post('/toggle-verification', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { emailId, verified } = req.body;
    const adminUserId = req.user.userId;

    if (!emailId) {
      return res.status(400).json({
        success: false,
        message: 'Email ID is required'
      });
    }

    const updateQuery = `
      UPDATE user_email_addresses 
      SET 
        is_verified = $1,
        verified_at = CASE WHEN $1 = true THEN NOW() ELSE verified_at END,
        verification_method = CASE WHEN $1 = true AND verification_method IS NULL THEN 'admin' ELSE verification_method END,
        updated_at = NOW()
      WHERE id = $2
      RETURNING *
    `;

    const result = await database.query(updateQuery, [verified, emailId]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Email record not found'
      });
    }

    // Log the admin action
    const logQuery = `
      INSERT INTO admin_action_logs (
        admin_user_id, 
        action_type, 
        target_table, 
        target_id, 
        details, 
        created_at
      ) VALUES ($1, $2, $3, $4, $5, NOW())
    `;

    await database.query(logQuery, [
      adminUserId,
      'email_verification_toggle',
      'user_email_addresses',
      emailId,
      JSON.stringify({
        email_address: result.rows[0].email_address,
        previous_status: !verified,
        new_status: verified
      })
    ]);

    res.json({
      success: true,
      message: `Email verification ${verified ? 'enabled' : 'disabled'} successfully`,
      email: result.rows[0]
    });

  } catch (error) {
    console.error('Error toggling email verification:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update email verification status',
      error: error.message
    });
  }
});

/**
 * Manually verify email (admin action)
 * POST /api/admin/email-management/manual-verify
 */
router.post('/manual-verify', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { userId, email, purpose = 'admin_verified' } = req.body;
    const adminUserId = req.user.userId;

    if (!userId || !email) {
      return res.status(400).json({
        success: false,
        message: 'User ID and email are required'
      });
    }

    // Check if email already exists
    const existingQuery = `
      SELECT * FROM user_email_addresses 
      WHERE user_id = $1 AND email_address = $2
    `;
    const existingResult = await database.query(existingQuery, [userId, email]);

    if (existingResult.rows.length > 0) {
      // Update existing record
      const updateQuery = `
        UPDATE user_email_addresses 
        SET 
          is_verified = true,
          verified_at = NOW(),
          verification_method = 'admin',
          purpose = $3,
          updated_at = NOW()
        WHERE user_id = $1 AND email_address = $2
        RETURNING *
      `;
      
      const result = await database.query(updateQuery, [userId, email, purpose]);
      
      res.json({
        success: true,
        message: 'Email verification updated by admin',
        email: result.rows[0]
      });
    } else {
      // Create new verified email record
      const insertQuery = `
        INSERT INTO user_email_addresses (
          user_id, email_address, is_verified, verified_at, 
          purpose, verification_method, created_at, updated_at
        ) VALUES ($1, $2, true, NOW(), $3, 'admin', NOW(), NOW())
        RETURNING *
      `;
      
      const result = await database.query(insertQuery, [userId, email, purpose]);
      
      res.json({
        success: true,
        message: 'Email manually verified by admin',
        email: result.rows[0]
      });
    }

    // Log the admin action
    const logQuery = `
      INSERT INTO admin_action_logs (
        admin_user_id, 
        action_type, 
        target_table, 
        target_id, 
        details, 
        created_at
      ) VALUES ($1, $2, $3, $4, $5, NOW())
    `;

    await database.query(logQuery, [
      adminUserId,
      'manual_email_verification',
      'user_email_addresses',
      userId,
      JSON.stringify({
        email_address: email,
        purpose: purpose,
        action: 'manual_verify'
      })
    ]);

  } catch (error) {
    console.error('Error manually verifying email:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to manually verify email',
      error: error.message
    });
  }
});

/**
 * Get OTP verification history
 * GET /api/admin/email-management/otp-history
 */
router.get('/otp-history', auth.authMiddleware(), auth.roleMiddleware(['super_admin', 'country_admin']), async (req, res) => {
  try {
    const { page = 1, limit = 50, email = '' } = req.query;
    const offset = (page - 1) * limit;

    let query = `
      SELECT 
        eov.*,
        u.display_name,
        u.first_name,
        u.last_name
      FROM email_otp_verifications eov
      LEFT JOIN users u ON eov.user_id = u.id
      WHERE 1=1
    `;

    const params = [];
    let paramCount = 0;

    if (email) {
      paramCount++;
      query += ` AND eov.email ILIKE $${paramCount}`;
      params.push(`%${email}%`);
    }

    query += ` ORDER BY eov.created_at DESC LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}`;
    params.push(limit, offset);

    const result = await database.query(query, params);

    // Get total count
    let countQuery = 'SELECT COUNT(*) as total FROM email_otp_verifications WHERE 1=1';
    if (email) {
      countQuery += ' AND email ILIKE $1';
    }

    const countResult = await database.query(
      countQuery, 
      email ? [`%${email}%`] : []
    );

    const total = parseInt(countResult.rows[0].total);

    res.json({
      success: true,
      otpHistory: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        totalPages: Math.ceil(total / limit),
      }
    });

  } catch (error) {
    console.error('Error fetching OTP history:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch OTP history',
      error: error.message
    });
  }
});

module.exports = router;
