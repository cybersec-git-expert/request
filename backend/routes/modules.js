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
      'ride_sharing',
      'price_request',
  // Service sub-modules (admin can enable via country-modules)
  // Keeping disabled here by default to allow country-modules to drive state
    ],
    disabled_modules: [] // All modules available
  },
  'US': { // United States
    enabled_modules: [
      'item_request',
      'service_request',
      'rental_request',
      'delivery_request',
      'ride_sharing',
      // Extended service modules
      'tours',
      'events',
      'construction',
      'education',
      'hiring',
      'other'
    ],
    disabled_modules: ['price_request'] // Example
  },
  'IN': { // India
    enabled_modules: [
      'item_request',
      'service_request',
      'delivery_request',
      'ride_sharing',
      // Extended service modules
      'tours',
      'events',
      'construction',
      'education',
      'hiring',
      'other'
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
  // Note: extended service modules (tours, events, construction, education, hiring, other)
  // are exposed via /api/modules/all but toggled per-country using /api/country-modules
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
      },
      // Extended service modules (per-country toggle in country-modules)
      {
        id: 'tours',
        name: 'Tours & Experiences',
        description: 'Guided tours, travel experiences, accommodation, and transport for tourism',
        features: ['Tour packages', 'Experience booking', 'Accommodation', 'Transport'],
        dependencies: ['In-app Messaging', 'Location Services']
      },
      {
        id: 'events',
        name: 'Event Services',
        description: 'Venues, catering, entertainment, rentals, and event staffing',
        features: ['Venue listings', 'Catering', 'Entertainment', 'Rentals & supplies'],
        dependencies: ['In-app Messaging']
      },
      {
        id: 'construction',
        name: 'Construction Services',
        description: 'New builds, renovations, trades, consultation, and materials',
        features: ['Trades & contractors', 'Renovation', 'Design & BOQ', 'Materials & equipment'],
        dependencies: ['In-app Messaging', 'Location Services']
      },
      {
        id: 'education',
        name: 'Education & Training',
        description: 'Tutoring, professional courses, arts & hobbies, admissions consulting',
        features: ['Course listings', 'Levels & skills', 'Scheduling'],
        dependencies: ['In-app Messaging']
      },
      {
        id: 'hiring',
        name: 'Recruitment & Staffing',
        description: 'Job categories across hospitality, retail, IT, construction, admin, logistics, domestic, creative',
        features: ['Job categories', 'Applicant messaging'],
        dependencies: ['In-app Messaging']
      },
      {
        id: 'other',
        name: 'Other Services',
        description: 'Miscellaneous services not covered by other modules',
        features: ['General service listings'],
        dependencies: ['In-app Messaging']
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

// Get all available modules with details
router.get('/list', async (req, res) => {
  try {
    // Define available modules (this could later be moved to a database table)
    const modules = [
      {
        id: 'item',
        name: 'Item Request',
        description: 'Buy and sell items - electronics, furniture, clothing, etc.',
        icon: '🛍️',
        color: '#FF6B35',
        requestTypes: ['item'],
        defaultEnabled: true
      },
      {
        id: 'service',
        name: 'Service Request',
        description: 'Find and offer services - cleaning, repairs, tutoring, etc.',
        icon: '🔧',
        color: '#4ECDC4',
        requestTypes: ['service'],
        defaultEnabled: true
      },
      {
        id: 'rent',
        name: 'Rent Request',
        description: 'Rent items temporarily - tools, equipment, vehicles, etc.',
        icon: '📅',
        color: '#45B7D1',
        requestTypes: ['rent', 'rental'],
        defaultEnabled: false
      },
      {
        id: 'delivery',
        name: 'Delivery Request',
        description: 'Package delivery and courier services',
        icon: '📦',
        color: '#96CEB4',
        requestTypes: ['delivery'],
        defaultEnabled: false
      },
      {
        id: 'ride',
        name: 'Ride Sharing',
        description: 'Taxi and ride sharing services',
        icon: '🚗',
        color: '#FFEAA7',
        requestTypes: ['ride'],
        defaultEnabled: false
      },
      {
        id: 'price',
        name: 'Price Request',
        description: 'Price comparison and quotes',
        icon: '💰',
        color: '#DDA0DD',
        requestTypes: ['price'],
        defaultEnabled: false
      },
      {
        id: 'tours',
        name: 'Tours Request',
        description: 'Tour and experience services',
        icon: '🗺️',
        color: '#98D8C8',
        requestTypes: ['tours'],
        defaultEnabled: false
      },
      {
        id: 'events',
        name: 'Events Request',
        description: 'Event planning and management services',
        icon: '🎉',
        color: '#F7DC6F',
        requestTypes: ['events'],
        defaultEnabled: false
      },
      {
        id: 'construction',
        name: 'Construction Request',
        description: 'Construction and building services',
        icon: '🏗️',
        color: '#F8C471',
        requestTypes: ['construction'],
        defaultEnabled: false
      },
      {
        id: 'education',
        name: 'Education Request',
        description: 'Educational and training services',
        icon: '🎓',
        color: '#85C1E9',
        requestTypes: ['education'],
        defaultEnabled: false
      },
      {
        id: 'hiring', // keep id for backward compatibility in existing data
        name: 'Job Request',
        description: 'Candidates post job requests; employers respond',
        icon: '👥',
        color: '#D7BDE2',
        // support both legacy and new alias
        requestTypes: ['hiring', 'job'],
        defaultEnabled: false
      },
      {
        id: 'other',
        name: 'Other Request',
        description: 'Miscellaneous business services',
        icon: '📋',
        color: '#AED6F1',
        requestTypes: ['other'],
        defaultEnabled: false
      }
    ];

    res.json({
      success: true,
      data: modules
    });
  } catch (error) {
    console.error('Error fetching modules:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching modules',
      error: error.message
    });
  }
});

module.exports = router;
