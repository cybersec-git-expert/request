# 🏗️ Centralized Module Management System

## � Overview

The **Centralized Module Management System** provides country-specific control over business modules and features in the Request Marketplace application. This system allows administrators to enable/disable specific modules for different countries, providing granular control over feature availability.

## 🎯 System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Backend API   │◄──►│ Module Management │◄──►│ Feature Gating  │
│   (Express.js)  │    │    Service       │    │    Service      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Country Config  │    │   Module Cache   │    │   UI Components │
│   Database      │    │   (30min TTL)    │    │ (Coming Soon)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## � Business Modules

| Module | ID | Description | Controls |
|--------|----|-----------  |----------|
| **Item Request** | `item_request` | Basic marketplace for buying/selling items | Create item requests |
| **Service Request** | `service_request` | Service marketplace | Create service requests |
| **Rental Request** | `rental_request` | Equipment/vehicle rental | Create rental requests |
| **Delivery Request** | `delivery_request` | Delivery services | Create delivery requests, delivery business registration |
| **Ride Sharing** | `ride_sharing` | Taxi and ride services | Create ride requests, driver registration, ride alerts menu |
| **Price Request** | `price_request` | Price comparison | Create price requests, price comparison navigation, business type restrictions |

## 🔧 Backend Implementation

### API Endpoints

#### 1. Get Enabled Modules
```http
GET /api/modules/enabled?country=LK
```

**Response:**
```json
{
  "success": true,
  "country": "LK",
  "enabled_modules": ["item_request", "service_request", "rental_request", "delivery_request", "ride_sharing", "price_request"],
  "disabled_modules": [],
  "total_modules": 6
}
```

#### 2. Check Specific Module
```http
GET /api/modules/check/ride_sharing?country=LK
```

**Response:**
```json
{
  "success": true,
  "country": "LK", 
  "module": "ride_sharing",
  "enabled": true
}
```

#### 3. Get All Available Modules
```http
GET /api/modules/all
```

### Configuration Management

#### File: `backend/routes/modules.js`

```javascript
const COUNTRY_MODULE_CONFIG = {
  'LK': { // Sri Lanka - All modules enabled
    enabled_modules: [
      'item_request',
      'service_request', 
      'rental_request',
      'delivery_request',
      'ride_sharing',
      'price_request'
    ],
    disabled_modules: []
  },
  'US': { // United States - Price requests disabled 
    enabled_modules: [
      'item_request',
      'service_request',
      'rental_request',
      'delivery_request',
      'ride_sharing'
    ],
    disabled_modules: ['price_request']
  },
  'IN': { // India - Rental and price disabled
    enabled_modules: [
      'item_request',
      'service_request',
      'delivery_request',
      'ride_sharing'
    ],
    disabled_modules: ['rental_request', 'price_request']
  }
};
  },
  'US': { // United States  
    enabled_modules: [
      'item_request',
      'service_request',
      'rental_request',
      'delivery_request',
      'ride_sharing'
    ],
    disabled_modules: ['price_request']
  }
};
```

### API Endpoints

#### 1. Get Enabled Modules
```http
GET /api/modules/enabled?country=LK
```

**Response:**
```json
{
  "success": true,
  "country": "LK",
  "enabled_modules": ["item_request", "service_request", "rental_request", "delivery_request", "ride_sharing", "price_request"],
  "disabled_modules": [],
  "total_modules": 6
}
```

#### 2. Check Specific Module
```http
GET /api/modules/check/ride_sharing?country=LK
```

**Response:**
```json
{
  "success": true,
  "country": "LK", 
  "module": "ride_sharing",
  "enabled": true
}
```

#### 3. Get All Available Modules
```http
GET /api/modules/all
```

**Response:**
```json
{
  "success": true,
  "modules": [
    {
      "id": "item_request",
      "name": "Item Request",
      "description": "Buy and sell items - electronics, furniture, clothing, etc.",
      "features": ["Product listings", "Categories & subcategories", "Image uploads", "Price negotiations"]
    }
  ]
}
```

## 📱 Flutter Integration

### Core Services

#### 1. ModuleManagementService
```dart
// Get enabled modules
final enabledModules = await ModuleManagementService.instance.getEnabledModules();

// Check if specific module is enabled
final isRideEnabled = enabledModules.contains(BusinessModule.rideSharing);
```

#### 2. FeatureGateService
```dart
// Check if driver registration should be available
final canRegisterDriver = await FeatureGateService.instance.isDriverRegistrationEnabled();

// Get available business types
final businessTypes = await FeatureGateService.instance.getAvailableBusinessTypes();

// Check navigation features
final showPriceComparison = await FeatureGateService.instance.isNavigationFeatureEnabled('price_comparison');

// Check menu features  
final showProductSection = await FeatureGateService.instance.isMenuFeatureEnabled('product_section');
```

### UI Integration Patterns

#### 1. Gate Entire Screens
```dart
FeatureGateService.instance.gateWidget(
  requiredModule: BusinessModule.rideSharing,
  enabledWidget: DriverRegistrationButton(),
  disabledWidget: ComingSoonButton(),
)
```

#### 2. Navigate or Show Coming Soon
```dart
await FeatureGateService.instance.navigateOrShowComingSoon(
  context: context,
  requiredModule: BusinessModule.rideSharing,
  featureName: 'Driver Registration',
  description: 'Driver registration is not available in your country yet.',
  icon: Icons.drive_eta,
  onEnabled: () => Navigator.pushNamed(context, '/driver-registration'),
);
```

