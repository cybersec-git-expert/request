const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config({ path: '.env.rds' });

// Import services
const dbService = require('./services/database');

// Import routes
const authRoutes = require('./routes/auth');
const flutterAuthRoutes = require('./routes/flutter-auth');
const categoryRoutes = require('./routes/categories');
const subcategoryRoutes = require('./routes/subcategories');
const countryModuleRoutes = require('./routes/country-modules');
const cityRoutes = require('./routes/cities');
const requestRoutes = require('./routes/requests');
const vehicleTypeRoutes = require('./routes/vehicle-types');
const brandRoutes = require('./routes/brands');
const masterProductRoutes = require('./routes/master-products');
const entityActivationRoutes = require('./routes/entity-activations');
const subscriptionPlansNewRoutes = require('./routes/subscription-plans-new');

// New country-specific routes
const countryProductRoutes = require('./routes/country-products');
const countryCategoryRoutes = require('./routes/country-categories');
const countrySubcategoryRoutes = require('./routes/country-subcategories');
const countryBrandRoutes = require('./routes/country-brands');
const countryVariableTypeRoutes = require('./routes/country-variable-types');
const adminUserRoutes = require('./routes/admin-users');

const app = express();

// Security middleware
app.use(helmet());

// CORS setup: always include common dev origins, merge with ALLOWED_ORIGINS if provided
const defaultOrigins = ['http://localhost:3000', 'http://localhost:5173'];
const envOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim()).filter(Boolean)
    : [];
const allowedOrigins = Array.from(new Set([...defaultOrigins, ...envOrigins]));
app.use(cors({
        origin: (origin, callback) => {
                // Allow non-browser or same-origin requests (like curl / server-to-server)
                if (!origin) return callback(null, true);
                if (allowedOrigins.includes(origin)) return callback(null, true);
                console.warn(`CORS blocked origin: ${origin}`);
                return callback(new Error('Not allowed by CORS'));
        },
        credentials: true
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: {
        error: 'Too many requests from this IP, please try again later.'
    }
});
app.use('/api/', limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging middleware
app.use(morgan('combined'));

// Health check endpoint
app.get('/health', async (req, res) => {
    try {
        const dbHealth = await dbService.healthCheck();
        if (dbHealth.status !== 'healthy') {
            const diag = await dbService.diagnoseConnectivity();
            return res.status(503).json({
                status: 'unhealthy',
                database: dbHealth,
                diagnostics: diag
            });
        }

        res.json({
            status: 'healthy',
            database: dbHealth,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('Health check error:', error);
        res.status(503).json({
            status: 'unhealthy',
            error: error.message
        });
    }
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/auth', flutterAuthRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/subcategories', subcategoryRoutes);
app.use('/api/cities', cityRoutes);
app.use('/api/requests', requestRoutes);
app.use('/api/vehicle-types', vehicleTypeRoutes);
app.use('/api/country-modules', countryModuleRoutes);
app.use('/api/brands', brandRoutes);
app.use('/api/master-products', masterProductRoutes);
app.use('/api/entity-activations', entityActivationRoutes);
app.use('/api/subscription-plans-new', subscriptionPlansNewRoutes);

// Country-specific routes
app.use('/api/country-products', countryProductRoutes);
app.use('/api/country-categories', countryCategoryRoutes);
app.use('/api/country-subcategories', countrySubcategoryRoutes);
app.use('/api/country-brands', countryBrandRoutes);
app.use('/api/country-variable-types', countryVariableTypeRoutes);
app.use('/api/admin-users', adminUserRoutes);

// Generic catch-all for API routes not found
app.use('/api/*', (req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found'
    });
});

// Generic error handler
app.use((err, req, res, next) => {
    console.error('Express error:', err);
    res.status(500).json({
        success: false,
        error: err.message || 'Internal server error'
    });
});

// Start server
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🔗 Health check: http://localhost:${PORT}/health`);
    console.log(`📊 API base: http://localhost:${PORT}/api`);
    console.log(`🌍 CORS allowed origins: ${allowedOrigins.join(', ')}`);
});

module.exports = app;
                status: 'unhealthy',
                timestamp: new Date().toISOString(),
                database: dbHealth,
                diagnosis: diag
            });
        }
        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            database: dbHealth,
            version: process.env.npm_package_version || '1.0.0'
        });
    } catch (error) {
        const diag = await dbService.diagnoseConnectivity().catch(()=>null);
        res.status(503).json({
            status: 'unhealthy',
            error: error.message,
            timestamp: new Date().toISOString(),
            diagnosis: diag
        });
    }
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/auth', flutterAuthRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/subcategories', subcategoryRoutes);
app.use('/api/cities', cityRoutes);
app.use('/api/requests', requestRoutes);
app.use('/api/vehicle-types', vehicleTypeRoutes);
app.use('/api/country-modules', countryModuleRoutes);
app.use('/api/brands', brandRoutes);
app.use('/api/master-products', masterProductRoutes);
app.use('/api/entity-activations', entityActivationRoutes);
app.use('/api/subscription-plans-new', subscriptionPlansNewRoutes);

