console.log('🚀 Request Backend Production Server Starting...');
console.log('📅 Server started at:', new Date().toISOString());
// Zero-downtime CI/CD deployment test

// Request Backend API Server - Updated for CI/CD deployment
const express = require('express');

const cors = require('cors');

const helmet = require('helmet');

const morgan = require('morgan');

const rateLimit = require('express-rate-limit');

const dotenv = require('dotenv');



// Load environment variables

dotenv.config({ path: '.env.rds' });

// Fallback to .env for local development (won't override existing vars)

dotenv.config();



// Import services

const dbService = require('./services/database');
const entitlementsService = require('./services/entitlements-service');



// Import routes

const authRoutes = require('./routes/auth');

const flutterAuthRoutes = require('./routes/flutter-auth');

const categoryRoutes = require('./routes/categories');

const subcategoryRoutes = require('./routes/subcategories');

const countryModuleRoutes = require('./routes/country-modules');

const countriesRoutes = require('./routes/countries');

const cityRoutes = require('./routes/cities');

const requestRoutes = require('./routes/requests');

const uploadRoutes = require('./routes/upload'); // Image upload routes

const uploadS3Routes = require('./routes/uploadS3'); // S3 upload routes

const chatRoutes = require('./routes/chat'); // Chat routes

const brandRoutes = require('./routes/brands');

const masterProductRoutes = require('./routes/master-products');

const productSyncRoutes = require('./routes/product-sync');

const entityActivationRoutes = require('./routes/entity-activations');
const subscriptionRoutes = require('./routes/subscription');
const simpleSubscriptionRoutes = require('./routes/simple-subscription');
const simpleSubscriptionAdminRoutes = require('./routes/simple-subscription-admin');
// Removed: subscription plan routes

// Removed: subscription plan routes

const dashboardRoutes = require('./routes/dashboard');

const customProductVariableRoutes = require('./routes/custom-product-variables');


const contentPagesRoutes = require('./routes/content-pages');

const globalResponsesRoutes = require('./routes/responses-global');

const smsRoutes = require('./routes/sms');

const notificationsRoutes = require('./routes/notifications');

const contactRoutes = require('./routes/contact');

const bannersRoutes = require('./routes/banners'); // NEW - Banners CRUD
const reviewsRoutes = require('./routes/reviews'); // NEW - User reviews API
const promoCodesRoutes = require('./routes/promo-codes'); // NEW - Promo codes admin
// Removed: subscriptions and subscription-country-pricing routes
const authService = require('./services/auth'); // Auth middleware for protected routes



// New country-specific routes

const countryProductRoutes = require('./routes/country-products');

const countryCategoryRoutes = require('./routes/country-categories');

const countrySubcategoryRoutes = require('./routes/country-subcategories');

const countryBrandRoutes = require('./routes/country-brands');

const countryVariableTypeRoutes = require('./routes/country-variable-types');

const usersRoutes = require('./routes/users');

const adminUserRoutes = require('./routes/admin-users');

// const driverVerificationRoutes = require('./routes/driver-verifications'); // DISABLED - functionality moved to unified-verification

// const businessVerificationRoutes = require('./routes/business-verifications-simple'); // DISABLED - functionality moved to unified-verification

const businessCategoriesRoutes = require('./routes/business-categories'); // NEW - Business categories management

const businessRegistrationFormRoutes = require('./routes/business-registration-form'); // NEW - Business registration form data

const unifiedVerificationRoutes = require('./routes/unified-verification'); // Unified verification service

const adminSMSRoutes = require('./routes/admin-sms');

const emailVerificationRoutes = require('./routes/email-verification');

const adminEmailManagementRoutes = require('./routes/admin-email-management');

const tempMigrationRoutes = require('./routes/temp-migration'); // Temporary migration routes

const modulesRoutes = require('./routes/modules'); // Module management routes

const priceListingsRoutes = require('./routes/price-listings'); // Price listings routes

const priceStagingRoutes = require('./routes/price-staging'); // Price staging system routes

const paymentMethodsRoutes = require('./routes/payment-methods'); // Country payment methods and business mappings



// Initialize price staging service

const priceStagingService = require('./services/price_staging_service');



