# 📚 Admin Permissions System - Complete Documentation

## 🌟 Overview

The Request Marketplace admin panel features a comprehensive role-based permission system that controls access to different modules and functionalities. This system supports automatic permission propagation when new modules are added, ensuring that existing admin users receive appropriate permissions without manual intervention.

## 🏗️ System Architecture

### 🎯 Core Components

1. **Permission Matrix** - Defines which permissions belong to which role types
2. **Menu Configuration** - Controls sidebar navigation based on permissions  
3. **Auto-Propagation System** - Automatically updates permissions when new modules are added
4. **Role-Based Access Control** - Enforces permissions at the component level

### 📊 Database Structure

```javascript
// Admin User Document in Firestore
{
  email: "admin@example.com",
  role: "country_admin", // or "super_admin"
  country: "LK", // Country code for country admins
  permissions: {
    requestManagement: true,
    vehicleManagement: true,
    countryVehicleTypeManagement: true,
    // ... other permissions
  },
  lastPermissionUpdate: "2025-08-16T10:30:00Z"
}
```

## 👥 User Roles

### 👑 Super Admin
- **Scope**: Global access across all countries
- **Permissions Count**: 30 total permissions
- **Special Access**: Can manage other admin users, global configurations
- **Country Access**: All countries

### 🌍 Country Admin  
- **Scope**: Limited to assigned country
- **Permissions Count**: 27 permissions (missing adminUsersManagement)
- **Special Access**: Country-specific data management
- **Country Access**: Single assigned country only

## 🔐 Permission Categories

### 📋 Request Management
```javascript
{
  requestManagement: true,        // View/manage service requests
  responseManagement: true,       // View/manage responses to requests  
  priceListingManagement: true,   // Manage product price listings
}
```

### 🏢 Business Management
```javascript
{
  productManagement: true,        // Global product catalog management
  businessManagement: true,       // Business verification & management
  driverVerification: true,       // Driver verification & management
}
```

### 🚗 Vehicle Management
```javascript
{
  vehicleManagement: true,              // General vehicle management
  countryVehicleTypeManagement: true,   // Country-specific vehicle types
}
```

### 🏙️ Location Management
```javascript
{
  cityManagement: true,           // City and location management
}
```

### 👥 User & System Management
```javascript
{
  userManagement: true,           // End user management
  subscriptionManagement: true,   // User subscription management
  promoCodeManagement: true,      // Promotional code management
  moduleManagement: true,         // System module configuration
}
```

### 📦 Product Catalog Management

#### Global Management (Super Admin)
```javascript
{
  categoryManagement: true,       // Global category management
  subcategoryManagement: true,    // Global subcategory management  
  brandManagement: true,          // Global brand management
  variableTypeManagement: true,   // Global variable type management
}
```

#### Country-Specific Management (Country Admin)
```javascript
{
  countryProductManagement: true,        // Country product activation
  countryCategoryManagement: true,       // Country category activation
  countrySubcategoryManagement: true,    // Country subcategory activation
  countryBrandManagement: true,          // Country brand activation
  countryVariableTypeManagement: true,   // Country variable activation
  countryVehicleTypeManagement: true,    // Country vehicle type activation
}
```

### 📄 Content Management
```javascript
{
  contentManagement: true,        // Page and content management
  countryPageManagement: true,    // Country-specific page management
}
```

### 💳 Legal & Payment Management
```javascript
{
  paymentMethodManagement: true,  // Payment method configuration
  legalDocumentManagement: true,  // Legal document management
}
```

### 🔧 Admin Management (Super Admin Only)
```javascript
{
  adminUsersManagement: true,     // Create/manage other admin users
}
```

## 🎛️ Menu Configuration

### 📂 Menu Structure in Layout.jsx

