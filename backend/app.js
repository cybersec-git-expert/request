// DEPRECATED: Use backend/server.js as the single entry point.
// This file remains for legacy references but should not be used to start the server.

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const app = express();
// Entitlements (usage limits)
let entitlements;
try {
  entitlements = require('./entitlements');
} catch (e) {
  // optional
}

// Security middleware
app.use(helmet());
app.use(cors());

// Trust reverse proxy (so req.protocol honors X-Forwarded-Proto)
// This ensures generated absolute URLs use https when behind Nginx/SSL
app.set('trust proxy', 1);

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
app.use(morgan('combined'));

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Use the shared database service
    const dbService = require('./services/database');
    const pool = dbService.pool;
    const result = await pool.query('SELECT NOW()');
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: {
        status: 'healthy',
        timestamp: result.rows[0].now,
        connectionCount: pool.totalCount,
        idleCount: pool.idleCount,
        waitingCount: pool.waitingCount
      },
      version: '1.0.0'
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// Removed: legacy minimal /me/subscription probe

// Import routes
const authRoutes = require('./routes/auth');
const flutterAuthRoutes = require('./routes/flutter-auth'); // NEW
const awsDiagnosticRoutes = require('./routes/aws-diagnostic'); // TEMP - AWS diagnostic
const usersRoutes = require('./routes/users'); // NEW - user profile management
const categoryRoutes = require('./routes/categories');
const cityRoutes = require('./routes/cities');
const vehicleTypeRoutes = require('./routes/vehicle-types');
const requestRoutes = require('./routes/requests');
const countryRoutes = require('./routes/countries');
const uploadRoutes = require('./routes/upload'); // NEW
const uploadS3Routes = require('./routes/uploadS3'); // NEW - S3 upload/signed URLs
const testImageRoutes = require('./routes/test-images'); // TEST
// Removed: Subscriptions
const contentPagesRoutes = require('./routes/content-pages');
const bannersRoutes = require('./routes/banners'); // NEW - banners CRUD
console.log('🔧 About to require driver-verifications route');
const driverVerificationRoutes = require('./routes/driver-verifications'); // NEW
console.log('🔧 About to require business-verifications route');
const businessVerificationRoutes = require('./routes/business-verifications-simple'); // Use the simple working version
const businessTypesRoutes = require('./routes/business-types'); // NEW - admin business types management
const businessCategoriesRoutes = require('./routes/business-categories'); // NEW - business categories management
const businessRegistrationFormRoutes = require('./routes/business-registration-form'); // NEW - form data for business registration
const modulesRoutes = require('./routes/modules'); // NEW - module management
const adminSmsRoutes = require('./routes/admin-sms'); // NEW - SMS configuration management
const smsConfigRoutes = require('./routes/sms-config'); // NEW - SMS config API for frontend
const reviewsRoutes = require('./routes/reviews'); // NEW - user reviews API
// Business type benefits
const authService = require('./services/auth');
const entitlementSvc = require('./entitlements');
const entitlementsRoutes = require('./routes/entitlements'); // NEW - Entitlements API
const subscriptionsRoutes = require('./routes/subscriptions'); // NEW - Subscription management
const flutterSubscriptionsRoutes = require('./routes/flutter-subscriptions'); // NEW - Flutter subscription API

// Import centralized data routes
const masterProductsRoutes = require('./routes/master-products');
const brandsRoutes = require('./routes/brands');
const subcategoriesRoutes = require('./routes/subcategories');
const variableTypesRoutes = require('./routes/variable-types');
const promoCodesRoutes = require('./routes/promo-codes'); // NEW - promo codes admin
const dashboardRoutes = require('./routes/dashboard'); // NEW - dashboard counts/stats

// Import country-specific routes
const countryProductsRoutes = require('./routes/country-products');
const countryBrandsRoutes = require('./routes/country-brands');
const countryCategoriesRoutes = require('./routes/country-categories');
const countrySubcategoriesRoutes = require('./routes/country-subcategories');
const countryVariableTypesRoutes = require('./routes/country-variable-types');