#### 3. Filter Lists Dynamically
```dart
final availableBusinessTypes = await FeatureGateService.instance.getAvailableBusinessTypes();
// Use this list to populate business registration dropdowns
```

## 🎮 Testing Scenarios

### Scenario 1: Disable Ride Sharing
```javascript
// In modules.js
'LK': {
  enabled_modules: ['item_request', 'service_request', 'rental_request', 'delivery_request', 'price_request'],
  disabled_modules: ['ride_sharing']
}
```

**Expected Results:**
- ❌ Ride request creation shows "Coming Soon"
- ❌ Driver registration button hidden/disabled
- ❌ Ride alerts menu item hidden
- ✅ All other features work normally

### Scenario 2: Disable Delivery Services
```javascript
'LK': {
  enabled_modules: ['item_request', 'service_request', 'rental_request', 'ride_sharing', 'price_request'],
  disabled_modules: ['delivery_request']
}
```

**Expected Results:**
- ❌ Delivery request creation shows "Coming Soon"
- ❌ "Delivery" business type hidden in registration
- ✅ All other features work normally

### Scenario 3: Disable Price Requests
```javascript
'LK': {
  enabled_modules: ['item_request', 'service_request', 'rental_request', 'delivery_request', 'ride_sharing'],
  disabled_modules: ['price_request']
}
```

**Expected Results:**
- ❌ Price request creation shows "Coming Soon"
- ❌ Price comparison icon hidden in navigation
- ❌ Business types (retail, wholesale, ecommerce) hidden in registration
- ❌ Product section menu item hidden

## 🔄 Implementation Checklist

### ✅ Completed
- [x] Backend API endpoints
- [x] ModuleManagementService with caching
- [x] FeatureGateService for feature gating
- [x] ComingSoonWidget for disabled features
- [x] Home screen integration (create request modal)
- [x] Request type filtering in browse screen

### 🔄 In Progress
- [ ] Driver registration screen integration
- [ ] Business registration screen integration  
- [ ] Navigation bar feature gating
- [ ] Menu system feature gating

### 📋 Integration Points

#### Driver Registration Screen
```dart
// In driver_registration_screen.dart
@override
Widget build(BuildContext context) {
  return FutureBuilder<bool>(
    future: FeatureGateService.instance.isDriverRegistrationEnabled(),
    builder: (context, snapshot) {
      if (snapshot.data == false) {
        return ComingSoonWidget(
          title: 'Driver Registration',
          description: 'Driver registration is not available in your country yet.',
          icon: Icons.drive_eta,
        );
      }
      return DriverRegistrationForm(); // Existing form
    },
  );
}
```

#### Business Registration Screen
```dart
// Filter business types
Future<List<String>> _getAvailableBusinessTypes() async {
  return await FeatureGateService.instance.getAvailableBusinessTypes();
}
```

#### Navigation Bar
```dart
// Conditionally show price comparison icon
FutureBuilder<bool>(
  future: FeatureGateService.instance.isNavigationFeatureEnabled('price_comparison'),
  builder: (context, snapshot) {
    if (snapshot.data == true) {
      return IconButton(
        icon: Icon(Icons.compare_arrows),
        onPressed: () => Navigator.pushNamed(context, '/price-comparison'),
      );
    }
    return SizedBox.shrink();
  },
)
```

#### Menu System
```dart
// Conditionally show menu items
FutureBuilder<bool>(
  future: FeatureGateService.instance.isMenuFeatureEnabled('product_section'),
  builder: (context, snapshot) {
    if (snapshot.data == true) {
      return ListTile(
        title: Text('Products'),
        onTap: () => Navigator.pushNamed(context, '/products'),
      );
    }
    return SizedBox.shrink();
  },
)
```

## 🚀 Deployment Guide

### Adding a New Module
1. Update `BusinessModule` enum in `module_management_service.dart`
2. Add configuration in `_moduleConfigurations`
3. Update backend `COUNTRY_MODULE_CONFIG`
4. Add API documentation
5. Implement feature gating in relevant screens

### Changing Country Configuration
1. Edit `backend/routes/modules.js`
2. Restart server
3. Changes take effect immediately
4. Test in Flutter app

### Monitoring and Logging
- Backend logs module requests with country codes
- Flutter service caches responses for 30 minutes
- ComingSoonWidget tracks user interactions with disabled features

## 🔍 Troubleshooting

### Common Issues

#### Module Not Updating
- **Cause**: Server cache or restart required
- **Solution**: Restart backend server

#### Feature Still Visible After Disabling
- **Cause**: Flutter cache or missing integration
- **Solution**: Force refresh Flutter app or check feature gating implementation

#### Coming Soon Not Showing
- **Cause**: Module still enabled in backend
- **Solution**: Verify backend configuration and restart server

### Debug Commands
```bash
# Test module API
curl "http://localhost:3001/api/modules/enabled?country=LK"

# Test specific module
curl "http://localhost:3001/api/modules/check/ride_sharing?country=LK"

# Check all modules
curl "http://localhost:3001/api/modules/all"
```

## 📞 Support

For issues with the module management system:
1. Check backend logs for module API errors
2. Verify country configuration in `modules.js`
3. Test API endpoints with curl
4. Check Flutter service cache timeout
5. Validate feature gating implementation

---

**Last Updated**: August 22, 2025  
**Version**: 1.0.0  
**Author**: Development Team
