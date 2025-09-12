# Troubleshooting & FAQ Guide - Subscription & Payment Gateway System

## Table of Contents

1. [Common Issues & Solutions](#common-issues--solutions)
2. [Backend API Troubleshooting](#backend-api-troubleshooting)
3. [Frontend Admin Panel Issues](#frontend-admin-panel-issues)
4. [Flutter Mobile App Issues](#flutter-mobile-app-issues)
5. [Database Issues](#database-issues)
6. [Payment Gateway Issues](#payment-gateway-issues)
7. [Authentication Problems](#authentication-problems)
8. [Performance Issues](#performance-issues)
9. [Deployment Issues](#deployment-issues)
10. [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)

---

## Common Issues & Solutions

### 1. Server Won't Start

**Symptoms:**
- `Error: Cannot find module` errors
- Port already in use errors
- Database connection failures

**Solutions:**

```bash
# Check if port is in use
netstat -an | findstr :3001

# Kill process using port
taskkill /PID <process_id> /F

# Install missing dependencies
cd backend
npm install

# Check environment variables
echo $NODE_ENV
cat .env.rds
```

**Environment File Check:**
```bash
# Verify all required environment variables
grep -E "(DATABASE_URL|JWT_SECRET|GATEWAY_ENCRYPTION_KEY)" .env.rds
```

### 2. Authentication Token Errors

**Symptoms:**
- `authenticateToken is not defined`
- `TypeError: Cannot read property 'authMiddleware' of undefined`

**Solution:**
```javascript
// Correct import in route files
const auth = require('../utils/auth');

// Use middleware correctly
router.get('/protected-route', auth.authMiddleware, (req, res) => {
  // Route handler
});
```

### 3. Database Connection Issues

**Symptoms:**
- `ECONNREFUSED` errors
- `password authentication failed`
- `database does not exist`

**Solutions:**

```bash
# Check PostgreSQL service
sudo systemctl status postgresql
sudo systemctl start postgresql

# Test database connection
psql -h localhost -U username -d request_marketplace

# Create database if missing
createdb request_marketplace

# Check connection string format
DATABASE_URL=postgresql://username:password@host:port/database
```

### 4. CORS Issues

**Symptoms:**
- `Access-Control-Allow-Origin` errors in browser console
- Frontend can't connect to backend API

**Solution:**
```javascript
// In backend/app.js
const cors = require('cors');

app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://localhost:3001',
    'http://3.92.216.149:3001',
    'https://yourdomain.com'
  ],
  credentials: true
}));
```

---

## Backend API Troubleshooting

### Server Startup Issues

#### Issue: Module Import Errors
```bash
Error: Cannot find module '../utils/auth'
```

**Solution:**
```bash
# Check file structure
ls -la backend/utils/
ls -la backend/middleware/

# Correct import path
const auth = require('../middleware/auth'); // or correct path
```

#### Issue: Environment Variables Not Loading
```bash
# Debug environment loading
console.log('Environment variables:', {
  NODE_ENV: process.env.NODE_ENV,
  DATABASE_URL: process.env.DATABASE_URL ? 'Set' : 'Not set',
  JWT_SECRET: process.env.JWT_SECRET ? 'Set' : 'Not set'
});
```

### Database Query Issues

#### Issue: Table Does Not Exist
```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%subscription%';

-- Run migrations if missing
\i backend/database/migrations/enhance_subscription_tracking.sql
\i backend/database/migrations/create_payment_gateways.sql
```

#### Issue: Column Does Not Exist
```sql
-- Check table structure
\d+ simple_subscription_plans
\d+ simple_subscription_country_pricing

-- Add missing columns
ALTER TABLE simple_subscription_plans 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
```

### API Response Issues

#### Issue: Empty Response or 500 Errors
```javascript
// Add error logging
app.use((err, req, res, next) => {
  console.error('API Error:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    body: req.body
  });
  
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});
```

#### Issue: Authentication Middleware Not Working
```javascript
// Debug authentication
const authMiddleware = (req, res, next) => {
  console.log('Auth middleware - Headers:', req.headers.authorization);
  
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    console.log('No token provided');
    return res.status(401).json({ error: 'No token provided' });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('Token decoded:', decoded);
    req.user = decoded;
    next();
  } catch (error) {
    console.log('Token verification failed:', error.message);
    res.status(401).json({ error: 'Invalid token' });
  }
};
```

---

## Frontend Admin Panel Issues

### React Component Issues

#### Issue: Components Not Rendering
```javascript
// Check React Developer Tools
// Add debug logging

useEffect(() => {
  console.log('Component mounted');
  console.log('Auth context:', authContext);
  console.log('User data:', authContext.user);
}, []);
```

#### Issue: API Calls Failing
```javascript
// Debug API service
const apiService = {
  async request(endpoint, options = {}) {
    const url = `${process.env.REACT_APP_API_BASE_URL}${endpoint}`;
    console.log('API Request:', { url, options });
    
    try {
      const response = await fetch(url, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${getToken()}`,
          ...options.headers
        },
        ...options
      });
      
      console.log('API Response:', { status: response.status, url });
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error('API Error Response:', errorText);
        throw new Error(`API Error: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error('API Request Failed:', error);
      throw error;
    }
  }
};
```

### Material-UI Issues

#### Issue: Styling Not Applied
```bash
# Check Material-UI installation
npm ls @mui/material @emotion/react @emotion/styled

# Reinstall if needed
npm uninstall @mui/material @emotion/react @emotion/styled
npm install @mui/material @emotion/react @emotion/styled
```

#### Issue: Theme Not Working
```javascript
// Debug theme
import { createTheme, ThemeProvider } from '@mui/material/styles';

const theme = createTheme({
  // Add debug
  breakpoints: {
    values: {
      xs: 0,
      sm: 600,
      md: 900,
      lg: 1200,
      xl: 1536,
    },
  },
});

console.log('Theme created:', theme);
```

### State Management Issues

#### Issue: Context State Not Updating
```javascript
// Debug context provider
const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  
  useEffect(() => {
    console.log('AuthProvider - User state changed:', user);
  }, [user]);
  
  const login = async (credentials) => {
    console.log('Login attempt:', credentials);
    try {
      const response = await authService.login(credentials);
      console.log('Login response:', response);
      setUser(response.user);
      localStorage.setItem('token', response.token);
    } catch (error) {
      console.error('Login failed:', error);
      throw error;
    }
  };
  
  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};
```

---

## Flutter Mobile App Issues

### Build Issues

#### Issue: Flutter Build Fails
```bash
# Clean build cache
flutter clean
flutter pub get

# Check Flutter doctor
flutter doctor -v

# Check for dependency conflicts
flutter pub deps
```

#### Issue: Android Build Errors
```bash
# Check Android SDK
flutter doctor --android-licenses

# Clean Android build
cd android
./gradlew clean
cd ..
flutter build apk --debug
```

#### Issue: iOS Build Errors (macOS only)
```bash
# Update CocoaPods
cd ios
pod install --repo-update
cd ..

# Clean iOS build
flutter clean
flutter build ios --debug
```

### Network Connectivity Issues

#### Issue: API Calls Not Working
```dart
// Debug HTTP client
class ApiClient {
  static const String baseUrl = 'http://10.0.2.2:3001/api'; // For Android emulator
  // static const String baseUrl = 'http://localhost:3001/api'; // For iOS simulator
  
  static Future<http.Response> get(String endpoint) async {
    final url = '$baseUrl$endpoint';
    print('API GET: $url');
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await getToken()}',
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      return response;
    } catch (error) {
      print('API Error: $error');
      rethrow;
    }
  }
}
```

#### Issue: Certificate Verification Failed
```dart
// For development only - bypass SSL verification
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// In main.dart
void main() {
  HttpOverrides.global = MyHttpOverrides(); // Only for development
  runApp(MyApp());
}
```

### State Management Issues

#### Issue: Provider State Not Updating
```dart
// Debug provider
class SubscriptionProvider extends ChangeNotifier {
  List<SubscriptionPlan> _plans = [];
  
  List<SubscriptionPlan> get plans => _plans;
  
  Future<void> loadPlans(String countryCode) async {
    print('Loading plans for country: $countryCode');
    try {
      final plansData = await subscriptionService.getSubscriptionPlans(countryCode);
      _plans = plansData.map((data) => SubscriptionPlan.fromJson(data)).toList();
      print('Loaded ${_plans.length} plans');
      notifyListeners();
    } catch (error) {
      print('Failed to load plans: $error');
      rethrow;
    }
  }
}
```

### Widget Issues

#### Issue: UI Not Updating
```dart
// Use Consumer widget to rebuild on state changes
Consumer<SubscriptionProvider>(
  builder: (context, provider, child) {
    print('Building subscription list, plans: ${provider.plans.length}');
    
    if (provider.plans.isEmpty) {
      return CircularProgressIndicator();
    }
    
    return ListView.builder(
      itemCount: provider.plans.length,
      itemBuilder: (context, index) {
        final plan = provider.plans[index];
        return ListTile(
          title: Text(plan.name),
          subtitle: Text('${plan.currency} ${plan.price}'),
        );
      },
    );
  },
)
```

---

## Database Issues

### Connection Problems

#### Issue: PostgreSQL Won't Start
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Start PostgreSQL
sudo systemctl start postgresql

# Enable auto-start
sudo systemctl enable postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log
```

#### Issue: Connection Refused
```bash
# Check if PostgreSQL is listening
sudo netstat -tlnp | grep :5432

# Check PostgreSQL configuration
sudo nano /etc/postgresql/13/main/postgresql.conf
# Ensure: listen_addresses = '*'

sudo nano /etc/postgresql/13/main/pg_hba.conf
# Add: host all all 0.0.0.0/0 md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Table/Schema Issues

#### Issue: Missing Tables
```sql
-- Check existing tables
\dt

-- Run all migrations
\i backend/database/migrations/enhance_subscription_tracking.sql
\i backend/database/migrations/create_payment_gateways.sql

-- Verify tables created
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

#### Issue: Foreign Key Constraints
```sql
-- Check constraint violations
SELECT conname, conrelid::regclass, confrelid::regclass
FROM pg_constraint 
WHERE contype = 'f';

-- Drop and recreate if needed
ALTER TABLE simple_subscription_country_pricing 
DROP CONSTRAINT IF EXISTS simple_subscription_country_pricing_plan_code_fkey;

ALTER TABLE simple_subscription_country_pricing 
ADD CONSTRAINT simple_subscription_country_pricing_plan_code_fkey 
FOREIGN KEY (plan_code) REFERENCES simple_subscription_plans(code);
```

### Performance Issues

#### Issue: Slow Queries
```sql
-- Enable query logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_min_duration_statement = 1000; -- Log queries > 1 second
SELECT pg_reload_conf();

-- Check slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Add missing indexes
CREATE INDEX CONCURRENTLY idx_user_subscriptions_user_id 
ON user_simple_subscriptions(user_id);

CREATE INDEX CONCURRENTLY idx_country_pricing_country_plan 
ON simple_subscription_country_pricing(country_code, plan_code);
```

#### Issue: High Memory Usage
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('request_marketplace'));

-- Check table sizes
SELECT 
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Vacuum and analyze
VACUUM ANALYZE;
```

---

## Payment Gateway Issues

### Stripe Integration

#### Issue: Stripe Keys Not Working
```javascript
// Test Stripe connection
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

async function testStripe() {
  try {
    const account = await stripe.accounts.retrieve();
    console.log('Stripe account:', account.id);
  } catch (error) {
    console.error('Stripe error:', error.message);
  }
}
```

#### Issue: Webhook Verification Failed
```javascript
// Debug webhook signature
app.post('/api/webhooks/stripe', express.raw({type: 'application/json'}), (req, res) => {
  const sig = req.headers['stripe-signature'];
  console.log('Webhook signature:', sig);
  console.log('Webhook secret:', process.env.STRIPE_WEBHOOK_SECRET);
  
  try {
    const event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
    console.log('Webhook event:', event.type);
    // Handle event
    res.json({received: true});
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
  }
});
```

### PayPal Integration

#### Issue: PayPal Authentication Failed
```javascript
// Test PayPal credentials
const paypal = require('@paypal/checkout-server-sdk');

const clientId = process.env.PAYPAL_CLIENT_ID;
const clientSecret = process.env.PAYPAL_CLIENT_SECRET;
const environment = process.env.PAYPAL_ENVIRONMENT === 'live' 
  ? new paypal.core.LiveEnvironment(clientId, clientSecret)
  : new paypal.core.SandboxEnvironment(clientId, clientSecret);

const client = new paypal.core.PayPalHttpClient(environment);

async function testPayPal() {
  try {
    const request = new paypal.orders.OrdersGetRequest('test-order-id');
    const response = await client.execute(request);
    console.log('PayPal connection successful');
  } catch (error) {
    console.error('PayPal error:', error.message);
  }
}
```

### Gateway Configuration Issues

#### Issue: Encrypted Credentials Not Decrypting
```javascript
// Debug encryption/decryption
const crypto = require('crypto');

function testEncryption() {
  const key = process.env.GATEWAY_ENCRYPTION_KEY;
  console.log('Encryption key length:', key ? key.length : 'undefined');
  
  if (!key || key.length !== 32) {
    throw new Error('Encryption key must be 32 characters long');
  }
  
  const testData = { api_key: 'test_key_12345' };
  
  try {
    // Encrypt
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher('aes-256-cbc', key);
    let encrypted = cipher.update(JSON.stringify(testData), 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    console.log('Encryption successful');
    
    // Decrypt
    const decipher = crypto.createDecipher('aes-256-cbc', key);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    const result = JSON.parse(decrypted);
    console.log('Decryption successful:', result);
    
  } catch (error) {
    console.error('Encryption/Decryption error:', error.message);
  }
}
```

---

## Authentication Problems

### JWT Token Issues

#### Issue: Token Expired or Invalid
```javascript
// Debug JWT
const jwt = require('jsonwebtoken');

function debugToken(token) {
  try {
    const decoded = jwt.decode(token);
    console.log('Token payload:', decoded);
    console.log('Token expires:', new Date(decoded.exp * 1000));
    console.log('Current time:', new Date());
    
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    console.log('Token verified successfully');
    return verified;
  } catch (error) {
    console.error('Token error:', error.message);
    if (error.name === 'TokenExpiredError') {
      console.log('Token has expired');
    } else if (error.name === 'JsonWebTokenError') {
      console.log('Token is invalid');
    }
    throw error;
  }
}
```

#### Issue: User Session Lost
```javascript
// Frontend: Check localStorage
function checkAuthState() {
  const token = localStorage.getItem('token');
  console.log('Stored token:', token ? 'exists' : 'not found');
  
  if (token) {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      console.log('Token payload:', payload);
      console.log('Token expires:', new Date(payload.exp * 1000));
      
      if (payload.exp * 1000 < Date.now()) {
        console.log('Token has expired, removing');
        localStorage.removeItem('token');
        return null;
      }
      
      return payload;
    } catch (error) {
      console.error('Invalid token format:', error);
      localStorage.removeItem('token');
      return null;
    }
  }
  
  return null;
}
```

### Role-Based Access Issues

#### Issue: Insufficient Permissions
```javascript
// Debug user permissions
function checkPermissions(req, res, next) {
  console.log('User object:', req.user);
  console.log('Required role:', req.route.path);
  console.log('User role:', req.user?.role);
  console.log('User country:', req.user?.country_code);
  
  if (req.user?.role !== 'country_admin') {
    console.log('Access denied: insufficient role');
    return res.status(403).json({ error: 'Insufficient permissions' });
  }
  
  next();
}
```

---

## Performance Issues

### Database Performance

#### Issue: Slow API Responses
```sql
-- Monitor query performance
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  rows
FROM pg_stat_statements 
WHERE calls > 100
ORDER BY mean_time DESC
LIMIT 10;

-- Add indexes for common queries
CREATE INDEX CONCURRENTLY idx_user_subscriptions_status 
ON user_simple_subscriptions(status) WHERE status = 'active';

CREATE INDEX CONCURRENTLY idx_usage_monthly_user_month 
ON usage_monthly(user_id, year_month);
```

#### Issue: Memory Usage High
```bash
# Check PostgreSQL memory settings
sudo -u postgres psql -c "SHOW shared_buffers;"
sudo -u postgres psql -c "SHOW effective_cache_size;"

# Optimize PostgreSQL memory (in postgresql.conf)
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB
```

### Application Performance

#### Issue: High CPU Usage
```bash
# Monitor Node.js process
top -p `pgrep node`

# Check for memory leaks
node --max-old-space-size=4096 server.js

# Profile application
node --prof server.js
# Generate profile report
node --prof-process isolate-*.log > profile.txt
```

#### Issue: Slow Frontend Loading
```bash
# Analyze bundle size
cd admin-react
npm run build
npx webpack-bundle-analyzer build/static/js/*.js

# Optimize React app
# Use React.memo for expensive components
# Implement code splitting
# Lazy load components
```

---

## Deployment Issues

### Production Server Issues

#### Issue: PM2 Process Crashes
```bash
# Check PM2 logs
pm2 logs request-backend

# Restart application
pm2 restart request-backend

# Check PM2 status
pm2 status

# Monitor PM2 processes
pm2 monit
```

#### Issue: Nginx Configuration
```bash
# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Verify proxy pass working
curl -H "Host: yourdomain.com" http://localhost/api/health
```

### SSL Certificate Issues

#### Issue: Certificate Expired
```bash
# Check certificate expiry
openssl x509 -in /etc/letsencrypt/live/yourdomain.com/cert.pem -text -noout | grep "Not After"

# Renew certificate
sudo certbot renew --dry-run
sudo certbot renew

# Restart services
sudo systemctl restart nginx
```

### Environment Configuration

#### Issue: Production Environment Variables
```bash
# Check environment file
cat /var/www/request/backend/.env.rds

# Verify environment in application
node -e "
require('dotenv').config({ path: '.env.rds' });
console.log('NODE_ENV:', process.env.NODE_ENV);
console.log('DATABASE_URL:', process.env.DATABASE_URL ? 'Set' : 'Not set');
console.log('JWT_SECRET:', process.env.JWT_SECRET ? 'Set' : 'Not set');
"
```

---

## Frequently Asked Questions (FAQ)

### General Questions

**Q: How do I reset the database completely?**
```bash
# Drop and recreate database
dropdb request_marketplace
createdb request_marketplace

# Run migrations
cd backend
node -e "
const fs = require('fs');
const db = require('./services/database');
async function runMigrations() {
  const sql1 = fs.readFileSync('./database/migrations/enhance_subscription_tracking.sql', 'utf8');
  await db.query(sql1);
  const sql2 = fs.readFileSync('./database/migrations/create_payment_gateways.sql', 'utf8');
  await db.query(sql2);
  console.log('Migrations completed');
  process.exit(0);
}
runMigrations().catch(console.error);
"
```

**Q: How do I create a super admin user?**
```sql
-- Insert super admin directly into database
INSERT INTO users (id, email, password_hash, first_name, last_name, role, is_verified)
VALUES (
  gen_random_uuid(),
  'superadmin@company.com',
  '$2b$10$encrypted_password_hash_here',
  'Super',
  'Admin',
  'super_admin',
  true
);
```

**Q: How do I backup and restore the database?**
```bash
# Backup
pg_dump request_marketplace > backup_$(date +%Y%m%d).sql

# Restore
psql request_marketplace < backup_20231215.sql

# Backup with compression
pg_dump request_marketplace | gzip > backup_$(date +%Y%m%d).sql.gz

# Restore from compressed backup
gunzip -c backup_20231215.sql.gz | psql request_marketplace
```

### Subscription System

**Q: How do I add a new subscription plan?**
```sql
-- Add new plan template
INSERT INTO simple_subscription_plans (code, name, description, default_price, default_currency, default_response_limit)
VALUES ('Premium', 'Premium Plan', 'Advanced features for power users', 19.99, 'USD', -1);

-- Add country-specific pricing
INSERT INTO simple_subscription_country_pricing (plan_code, country_code, price, currency, response_limit, approval_status)
VALUES ('Premium', 'US', 19.99, 'USD', -1, 'approved');
```

**Q: How do I check a user's subscription status?**
```sql
SELECT 
  u.email,
  us.plan_code,
  us.status,
  us.expires_at,
  p.name as plan_name,
  cp.price,
  cp.currency
FROM users u
LEFT JOIN user_simple_subscriptions us ON u.id = us.user_id
LEFT JOIN simple_subscription_plans p ON us.plan_code = p.code
LEFT JOIN simple_subscription_country_pricing cp ON p.code = cp.plan_code AND us.country_code = cp.country_code
WHERE u.email = 'user@example.com';
```

**Q: How do I manually expire a subscription?**
```sql
UPDATE user_simple_subscriptions 
SET status = 'expired', expires_at = CURRENT_TIMESTAMP
WHERE user_id = (SELECT id FROM users WHERE email = 'user@example.com');
```

### Payment Gateway

**Q: How do I test payment gateway configuration?**
```bash
# Test Stripe configuration
curl -X POST "http://localhost:3001/api/admin/payment-gateways/configure" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer admin-token" \
  -d '{
    "country_code": "US",
    "payment_gateway_id": 1,
    "configuration": {
      "api_key": "pk_test_...",
      "secret_key": "sk_test_..."
    }
  }'
```

**Q: How do I switch primary payment gateway for a country?**
```sql
-- Remove primary flag from all gateways for country
UPDATE country_payment_gateways 
SET is_primary = false 
WHERE country_code = 'US';

-- Set new primary gateway
UPDATE country_payment_gateways 
SET is_primary = true 
WHERE country_code = 'US' AND payment_gateway_id = 2;
```

**Q: How do I view encrypted payment gateway credentials?**
```javascript
// In backend console
const db = require('./services/database');
const { decryptGatewayConfig } = require('./utils/encryption');

async function viewCredentials() {
  const result = await db.query(
    'SELECT configuration FROM country_payment_gateways WHERE country_code = $1',
    ['US']
  );
  
  if (result.rows.length > 0) {
    const decrypted = decryptGatewayConfig(result.rows[0].configuration);
    console.log('Decrypted credentials:', decrypted);
  }
}
```

### Authentication & Security

**Q: How do I generate a new JWT secret?**
```bash
# Generate secure random string
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

# Or use openssl
openssl rand -hex 64
```

**Q: How do I rotate encryption keys?**
```bash
# 1. Generate new key
NEW_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# 2. Update environment
echo "GATEWAY_ENCRYPTION_KEY_NEW=$NEW_KEY" >> .env.rds

# 3. Migration script to re-encrypt with new key
node -e "
const db = require('./services/database');
const crypto = require('crypto');

async function migrateEncryption() {
  const oldKey = process.env.GATEWAY_ENCRYPTION_KEY;
  const newKey = process.env.GATEWAY_ENCRYPTION_KEY_NEW;
  
  const gateways = await db.query('SELECT id, configuration FROM country_payment_gateways');
  
  for (const gateway of gateways.rows) {
    // Decrypt with old key
    const decipher = crypto.createDecipher('aes-256-cbc', oldKey);
    let decrypted = decipher.update(gateway.configuration, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    // Encrypt with new key
    const cipher = crypto.createCipher('aes-256-cbc', newKey);
    let encrypted = cipher.update(decrypted, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    // Update database
    await db.query('UPDATE country_payment_gateways SET configuration = $1 WHERE id = $2',
      [encrypted, gateway.id]);
  }
  
  console.log('Encryption migration completed');
}
"
```

### Flutter App

**Q: How do I debug API connectivity in Flutter?**
```dart
// Add to main.dart for debugging
void main() {
  debugPrint('App starting...');
  
  // Enable HTTP logging
  if (kDebugMode) {
    HttpOverrides.global = MyHttpOverrides();
  }
  
  runApp(MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        print('Certificate for $host:$port');
        return true; // Only for development
      };
  }
}
```

**Q: How do I clear Flutter app data during development?**
```bash
# Clear app data on device/emulator
flutter clean
flutter pub get

# For Android emulator
adb shell pm clear com.example.request

# For iOS simulator
xcrun simctl uninstall booted com.example.request
```

---

## Emergency Procedures

### System Down Emergency

1. **Check server status:**
```bash
curl -I http://your-domain.com/health
pm2 status
sudo systemctl status nginx postgresql
```

2. **Quick restart procedure:**
```bash
pm2 restart all
sudo systemctl restart nginx
sudo systemctl restart postgresql
```

3. **Check logs immediately:**
```bash
pm2 logs --lines 50
tail -n 50 /var/log/nginx/error.log
sudo tail -n 50 /var/log/postgresql/postgresql-*.log
```

### Data Corruption Emergency

1. **Immediate backup:**
```bash
pg_dump request_marketplace > emergency_backup_$(date +%Y%m%d_%H%M%S).sql
```

2. **Check data integrity:**
```sql
-- Check for orphaned records
SELECT COUNT(*) FROM user_simple_subscriptions us
LEFT JOIN users u ON us.user_id = u.id
WHERE u.id IS NULL;

-- Check for missing foreign key references
SELECT COUNT(*) FROM simple_subscription_country_pricing cp
LEFT JOIN simple_subscription_plans p ON cp.plan_code = p.code
WHERE p.code IS NULL;
```

3. **Contact procedures:**
   - Notify development team immediately
   - Document all symptoms and error messages
   - Preserve logs and database state
   - Prepare rollback plan if necessary

---

This troubleshooting guide should help you resolve most common issues with the subscription and payment gateway system. For issues not covered here, please contact the development team with detailed error logs and reproduction steps.
