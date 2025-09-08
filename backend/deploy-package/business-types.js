const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');

// Helper to detect if new country_business_types table exists
async function hasCountryBusinessTypesTable() {
  try {
    const r = await database.query(`
      SELECT 1 FROM information_schema.tables
      WHERE table_schema='public' AND table_name='country_business_types'
    `);
    return r.rows.length > 0;
  } catch {
    return false;
  }
}

// Check migration status endpoint
router.get('/migration-status', auth.authMiddleware(), async (req, res) => {
  try {
    console.log('🔍 Migration status endpoint called by user:', req.user.id, 'role:', req.user.role);
    
    // Check if user is super admin
    if (req.user.role !== 'super_admin') {
      console.log('❌ Access denied - not super admin');
      return res.status(403).json({
        success: false,
        message: 'Super admin access required'
      });
    }

    console.log('✅ Super admin access verified, checking migration status...');

    // Check if migration has been run
    const checkTableQuery = `
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'business_types'
      AND column_name = 'country_code'
    `;
    
    console.log('🔍 Checking for country_code column in business_types...');
    const hasCountryCode = await database.query(checkTableQuery, []);
    const needsMigration = hasCountryCode.rows.length > 0;
    console.log('📊 Migration needed:', needsMigration);
    
    // Check if country_business_types table exists
    const checkCountryTableQuery = `
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'country_business_types'
    `;
    
    console.log('🔍 Checking for country_business_types table...');
    const hasCountryTable = await database.query(checkCountryTableQuery, []);
    const hasCountryBusinessTypesTable = hasCountryTable.rows.length > 0;
    console.log('📊 Country business types table exists:', hasCountryBusinessTypesTable);
    
    const migrationStatus = {
      needsMigration,
      hasOldStructure: needsMigration,
      hasCountryBusinessTypesTable,
      migrationFile: 'migrate_business_types_restructure.js'
    };
    
    console.log('📋 Migration status result:', migrationStatus);
    
    res.json({
      success: true,
      data: migrationStatus
    });
  } catch (error) {
    console.error('❌ Error checking migration status:', error);
    res.status(500).json({
      success: false,
      message: 'Error checking migration status',
      error: error.message
    });
  }
});

