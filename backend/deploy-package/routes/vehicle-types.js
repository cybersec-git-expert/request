const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');

// Get all vehicle types for a country (public endpoint for admin panel)
router.get('/', async (req, res) => {
  try {
    const countryCode = (req.query.country || 'LK').toUpperCase();
    const includeInactive = req.query.includeInactive === 'true';

    const result = await database.query(`
      SELECT 
        vt.id,
        vt.name,
        vt.description,
        vt.icon,
        0 AS display_order,
        COALESCE(vt.capacity, 1) AS passenger_capacity,
        vt.is_active,
        vt.created_at,
        vt.updated_at,
        cvt.is_active AS country_specific_active,
        COALESCE(cvt.is_active, vt.is_active) AS country_enabled,
        cvt.id AS country_vehicle_type_id
      FROM vehicle_types vt
      LEFT JOIN country_vehicle_types cvt 
        ON vt.id = cvt.vehicle_type_id 
       AND cvt.country_code = $1
      WHERE ($2 OR vt.is_active = true)
      ORDER BY vt.name
    `, [countryCode, includeInactive]);

    // Adapt to frontend expected camelCase keys
    const data = result.rows.map(r => ({
      id: r.id,
      name: r.name,
      description: r.description,
      icon: r.icon || 'DirectionsCar',
      displayOrder: r.display_order,
      passengerCapacity: r.passenger_capacity,
      isActive: r.is_active,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
      countryEnabled: r.country_enabled,
      countrySpecificActive: r.country_specific_active,
      countryVehicleTypeId: r.country_vehicle_type_id
    }));

    res.json({ success: true, data });
  } catch (error) {
    console.error('Error fetching vehicle types:', error);
    res.status(500).json({ success: false, message: 'Error fetching vehicle types', error: error.message });
  }
});

// Toggle vehicle type status for a specific country (country admin only)
router.post('/:id/toggle-country', auth.authMiddleware(), async (req, res) => {
  try {
    const vehicleTypeId = req.params.id;
    const { isActive } = req.body;
    
    // Get user's country
    const countryCode = (req.user.country_code || req.user.country || 'LK').toUpperCase();
    
    // Check if vehicle type exists
    const vehicleType = await database.queryOne('SELECT * FROM vehicle_types WHERE id = $1', [vehicleTypeId]);
    if (!vehicleType) {
      return res.status(404).json({ success: false, message: 'Vehicle type not found' });
    }
    
    // Upsert country_vehicle_types record
    const result = await database.query(`
      INSERT INTO country_vehicle_types (vehicle_type_id, country_code, is_active)
      VALUES ($1, $2, $3)
      ON CONFLICT (vehicle_type_id, country_code)
      DO UPDATE SET is_active = EXCLUDED.is_active, updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `, [vehicleTypeId, countryCode, isActive]);
    
    res.json({ 
      success: true, 
      message: `Vehicle type ${isActive ? 'enabled' : 'disabled'} for ${countryCode}`,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error toggling vehicle type for country:', error);
    res.status(500).json({ success: false, message: 'Error updating vehicle type status', error: error.message });
  }
});

// Create a vehicle type
router.post('/', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const { name, description, icon, capacity, passengerCapacity, displayOrder, is_active, isActive } = req.body || {};
    if (!name || !name.trim()) return res.status(400).json({ success: false, message: 'Name is required' });
    const cap = Number.isFinite(passengerCapacity) ? passengerCapacity : (Number.isFinite(capacity) ? capacity : 1);
    const active = typeof isActive === 'boolean' ? isActive : (typeof is_active === 'boolean' ? is_active : true);
    const orderVal = Number.isFinite(displayOrder) ? displayOrder : null;

    const insert = await database.query(`
      INSERT INTO vehicle_types (name, description, icon, passenger_capacity, display_order, is_active)
      VALUES ($1,$2,$3,$4,$5,$6)
      RETURNING id,name,description,icon,passenger_capacity,display_order,is_active,created_at,updated_at
    `, [name.trim(), description || '', icon || 'DirectionsCar', cap, orderVal, active]);

    const r = insert.rows[0];
    res.status(201).json({ success: true, data: {
      id: r.id,
      name: r.name,
      description: r.description,
      icon: r.icon,
      displayOrder: r.display_order,
      passengerCapacity: r.passenger_capacity,
      isActive: r.is_active,
      createdAt: r.created_at,
      updatedAt: r.updated_at
    }});
  } catch (error) {
    console.error('Error creating vehicle type:', error);
    res.status(500).json({ success: false, message: 'Error creating vehicle type', error: error.message });
  }
});

