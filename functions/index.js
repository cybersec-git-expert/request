const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Import auto-activation triggers
const autoActivateTriggers = require('./auto-activate-triggers');

// Import SMS service
const smsService = require('./smsService');

// Import Email service
const emailService = require('./emailService');

// Import Unified Authentication service
const unifiedAuthService = require('./unifiedAuthService');

// Export auto-activation functions
exports.autoActivateNewVariableType = autoActivateTriggers.autoActivateNewVariableType;
exports.autoActivateNewCategory = autoActivateTriggers.autoActivateNewCategory;
exports.autoActivateNewSubcategory = autoActivateTriggers.autoActivateNewSubcategory;
exports.autoActivateNewBrand = autoActivateTriggers.autoActivateNewBrand;
exports.autoActivateNewProduct = autoActivateTriggers.autoActivateNewProduct;
exports.autoActivateNewVehicleType = autoActivateTriggers.autoActivateNewVehicleType;

// Export SMS functions
exports.sendOTP = smsService.sendOTP;
exports.verifyOTP = smsService.verifyOTP;
exports.testSMSConfig = smsService.testSMSConfig;
exports.getSMSStatistics = smsService.getSMSStatistics;

// Export Email functions
exports.sendEmailOTP = emailService.sendEmailOTP;
exports.verifyEmailOTP = emailService.verifyEmailOTP;
exports.testEmailConfig = emailService.testEmailConfig;
exports.getEmailStatistics = emailService.getEmailStatistics;

// Export Unified Authentication functions
exports.checkUserExists = unifiedAuthService.checkUserExists;
exports.sendRegistrationOTP = unifiedAuthService.sendRegistrationOTP;
exports.sendPasswordResetOTP = unifiedAuthService.sendPasswordResetOTP;
exports.verifyUnifiedOTP = unifiedAuthService.verifyOTP;
exports.loginWithPassword = unifiedAuthService.loginWithPassword;
exports.completeProfile = unifiedAuthService.completeProfile;
exports.resetPassword = unifiedAuthService.resetPassword;

exports.autoActivateForNewCountry = autoActivateTriggers.autoActivateForNewCountry;

// Business modules configuration (same as frontend)
const BUSINESS_MODULES = {
  ITEM: {
    id: 'item',
    name: 'Item Marketplace',
    description: 'Buy and sell items - electronics, furniture, clothing, etc.',
    icon: '🛍️',
    color: '#FF6B35',
    features: [
      'Product listings',
      'Categories & subcategories', 
      'Search & filters',
      'Reviews & ratings',
      'Wishlist',
      'Shopping cart'
    ],
    dependencies: ['payment', 'messaging'],
    defaultEnabled: true
  },
  SERVICE: {
    id: 'service',
    name: 'Service Marketplace',
    description: 'Find and offer services - cleaning, repairs, tutoring, etc.',
    icon: '🔧',
    color: '#4ECDC4',
    features: [
      'Service listings',
      'Professional profiles',
      'Booking system',
      'Time slots',
      'Service areas',
      'Portfolio gallery'
    ],
    dependencies: ['payment', 'messaging', 'location'],
    defaultEnabled: true
  },
  RENT: {
    id: 'rent',
    name: 'Rental System', 
    description: 'Rent items temporarily - tools, equipment, vehicles, etc.',
    icon: '📅',
    color: '#45B7D1',
    features: [
      'Rental duration',
      'Availability calendar',
      'Deposit system',
      'Return conditions',
      'Insurance options',
      'Late fees'
    ],
    dependencies: ['payment', 'messaging', 'location'],
    defaultEnabled: false
  },
  DELIVERY: {
    id: 'delivery',
    name: 'Delivery Service',
    description: 'Package delivery and courier services',
    icon: '📦',
    color: '#96CEB4',
    features: [
      'Pickup & delivery',
      'Package tracking',
      'Delivery zones',
      'Express delivery',
      'Package size/weight',
      'Delivery notes'
    ],
    dependencies: ['payment', 'location', 'driver'],
    defaultEnabled: false
  },
  RIDE: {
    id: 'ride',
    name: 'Ride Sharing',
    description: 'Taxi and ride sharing services',
    icon: '🚗',
    color: '#FFEAA7',
    features: [
      'Ride booking',
      'Driver matching',
      'Route optimization',
      'Fare calculation',
      'Live tracking',
      'Multiple stops'
    ],
    dependencies: ['payment', 'location', 'driver'],
    defaultEnabled: false
  },
  PRICE: {
    id: 'price',
    name: 'Price Comparison',
    description: 'Compare prices across different sellers/services',
    icon: '💰',
    color: '#DDA0DD',
    features: [
      'Price tracking',
      'Price alerts',
      'Comparison charts',
      'Historical data',
      'Best deals',
      'Price predictions'
    ],
    dependencies: ['item', 'service'],
    defaultEnabled: false
  }
};