// Health endpoint to verify table existence and basic schema
router.get('/health', auth.authMiddleware(), async (req, res) => {
  try {
    const hasCountry = await hasCountryBusinessTypesTable();
    let count = 0;
    let columns = [];
    if (hasCountry) {
      const c = await database.query('SELECT COUNT(*)::int AS count FROM country_business_types');
      count = c.rows[0]?.count || 0;
      const cols = await database.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema='public' AND table_name='country_business_types'
        ORDER BY ordinal_position
      `);
      columns = cols.rows.map(r => r.column_name);
    }
    res.json({ success: true, data: { hasCountryBusinessTypesTable: hasCountry, count, columns } });
  } catch (e) {
    res.status(500).json({ success: false, message: 'Health check failed', error: e.message });
  }
});

// Run migration endpoint (super admin only)
router.post('/run-migration', auth.authMiddleware(), async (req, res) => {
  try {
    // Check if user is super admin
    if (req.user.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Super admin access required'
      });
    }

    // Import and run the migration
    const { runBusinessTypesRestructuring } = require('../migrate_business_types_restructure');
    
    await runBusinessTypesRestructuring();
    
    res.json({
      success: true,
      message: 'Business types migration completed successfully!'
    });
  } catch (error) {
    console.error('Error running migration:', error);
    res.status(500).json({
      success: false,
      message: 'Error running migration: ' + error.message,
      error: error.message
    });
  }
});

// Global business types management (super admin only)

// Get all global business types (super admin only)
router.get('/global', auth.authMiddleware(), async (req, res) => {
  try {
    console.log('🔍 Global business types endpoint called by user:', req.user.id, 'role:', req.user.role);
    
    // Check if user is super admin
    if (req.user.role !== 'super_admin') {
      console.log('❌ Access denied - not super admin');
      return res.status(403).json({
        success: false,
        message: 'Super admin access required'
      });
    }

    console.log('✅ Super admin access verified, checking table structure...');
    
    // Check current table structure to determine if migration has been run
    const checkTableQuery = `
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'business_types'
      AND column_name = 'country_code'
    `;
    
    console.log('🔍 Executing table structure check query...');
    const hasCountryCode = await database.query(checkTableQuery, []);
    console.log('📊 Table structure check result:', hasCountryCode.rows.length > 0 ? 'Old structure (has country_code)' : 'New structure (no country_code)');
    
    let query, result;
    
    if (hasCountryCode.rows.length > 0) {
      console.log('📋 Using old structure query - showing unique business types as global templates');
      // Old structure - return unique business types as "global" templates
      query = `
        SELECT DISTINCT
          ROW_NUMBER() OVER (ORDER BY name) as id,
          name, 
          description, 
          icon, 
          display_order,
          true as is_active,
          MIN(created_at) as created_at,
          MAX(updated_at) as updated_at,
          COUNT(*) as country_usage
        FROM business_types bt
        WHERE is_active = true
        GROUP BY name, description, icon, display_order
        ORDER BY display_order, name
      `;
    } else {
      console.log('🌍 Using new structure query - querying global business types table');
      // New structure - query global business types table
      query = `
        SELECT 
          bt.id, 
          bt.name, 
          bt.description, 
          bt.icon, 
          bt.display_order,
          bt.is_active,
          bt.created_at,
          bt.updated_at,
          COALESCE(COUNT(cbt.id), 0) as country_usage
        FROM business_types bt
        LEFT JOIN country_business_types cbt ON cbt.global_business_type_id = bt.id
        GROUP BY bt.id, bt.name, bt.description, bt.icon, bt.display_order, bt.is_active, bt.created_at, bt.updated_at
        ORDER BY bt.display_order, bt.name
      `;
    }

    console.log('🚀 Executing main query...');
    result = await database.query(query, []);
    console.log('📊 Query result:', result.rows.length, 'business types found');

    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('❌ Error fetching global business types:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching global business types',
      error: error.message
    });
  }
});

// Create global business type (super admin only)
router.post('/global', auth.authMiddleware(), async (req, res) => {
  try {
    // Check if user is super admin
    if (req.user.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Super admin access required'
      });
    }

    // Check if migration has been run
    const checkTableQuery = `
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'business_types'
      AND column_name = 'country_code'
    `;
    
    const hasCountryCode = await database.query(checkTableQuery, []);
    
    if (hasCountryCode.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Please run the business types migration first. The system needs to be updated to support global business types.'
      });
    }

    const { name, description, icon, display_order = 0 } = req.body;
    
    // Validate required fields
    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Name is required'
      });
    }

    // Check if name already exists
    const existingType = await database.queryOne(
      'SELECT id FROM business_types WHERE LOWER(name) = LOWER($1)',
      [name]
    );

    if (existingType) {
      return res.status(400).json({
        success: false,
        message: 'A global business type with this name already exists'
      });
    }

    const query = `
      INSERT INTO business_types (name, description, icon, display_order, created_by)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `;

    const result = await database.queryOne(query, [
      name,
      description || null,
      icon || null,
      display_order,
      req.user.id
    ]);

    res.json({
      success: true,
      message: 'Global business type created successfully',
      data: result
    });
  } catch (error) {
    console.error('Error creating global business type:', error);
    res.status(500).json({
      success: false,
      message: 'Error creating global business type',
      error: error.message
    });
  }
});

// Update global business type (super admin only)
router.put('/global/:id', auth.authMiddleware(), async (req, res) => {
  try {
    // Check if user is super admin
    if (req.user.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Super admin access required'
      });
    }

    const { id } = req.params;
    const { name, description, icon, display_order, is_active } = req.body;

    // Check if global business type exists
    const existingType = await database.queryOne(
      'SELECT * FROM business_types WHERE id = $1',
      [id]
    );

    if (!existingType) {
      return res.status(404).json({
        success: false,
        message: 'Global business type not found'
      });
    }

    // If name is being updated, check for duplicates
    if (name && name.toLowerCase() !== existingType.name.toLowerCase()) {
      const duplicate = await database.queryOne(
        'SELECT id FROM business_types WHERE LOWER(name) = LOWER($1) AND id != $2',
        [name, id]
      );

      if (duplicate) {
        return res.status(400).json({
          success: false,
          message: 'A global business type with this name already exists'
        });
      }
    }

    const query = `
      UPDATE business_types 
      SET 
        name = COALESCE($1, name),
        description = COALESCE($2, description),
        icon = COALESCE($3, icon),
        display_order = COALESCE($4, display_order),
        is_active = COALESCE($5, is_active),
        updated_at = CURRENT_TIMESTAMP,
        updated_by = $6
      WHERE id = $7
      RETURNING *
    `;

    const result = await database.queryOne(query, [
      name || null,
      description || null,
      icon || null,
      display_order !== undefined ? display_order : null,
      is_active !== undefined ? is_active : null,
      req.user.id,
      id
    ]);

    res.json({
      success: true,
      message: 'Global business type updated successfully',
      data: result
    });
  } catch (error) {
    console.error('Error updating global business type:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating global business type',
      error: error.message
    });
  }
});

// Delete global business type (super admin only)
router.delete('/global/:id', auth.authMiddleware(), async (req, res) => {
  try {
    // Check if user is super admin
    if (req.user.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Super admin access required'
      });
    }

    const { id } = req.params;

    // Check if global business type exists
    const existingType = await database.queryOne(
      'SELECT * FROM business_types WHERE id = $1',
      [id]
    );

    if (!existingType) {
      return res.status(404).json({
        success: false,
        message: 'Global business type not found'
      });
    }

    // Check if this global type is being used by any countries
    const usageCount = await database.queryOne(
      'SELECT COUNT(*) as count FROM country_business_types WHERE global_business_type_id = $1',
      [id]
    );

    if (parseInt(usageCount.count) > 0) {
      return res.status(400).json({
        success: false,
        message: `Cannot delete this global business type as it is being used by ${usageCount.count} country business type(s)`
      });
    }

    // Soft delete - set as inactive
    const query = `
      UPDATE business_types 
      SET 
        is_active = false,
        updated_at = CURRENT_TIMESTAMP,
        updated_by = $1
      WHERE id = $2
      RETURNING *
    `;

    const result = await database.queryOne(query, [req.user.id, id]);

    res.json({
      success: true,
      message: 'Global business type deleted successfully',
      data: result
    });
  } catch (error) {
    console.error('Error deleting global business type:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting global business type',
      error: error.message
    });
  }
});

// Country-specific business types management

// Get all business types for a country (public endpoint for registration form)
router.get('/', async (req, res) => {
  try {
    const { country_code = 'LK' } = req.query;

    if (await hasCountryBusinessTypesTable()) {
      const query = `
        SELECT id, name, description, icon, display_order
        FROM country_business_types 
        WHERE country_code = $1 AND is_active = true
        ORDER BY display_order, name
      `;
      const result = await database.query(query, [country_code]);
      return res.json({ success: true, data: result.rows });
    }

    // Legacy fallback: read from old business_types if not migrated yet
    const legacyQuery = `
      SELECT id, name, description, icon, display_order
      FROM business_types
      WHERE country_code = $1 AND is_active = true
      ORDER BY display_order, name
    `;
    const legacy = await database.query(legacyQuery, [country_code]);

    res.json({ success: true, data: legacy.rows });
  } catch (error) {
    console.error('Error fetching business types:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching business types',
      error: error.message
    });
  }
});

// Admin endpoints - require admin authentication
router.use(auth.authMiddleware());

// Check admin permissions
const checkAdminPermission = (req, res, next) => {
  const userRole = req.user.role;
  const userCountry = req.user.country_code;
  const permissions = req.user.permissions || {};
  
  // Super admins can manage all countries
  if (userRole === 'super_admin') {
    return next();
  }
  
  // Country admins can only manage their own country
  if (userRole === 'admin' || userRole === 'country_admin') {
    // Enforce explicit permission flag for managing country business types
    if (!permissions.countryBusinessTypeManagement) {
      return res.status(403).json({ success: false, message: 'Permission denied: country business types management' });
    }
    req.adminCountry = userCountry; // Restrict to admin's country
    return next();
  }
  
  return res.status(403).json({
    success: false,
    message: 'Admin access required'
  });
};

router.use(checkAdminPermission);

// Get available global business types for reference
router.get('/global-templates', async (req, res) => {
  try {
    const query = `
      SELECT id, name, description, icon, display_order
      FROM business_types 
      WHERE is_active = true
      ORDER BY display_order, name
    `;

    const result = await database.query(query, []);

    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching global business type templates:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching global business type templates',
      error: error.message
    });
  }
});

// Get all business types (admin view with all details)
router.get('/admin', async (req, res) => {
  try {
    const { country_code } = req.query;
    const userRole = req.user.role;
    const hasCountry = await hasCountryBusinessTypesTable();
    
    let query;
    
    const params = [];
    const conditions = [];
    
    if (hasCountry) {
      query = `
  SELECT cbt.*, 
         bt.name as global_name,
         bt.description as global_description,
         bt.icon as global_icon,
         cb.name as created_by_name,
         ub.name as updated_by_name
        FROM country_business_types cbt
        LEFT JOIN business_types bt ON cbt.global_business_type_id = bt.id
        LEFT JOIN admin_users cb ON cbt.created_by = cb.id
        LEFT JOIN admin_users ub ON cbt.updated_by = ub.id
      `;
      // Super admins see all countries, others see only their country
      if (userRole !== 'super_admin') {
        conditions.push('cbt.country_code = $1');
        params.push(req.adminCountry || req.user.country_code);
      } else if (country_code) {
        conditions.push('cbt.country_code = $1');
        params.push(country_code);
      }
      if (conditions.length > 0) query += ' WHERE ' + conditions.join(' AND ');
      query += ' ORDER BY cbt.country_code, cbt.display_order, cbt.name';
      const result = await database.query(query, params);
      return res.json({ success: true, data: result.rows });
    }

    // Legacy fallback: list from old business_types
    query = `
      SELECT bt.*, NULL::text as created_by_name, NULL::text as updated_by_name
      FROM business_types bt
    `;
    if (userRole !== 'super_admin') {
      conditions.push('bt.country_code = $1');
      params.push(req.adminCountry || req.user.country_code);
    } else if (country_code) {
      conditions.push('bt.country_code = $1');
      params.push(country_code);
    }
    if (conditions.length > 0) query += ' WHERE ' + conditions.join(' AND ');
    query += ' ORDER BY bt.country_code, bt.display_order, bt.name';
    const legacyResult = await database.query(query, params);

    res.json({ success: true, data: legacyResult.rows });
  } catch (error) {
    console.error('Error fetching business types (admin):', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching business types',
      error: error.message
    });
  }
});

// Create new business type
router.post('/admin', auth.authMiddleware(), async (req, res) => {
  try {
    if (!(await hasCountryBusinessTypesTable())) {
      return res.status(400).json({ success: false, message: 'Business types migration required. Please run /api/business-types/run-migration as super admin.' });
    }
    const { name, description, icon, country_code, display_order = 0, global_business_type_id } = req.body;
    const userId = req.user.id;
    
    // Validate required fields
    if (!name || !country_code) {
      return res.status(400).json({
        success: false,
        message: 'Name and country_code are required'
      });
    }
    
    // Check if user can manage this country
    if (req.adminCountry && req.adminCountry !== country_code) {
      return res.status(403).json({
        success: false,
        message: 'Cannot manage business types for other countries'
      });
    }

    const insertQuery = `
      INSERT INTO country_business_types (name, description, icon, country_code, display_order, global_business_type_id, created_by, updated_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
      RETURNING *
    `;

    const result = await database.queryOne(insertQuery, [
      name, description, icon, country_code, display_order, global_business_type_id || null, userId
    ]);

    res.status(201).json({
      success: true,
      message: 'Business type created successfully',
      data: result
    });
  } catch (error) {
    console.error('Error creating business type:', error);
    
    if (error.code === '23505') { // Unique constraint violation
      return res.status(400).json({
        success: false,
        message: 'Business type with this name already exists in this country'
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Error creating business type',
      error: error.message
    });
  }
});

// Update business type
router.put('/admin/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, icon, is_active, display_order, global_business_type_id } = req.body;
    const userId = req.user.id;

    // Check if business type exists and user can manage it
    const checkQuery = `
      SELECT * FROM country_business_types WHERE id = $1
    `;
    
    const existingType = await database.queryOne(checkQuery, [id]);
    
    if (!existingType) {
      return res.status(404).json({
        success: false,
        message: 'Business type not found'
      });
    }
    
    // Check country permission
    if (req.adminCountry && req.adminCountry !== existingType.country_code) {
      return res.status(403).json({
        success: false,
        message: 'Cannot manage business types for other countries'
      });
    }

    const updateQuery = `
      UPDATE country_business_types 
      SET name = COALESCE($2, name),
          description = COALESCE($3, description),
          icon = COALESCE($4, icon),
          is_active = COALESCE($5, is_active),
          display_order = COALESCE($6, display_order),
          global_business_type_id = COALESCE($7, global_business_type_id),
          updated_by = $8,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
      RETURNING *
    `;

    const result = await database.queryOne(updateQuery, [
      id, name, description, icon, is_active, display_order, global_business_type_id, userId
    ]);

    res.json({
      success: true,
      message: 'Business type updated successfully',
      data: result
    });
  } catch (error) {
    console.error('Error updating business type:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating business type',
      error: error.message
    });
  }
});

// Delete business type (soft delete by setting inactive)
router.delete('/admin/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Check if business type exists and user can manage it
    const checkQuery = `
      SELECT * FROM country_business_types WHERE id = $1
    `;
    
    const existingType = await database.queryOne(checkQuery, [id]);
    
    if (!existingType) {
      return res.status(404).json({
        success: false,
        message: 'Business type not found'
      });
    }
    
    // Check country permission
    if (req.adminCountry && req.adminCountry !== existingType.country_code) {
      return res.status(403).json({
        success: false,
        message: 'Cannot manage business types for other countries'
      });
    }

    // Check if any businesses are using this type
    const usageCheck = await database.query(
      'SELECT COUNT(*) as count FROM business_verification WHERE country_business_type_id = $1',
      [id]
    );

    if (parseInt(usageCheck.rows[0].count) > 0) {
      // Soft delete - deactivate instead of deleting
      const deactivateQuery = `
        UPDATE country_business_types 
        SET is_active = false, updated_by = $2, updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
        RETURNING *
      `;

      const result = await database.queryOne(deactivateQuery, [id, userId]);

      return res.json({
        success: true,
        message: 'Business type deactivated (cannot delete due to existing usage)',
        data: result
      });
    } else {
      // Hard delete if no usage
      await database.query('DELETE FROM country_business_types WHERE id = $1', [id]);

      res.json({
        success: true,
        message: 'Business type deleted successfully'
      });
    }
  } catch (error) {
    console.error('Error deleting business type:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting business type',
      error: error.message
    });
  }
});

// Copy business types from one country to another (super admin only)
router.post('/admin/copy', auth.authMiddleware(), async (req, res) => {
  try {
    if (req.user.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Super admin access required'
      });
    }

    const { from_country, to_country } = req.body;
    const userId = req.user.id;

    if (!from_country || !to_country) {
      return res.status(400).json({
        success: false,
        message: 'from_country and to_country are required'
      });
    }

    // Copy business types
    const copyQuery = `
      INSERT INTO country_business_types (name, description, icon, country_code, display_order, global_business_type_id, created_by, updated_by)
      SELECT name, description, icon, $2, display_order, global_business_type_id, $3, $3
      FROM country_business_types 
      WHERE country_code = $1 AND is_active = true
      ON CONFLICT (name, country_code) DO NOTHING
      RETURNING *
    `;

    const result = await database.query(copyQuery, [from_country, to_country, userId]);

    res.json({
      success: true,
      message: `Copied ${result.rows.length} business types from ${from_country} to ${to_country}`,
      data: result.rows
    });
  } catch (error) {
    console.error('Error copying business types:', error);
    res.status(500).json({
      success: false,
      message: 'Error copying business types',
      error: error.message
    });
  }
});

module.exports = router;