// Get vehicle type by ID
router.get('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const vehicleTypeId = req.params.id;
    
    const vehicleType = await database.queryOne(
      'SELECT * FROM vehicle_types WHERE id = $1',
      [vehicleTypeId]
    );

    if (!vehicleType) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle type not found'
      });
    }

    res.json({
      success: true,
      data: vehicleType
    });
  } catch (error) {
    console.error('Error fetching vehicle type:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching vehicle type',
      error: error.message
    });
  }
});

// Update vehicle type (super admin only)
router.put('/:id', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const id = req.params.id;
    const { name, description, icon, capacity, passengerCapacity, displayOrder, is_active, isActive } = req.body || {};
    const existing = await database.queryOne('SELECT id FROM vehicle_types WHERE id = $1', [id]);
    if (!existing) return res.status(404).json({ success: false, message: 'Vehicle type not found' });

    const update = await database.query(`
      UPDATE vehicle_types
      SET
        name = COALESCE($2, name),
        description = COALESCE($3, description),
        icon = COALESCE($4, icon),
        passenger_capacity = COALESCE($5, passenger_capacity),
        display_order = COALESCE($6, display_order),
        is_active = COALESCE($7, is_active),
        updated_at = NOW()
      WHERE id = $1
      RETURNING id,name,description,icon,passenger_capacity,display_order,is_active,created_at,updated_at
    `, [
      id,
      name,
      description,
      icon,
      Number.isFinite(passengerCapacity) ? passengerCapacity : (Number.isFinite(capacity) ? capacity : null),
      Number.isFinite(displayOrder) ? displayOrder : null,
      typeof isActive === 'boolean' ? isActive : (typeof is_active === 'boolean' ? is_active : null)
    ]);

    const r = update.rows[0];
    res.json({ success: true, data: {
      id: r.id,
      name: r.name,
      description: r.description,
      icon: r.icon,
      displayOrder: r.display_order,
      passengerCapacity: r.passenger_capacity,
      isActive: r.is_active,
      createdAt: r.created_at,
      updatedAt: r.updated_at
    }});
  } catch (error) {
    console.error('Error updating vehicle type:', error);
    res.status(500).json({ success: false, message: 'Error updating vehicle type', error: error.message });
  }
});

// Delete vehicle type (super admin only)
router.delete('/:id', auth.authMiddleware(), auth.roleMiddleware(['super_admin']), async (req, res) => {
  try {
    const id = req.params.id;
    const deleted = await database.queryOne('DELETE FROM vehicle_types WHERE id = $1 RETURNING id,name', [id]);
    if (!deleted) return res.status(404).json({ success: false, message: 'Vehicle type not found' });
    res.json({ success: true, message: 'Vehicle type deleted', data: deleted });
  } catch (error) {
    console.error('Error deleting vehicle type:', error);
    res.status(500).json({ success: false, message: 'Error deleting vehicle type', error: error.message });
  }
});

// Initialize country vehicle types (auto-populate when country admin first accesses)
router.post('/initialize-country', auth.authMiddleware(), async (req, res) => {
  try {
    const countryCode = (req.user.country_code || req.user.country || 'LK').toUpperCase();
    
    // Check if country already has vehicle types configured
    const existingCount = await database.queryOne(
      'SELECT COUNT(*) as count FROM country_vehicle_types WHERE country_code = $1',
      [countryCode]
    );
    
    if (existingCount.count > 0) {
      return res.json({ 
        success: true, 
        message: 'Country vehicle types already initialized',
        count: existingCount.count 
      });
    }
    
    // Get all active vehicle types and add them as disabled for this country
    const vehicleTypes = await database.query(
      'SELECT id, name FROM vehicle_types WHERE is_active = true ORDER BY name'
    );
    
    if (vehicleTypes.rows.length === 0) {
      return res.json({ 
        success: true, 
        message: 'No vehicle types available to initialize' 
      });
    }
    
    // Insert all vehicle types as disabled for this country
    const insertPromises = vehicleTypes.rows.map(vt => 
      database.query(`
        INSERT INTO country_vehicle_types (vehicle_type_id, country_code, is_active)
        VALUES ($1, $2, false)
      `, [vt.id, countryCode])
    );
    
    await Promise.all(insertPromises);
    
    res.json({ 
      success: true, 
      message: `Initialized ${vehicleTypes.rows.length} vehicle types for ${countryCode} (all disabled by default)`,
      count: vehicleTypes.rows.length,
      countryCode: countryCode
    });
  } catch (error) {
    console.error('Error initializing country vehicle types:', error);
    res.status(500).json({ success: false, message: 'Error initializing country vehicle types', error: error.message });
  }
});