const app = express();
// Record process start time for liveness/debug
const startedAt = new Date().toISOString();

// Build metadata (optional)
const buildInfo = {
  version: process.env.npm_package_version || '1.0.0',
  commit: process.env.GITHUB_SHA || process.env.COMMIT_SHA || null,
  startedAt,
};



// Security middleware

app.use(helmet({

  crossOriginResourcePolicy: { policy: 'cross-origin' }

}));



// CORS configuration

const allowedOrigins = [

  'http://localhost:3000',

  'http://localhost:3001', 

  'http://localhost:5173',

  'http://localhost:5174',

  'http://127.0.0.1:3000',

  'http://127.0.0.1:3001',

  'http://10.0.2.2:3001', // Android emulator

  // Production domains

  'https://api.alphabet.lk',

  'https://admin.alphabet.lk',

  'https://alphabet.lk',

  // Legacy domains

  'https://admin.requestmarketplace.com',

  'https://requestmarketplace.com'

];



app.use(cors({

  origin: (origin, callback) => {

    if (!origin || allowedOrigins.includes(origin)) {

      callback(null, true);

    } else {

      callback(new Error('Not allowed by CORS'));

    }

  },

  credentials: true,

  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],

  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']

}));



// Rate limiting

const limiter = rateLimit({

  windowMs: 15 * 60 * 1000, // 15 minutes

  max: 1000, // limit each IP to 1000 requests per windowMs

  message: 'Too many requests from this IP, please try again later.',

  standardHeaders: true,

  legacyHeaders: false,

});

app.use(limiter);



// Middleware

app.use(morgan('combined'));

app.use(express.json({ limit: '50mb' }));

app.use(express.urlencoded({ extended: true, limit: '50mb' }));



// Health check endpoint

// Shared readiness handler (DB connectivity + metadata)
async function handleReadiness(req, res) {
  const started = Date.now();
  try {
    const dbHealth = await dbService.healthCheck();
    const isDbHealthy = dbHealth && (dbHealth.status === 'healthy' || dbHealth.timestamp);
    if (!isDbHealthy) {
      const diag = await dbService.diagnoseConnectivity().catch(() => null);
      const durationMs = Date.now() - started;
      console.error('[readiness] unhealthy', {
        method: req.method,
        path: req.originalUrl,
        durationMs,
        dbHealth,
        diagnosis: diag && (diag.message || diag)
      });
      return res.status(503).json({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        database: dbHealth,
        diagnosis: diag,
        build: buildInfo,
        durationMs,
      });
    }
    return res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: dbHealth,
      version: buildInfo.version,
      build: buildInfo,
      durationMs: Date.now() - started,
    });
  } catch (error) {
    const diag = await dbService.diagnoseConnectivity().catch(() => null);
    const durationMs = Date.now() - started;
    console.error('[readiness] error', {
      method: req.method,
      path: req.originalUrl,
      durationMs,
      error: error && (error.stack || error.message || String(error))
    });
    return res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      diagnosis: diag,
      build: buildInfo,
      durationMs,
    });
  }
}

// Readiness (backwards compatible): /health
app.get('/health', async (req, res) => handleReadiness(req, res));
// HEAD support for quick probes (lightweight readiness)
app.head('/health', async (req, res) => {
  try {
    await dbService.healthCheck();
    return res.sendStatus(200);
  } catch (_) {
    return res.sendStatus(503);
  }
});

// Liveness: fast, no DB
app.get('/live', (req, res) => {
  return res.status(200).json({ status: 'ok', timestamp: new Date().toISOString(), build: buildInfo });
});
app.head('/live', (req, res) => res.sendStatus(200));