// Import price comparison routes
const priceListingsRoutes = require('./routes/price-listings');
const paymentMethodsRoutes = require('./routes/payment-methods');
const s3Routes = require('./routes/uploadS3');
const countryPaymentGatewaysRoutes = require('./routes/country-payment-gateways');
const paymentsRoutes = require('./routes/payments'); // NEW - payments/checkout/webhooks


console.log('🔧 About to register driver-verifications route');

// Helper: safely mount routers without crashing if a module isn't a middleware
function safeUse(path, mod, name) {
  try {
    if (mod && typeof mod === 'function') {
      app.use(path, mod);
      console.log(`✅ Mounted ${name} at ${path}`);
      return;
    }
    if (mod && mod.router && typeof mod.router === 'function') {
      app.use(path, mod.router);
      console.log(`✅ Mounted ${name}.router at ${path}`);
      return;
    }
    if (mod && typeof mod.default === 'function') {
      app.use(path, mod.default);
      console.log(`✅ Mounted ${name}.default at ${path}`);
      return;
    }
    console.error(`❌ Skipping mount for ${name} at ${path}: not a middleware (got ${typeof mod})`);
  } catch (e) {
    console.error(`❌ Error mounting ${name} at ${path}:`, e.message);
  }
}

// Serve static files (uploaded images)
const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, 'uploads'), {
  setHeaders: (res, path) => {
    // Set CORS headers for images
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET');
    res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  }
}));

// Use routes (safely)
safeUse('/api/auth', authRoutes, 'authRoutes');
safeUse('/api/auth', flutterAuthRoutes, 'flutterAuthRoutes'); // NEW - adds Flutter-specific endpoints
safeUse('/api/diagnostic', awsDiagnosticRoutes, 'awsDiagnosticRoutes'); // TEMP - AWS diagnostic
safeUse('/api/users', usersRoutes, 'usersRoutes'); // NEW - user profile management
safeUse('/api/categories', categoryRoutes, 'categoryRoutes');
safeUse('/api/cities', cityRoutes, 'cityRoutes');
safeUse('/api/vehicle-types', vehicleTypeRoutes, 'vehicleTypeRoutes');
safeUse('/api/requests', requestRoutes, 'requestRoutes');
safeUse('/api/countries', countryRoutes, 'countryRoutes');

// Centralized data routes (Super Admin)
safeUse('/api/master-products', masterProductsRoutes, 'masterProductsRoutes');
safeUse('/api/brands', brandsRoutes, 'brandsRoutes');
safeUse('/api/subcategories', subcategoriesRoutes, 'subcategoriesRoutes');
safeUse('/api/variable-types', variableTypesRoutes, 'variableTypesRoutes');
safeUse('/api/promo-codes', promoCodesRoutes, 'promoCodesRoutes'); // NEW - promo codes admin
// Dashboard routes (aggregate stats and legacy count endpoints)
safeUse('/api', dashboardRoutes, 'dashboardRoutes');

// Country-specific routes
safeUse('/api/country-products', countryProductsRoutes, 'countryProductsRoutes');
safeUse('/api/country-brands', countryBrandsRoutes, 'countryBrandsRoutes');
safeUse('/api/country-categories', countryCategoriesRoutes, 'countryCategoriesRoutes');
safeUse('/api/country-subcategories', countrySubcategoriesRoutes, 'countrySubcategoriesRoutes');
safeUse('/api/country-variable-types', countryVariableTypesRoutes, 'countryVariableTypesRoutes');

// Price comparison routes  
safeUse('/api/price-listings', priceListingsRoutes, 'priceListingsRoutes');
safeUse('/api/payment-methods', paymentMethodsRoutes, 'paymentMethodsRoutes');
safeUse('/api/country-payment-gateways', countryPaymentGatewaysRoutes, 'countryPaymentGatewaysRoutes');
safeUse('/api/payments', paymentsRoutes, 'paymentsRoutes');
safeUse('/api/s3', s3Routes, 's3Routes');
safeUse('/api/banners', bannersRoutes, 'bannersRoutes'); // NEW - banners CRUD

