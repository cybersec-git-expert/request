// Mobile App API - Get Country Modules Configuration
// This calls the backend REST API endpoint

// Updated to use REST API instead of Firestore
import api from '../services/apiClient';
import { BUSINESS_MODULES } from '../constants/businessModules';

/**
 * Get enabled modules and configuration for a specific country
 * @param {string} countryCode - ISO country code (e.g., 'LK', 'US')
 * @returns {Object} Country module configuration
 */
export const getCountryModules = async (countryCode) => {
  try {
    console.log(`🌍 Fetching modules for country: ${countryCode}`);
    
    // Fetch from backend REST; fall back to default if 404
    let moduleData;
    try {
      const { data } = await api.get(`/country-modules/${countryCode}`);
      moduleData = data;
    } catch (e) {
      if (e?.response?.status !== 404) throw e;
    }

    if (!moduleData) {
      // Return default configuration if none exists
      console.log(`⚠️ No module config found for ${countryCode}, using defaults`);
      return {
        success: true,
        countryCode,
        modules: {
          item: true,      // Item marketplace - enabled by default
          service: true,   // Service marketplace - enabled by default
          rent: false,     // Rental system - disabled by default
          delivery: false, // Delivery service - disabled by default
          ride: false,     // Ride sharing - disabled by default
          price: false     // Price comparison - disabled by default
        },
        coreDependencies: {
          payment: true,
          messaging: true,
          location: true,
          driver: false
        },
        lastUpdated: null
      };
    }
    
  console.log(`✅ Found module config for ${countryCode}:`, moduleData.modules);
    
    return {
      success: true,
      countryCode,
  modules: moduleData.modules || {},
  coreDependencies: moduleData.coreDependencies || {},
  lastUpdated: moduleData.updatedAt || null,
  version: moduleData.version || '1.0.0'
    };
    
  } catch (error) {
    console.error('❌ Error fetching country modules:', error);
    return {
      success: false,
      error: error.message,
      countryCode
    };
  }
};

/**
 * Get module details and features for the mobile app
 * @param {Array} enabledModules - Array of enabled module IDs
 * @returns {Object} Module details for mobile app
 */
export const getModuleDetails = (enabledModules) => {
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
        apiEndpoints: getModuleApiEndpoints(moduleId),
        mobileScreens: getModuleScreens(moduleId)
      };
    }
  });
  
  return moduleDetails;
};

/**
 * Get API endpoints for a specific module
 * @param {string} moduleId - Module identifier
 * @returns {Object} API endpoints configuration
 */
const getModuleApiEndpoints = (moduleId) => {
  const endpoints = {
    item: {
      list: '/api/items',
      create: '/api/items',
      update: '/api/items/:id',
      delete: '/api/items/:id',
      search: '/api/items/search',
      categories: '/api/items/categories'
    },
    service: {
      list: '/api/services',
      create: '/api/services',
      update: '/api/services/:id',
      delete: '/api/services/:id',
      book: '/api/services/:id/book',
      availability: '/api/services/:id/availability'
    },
    rent: {
      list: '/api/rentals',
      create: '/api/rentals',
      book: '/api/rentals/:id/book',
      availability: '/api/rentals/:id/calendar',
      return: '/api/rentals/:id/return'
    },
    delivery: {
      create: '/api/deliveries',
      track: '/api/deliveries/:id/track',
      quote: '/api/deliveries/quote',
      drivers: '/api/deliveries/drivers'
    },
    ride: {
      request: '/api/rides/request',
      track: '/api/rides/:id/track',
      cancel: '/api/rides/:id/cancel',
      drivers: '/api/rides/nearby-drivers'
    },
    price: {
      compare: '/api/prices/compare',
      track: '/api/prices/track',
      alerts: '/api/prices/alerts'
    }
  };
  
  return endpoints[moduleId] || {};
};

/**
 * Get mobile screen configurations for a module
 * @param {string} moduleId - Module identifier
 * @returns {Object} Mobile screen configuration
 */
const getModuleScreens = (moduleId) => {
  const screens = {
    item: [
      { name: 'ItemList', route: '/items' },
      { name: 'ItemDetail', route: '/items/:id' },
      { name: 'ItemCreate', route: '/items/create' },
      { name: 'ItemEdit', route: '/items/:id/edit' },
      { name: 'ItemSearch', route: '/items/search' }
    ],
    service: [
      { name: 'ServiceList', route: '/services' },
      { name: 'ServiceDetail', route: '/services/:id' },
      { name: 'ServiceBook', route: '/services/:id/book' },
      { name: 'ServiceCreate', route: '/services/create' },
      { name: 'MyServices', route: '/my-services' }
    ],
    rent: [
      { name: 'RentalList', route: '/rentals' },
      { name: 'RentalDetail', route: '/rentals/:id' },
      { name: 'RentalBook', route: '/rentals/:id/book' },
      { name: 'RentalCalendar', route: '/rentals/:id/calendar' },
      { name: 'MyRentals', route: '/my-rentals' }
    ],
    delivery: [
      { name: 'DeliveryRequest', route: '/delivery/request' },
      { name: 'DeliveryTrack', route: '/delivery/track/:id' },
      { name: 'DeliveryHistory', route: '/delivery/history' }
    ],
    ride: [
      { name: 'RideRequest', route: '/ride/request' },
      { name: 'RideTrack', route: '/ride/track/:id' },
      { name: 'RideHistory', route: '/ride/history' }
    ],
    price: [
      { name: 'PriceCompare', route: '/price/compare' },
      { name: 'PriceAlerts', route: '/price/alerts' },
      { name: 'PriceHistory', route: '/price/history' }
    ]
  };
  
  return screens[moduleId] || [];
};

// Export the main function for use as Cloud Function
export const handleGetCountryModules = async (req, res) => {
  const { countryCode } = req.params;
  
  if (!countryCode) {
    return res.status(400).json({
      success: false,
      error: 'Country code is required'
    });
  }
  
  try {
    const result = await getCountryModules(countryCode.toUpperCase());
    
    if (!result.success) {
      return res.status(500).json(result);
    }
    
    // Add module details for enabled modules
    const enabledModules = Object.keys(result.modules).filter(key => result.modules[key]);
    const moduleDetails = getModuleDetails(enabledModules);
    
    res.json({
      ...result,
      moduleDetails,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};