```javascript
const menuItems = [
  // Dashboard
  { text: 'Dashboard', icon: <Dashboard />, path: '/', access: 'all' },
  
  // Request Management
  { text: 'Requests', icon: <Assignment />, path: '/requests', access: 'all', permission: 'requestManagement' },
  { text: 'Responses', icon: <Reply />, path: '/responses', access: 'all', permission: 'responseManagement' },
  { text: 'Price Listings', icon: <PriceCheck />, path: '/price-listings', access: 'all', permission: 'priceListingManagement' },
  
  // Global Management (Super Admin Only)
  { text: 'Products', icon: <ShoppingCart />, path: '/products', access: 'super_admin', permission: 'productManagement' },
  { text: 'Vehicle Types', icon: <Settings />, path: '/vehicles', access: 'super_admin', permission: 'vehicleManagement' },
  { text: 'Categories', icon: <Category />, path: '/categories', access: 'super_admin', permission: 'categoryManagement' },
  { text: 'Variable Types', icon: <Tune />, path: '/variable-types', access: 'super_admin', permission: 'variableTypeManagement' },
  
  // Country-Specific Management (Country Admin)
  { text: 'Products', icon: <ShoppingCart />, path: '/country-products', access: 'country_admin', permission: 'countryProductManagement' },
  { text: 'Categories', icon: <Category />, path: '/country-categories', access: 'country_admin', permission: 'countryCategoryManagement' },
  { text: 'Variable Types', icon: <Tune />, path: '/country-variable-types', access: 'country_admin', permission: 'countryVariableTypeManagement' },
  { text: 'Vehicle Types', icon: <Settings />, path: '/country-vehicle-types', access: 'country_admin', permission: 'countryVehicleTypeManagement' },
  
  // Shared Management (All Users)
  { text: 'Businesses', icon: <Business />, path: '/businesses', access: 'all', permission: 'businessManagement' },
  { text: 'Vehicle Management', icon: <DirectionsCar />, path: '/vehicles-module', access: 'all', permission: 'vehicleManagement' },
  
  // Admin Management (Super Admin Only)
  { text: 'Admin Management', icon: <AdminPanelSettings />, path: '/admin-management', access: 'super_admin', permission: 'adminUsersManagement' },
];
```

### 🎯 Access Control Logic

```javascript
// Menu filtering logic in Layout.jsx
menuItems.filter(item => {
  if (item.text === 'Divider') return true;
  
  // For super admin - show super_admin and all access items
  if (isSuperAdmin) {
    return item.access === 'super_admin' || item.access === 'all';
  }
  
  // For country admin - show only country_admin and all access items
  if (!isSuperAdmin) {
    if (item.access === 'super_admin') return false; // Exclude super admin items
    if (item.access === 'country_admin') return true;
    if (item.access === 'all') {
      // Check if user has required permission
      if (item.permission) {
        return adminData?.permissions?.[item.permission] === true;
      }
      return true;
    }
  }
  
  return false;
})
```

## 🔄 Automatic Permission Propagation

### 📁 Auto-Propagation Script: `auto-propagate-permissions.cjs`

```javascript
// Standard permissions for all admin types
const STANDARD_PERMISSIONS = {
  // Request Management
  requestManagement: true,
  responseManagement: true,
  priceListingManagement: true,
  
  // Business Management  
  productManagement: true,
  businessManagement: true,
  driverVerification: true,
  
  // Vehicle Management
  vehicleManagement: true,
  
  // Country-specific permissions
  countryProductManagement: true,
  countryCategoryManagement: true,
  countrySubcategoryManagement: true,
  countryBrandManagement: true,
  countryVariableTypeManagement: true,
  countryVehicleTypeManagement: true,
  
  // ... other permissions
};

// Super admin only permissions
const SUPER_ADMIN_ONLY_PERMISSIONS = {
  adminUsersManagement: true
};
```

### 🚀 Usage

```bash
# Run permission propagation
cd admin-react
node auto-propagate-permissions.cjs
```

### ✅ What It Does

1. **Scans existing admin users** in Firestore
2. **Adds missing standard permissions** to all users
3. **Adds super admin permissions** only to super admins
4. **Preserves existing permissions** (no overwrites)
5. **Logs all changes** for audit trail
6. **Updates lastPermissionUpdate** timestamp

## 🛠️ Adding New Modules

### 📝 Step-by-Step Process

#### 1. Add Menu Item to Layout.jsx

```javascript
// Add to menuItems array in Layout.jsx
{ 
  text: 'New Module Name', 
  icon: <NewIcon />, 
  path: '/new-module', 
  access: 'all',  // or 'super_admin' or 'country_admin'
  permission: 'newModuleManagement' 
}
```

#### 2. Update Permission Script

```javascript
// Add to STANDARD_PERMISSIONS in auto-propagate-permissions.cjs
const STANDARD_PERMISSIONS = {
  // ... existing permissions
  newModuleManagement: true,  // NEW permission
};
```

#### 3. Add Route to App.jsx

