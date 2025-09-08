const express = require('express');
const router = express.Router();
const dbService = require('../services/database');
const authService = require('../services/auth');
const { getDefaultPermissionsForRole } = require('../services/adminPermissions');

// Helper to adapt DB row -> API response (camelCase + legacy fields)
function adapt(row){
  if(!row) return row;
  const { password_hash, country_code, name, is_active, ...rest } = row;
  return {
    ...rest,
    id: row.id,
    email: row.email,
    displayName: name, // map name -> displayName for frontend
    name, // keep original for safety
    role: row.role,
    country: country_code,
    country_code, // keep original for safety
    permissions: row.permissions || {},
    isActive: is_active,
    is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    country_name: row.country_name
  };
}// Build WHERE conditions based on query & auth
function buildListQuery(req){
  const where = [];
  const params = [];
  let p = 1;
  const q = req.query || {};
  if(q.email){
    where.push(`LOWER(au.email) = LOWER($${p})`); params.push(q.email); p++;
  }
  // Country filtering: if requester is country_admin force their country
  if(req.user.role === 'country_admin'){
    where.push(`au.country_code = $${p}`); params.push(req.user.country_code || req.user.country || ''); p++;
  } else if(q.country){
    where.push(`au.country_code = $${p}`); params.push(q.country); p++;
  }
  const whereSql = where.length ? 'WHERE ' + where.join(' AND ') : '';
  return { whereSql, params };
}

// GET /api/admin-users  (supports ?email= & ?country=) + role-based scoping
router.get('/', authService.authMiddleware(), async (req, res) => {
  try {
    const { whereSql, params } = buildListQuery(req);
    const sql = `SELECT au.*, c.name as country_name FROM admin_users au LEFT JOIN countries c ON au.country_code = c.code ${whereSql} ORDER BY au.created_at DESC`;
    const result = await dbService.query(sql, params);
    res.json({ success:true, data: result.rows.map(adapt), count: result.rows.length });
  } catch (error) {
    console.error('Error fetching admin users:', error);
    res.status(500).json({ success:false, message:'Failed to fetch admin users' });
  }
});

// GET /api/admin-users/:id
router.get('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    const result = await dbService.query('SELECT au.*, c.name as country_name FROM admin_users au LEFT JOIN countries c ON au.country_code = c.code WHERE au.id = $1', [id]);
    if(!result.rows.length) return res.status(404).json({ success:false, message:'Admin user not found' });
    // Country admin cannot access other countries' users
    const row = result.rows[0];
    if(req.user.role === 'country_admin' && row.country_code !== (req.user.country_code || req.user.country)){
      return res.status(403).json({ success:false, message:'Forbidden' });
    }
    res.json({ success:true, data: adapt(row) });
  } catch (error) {
    console.error('Error fetching admin user:', error);
    res.status(500).json({ success:false, message:'Failed to fetch admin user' });
  }
});

