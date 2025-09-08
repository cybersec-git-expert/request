const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');
const { getSignedUrl } = require('../services/s3Upload');
const { checkUnifiedPhoneVerification, checkUnifiedEmailVerification } = require('../utils/unifiedVerification');

console.log('🏢 Simple business verification routes loaded');

// Phone number normalization function (unified with driver verification)
function normalizePhoneNumber(phone) {
  if (!phone) return null;
  // Remove all non-digit characters except +
  const normalized = phone.replace(/[^\d+]/g, '');
  // If starts with +94, keep as is
  if (normalized.startsWith('+94')) {
    return normalized;
  }
  // If starts with 94, add +
  if (normalized.startsWith('94') && normalized.length === 11) {
    return '+' + normalized;
  }
  // If starts with 0, replace with +94
  if (normalized.startsWith('0') && normalized.length === 10) {
    return '+94' + normalized.substring(1);
  }
  // If 9 digits, assume it's without leading 0, add +94
  if (normalized.length === 9) {
    return '+94' + normalized;
  }
  return normalized;
}// Helper function to check and update phone verification status (unified with driver verification)
async function checkPhoneVerificationStatus(userId, phoneNumber) {
  return await checkUnifiedPhoneVerification(userId, phoneNumber);
}

async function checkEmailVerificationStatus(userId, email) {
  return await checkUnifiedEmailVerification(userId, email);
}

console.log('🏢 Simple business verification routes loaded');

// Test endpoint
router.get('/test', (req, res) => {
  res.json({
    success: true,
    message: 'Simple business verification routes are working!',
    timestamp: new Date().toISOString()
  });
});

