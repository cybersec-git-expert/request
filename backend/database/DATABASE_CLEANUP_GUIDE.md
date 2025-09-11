# Database Cleanup Guide - Remove Ride/Driver Functionality

## 🚨 **IMPORTANT: BACKUP YOUR DATABASE FIRST!**

Before running any cleanup scripts, create a complete backup of your database:

```bash
# PostgreSQL backup
pg_dump -h your_host -U your_user -d your_database > backup_before_cleanup.sql

# Or if using local PostgreSQL
pg_dump your_database_name > backup_before_cleanup.sql
```

## 📋 **Tables to be Removed**

The cleanup script will remove these ride/driver-related tables:

### 🗑️ **Tables to Delete:**
- `driver_document_audit` - Driver document verification audit trail
- `driver_verifications` - Driver verification status and documents  
- `country_vehicles` - Vehicle listings by country
- `country_vehicle_types` - Vehicle type configurations per country
- `vehicle_types` - Master vehicle types table

### 🧹 **Data Cleanup:**
The script will also clean up ride-related data from:
- `categories` - Remove ride/driver/vehicle/transport categories
- `business_types` - Remove ride/driver business types
- `master_products` - Remove ride/driver/vehicle products
- `country_categories` - Remove country-specific ride categories
- `country_products` - Remove country-specific ride products
- `subscription_plans` - Remove driver/ride subscription plans
- `requests` - Convert ride requests to service requests (preserves data)

## 🚀 **How to Run the Cleanup**

### Option 1: Using psql command line
```bash
# Connect to your database
psql -h your_host -U your_user -d your_database

# Run the cleanup script
\i backend/database/migrations/999_cleanup_ride_tables.sql
```

### Option 2: Using your database admin tool
1. Open your database admin tool (pgAdmin, DBeaver, etc.)
2. Connect to your database
3. Open and execute the file: `backend/database/migrations/999_cleanup_ride_tables.sql`

### Option 3: Using Node.js script
```bash
# Navigate to backend directory
cd backend

# Run cleanup via Node.js (if you have a database connection)
node -e "
const fs = require('fs');
const sql = fs.readFileSync('./database/migrations/999_cleanup_ride_tables.sql', 'utf8');
// Execute sql using your database client
console.log('SQL script ready to execute');
"
```

## ✅ **What Happens After Cleanup**

### 🎯 **Preserved Data:**
- All user accounts and authentication data
- All requests and responses (ride requests converted to service requests)
- All business registrations and verifications
- All payment and subscription data (except ride-specific plans)
- All location and country configuration data

### 🗑️ **Removed Data:**
- All driver verification records
- All vehicle type configurations
- All ride-specific categories and products
- All ride-specific subscription plans
- All driver document audit trails

## 🔍 **Verification Steps**

After running the cleanup, verify the changes:

```sql
-- Check that tables are gone
SELECT table_name FROM information_schema.tables 
WHERE table_name IN ('driver_document_audit', 'driver_verifications', 'country_vehicles', 'country_vehicle_types', 'vehicle_types');

-- Should return no rows

-- Check that ride-related data is cleaned up
SELECT COUNT(*) FROM categories WHERE LOWER(name) LIKE '%ride%';
SELECT COUNT(*) FROM business_types WHERE LOWER(name) LIKE '%driver%';
SELECT COUNT(*) FROM master_products WHERE LOWER(name) LIKE '%vehicle%';

-- All should return 0

-- Check requests are converted
SELECT DISTINCT request_type FROM requests;
-- Should not include 'ride'
```

## 🔄 **Rollback Plan**

If you need to rollback:

1. **Restore from backup:**
   ```bash
   # Drop current database (BE VERY CAREFUL!)
   dropdb your_database_name
   
   # Create new database
   createdb your_database_name
   
   # Restore from backup
   psql your_database_name < backup_before_cleanup.sql
   ```

2. **Or restore just the deleted tables** if you have individual table backups

## 📊 **Expected Results**

After cleanup, your database will be:
- ✅ **Simplified** - No ride/driver complexity
- ✅ **Focused** - Only core business functionality remains
- ✅ **Clean** - No orphaned ride-related data
- ✅ **Optimized** - Smaller database size and better performance

## 🎯 **Next Steps**

1. Run the cleanup script
2. Verify the results
3. Update your application configuration if needed
4. Test your simplified application
5. Deploy to production

Your database will now match your simplified app that focuses on your core 3-responses-per-month business model!