// POST /api/admin-users  (super_admin OR country_admin with restrictions)
router.post('/', authService.authMiddleware(), async (req, res) => {
  try {
    const body = req.body || {};
    // Normalise field names from frontend
    const email = (body.email || '').toLowerCase().trim();
    const rawPassword = body.password;
    const displayName = body.display_name || body.displayName || body.name || '';
    let role = body.role || 'country_admin';
    let countryCode = body.country_code || body.country || body.countryCode || null;
        
    // Use default permissions for role instead of frontend-provided permissions
    // This ensures all new admin users get the complete set of permissions
    const permissions = getDefaultPermissionsForRole(role);
        
    const isActive = body.is_active !== undefined ? body.is_active : (body.isActive !== undefined ? body.isActive : true);

    if(!email || !rawPassword || !displayName){
      return res.status(400).json({ success:false, message:'email, password, displayName required' });
    }

    // Country admin restrictions
    if(req.user.role === 'country_admin'){
      role = 'country_admin'; // cannot create super admins
      const ownCountry = req.user.country_code || req.user.country;
      countryCode = ownCountry; // force to own country
    }
    // Super admin must supply country code
    if(!countryCode){
      return res.status(400).json({ success:false, message:'country code required' });
    }
    if(role === 'super_admin' && req.user.role !== 'super_admin'){
      return res.status(403).json({ success:false, message:'Only super admins can create super admin users' });
    }

    // Check duplicate email
    const dup = await dbService.query('SELECT 1 FROM admin_users WHERE LOWER(email)=LOWER($1)', [email]);
    if(dup.rows.length){
      return res.status(409).json({ success:false, message:'Email already registered' });
    }

    const passwordHash = await authService.hashPassword(rawPassword);
    const insert = await dbService.query('INSERT INTO admin_users (email,password_hash,name,role,country_code,permissions,is_active) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *', [email, passwordHash, displayName, role, countryCode, permissions, isActive]);
    const row = insert.rows[0];

    // Auto-initialize vehicle types for new country admins
    if (role === 'country_admin' && countryCode) {
      try {
        console.log(`Auto-initializing vehicle types for new country admin: ${countryCode}`);
                
        // Check if country already has vehicle types configured
        const existingCount = await dbService.queryOne(
          'SELECT COUNT(*) as count FROM country_vehicle_types WHERE country_code = $1',
          [countryCode.toUpperCase()]
        );
                
        if (existingCount.count == 0) {
          // Get all active vehicle types and add them as disabled for this country
          const vehicleTypes = await dbService.query(
            'SELECT id, name FROM vehicle_types WHERE is_active = true ORDER BY name'
          );
                    
          if (vehicleTypes.rows.length > 0) {
            // Insert all vehicle types as disabled for this country
            const insertPromises = vehicleTypes.rows.map(vt => 
              dbService.query(`
                                INSERT INTO country_vehicle_types (vehicle_type_id, country_code, is_active)
                                VALUES ($1, $2, false)
                            `, [vt.id, countryCode.toUpperCase()])
            );
                        
            await Promise.all(insertPromises);
            console.log(`✅ Initialized ${vehicleTypes.rows.length} vehicle types for ${countryCode} (all disabled by default)`);
          }
        } else {
          console.log(`ℹ️ Vehicle types already initialized for ${countryCode} (${existingCount.count} entries)`);
        }
      } catch (autoInitError) {
        console.error('Warning: Failed to auto-initialize vehicle types:', autoInitError);
        // Don't fail the user creation if vehicle type initialization fails
      }
    }

    res.status(201).json({ success:true, message:'Admin user created successfully', data: adapt(row) });
  } catch (error) {
    console.error('Error creating admin user:', error);
    res.status(500).json({ success:false, message:'Failed to create admin user' });
  }
});

// PUT /api/admin-users/:id  (country_admin limited)
router.put('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    const body = req.body || {};
    const displayName = body.display_name || body.displayName;
    let role = body.role;
    let countryCode = body.country_code || body.country;
    const permissions = body.permissions || {};
    const isActive = body.is_active !== undefined ? body.is_active : body.isActive;

    // Load existing user
    const existing = await dbService.query('SELECT * FROM admin_users WHERE id = $1', [id]);
    if(!existing.rows.length) return res.status(404).json({ success:false, message:'Admin user not found' });
    const current = existing.rows[0];

    // Country admin restrictions
    if(req.user.role === 'country_admin'){
      const ownCountry = req.user.country_code || req.user.country;
      if(current.country_code !== ownCountry){
        return res.status(403).json({ success:false, message:'Cannot modify users from another country' });
      }
      // Force constraints
      role = 'country_admin';
      countryCode = ownCountry;
    }
    if(role === 'super_admin' && req.user.role !== 'super_admin'){
      return res.status(403).json({ success:false, message:'Cannot promote to super admin' });
    }

    const updates = {
      name: displayName !== undefined ? displayName : current.name,
      role: role || current.role,
      country_code: countryCode || current.country_code,
      permissions: Object.keys(permissions).length ? permissions : current.permissions,
      is_active: isActive !== undefined ? isActive : current.is_active
    };

    const result = await dbService.query('UPDATE admin_users SET name=$1, role=$2, country_code=$3, permissions=$4, is_active=$5, updated_at=CURRENT_TIMESTAMP WHERE id=$6 RETURNING *', [updates.name, updates.role, updates.country_code, updates.permissions, updates.is_active, id]);
    const row = result.rows[0];
    res.json({ success:true, message:'Admin user updated successfully', data: adapt(row) });
  } catch (error) {
    console.error('Error updating admin user:', error);
    res.status(500).json({ success:false, message:'Failed to update admin user' });
  }
});