// Create business verification
router.post('/', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated'
      });
    }

    const {
      business_name,
      business_email,
      business_phone,
      business_address,
      business_type_id, // NEW: Reference to business_types table
      business_type, // Legacy string (ignored for writes)
      business_category, // Accept business_category from Flutter (deprecated)
      categories, // Array of category IDs for notifications
      registration_number,
      tax_number,
      country_id,
      country_code, // Accept country code as alternative
      city_id,
      description,
      business_description, // Accept both field names
      business_license_url,
      tax_certificate_url,
      insurance_document_url,
      business_logo_url
    } = req.body;

    // Use unified verification system (same as driver verification)
    const phoneVerification = await checkPhoneVerificationStatus(userId, business_phone);
    const emailVerification = await checkEmailVerificationStatus(userId, business_email);
    
    console.log(`📞 Phone verification for user ${userId}:`, phoneVerification);
    console.log(`📧 Email verification for user ${userId}:`, emailVerification);

    // Handle country - accept either country_id or country_code
    let finalCountryValue = country_code; // Use country code as text
    if (!finalCountryValue && country_id) {
      // If country_id provided, look up the code
      const countryQuery = 'SELECT code FROM countries WHERE id = $1';
      const countryResult = await database.query(countryQuery, [country_id]);
      if (countryResult.rows.length > 0) {
        finalCountryValue = countryResult.rows[0].code;
      }
    } else if (country_code) {
      // Verify the country code exists
      const countryQuery = 'SELECT code FROM countries WHERE code = $1';
      const countryResult = await database.query(countryQuery, [country_code]);
      if (countryResult.rows.length > 0) {
        finalCountryValue = country_code;
      }
    }

    // Validate required fields
    if (!business_name || !business_email || !business_phone || !finalCountryValue) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: business_name, business_email, business_phone, and country_code'
      });
    }

    // Resolve a non-null business_category for backward compatibility (DB has NOT NULL)
    let resolvedBusinessCategory = business_category;
    if (!resolvedBusinessCategory) {
      try {
        if (business_type_id) {
          const bt = await database.query('SELECT name FROM business_types WHERE id = $1', [business_type_id]);
          if (bt.rows.length > 0) {
            resolvedBusinessCategory = bt.rows[0].name || null;
          }
        }
      } catch (e) {
        console.warn('⚠️ Could not resolve business_category from business_type_id:', e.message);
      }
      // Additional back-compat fallbacks
      if (!resolvedBusinessCategory && (description || business_description)) {
        resolvedBusinessCategory = (business_description || description) || null;
      }
      if (!resolvedBusinessCategory && business_type) {
        resolvedBusinessCategory = business_type;
      }
      if (!resolvedBusinessCategory) {
        resolvedBusinessCategory = 'general';
      }
    }
    console.log('🧭 Resolved business_category:', resolvedBusinessCategory, 'from type_id:', business_type_id);

    // Check if user already has a business verification
    const existingQuery = 'SELECT id FROM business_verifications WHERE user_id = $1';
    const existingResult = await database.query(existingQuery, [userId]);

    if (existingResult.rows.length > 0) {
      // Get existing record to check for document changes
      const currentQuery = 'SELECT * FROM business_verifications WHERE user_id = $1';
      const currentResult = await database.query(currentQuery, [userId]);
      const currentData = currentResult.rows[0];

      // Check which documents are being updated and build status reset fields
      const statusUpdates = [];
      const statusValues = [];
      // We have 17 fixed params before WHERE (ending with email_verified=$17),
      // userId is $18, so dynamic status params should start at $19
      let paramCounter = 18; // Starting after the main update parameters

      // Check if business license is being updated
      if (business_license_url && business_license_url !== currentData.business_license_url) {
        statusUpdates.push(`business_license_status = $${++paramCounter}`);
        statusValues.push('pending');
        console.log('🔄 Resetting business license status to pending due to document change');
      }

      // Check if tax certificate is being updated
      if (tax_certificate_url && tax_certificate_url !== currentData.tax_certificate_url) {
        statusUpdates.push(`tax_certificate_status = $${++paramCounter}`);
        statusValues.push('pending');
        console.log('🔄 Resetting tax certificate status to pending due to document change');
      }

      // Check if insurance document is being updated
      if (insurance_document_url && insurance_document_url !== currentData.insurance_document_url) {
        statusUpdates.push(`insurance_document_status = $${++paramCounter}`);
        statusValues.push('pending');
        console.log('🔄 Resetting insurance document status to pending due to document change');
      }

      // Check if business logo is being updated
      if (business_logo_url && business_logo_url !== currentData.business_logo_url) {
        statusUpdates.push(`business_logo_status = $${++paramCounter}`);
        statusValues.push('pending');
        console.log('🔄 Resetting business logo status to pending due to document change');
      }

      // Build the update query with dynamic status resets
      const statusUpdateClause = statusUpdates.length > 0 ? `, ${statusUpdates.join(', ')}` : '';
      
      const updateQuery = `
        UPDATE business_verifications 
        SET business_name = $1, business_email = $2, business_phone = $3, 
            business_address = $4, business_type_id = $5, business_category = $6, 
            categories = $7, license_number = $8, 
            tax_id = $9, country = $10, business_description = $11,
            business_license_url = $12, tax_certificate_url = $13,
            insurance_document_url = $14, business_logo_url = $15,
            phone_verified = $16, email_verified = $17,
            updated_at = CURRENT_TIMESTAMP${statusUpdateClause}
        WHERE user_id = $18
        RETURNING *
      `;
      
      const updateValues = [
        business_name, business_email, business_phone, business_address,
        business_type_id, resolvedBusinessCategory,
        categories ? JSON.stringify(categories) : JSON.stringify([]),
        registration_number, tax_number, finalCountryValue, 
        business_description || description, business_license_url, tax_certificate_url,
        insurance_document_url, business_logo_url, phoneVerification.phoneVerified, emailVerification.emailVerified, userId,
        ...statusValues
      ];

      const result = await database.query(updateQuery, updateValues);

      return res.json({
        success: true,
        message: 'Business verification updated successfully',
        data: result.rows[0],
        verification: {
          phone: phoneVerification,
          email: emailVerification
        }
      });
    } else {
      // Create new record
      const insertQuery = `
        INSERT INTO business_verifications 
        (user_id, business_name, business_email, business_phone, business_address, 
         business_type_id, business_category, categories, license_number, tax_id, country, 
         business_description, business_license_url, tax_certificate_url,
         insurance_document_url, business_logo_url, phone_verified, email_verified, 
         status, submitted_at, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, 'pending', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        RETURNING *
      `;
      
      const result = await database.query(insertQuery, [
        userId, business_name, business_email, business_phone, business_address,
        business_type_id, resolvedBusinessCategory,
        categories ? JSON.stringify(categories) : JSON.stringify([]),
        registration_number, tax_number, finalCountryValue, 
        business_description || description, business_license_url, tax_certificate_url,
        insurance_document_url, business_logo_url, phoneVerification.phoneVerified, emailVerification.emailVerified
      ]);

      return res.json({
        success: true,
        message: 'Business verification submitted successfully',
        data: result.rows[0],
        verification: {
          phone: phoneVerification,
          email: emailVerification
        }
      });
    }

  } catch (error) {
    console.error('Error creating/updating business verification:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Get business verification by user ID
router.get('/user/:userId', auth.authMiddleware(), async (req, res) => {
  try {
    const { userId } = req.params;
    
    const query = `
      SELECT bv.*, 
             c.name as country_name,
             bt.name AS business_type_name
      FROM business_verifications bv
      LEFT JOIN countries c ON bv.country = c.code
      LEFT JOIN business_types bt ON bt.id = bv.business_type_id
      WHERE bv.user_id = $1
    `;
    
    const result = await database.query(query, [userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'No business verification found for this user'
      });
    }

    // Transform data to match admin panel expectations (camelCase)
    const row = result.rows[0];
    
    // Check phone and email verification status using unified system
    const phoneStatus = await checkPhoneVerificationStatus(userId, row.business_phone);
    const emailStatus = await checkEmailVerificationStatus(userId, row.business_email);
    
    console.log('📱 Business phone verification result:', phoneStatus);
    console.log('📧 Business email verification result:', emailStatus);
    
    const transformedData = {
      ...row,
      // Add camelCase aliases for admin panel
      businessName: row.business_name,
      businessEmail: row.business_email,
      businessPhone: row.business_phone,
      businessAddress: row.business_address,
      businessTypeId: row.business_type_id,
      businessTypeName: row.business_type_name || null,
      businessType: row.business_type || row.business_type_name || null, // Backward-compatible alias
      businessCategory: row.business_category, // Keep for backward compatibility
      categories: row.categories, // New field - array of category IDs
      businessDescription: row.business_description,
      licenseNumber: row.license_number,
      taxId: row.tax_id,
      countryName: row.country_name,
      businessLogoUrl: row.business_logo_url,
      businessLicenseUrl: row.business_license_url,
      insuranceDocumentUrl: row.insurance_document_url,
      taxCertificateUrl: row.tax_certificate_url,
      businessLogoStatus: row.business_logo_status,
      businessLicenseStatus: row.business_license_status,
      insuranceDocumentStatus: row.insurance_document_status,
      taxCertificateStatus: row.tax_certificate_status,
      businessLogoRejectionReason: row.business_logo_rejection_reason,
      businessLicenseRejectionReason: row.business_license_rejection_reason,
      insuranceDocumentRejectionReason: row.insurance_document_rejection_reason,
      taxCertificateRejectionReason: row.tax_certificate_rejection_reason,
      documentVerification: row.document_verification,
      isVerified: row.is_verified,
      reviewedBy: row.reviewed_by,
      reviewedDate: row.reviewed_date,
      submittedAt: row.submitted_at,
      approvedAt: row.approved_at,
      lastUpdated: row.last_updated,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      // Add unified verification status (overrides database values)
      phoneVerified: phoneStatus.phoneVerified,
      phoneVerificationSource: phoneStatus.verificationSource,
      requiresPhoneVerification: phoneStatus.requiresManualVerification,
      emailVerified: emailStatus.emailVerified,
      emailVerificationSource: emailStatus.verificationSource,
      requiresEmailVerification: emailStatus.requiresManualVerification
    };

    res.json({
      success: true,
      data: transformedData
    });

  } catch (error) {
    console.error('Error fetching business verification:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Get all business verifications (for admin panel)
router.get('/', auth.authMiddleware(), async (req, res) => {
  try {
    const { country, status, limit = 50, offset = 0 } = req.query;
    
    let query = `
      SELECT bv.*, 
             c.name as country_name,
             u.first_name, u.last_name, u.email as user_email,
             bt.name AS business_type_name
      FROM business_verifications bv
      LEFT JOIN countries c ON bv.country = c.code
      LEFT JOIN users u ON bv.user_id = u.id
      LEFT JOIN business_types bt ON bt.id = bv.business_type_id
      WHERE 1=1
    `;
    
    const params = [];
    let paramCount = 0;
    
    // Add filters
    if (country) {
      paramCount++;
      query += ` AND bv.country = $${paramCount}`;
      params.push(country);
    }
    
    if (status && status !== 'all') {
      paramCount++;
      query += ` AND bv.status = $${paramCount}`;
      params.push(status);
    }
    
    // Add ordering and pagination
    query += ' ORDER BY bv.created_at DESC';
    
    if (limit) {
      paramCount++;
      query += ` LIMIT $${paramCount}`;
      params.push(parseInt(limit));
    }
    
    if (offset) {
      paramCount++;
      query += ` OFFSET $${paramCount}`;
      params.push(parseInt(offset));
    }
    
    const result = await database.query(query, params);

    // Transform data and apply unified verification to each business
    const transformedData = await Promise.all(result.rows.map(async (row) => {
      // Check unified verification status for each business
      const phoneStatus = await checkPhoneVerificationStatus(row.user_id, row.business_phone);
      const emailStatus = await checkEmailVerificationStatus(row.user_id, row.business_email);
      
      return {
        ...row,
        // Add camelCase aliases for admin panel
        businessName: row.business_name,
        businessEmail: row.business_email,
        businessPhone: row.business_phone,
        businessAddress: row.business_address,
        businessTypeId: row.business_type_id,
        businessTypeName: row.business_type_name || null,
        businessType: row.business_type || row.business_type_name || null,
        businessCategory: row.business_category,
        businessDescription: row.business_description,
        licenseNumber: row.license_number,
        taxId: row.tax_id,
        countryName: row.country_name,
        businessLogoUrl: row.business_logo_url,
        businessLicenseUrl: row.business_license_url,
        insuranceDocumentUrl: row.insurance_document_url,
        taxCertificateUrl: row.tax_certificate_url,
        businessLogoStatus: row.business_logo_status,
        businessLicenseStatus: row.business_license_status,
        insuranceDocumentStatus: row.insurance_document_status,
        taxCertificateStatus: row.tax_certificate_status,
        businessLogoRejectionReason: row.business_logo_rejection_reason,
        businessLicenseRejectionReason: row.business_license_rejection_reason,
        insuranceDocumentRejectionReason: row.insurance_document_rejection_reason,
        taxCertificateRejectionReason: row.tax_certificate_rejection_reason,
        documentVerification: row.document_verification,
        isVerified: row.is_verified,
        // Use unified verification status (overrides database values)
        phoneVerified: phoneStatus.phoneVerified,
        phoneVerificationSource: phoneStatus.verificationSource,
        requiresPhoneVerification: phoneStatus.requiresManualVerification,
        emailVerified: emailStatus.emailVerified,
        emailVerificationSource: emailStatus.verificationSource,
        requiresEmailVerification: emailStatus.requiresManualVerification,
        reviewedBy: row.reviewed_by,
        reviewedDate: row.reviewed_date,
        submittedAt: row.submitted_at,
        approvedAt: row.approved_at,
        lastUpdated: row.last_updated,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        userEmail: row.user_email,
        firstName: row.first_name,
        lastName: row.last_name
      };
    }));

    res.json({
      success: true,
      data: transformedData,
      count: transformedData.length
    });

  } catch (error) {
    console.error('Error fetching business verifications:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Update business verification status (for admin panel)
// Update business verification status (authenticated endpoint)
router.put('/:id/status', auth.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    const { status, notes, phone_verified, email_verified } = req.body;
    const reviewedBy = req.user?.id; // Get admin user ID
    
    console.log(`🔄 AUTHENTICATED: Updating business verification ${id} status to: ${status}`);
    console.log('👤 Admin user:', {
      id: req.user?.id,
      email: req.user?.email,
      role: req.user?.role
    });
    console.log('📥 Request body:', req.body);
    
    // Prepare update query based on status
    let updateQuery, queryParams;
    
    if (status === 'approved') {
      updateQuery = `
        UPDATE business_verifications 
        SET status = $1, notes = $2, phone_verified = $3, email_verified = $4, 
            reviewed_by = $5, reviewed_date = CURRENT_TIMESTAMP, 
            approved_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP,
            is_verified = true
        WHERE id = $6
        RETURNING *
      `;
      queryParams = [status, notes, phone_verified, email_verified, reviewedBy, id];
    } else {
      updateQuery = `
        UPDATE business_verifications 
        SET status = $1, notes = $2, phone_verified = $3, email_verified = $4, 
            reviewed_by = $5, reviewed_date = CURRENT_TIMESTAMP, 
            updated_at = CURRENT_TIMESTAMP,
            is_verified = false
        WHERE id = $6
        RETURNING *
      `;
      queryParams = [status, notes, phone_verified, email_verified, reviewedBy, id];
    }
    
    console.log('📝 SQL Query:', updateQuery);
    console.log('📊 Query params:', queryParams);
    
    const result = await database.query(updateQuery, queryParams);

    if (result.rows.length === 0) {
      console.log(`❌ No business verification found with ID: ${id}`);
      return res.status(404).json({
        success: false,
        message: 'Business verification not found'
      });
    }

    console.log(`✅ Business verification ${id} updated successfully to status: ${status}`);
    console.log('📋 Updated record:', result.rows[0]);

    // Transform data for response
    const row = result.rows[0];
    const transformedData = {
      ...row,
      businessName: row.business_name,
      businessEmail: row.business_email,
      businessPhone: row.business_phone,
      businessAddress: row.business_address,
      businessCategory: row.business_category,
      businessDescription: row.business_description,
      licenseNumber: row.license_number,
      taxId: row.tax_id,
      countryName: row.country_name,
      businessLogoUrl: row.business_logo_url,
      businessLicenseUrl: row.business_license_url,
      insuranceDocumentUrl: row.insurance_document_url,
      taxCertificateUrl: row.tax_certificate_url,
      businessLogoStatus: row.business_logo_status,
      businessLicenseStatus: row.business_license_status,
      insuranceDocumentStatus: row.insurance_document_status,
      taxCertificateStatus: row.tax_certificate_status,
      isVerified: row.is_verified,
      phoneVerified: row.phone_verified,
      emailVerified: row.email_verified,
      reviewedBy: row.reviewed_by,
      reviewedDate: row.reviewed_date,
      submittedAt: row.submitted_at,
      approvedAt: row.approved_at,
      lastUpdated: row.last_updated,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };

    res.json({
      success: true,
      message: 'Business verification status updated successfully',
      data: transformedData
    });

  } catch (error) {
    console.error('Error updating business verification status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Update individual document status (approve/reject a single document)
router.put('/:id/documents/:docType', auth.authMiddleware(), async (req, res) => {
  try {
    const { id, docType } = req.params;
    const { status, rejectionReason } = req.body;
    const reviewedBy = req.user?.id;

    console.log(`🗂 Updating document status: business_verification_id=${id} docType=${docType} -> ${status}`);
    console.log('📥 Body:', req.body);

    const validDocs = {
      businessLogo: {
        statusColumn: 'business_logo_status',
        reasonColumn: 'business_logo_rejection_reason'
      },
      businessLicense: {
        statusColumn: 'business_license_status',
        reasonColumn: 'business_license_rejection_reason'
      },
      insuranceDocument: {
        statusColumn: 'insurance_document_status',
        reasonColumn: 'insurance_document_rejection_reason'
      },
      taxCertificate: {
        statusColumn: 'tax_certificate_status',
        reasonColumn: 'tax_certificate_rejection_reason'
      }
    };

    if (!validDocs[docType]) {
      return res.status(400).json({ success: false, message: 'Invalid document type' });
    }

    if (!['approved', 'rejected', 'pending'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status value' });
    }

    const { statusColumn, reasonColumn } = validDocs[docType];

    const updateQuery = `
      UPDATE business_verifications
      SET ${statusColumn} = $1::varchar,
          ${reasonColumn} = CASE WHEN $1::varchar = 'rejected' THEN $2::text ELSE NULL END,
          reviewed_by = $3::uuid,
          reviewed_date = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $4::int
      RETURNING *
    `;

    const params = [status, rejectionReason || null, reviewedBy, id];
    console.log('📝 Doc SQL:', updateQuery);
    console.log('📊 Doc params:', params);

    const result = await database.query(updateQuery, params);
    console.log('📥 Raw update result row count:', result.rowCount);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Business verification not found' });
    }

    const row = result.rows[0];
    console.log('✅ Updated document row fragment:', {
      id: row.id,
      [statusColumn]: row[statusColumn],
      [reasonColumn]: row[reasonColumn],
      status: row.status
    });
    // Compute is_verified again only if all docs approved & status approved & contact verified
    const allDocsApproved = ['business_logo_status','business_license_status','insurance_document_status','tax_certificate_status']
      .every(col => row[col] === 'approved' || row[col] === null || row[col] === undefined);

    if (allDocsApproved && row.status === 'approved' && row.phone_verified && row.email_verified && !row.is_verified) {
      await database.query('UPDATE business_verifications SET is_verified = true, approved_at = COALESCE(approved_at, CURRENT_TIMESTAMP) WHERE id = $1', [id]);
      row.is_verified = true;
    }

    res.json({
      success: true,
      message: 'Document status updated',
      data: {
        id: row.id,
        status: row.status,
        isVerified: row.is_verified,
        [statusColumn]: row[statusColumn],
        [reasonColumn]: row[reasonColumn]
      }
    });
  } catch (error) {
    console.error('Error updating document status:', error);
    res.status(500).json({ success: false, message: 'Internal server error', error: error.message });
  }
});

// Phone verification endpoints for business verification
router.post('/verify-phone/send-otp', auth.authMiddleware(), async (req, res) => {
  try {
    console.log('📱 Business verification OTP request received:', {
      body: req.body,
      headers: req.headers['content-type'],
      userId: req.user?.id
    });

    const { phoneNumber, countryCode } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated'
      });
    }

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Normalize phone early (bug fix: previously used before definition)
    const normalizedPhone = normalizePhoneNumber(phoneNumber);

    // Use unified verification system to check all three tables
    console.log(`🔍 Business verification: Checking unified phone verification for user ${userId}...`);
    const verificationCheck = await checkUnifiedPhoneVerification(userId, normalizedPhone);
    
    if (verificationCheck.phoneVerified) {
      console.log(`✅ Business verification: Phone ${normalizedPhone} already verified via ${verificationCheck.verificationSource} - skipping OTP`);
      return res.json({
        success: true,
        message: 'Phone number is already verified',
        already_verified: true,
        verification_source: verificationCheck.verificationSource,
        verified_phone: verificationCheck.verifiedPhone,
        checked_tables: verificationCheck.checkedTables
      });
    } else {
      console.log(`❌ Business verification: Phone ${normalizedPhone} not verified in any table - sending OTP`);
      console.log('📊 Business verification: Checked tables:', verificationCheck.checkedTables);
    }

    // Send OTP using country-specific SMS service
    const smsService = require('../services/smsService');
    
    // Auto-detect country if not provided
    const detectedCountry = countryCode || smsService.detectCountry(normalizedPhone);
    console.log(`🌍 Using country: ${detectedCountry} for SMS delivery`);

    try {
      const result = await smsService.sendOTP(normalizedPhone, detectedCountry);

      // Store additional metadata for business verification
      await database.query(
        `UPDATE phone_otp_verifications 
         SET user_id = $1, verification_type = 'business_verification'
         WHERE phone = $2 AND otp_id = $3`,
        [userId, normalizedPhone, result.otpId]
      );

      console.log(`✅ OTP sent via ${result.provider} for business verification: ${normalizedPhone}`);

      return res.json({
        success: true,
        message: 'OTP sent successfully',
        phoneNumber: normalizedPhone,
        otpId: result.otpId,
        provider: result.provider,
        countryCode: detectedCountry,
        expiresIn: result.expiresIn
      });
    } catch (error) {
      console.error('SMS service error (business verification):', error.message);
      console.error('SMS service error details:', {
        stack: error.stack,
        errorType: typeof error,
        errorObject: error
      });
      
      // Development fallback: auto-generate OTP when no SMS config
      if (process.env.NODE_ENV !== 'production') {
        try {
          const otp = '123456';
          const otpId = `dev_${Date.now()}`;
          await database.query(`
            INSERT INTO phone_otp_verifications 
            (otp_id, phone, otp, country_code, expires_at, attempts, max_attempts, created_at, provider_used)
            VALUES ($1,$2,$3,$4, NOW() + interval '5 minute', 0, 3, NOW(), 'dev_fallback')
          `, [otpId, normalizedPhone, otp, detectedCountry]);
          console.log('🛠 Dev fallback OTP generated (business): 123456');
          return res.json({
            success: true,
            message: 'DEV MODE: OTP generated (use 123456)',
            phoneNumber: normalizedPhone,
            otpId,
            provider: 'dev_fallback',
            countryCode: detectedCountry,
            devOtp: otp,
            expiresIn: 300
          });
        } catch (e2) {
          console.error('Dev fallback generation failed:', e2.message);
        }
      }
      return res.status(500).json({
        success: false,
        message: typeof error.message === 'string' ? error.message : 'Failed to send OTP',
        errorDebug: {
          errorType: typeof error,
          errorMessage: error.message,
          errorString: String(error)
        }
      });
    }

  } catch (error) {
    console.error('Error sending OTP for business verification:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

router.post('/verify-phone/verify-otp', auth.authMiddleware(), async (req, res) => {
  try {
    const { phoneNumber, otp, otpId } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated'
      });
    }

    if (!phoneNumber || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Phone number and OTP are required'
      });
    }

    // Verify OTP using country-specific SMS service
    const smsService = require('../services/smsService');
    
    const normalizedPhone = normalizePhoneNumber(phoneNumber);
    console.log(`🔍 Verifying OTP for business verification - Phone: ${phoneNumber} → ${normalizedPhone}, OTP: ${otp}, User: ${userId}`);

    try {
      const verificationResult = await smsService.verifyOTP(normalizedPhone, otp, otpId);

      if (verificationResult.verified) {
        // Auto-detect country for phone number
        const detectedCountry = smsService.detectCountry(normalizedPhone);

        // 1. Update business verification phone verification status
        await database.query(`
          UPDATE business_verifications 
          SET phone_verified = true 
          WHERE user_id = $1
        `, [userId]);

        // 2. Mark user record phone_verified AND save the phone number if not already set
        const userUpdateResult = await database.query(`
          UPDATE users 
          SET phone_verified = true, 
              phone = CASE 
                WHEN phone IS NULL OR phone = '' THEN $2 
                ELSE phone 
              END,
              updated_at = NOW()
          WHERE id = $1
          RETURNING phone, phone_verified
        `, [userId, normalizedPhone]);

        console.log('📱 User phone updated:', userUpdateResult.rows[0]);

        // 3. Update any associated business_verifications row(s)
        const businessVerificationUpdate = await database.query(`
          UPDATE business_verifications
          SET phone_verified = true, updated_at = NOW()
          WHERE user_id = $1
          RETURNING id, status, phone_verified, email_verified,
                    business_logo_status, business_license_status,
                    insurance_document_status, tax_certificate_status,
                    is_verified
        `, [userId]);

        const businessVerification = businessVerificationUpdate.rows[0] || null;

        // 4. If business_verifications row exists, recompute is_verified if all conditions met
        if (businessVerification) {
          const allDocsApproved = ['business_logo_status','business_license_status','insurance_document_status','tax_certificate_status']
            .every(col => businessVerification[col] === 'approved' || businessVerification[col] == null);
          if (allDocsApproved && businessVerification.status === 'approved' && businessVerification.phone_verified && businessVerification.email_verified && !businessVerification.is_verified) {
            const isVerRes = await database.query(
              'UPDATE business_verifications SET is_verified = true, approved_at = COALESCE(approved_at, CURRENT_TIMESTAMP) WHERE id = $1 RETURNING is_verified, approved_at',
              [businessVerification.id]
            );
            businessVerification.is_verified = isVerRes.rows[0]?.is_verified || businessVerification.is_verified;
          }
        }

        console.log(`✅ Phone verified for business verification: ${normalizedPhone}. User & business_verifications updated.`);

        return res.json({
          success: true,
          message: 'Phone number verified successfully',
          phoneNumber: normalizedPhone,
          verified: true,
          provider: verificationResult.provider,
          verificationSource: 'user_phone_numbers',
          userPhoneVerified: true,
          businessVerificationUpdated: !!businessVerification,
          businessVerification: businessVerification ? {
            id: businessVerification.id,
            status: businessVerification.status,
            phone_verified: businessVerification.phone_verified,
            email_verified: businessVerification.email_verified,
            is_verified: businessVerification.is_verified
          } : null
        });
      } else {
        return res.status(400).json({
          success: false,
          message: verificationResult.message || 'Invalid or expired OTP'
        });
      }
    } catch (error) {
      console.error('SMS verification error:', error);
      return res.status(500).json({
        success: false,
        message: error.message || 'Failed to verify OTP'
      });
    }

  } catch (error) {
    console.error('Error verifying OTP for business verification:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get unified verification status for phone/email (used by both business and driver screens)
router.post('/check-verification-status', auth.authMiddleware(), async (req, res) => {
  try {
    const { phoneNumber, email } = req.body;
    const userId = req.user?.id;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated'
      });
    }

    console.log(`🔍 Checking verification status for user ${userId}, phone: ${phoneNumber}, email: ${email}`);

    const result = {
      success: true,
      phoneVerified: false,
      emailVerified: false,
      phoneVerificationSource: null,
      emailVerificationSource: null,
      requiresPhoneOTP: false,
      requiresEmailOTP: false
    };

    // Check phone verification if provided
    if (phoneNumber) {
      const phoneStatus = await checkPhoneVerificationStatus(userId, phoneNumber);
      result.phoneVerified = phoneStatus.phoneVerified;
      result.phoneVerificationSource = phoneStatus.verificationSource;
      result.requiresPhoneOTP = phoneStatus.requiresManualVerification;
      
      console.log(`📱 Phone status: verified=${phoneStatus.phoneVerified}, source=${phoneStatus.verificationSource}`);
    }

    // Check email verification if provided
    if (email) {
      const emailStatus = await checkEmailVerificationStatus(userId, email);
      result.emailVerified = emailStatus.emailVerified;
      result.emailVerificationSource = emailStatus.verificationSource;
      result.requiresEmailOTP = emailStatus.requiresManualVerification;
      
      console.log(`📧 Email status: verified=${emailStatus.emailVerified}, source=${emailStatus.verificationSource}`);
    }

    res.json(result);
  } catch (error) {
    console.error('Error checking verification status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Get signed URL for document viewing
router.post('/signed-url', async (req, res) => {
  try {
    const { fileUrl } = req.body;
    
    if (!fileUrl) {
      return res.status(400).json({
        success: false,
        message: 'File URL is required'
      });
    }

    console.log('🔗 Generating signed URL for business document:', fileUrl);
    
    const signedUrl = await getSignedUrl(fileUrl, 3600); // 1 hour expiry
    
    res.json({
      success: true,
      signedUrl: signedUrl
    });
  } catch (error) {
    console.error('❌ Error generating signed URL:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate signed URL',
      error: error.message
    });
  }
});

module.exports = router;