/**
 * Get country modules configuration for mobile app
 * API endpoint: /getCountryModules/{countryCode}
 */
exports.getCountryModules = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    const countryCode = req.path.split('/').pop() || req.query.country;
    
    if (!countryCode) {
      return res.status(400).json({
        success: false,
        error: 'Country code is required'
      });
    }

    console.log(`🌍 Fetching modules for country: ${countryCode}`);

    // Get country module configuration from Firestore
    const countryModuleRef = db.collection('country_modules').doc(countryCode.toUpperCase());
    const countryModuleDoc = await countryModuleRef.get();

    let moduleData;
    
    if (!countryModuleDoc.exists) {
      console.log(`⚠️ No module config found for ${countryCode}, using defaults`);
      
      // Default configuration
      moduleData = {
        modules: {
          item: true,
          service: true,
          rent: false,
          delivery: false,
          ride: false,
          price: false
        },
        coreDependencies: {
          payment: true,
          messaging: true,
          location: true,
          driver: false
        },
        lastUpdated: null
      };
    } else {
      moduleData = countryModuleDoc.data();
      console.log(`✅ Found module config for ${countryCode}`, moduleData.modules);
    }

    // Get enabled modules details
    const enabledModules = Object.keys(moduleData.modules).filter(key => moduleData.modules[key]);
    const moduleDetails = {};

    enabledModules.forEach(moduleId => {
      const moduleConfig = BUSINESS_MODULES[moduleId.toUpperCase()];
      if (moduleConfig) {
        moduleDetails[moduleId] = {
          id: moduleConfig.id,
          name: moduleConfig.name,
          description: moduleConfig.description,
          icon: moduleConfig.icon,
          color: moduleConfig.color,
          features: moduleConfig.features,
          dependencies: moduleConfig.dependencies
        };
      }
    });

    const response = {
      success: true,
      countryCode: countryCode.toUpperCase(),
      modules: moduleData.modules,
      coreDependencies: moduleData.coreDependencies,
      moduleDetails,
      enabledModules,
      lastUpdated: moduleData.updatedAt || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };

    res.json(response);

  } catch (error) {
    console.error('❌ Error fetching country modules:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * Update country modules (admin only)
 * API endpoint: /updateCountryModules
 */
exports.updateCountryModules = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({
      success: false,
      error: 'Method not allowed. Use POST.'
    });
  }

  try {
    const { countryCode, modules, coreDependencies, adminUid } = req.body;

    if (!countryCode || !modules || !adminUid) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: countryCode, modules, adminUid'
      });
    }

    // Verify admin user (optional - add authentication middleware)
    const adminRef = db.collection('admin_users').doc(adminUid);
    const adminDoc = await adminRef.get();
    
    if (!adminDoc.exists) {
      return res.status(403).json({
        success: false,
        error: 'Invalid admin user'
      });
    }

    // Update country modules
    const countryModuleRef = db.collection('country_modules').doc(countryCode.toUpperCase());
    
    await countryModuleRef.set({
      countryCode: countryCode.toUpperCase(),
      modules,
      coreDependencies: coreDependencies || {},
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: adminUid
    });

    console.log(`✅ Updated modules for ${countryCode}:`, modules);

    res.json({
      success: true,
      message: `Modules updated successfully for ${countryCode}`
    });

  } catch (error) {
    console.error('❌ Error updating country modules:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * Get all available modules (for admin panel)
 */
exports.getAllModules = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    res.json({
      success: true,
      modules: BUSINESS_MODULES,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Import and export the migration function
const { migrateCountrySupport } = require('./migrate-country');
exports.migrateCountrySupport = migrateCountrySupport;