// Country-specific routes
app.use('/api/country-products', countryProductRoutes);
app.use('/api/country-categories', countryCategoryRoutes);
app.use('/api/country-subcategories', countrySubcategoryRoutes);
app.use('/api/country-brands', countryBrandRoutes);
app.use('/api/country-variable-types', countryVariableTypeRoutes);
app.use('/api/admin-users', adminUserRoutes);

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found'
    });
});

// Global error handler
app.use((error, req, res, next) => {
    console.error('Global error handler:', error);
    
    res.status(error.statusCode || 500).json({
        success: false,
        error: process.env.NODE_ENV === 'production' 
            ? 'Internal server error' 
            : error.message,
        ...(process.env.NODE_ENV !== 'production' && { stack: error.stack })
    });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('SIGTERM received, shutting down gracefully');
    
    try {
        await dbService.close();
        console.log('Database connections closed');
        process.exit(0);
    } catch (error) {
        console.error('Error during shutdown:', error);
        process.exit(1);
    }
});

process.on('SIGINT', async () => {
    console.log('SIGINT received, shutting down gracefully');
    
    try {
        await dbService.close();
        console.log('Database connections closed');
        process.exit(0);
    } catch (error) {
        console.error('Error during shutdown:', error);
        process.exit(1);
    }
});

// Startup DB connectivity check
(async () => {
    try {
        const healthy = await dbService.healthCheck();
        if (healthy.status !== 'healthy') {
            console.error('Database not healthy at startup:', healthy);
        } else {
            console.log('Database connection OK at startup');
        }
    } catch (e) {
        console.error('Failed initial DB connectivity check:', e);
    }
})();

// Preferred port logic: try desired (PORT or 3001). If in use and AUTO_FALLBACK not disabled, try fallback (3010 or FALLBACK_PORT)
const desiredPort = process.env.ENV_FORCE_PORT || process.env.PORT || '3001';
const fallbackPort = process.env.FALLBACK_PORT || '3010';
let attemptedFallback = false;

function start(port){
    const server = app.listen(port, () => {
        console.log(`🚀 Server running on port ${port}`);
        console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
        console.log(`🔗 Health check: http://localhost:${port}/health`);
    });
    server.on('error', (err) => {
        if(err.code === 'EADDRINUSE' && !attemptedFallback && process.env.AUTO_FALLBACK !== 'false'){
            console.warn(`Port ${port} in use. Attempting fallback ${fallbackPort}...`);
            attemptedFallback = true;
            setTimeout(()=> start(fallbackPort), 500);
        } else {
            console.error('Failed to start server:', err);
            process.exit(1);
        }
    });
}
start(desiredPort);

module.exports = app;