safeUse('/api/upload', uploadRoutes, 'uploadRoutes'); // NEW - image upload endpoint
safeUse('/api/uploads', uploadRoutes, 'uploadRoutes(alias)'); // Alias to support admin-react '/uploads/payment-methods'
safeUse('/api/s3', uploadS3Routes, 'uploadS3Routes'); // NEW - S3 upload + signed URL endpoints
safeUse('/api/test-images', testImageRoutes, 'testImageRoutes'); // TEST - image serving test
// Removed: subscription-management, subscription-plans, subscriptions
safeUse('/api/content-pages', contentPagesRoutes, 'contentPagesRoutes'); // content pages management
safeUse('/api/driver-verifications', driverVerificationRoutes, 'driverVerificationRoutes'); // NEW - driver verification management
safeUse('/api/business-verifications', businessVerificationRoutes, 'businessVerificationRoutes'); // NEW - business verification management
safeUse('/api/business-types', businessTypesRoutes, 'businessTypesRoutes'); // NEW - admin business types management
safeUse('/api/business-categories', businessCategoriesRoutes, 'businessCategoriesRoutes'); // NEW - business categories management  
safeUse('/api/business-registration', businessRegistrationFormRoutes, 'businessRegistrationFormRoutes'); // NEW - business registration form data
safeUse('/api/modules', modulesRoutes, 'modulesRoutes'); // NEW - module management
safeUse('/api/admin', adminSmsRoutes, 'adminSmsRoutes'); // NEW - SMS configuration management
safeUse('/api/sms', smsConfigRoutes, 'smsConfigRoutes'); // NEW - SMS config API for frontend
safeUse('/api/reviews', reviewsRoutes, 'reviewsRoutes'); // NEW - user reviews
safeUse('/api/subscriptions', subscriptionsRoutes, 'subscriptionsRoutes'); // NEW - Subscription management  
safeUse('/api/flutter/subscriptions', flutterSubscriptionsRoutes, 'flutterSubscriptionsRoutes'); // NEW - Flutter subscription API
safeUse('/api/entitlements', entitlementsRoutes, 'entitlementsRoutes'); // NEW - Entitlements API  
// Removed: business-type-benefits routes (no longer used)
// Removed: subscriptions routes mount
// Current user entitlements (for gating in app)
app.get('/api/me/entitlements', authService.authMiddleware(), async (req, res) => {
  const started = Date.now();
  const userObj = req.user || {};
  console.log('[entitlements-route] /api/me/entitlements start', {
    ts: new Date().toISOString(),
    userId: userObj.id,
    role: userObj.role,
    hasUser: !!userObj.id
  });
  if (!userObj.id) {
    console.warn('[entitlements-route] missing req.user.id after auth middleware');
    return res.status(401).json({ success: false, error: 'unauthorized' });
  }
  try {
    const data = await entitlementSvc.getEntitlements(userObj.id, userObj.role);
    console.log('[entitlements-route] success', {
      durationMs: Date.now() - started,
      responseCountThisMonth: data.responseCountThisMonth,
      remainingResponses: data.remainingResponses,
      canRespond: data.canRespond
    });
    return res.json({ success: true, data });
  } catch (e) {
    console.error('[entitlements-route] ERROR', e && e.message || e);
    if (e && e.stack) console.error('[entitlements-route] STACK', e.stack);
    // Provide diagnostic hint in response (non-sensitive)
    return res.status(500).json({ success: false, error: 'failed', detail: e.message || String(e) });
  }
});
console.log('🔧 Driver-verifications route registered at /api/driver-verifications');
console.log('🔧 Business-verifications route registered at /api/business-verifications');
console.log('🔧 Business-types route registered at /api/business-types');
console.log('🔧 Business-categories route registered at /api/business-categories');
console.log('🔧 Business-registration route registered at /api/business-registration');

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
});

// Only start the HTTP listener when not running in test environment (so Jest / supertest can import app)
if (process.env.NODE_ENV !== 'test') {
  const PORT = process.env.PORT || 3001;
  const HOST = process.env.HOST || '0.0.0.0'; // Allow connections from all interfaces including Android emulator
  app.listen(PORT, HOST, () => {
    console.log(`Server running on ${HOST}:${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`Android emulator can access via: http://10.0.2.2:${PORT}/health`);
  });
}

module.exports = app;