```javascript
// Add route in App.jsx
<Route path="new-module" element={<NewModuleComponent />} />
```

#### 4. Run Auto-Propagation

```bash
node auto-propagate-permissions.cjs
```

#### 5. Create Component with Permission Check

```javascript
// In your new component
import useCountryFilter from '../hooks/useCountryFilter';

const NewModuleComponent = () => {
  const { adminData, isSuperAdmin } = useCountryFilter();
  
  // Check permissions
  const hasPermission = isSuperAdmin || adminData?.permissions?.newModuleManagement;
  
  if (!hasPermission) {
    return (
      <Alert severity="error">
        You don't have permission to access this module.
      </Alert>
    );
  }
  
  // Your component content
  return <div>New Module Content</div>;
};
```

## 🔍 Permission Checking Patterns

### 🎯 Component-Level Permission Check

```javascript
// Standard permission check pattern
const hasPermission = isSuperAdmin || adminData?.permissions?.specificPermission;

if (!hasPermission) {
  return <Alert severity="error">Access Denied</Alert>;
}
```

### 🎛️ Menu Item Permission Check

```javascript
// In Layout.jsx menu filtering
if (item.permission) {
  return adminData?.permissions?.[item.permission] === true;
}
```

### 🔒 Feature-Level Permission Check

```javascript
// Conditional feature rendering
{adminData?.permissions?.featurePermission && (
  <Button>Feature Button</Button>
)}
```

## 🐛 Troubleshooting

### ❓ Common Issues

#### 🚫 "Menu item not showing for country admin"

**Problem**: Country admin has permission but menu item not visible

**Solution**: 
1. Check menu item `access` property in Layout.jsx
2. Verify permission name matches exactly
3. Run permission propagation script

```bash
# Check current permissions
node -e "/* verification script */"

# Run propagation
node auto-propagate-permissions.cjs
```

#### 🚫 "Permission denied error in component"

**Problem**: Component shows access denied despite having permission

**Solution**:
1. Check permission name spelling in component
2. Verify permission exists in database
3. Check if `adminData` is loaded properly

#### 🚫 "New module not accessible after adding"

**Problem**: Added new module but users can't access it

**Checklist**:
- ✅ Added menu item to Layout.jsx
- ✅ Added route to App.jsx  
- ✅ Added permission to auto-propagate script
- ✅ Ran permission propagation
- ✅ Added permission check to component

## 📊 Current System Status

### ✅ Fixed Issues

- **Vehicle Management Visibility**: Country admins can now see Vehicle Management
- **Permission Propagation**: Automatic system for new modules
- **Menu Filtering**: Removed hardcoded exclusions
- **Permission Matrix**: Complete 27/30 permission coverage

### 📈 System Metrics

- **Super Admin**: 30 total permissions
- **Country Admin**: 27 permissions (94% of super admin permissions)
- **Auto-Propagation**: ✅ Working
- **Menu Rendering**: ✅ Dynamic based on permissions

### 🎯 Permission Distribution

| Category | Super Admin | Country Admin |
|----------|-------------|---------------|
| Request Management | ✅ | ✅ |
| Business Management | ✅ | ✅ |
| Vehicle Management | ✅ | ✅ |
| Global Catalog Management | ✅ | ❌ |
| Country Catalog Management | ✅ | ✅ |
| Content Management | ✅ | ✅ |
| Admin Management | ✅ | ❌ |

## 🚀 Future Enhancements

### 💡 Planned Features

1. **Permission Groups**: Bundle related permissions
2. **Dynamic Permissions**: Runtime permission configuration
3. **Audit Logging**: Track permission changes
4. **Role Templates**: Predefined permission sets
5. **Permission Inheritance**: Hierarchical permission structure

### 🔧 Maintenance Tasks

1. **Regular Permission Audits**: Quarterly review of permission usage
2. **Performance Monitoring**: Track permission check performance  
3. **Security Reviews**: Validate permission enforcement
4. **Documentation Updates**: Keep docs synchronized with code

---

## 📞 Support

For permission-related issues:

1. **Check this documentation** first
2. **Run diagnostic scripts** to verify current state
3. **Use auto-propagation script** for permission issues
4. **Contact system administrator** for role changes

---

*This documentation covers the complete admin permissions system as of August 16, 2025. The system is designed to be scalable and maintainable, with automatic permission propagation ensuring seamless addition of new modules.*