// PUT /api/admin-users/:id/status  (toggle active)
router.put('/:id/status', authService.authMiddleware(), async (req,res) => {
  try {
    const { id } = req.params;
    const body = req.body || {};
    const existing = await dbService.query('SELECT * FROM admin_users WHERE id=$1', [id]);
    if(!existing.rows.length) return res.status(404).json({ success:false, message:'Admin user not found' });
    const row = existing.rows[0];
    if(req.user.role === 'country_admin'){
      const ownCountry = req.user.country_code || req.user.country;
      if(row.country_code !== ownCountry) return res.status(403).json({ success:false, message:'Forbidden' });
    }
    const newStatus = typeof body.isActive === 'boolean' ? body.isActive : !row.is_active;
    const upd = await dbService.query('UPDATE admin_users SET is_active=$1, updated_at=CURRENT_TIMESTAMP WHERE id=$2 RETURNING *', [newStatus, id]);
    res.json({ success:true, message:'Status updated', data: adapt(upd.rows[0]) });
  } catch (e){
    console.error('Toggle admin user status error', e);
    res.status(500).json({ success:false, message:'Error updating status' });
  }
});

// DELETE /api/admin-users/:id  (super_admin only)
router.delete('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    if(req.user.role !== 'super_admin'){
      return res.status(403).json({ success:false, message:'Only super admins can delete admin users' });
    }
    const { id } = req.params;
    const result = await dbService.query('DELETE FROM admin_users WHERE id = $1 RETURNING *', [id]);
    if(!result.rows.length) return res.status(404).json({ success:false, message:'Admin user not found' });
    res.json({ success:true, message:'Admin user deleted successfully' });
  } catch (error) {
    console.error('Error deleting admin user:', error);
    res.status(500).json({ success:false, message:'Failed to delete admin user' });
  }
});

// POST /api/admin-users/:id/password-reset (send password reset email)
router.post('/:id/password-reset', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get user details
    const existing = await dbService.query('SELECT * FROM admin_users WHERE id = $1', [id]);
    if(!existing.rows.length) return res.status(404).json({ success:false, message:'Admin user not found' });
    const user = existing.rows[0];
    
    // Permission check: super admin can reset anyone, country admin can only reset users in their country
    if(req.user.role === 'country_admin'){
      const ownCountry = req.user.country_code || req.user.country;
      if(user.country_code !== ownCountry) {
        return res.status(403).json({ success:false, message:'Cannot reset password for users in other countries' });
      }
    }
    
    // Generate new temporary password
    const tempPassword = Math.random().toString(36).slice(-12) + Math.random().toString(36).slice(-12).toUpperCase() + '!';
    const passwordHash = await authService.hashPassword(tempPassword);
    
    // Update password in database
    await dbService.query('UPDATE admin_users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [passwordHash, id]);
    
    // TODO: Send email with new password (implement email service)
    console.log(`🔑 Password reset for ${user.email}: ${tempPassword}`);
    
    res.json({ 
      success: true, 
      message: `Password reset initiated for ${user.email}`,
      // In production, don't return password - send via email only
      tempPassword: tempPassword // Remove this in production
    });
  } catch (error) {
    console.error('Error resetting password:', error);
    res.status(500).json({ success:false, message:'Failed to reset password' });
  }
});

module.exports = router;