// Test endpoint
app.get('/test', (req, res) => {
  res.json({ 
    message: 'Server is running!',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});



// Serve static files (uploaded images)

app.use('/uploads', express.static('uploads', {
  setHeaders: (res, path) => {
    // Set CORS headers for images
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET');
    res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  }
}));

// Alias: /api/health (same payload as /health)
app.get('/api/health', async (req, res) => handleReadiness(req, res));
// New aliases: /ready and /api/ready
app.get('/ready', async (req, res) => handleReadiness(req, res));
app.get('/api/ready', async (req, res) => handleReadiness(req, res));
app.head('/ready', async (req, res) => {
  try {
    await dbService.healthCheck();
    return res.sendStatus(200);
  } catch (_) {
    return res.sendStatus(503);
  }
});



// API routes
// const subscriptionRoutes = require('./routes/subscription'); // Not needed - already handled elsewhere

app.use('/api/auth', authRoutes);

app.use('/api/flutter/auth', flutterAuthRoutes);

app.use('/api/categories', categoryRoutes);

app.use('/api/subcategories', subcategoryRoutes);

app.use('/api/cities', cityRoutes);

app.use('/api/requests', requestRoutes);

app.use('/api/users', usersRoutes);
app.use('/api/reviews', reviewsRoutes); // Mount reviews for public profiles

app.use('/api/upload', uploadRoutes); // Image upload endpoint

app.use('/api/s3', uploadS3Routes); // S3 upload endpoints
app.use('/api/subscription', subscriptionRoutes); // Simple subscription system
app.use('/api/simple-subscription', simpleSubscriptionRoutes); // Simple subscription user endpoints
app.use('/api/admin/subscription', simpleSubscriptionAdminRoutes); // Simple subscription admin endpoints
app.use('/api/promo-codes', promoCodesRoutes); // NEW - Promo codes admin endpoints
// Entitlements API endpoints will be added at the end of the file

// Removed: subscription management routes
// const subscriptionManagementRoutes = require('./routes/subscription-management');
// app.use('/api/subscription-management', subscriptionManagementRoutes);
// Mount subscription plan admin routes (plans + per-country pricing)
// app.use('/api/subscription_plans_new', subscriptionPlansNewRoutes); // DEPRECATED
// Removed: /api/subscriptions (user subscription management not exposed here)
// Current user entitlements (for gating in app)
app.get('/api/me/entitlements', authService.authMiddleware(), async (req, res) => {
  const startTs = Date.now();
  const u = req.user || {};
  console.log('[entitlements-route] /api/me/entitlements start', {
    userId: u.id,
    role: u.role,
    ts: new Date().toISOString(),
    hasUser: !!u.id
  });
  if (!u.id) {
    // Dev-only viewer override to assist local testing without token
    if (process.env.NODE_ENV === 'development') {
      const headerId = req.headers['x-user-id'] || req.headers['user-id'];
      const queryId = req.query.viewer_id;
      const devId = (typeof headerId === 'string' && headerId.trim()) ? headerId.trim() : (typeof queryId === 'string' && queryId.trim() ? queryId.trim() : null);
      if (devId) {
        req.user = { id: devId, role: 'user' };
        console.warn('[entitlements-route] DEV viewer override in use (no auth)', { userId: devId });
      } else {
        console.warn('[entitlements-route] auth middleware provided no user id');
        return res.status(401).json({ success:false, error:'unauthorized' });
      }
    } else {
      console.warn('[entitlements-route] auth middleware provided no user id');
      return res.status(401).json({ success:false, error:'unauthorized' });
    }
  }
  try {
    // Use entitlements service
    const data = await entitlementsService.getEntitlements(u.id, u.role);
    console.log('[entitlements-route] success - using entitlements service');
    return res.json({ success: true, data });
  } catch (e) {
    console.error('[entitlements-route] ERROR', e && e.message || e);
    if (e && e.stack) console.error('[entitlements-route] STACK', e.stack);
    return res.status(500).json({ success:false, error:'failed', detail: e.message || String(e) });
  }
});

app.use('/api/chat', chatRoutes); // Chat endpoints

app.use('/api/country-modules', countryModuleRoutes);

app.use('/api/countries', countriesRoutes);

// Aliases for legacy mobile builds

app.use('/countries', countriesRoutes);

app.use('/api/v1/countries', countriesRoutes);

app.use('/api/brands', brandRoutes);

app.use('/api/master-products', masterProductRoutes);

app.use('/api/product-sync', productSyncRoutes);

app.use('/api/entity-activations', entityActivationRoutes);

// Removed: legacy subscription routes; using subscription-plans-new instead

app.use('/api', dashboardRoutes);

app.use('/api', customProductVariableRoutes);

app.use('/api/content-pages', contentPagesRoutes);

app.use('/api/responses', globalResponsesRoutes);

app.use('/api/sms', smsRoutes);

app.use('/api/notifications', notificationsRoutes);

app.use('/api/modules', modulesRoutes); // Module management endpoints

app.use('/api/price-listings', priceListingsRoutes); // Price listings endpoints

app.use('/api/price-staging', priceStagingRoutes); // Price staging system endpoints

app.use('/api/payment-methods', paymentMethodsRoutes); // Payment methods endpoints

app.use('/api/banners', bannersRoutes); // NEW - Banners CRUD

// Country-specific routes

app.use('/api/country-products', countryProductRoutes);

app.use('/api/country-categories', countryCategoryRoutes);

app.use('/api/country-subcategories', countrySubcategoryRoutes);

app.use('/api/country-brands', countryBrandRoutes);

app.use('/api/country-variable-types', countryVariableTypeRoutes);

app.use('/api/admin-users', adminUserRoutes);

// app.use('/api/driver-verifications', driverVerificationRoutes); // DISABLED - functionality moved to unified-verification

// app.use('/api/business-verifications', businessVerificationRoutes); // DISABLED - functionality moved to unified-verification

app.use('/api/business-categories', businessCategoriesRoutes); // NEW - Business categories management

app.use('/api/business-registration', businessRegistrationFormRoutes); // NEW - Business registration form data

app.use('/api/unified-verification', unifiedVerificationRoutes); // Unified verification service

app.use('/api/email-verification', emailVerificationRoutes); // Email OTP verification routes

app.use('/api/temp-migration', tempMigrationRoutes); // Temporary migration routes

app.use('/api/contact', contactRoutes);



// Mount SMS admin routes

try {

  console.log('📱 Mounting SMS admin routes...');

  const adminSMSRoutesModule = require('./routes/admin-sms');

  app.use('/api/admin', adminSMSRoutesModule);

  app.use('/api/admin/email-management', adminEmailManagementRoutes);

  console.log('✅ SMS admin routes mounted successfully');

} catch (error) {

  console.error('❌ Error mounting SMS admin routes:', error);

}



// Global error handler

app.use((err, req, res, next) => {

  console.error('Global error handler:', err);

    

  if (err.message === 'Not allowed by CORS') {

    return res.status(403).json({

      success: false,

      error: 'CORS policy violation',

      origin: req.get('Origin')

    });

  }

    

  res.status(500).json({

    success: false,

    error: 'Internal server error',

    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'

  });

});



// Simple ping endpoint for connectivity diagnostics

app.get('/api/ping', (req, res) => {

  res.json({ success: true, message: 'pong', time: new Date().toISOString() });

});



// Start server

const PORT = process.env.PORT || 3001;

const HOST = process.env.HOST || '0.0.0.0'; // Bind to all interfaces for Android emulator / devices

app.listen(PORT, HOST, () => {

  console.log(`🚀 Server running on ${HOST}:${PORT}`);

  console.log(`🔗 Health check: http://localhost:${PORT}/health`);

  console.log(`📊 API base: http://localhost:${PORT}/api`);

  console.log(`🤖 Android emulator: http://10.0.2.2:${PORT}/api`);

  console.log(`📶 Ping: http://localhost:${PORT}/api/ping`);

  console.log(`🌍 CORS allowed origins: ${allowedOrigins.join(', ')}`);

});

// Entitlements API endpoints - Using proper service
app.get('/api/entitlements-simple/me', async (req, res) => {
  try {
    const userId = req.query.user_id;
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'user_id parameter required'
      });
    }
    
    // Use entitlements service
    const entitlements = await entitlementsService.getEntitlements(userId);
    
    res.json({
      success: true,
      data: entitlements
    });
  } catch (error) {
    console.error('Error getting user entitlements:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get entitlements'
    });
  }
});

app.get('/api/entitlements/me', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }
    
    // Use entitlements service
    const entitlements = await entitlementsService.getEntitlements(userId);
    
    res.json({
      success: true,
      data: entitlements
    });
  } catch (error) {
    console.error('Error getting user entitlements:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get entitlements'
    });
  }
});

// 404 handler LAST - must be after all route definitions
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found',
    path: req.originalUrl,
    method: req.method
  });
});

module.exports = app;
