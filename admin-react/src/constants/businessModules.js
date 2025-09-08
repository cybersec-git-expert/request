// Business modules configuration
export const BUSINESS_MODULES = {
  ITEM: {
    id: 'item',
    name: 'Item Request',
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
    name: 'Service Request',
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
    name: 'Rent Request',
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
    name: 'Delivery Request',
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
    name: 'Price Request',
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
    dependencies: ['payment', 'messaging'],
    defaultEnabled: false
  },
  // New service modules (country toggles)
  TOURS: {
    id: 'tours',
    name: 'Tours & Experiences',
    description: 'Guided tours, experiences, accommodation, and transport',
    icon: '🧭',
    color: '#7D5BA6',
    features: [
      'Tour packages',
      'Experience booking',
      'Accommodation',
      'Transport'
    ],
    dependencies: ['messaging', 'location'],
    defaultEnabled: false
  },
  EVENTS: {
    id: 'events',
    name: 'Event Services',
    description: 'Venues, catering, entertainment, rentals, staffing',
    icon: '🎉',
    color: '#E67E22',
    features: [
      'Venue listings',
      'Catering & supplies',
      'Entertainment',
      'Event staffing'
    ],
    dependencies: ['messaging'],
    defaultEnabled: false
  },
  CONSTRUCTION: {
    id: 'construction',
    name: 'Construction Services',
    description: 'New builds, renovations, trades, consultation, materials',
    icon: '🏗️',
    color: '#C0392B',
    features: [
      'Trades & contractors',
      'Renovations',
      'Design & BOQ',
      'Materials & equipment'
    ],
    dependencies: ['messaging', 'location'],
    defaultEnabled: false
  },
  EDUCATION: {
    id: 'education',
    name: 'Education & Training',
    description: 'Tutoring, courses, arts & hobbies, admissions consulting',
    icon: '🎓',
    color: '#3F51B5',
    features: [
      'Course listings',
      'Levels & skills',
      'Scheduling'
    ],
    dependencies: ['messaging'],
    defaultEnabled: false
  },
  HIRING: {
    id: 'hiring',
    name: 'Job Requests',
    description: 'Candidates post job requests; employers respond',
    icon: '🧑‍💼',
    color: '#16A085',
    features: [
      'Job categories',
      'Applicant messaging'
    ],
    dependencies: ['messaging'],
    defaultEnabled: false
  },
  OTHER: {
    id: 'other',
    name: 'Other Services',
    description: 'Miscellaneous services not covered elsewhere',
    icon: '🧩',
    color: '#95A5A6',
    features: [
      'General service listings'
    ],
    dependencies: ['messaging'],
    defaultEnabled: false
  }
};

// Core system dependencies
export const CORE_DEPENDENCIES = {
  payment: 'Payment System',
  messaging: 'In-app Messaging',
  location: 'Location Services',
  driver: 'Driver Management'
};

// Get modules that a specific module depends on
export const getModuleDependencies = (moduleId) => {
  const module = BUSINESS_MODULES[moduleId.toUpperCase()];
  return module ? module.dependencies : [];
};

// Check if all dependencies are met for a module
export const canEnableModule = (moduleId, enabledModules, enabledDependencies) => {
  const dependencies = getModuleDependencies(moduleId);
  
  // Check if all dependencies are enabled
  for (const dep of dependencies) {
    if (BUSINESS_MODULES[dep.toUpperCase()]) {
      // It's a module dependency
      if (!enabledModules.includes(dep)) {
        return { canEnable: false, missing: dep, type: 'module' };
      }
    } else {
      // It's a core dependency
      if (!enabledDependencies.includes(dep)) {
        return { canEnable: false, missing: dep, type: 'core' };
      }
    }
  }
  
  return { canEnable: true };
};

// Get modules that depend on a specific module (reverse dependency check)
export const getModulesUsingDependency = (moduleId) => {
  return Object.keys(BUSINESS_MODULES).filter(key => {
    const module = BUSINESS_MODULES[key];
    return module.dependencies.includes(moduleId);
  });
};

// Map business types to the modules they use.
// Keep IDs in lower-case to match BUSINESS_MODULES[id].id
export const BUSINESS_TYPE_TO_MODULES = {
  // Current active LK types
  'Product Seller': ['item', 'service', 'rent', 'price'], // price is public but sellers manage prices
  // Delivery: keep name aligned with module while maintaining backend compatibility
  'Delivery': ['item', 'service', 'rent', 'delivery'],
  'Ride': ['ride'], // Ride sharing services

  // Future verticals (disabled by default at country level)
  'Tours': ['tours'],
  'Events': ['events'],
  'Construction': ['construction'],
  'Education': ['education'],
  'Job': ['hiring'],
  'Other': ['other']
};

// Helper: get module configs for a business type (filters unknowns safely)
export const getModulesForBusinessType = (typeName) => {
  const ids = BUSINESS_TYPE_TO_MODULES[typeName] || [];
  return ids
    .map(id => BUSINESS_MODULES[id.toUpperCase()])
    .filter(Boolean);
};

// Helper: check if a business type can use a specific module
export const canBusinessTypeUseModule = (typeName, moduleId) => {
  const ids = BUSINESS_TYPE_TO_MODULES[typeName] || [];
  return ids.includes(moduleId);
};

// Helper: merge modules for multiple business types (unique by id)
export const getModulesForBusinessTypes = (typeNames = []) => {
  const set = new Set();
  typeNames.forEach(t => (BUSINESS_TYPE_TO_MODULES[t] || []).forEach(id => set.add(id)));
  return Array.from(set)
    .map(id => BUSINESS_MODULES[id.toUpperCase()])
    .filter(Boolean);
};

// Capabilities inferred by business type (aligned with backend access rights)
export const getCapabilitiesForBusinessType = (typeName) => {
  const name = (typeName || '').toLowerCase();
  const isProductSeller = name === 'product seller';
  const isDeliveryService = name === 'delivery' || name === 'delivery service';
  const isRideService = name === 'ride';

  return {
    managePrices: isProductSeller, // price mgmt only for product sellers
  // Any verified business can respond to module requests (granular toggles)
  respondItem: true,
  respondService: true,
  respondRent: true,
  respondTours: true,
  respondEvents: true,
  respondConstruction: true,
  respondEducation: true,
  respondHiring: true,
  // Delivery is restricted to Delivery type
  respondDelivery: isDeliveryService,
  // Rides are for ride service businesses
  respondRide: isRideService,
  // Send ride requests is for individual users only (no business can send)
  sendRide: false
  };
};
