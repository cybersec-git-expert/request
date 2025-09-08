const express = require('express');
const router = express.Router();
// const { pool } = require('../config/database'); // Not needed for now

// Country-specific module configuration
// This should ideally be stored in a database table, but for now using a configuration object
const COUNTRY_MODULE_CONFIG = {
  'LK': { // Sri Lanka
    enabled_modules: [
      'item_request',
      'service_request', 
      'rental_request',
      'delivery_request',
      'ride_sharing', // All modules enabled for production
      'price_request'
    ],
    disabled_modules: [] // All modules available
  },
  'US': { // United States
    enabled_modules: [
      'item_request',
      'service_request',
      'rental_request',
      'delivery_request',
      'ride_sharing'
    ],
    disabled_modules: ['price_request'] // Example: Price requests not available in US
  },
  'IN': { // India
    enabled_modules: [
      'item_request',
      'service_request',
      'delivery_request',
      'ride_sharing'
    ],
    disabled_modules: ['rental_request', 'price_request']
  }
  // Add more countries as needed
};

// Default configuration for countries not explicitly configured
const DEFAULT_CONFIG = {
  enabled_modules: [
    'item_request',
    'service_request',
    'rental_request',
    'delivery_request',
    'ride_sharing',
    'price_request'
  ],
  disabled_modules: []
};

/**
 * GET /api/modules/enabled
 * Get enabled modules for a specific country
 * Query params: country (required) - ISO country code (e.g., 'LK', 'US', 'IN')
 */
router.get('/enabled', async (req, res) => {
  try {
    const { country } = req.query;
    
    if (!country) {
      return res.status(400).json({
        success: false,
        message: 'Country parameter is required'
      });
    }

    const countryCode = country.toString().toUpperCase();
    
    // Get configuration for the country, or use default
    const config = COUNTRY_MODULE_CONFIG[countryCode] || DEFAULT_CONFIG;
    
    // Log for debugging
    console.log(`Modules request for country ${countryCode}:`, config);
    
    res.json({
      success: true,
      country: countryCode,
      enabled_modules: config.enabled_modules,
      disabled_modules: config.disabled_modules,
      total_modules: config.enabled_modules.length
    });
    
  } catch (error) {
    console.error('Error getting enabled modules:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

/**
 * GET /api/modules/all
 * Get all available modules with their descriptions
 */
router.get('/all', async (req, res) => {
  try {
    const allModules = [
      {
        id: 'item_request',
        name: 'Item Request',
        description: 'Buy and sell items - electronics, furniture, clothing, etc.',
        features: ['Product listings', 'Categories & subcategories', 'Search & filters', 'Reviews & ratings'],
        dependencies: ['Payment System', 'In-app Messaging']
      },
      {
        id: 'service_request',
        name: 'Service Request',
        description: 'Find and offer services - cleaning, repairs, tutoring, etc.',
        features: ['Service listings', 'Professional profiles', 'Booking system', 'Time slots'],
        dependencies: ['Payment System', 'In-app Messaging', 'Location Services']
      },
      {
        id: 'rental_request',
        name: 'Rent Request',
        description: 'Rent items temporarily - tools, equipment, vehicles, etc.',
        features: ['Rental duration', 'Availability calendar', 'Deposit system', 'Return conditions'],
        dependencies: ['Payment System', 'In-app Messaging', 'Location Services']
      },
      {
        id: 'delivery_request',
        name: 'Delivery Request',
        description: 'Package delivery and courier services',
        features: ['Pickup & delivery', 'Package tracking', 'Delivery zones', 'Express delivery'],
        dependencies: ['Payment System', 'Location Services', 'Driver Management']
      },
      {
        id: 'ride_sharing',
        name: 'Ride Sharing',
        description: 'Taxi and ride sharing services',
        features: ['Ride booking', 'Driver matching', 'Route optimization', 'Fare calculation'],
        dependencies: ['Payment System', 'Location Services', 'Driver Management']
      },
      {
        id: 'price_request',
        name: 'Price Request',
        description: 'Compare prices across different sellers/services',
        features: ['Price tracking', 'Price alerts', 'Comparison charts', 'Historical data'],
        dependencies: ['Payment System', 'In-app Messaging']
      }
    ];
    
    res.json({
      success: true,
      modules: allModules
    });
    
  } catch (error) {
    console.error('Error getting all modules:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

/**
 * PUT /api/modules/config
 * Update module configuration for a country (Admin only)
 * Body: { country: string, enabled_modules: string[], disabled_modules: string[] }
 */
router.put('/config', async (req, res) => {
  try {
    // TODO: Add admin authentication middleware
    const { country, enabled_modules, disabled_modules } = req.body;
    
    if (!country || !enabled_modules || !Array.isArray(enabled_modules)) {
      return res.status(400).json({
        success: false,
        message: 'Country and enabled_modules array are required'
      });
    }
    
    const countryCode = country.toString().toUpperCase();
    
    // Update configuration (in production, this should be stored in database)
    COUNTRY_MODULE_CONFIG[countryCode] = {
      enabled_modules: enabled_modules,
      disabled_modules: disabled_modules || []
    };
    
    console.log(`Updated module config for ${countryCode}:`, COUNTRY_MODULE_CONFIG[countryCode]);
    
    res.json({
      success: true,
      message: `Module configuration updated for ${countryCode}`,
      config: COUNTRY_MODULE_CONFIG[countryCode]
    });
    
  } catch (error) {
    console.error('Error updating module config:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

/**
 * GET /api/modules/check/:module
 * Check if a specific module is enabled for a country
 * Params: module - module name (e.g., 'item_request', 'ride_sharing')
 * Query: country - ISO country code
 */
router.get('/check/:module', async (req, res) => {
  try {
    const { module } = req.params;
    const { country } = req.query;
    
    if (!country) {
      return res.status(400).json({
        success: false,
        message: 'Country parameter is required'
      });
    }
    
    const countryCode = country.toString().toUpperCase();
    const config = COUNTRY_MODULE_CONFIG[countryCode] || DEFAULT_CONFIG;
    
    const isEnabled = config.enabled_modules.includes(module);
    
    res.json({
      success: true,
      country: countryCode,
      module: module,
      enabled: isEnabled
    });
    
  } catch (error) {
    console.error('Error checking module:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

module.exports = router;