// Public endpoint for drivers to get enabled vehicle types for their country
router.get('/public/:countryCode', async (req, res) => {
  try {
    const countryCode = (req.params.countryCode || 'LK').toUpperCase();
    
    const result = await database.query(`
      SELECT 
        vt.id,
        vt.name,
        vt.description,
        vt.icon,
        0 AS display_order,
        COALESCE(vt.capacity, 1) AS passenger_capacity,
        vt.is_active,
        vt.created_at,
        vt.updated_at
      FROM vehicle_types vt
      INNER JOIN country_vehicle_types cvt 
        ON vt.id = cvt.vehicle_type_id 
       AND cvt.country_code = $1
       AND cvt.is_active = true
      WHERE vt.is_active = true
      ORDER BY vt.name
    `, [countryCode]);

    // Adapt to frontend expected camelCase keys
    const data = result.rows.map(r => ({
      id: r.id,
      name: r.name,
      description: r.description,
      icon: r.icon || 'DirectionsCar',
      displayOrder: r.display_order,
      passengerCapacity: r.passenger_capacity,
      isActive: r.is_active,
      createdAt: r.created_at,
      updatedAt: r.updated_at
    }));

    res.json({ success: true, data });
  } catch (error) {
    console.error('Error fetching public vehicle types:', error);
    res.status(500).json({ success: false, message: 'Error fetching vehicle types', error: error.message });
  }
});

// Public endpoint for ride requests to get available vehicle types 
// (country enabled + actually registered by verified drivers)
router.get('/available/:countryCode', async (req, res) => {
  try {
    const countryCode = (req.params.countryCode || 'LK').toUpperCase();
    
    const result = await database.query(`
      SELECT DISTINCT
        vt.id,
        vt.name,
        vt.description,
        vt.icon,
        0 AS display_order,
        COALESCE(vt.capacity, 1) AS passenger_capacity,
        vt.is_active,
        vt.created_at,
        vt.updated_at,
        COUNT(dv.id) AS registered_drivers_count
      FROM vehicle_types vt
      INNER JOIN country_vehicle_types cvt 
        ON vt.id = cvt.vehicle_type_id 
       AND cvt.country_code = $1
       AND cvt.is_active = true
      INNER JOIN driver_verifications dv
        ON dv.vehicle_type_id = vt.id
       AND dv.country = $1
       AND dv.is_verified = true
       AND dv.is_active = true
       AND dv.status = 'approved'
      WHERE vt.is_active = true
      GROUP BY vt.id, vt.name, vt.description, vt.icon, vt.capacity, vt.is_active, vt.created_at, vt.updated_at
      HAVING COUNT(dv.id) > 0
      ORDER BY vt.name
    `, [countryCode]);

    // Adapt to frontend expected camelCase keys
    const data = result.rows.map(r => ({
      id: r.id,
      name: r.name,
      description: r.description,
      icon: r.icon || 'DirectionsCar',
      displayOrder: r.display_order,
      passengerCapacity: r.passenger_capacity,
      isActive: r.is_active,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
      registeredDriversCount: parseInt(r.registered_drivers_count) || 0
    }));

    res.json({ 
      success: true, 
      data,
      count: data.length,
      message: `Found ${data.length} available vehicle types in ${countryCode} with registered drivers`
    });
  } catch (error) {
    console.error('Error fetching available vehicle types:', error);
    res.status(500).json({ success: false, message: 'Error fetching available vehicle types', error: error.message });
  }
});

module.exports = router;
