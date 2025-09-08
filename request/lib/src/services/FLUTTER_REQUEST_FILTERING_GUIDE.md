# Flutter Request Filtering System

## Overview

The Flutter request filtering system implements sophisticated role-based and country-based filtering to ensure users only see relevant requests based on their registration details and verification status.

## Filtering Rules

### 1. Country-Based Filtering (All Users)
- **Rule**: Users only see requests from their registered country
- **Implementation**: Filters by `request.country == user.countryCode`
- **Applies to**: All users regardless of role

### 2. Role-Based Filtering

#### Drivers
- **What they can see**: 
  - Ride requests matching their registered vehicle type
  - General requests (items, services, rentals, price checks)
- **Requirements**: 
  - Must be verified as a driver
  - Vehicle type must match the ride request requirement
- **Example**: A three-wheeler driver only sees three-wheeler ride requests

#### Delivery Service Businesses
- **What they can see**:
  - Delivery requests only
  - General requests (items, services, rentals, price checks)
- **Requirements**:
  - Must be verified as business or delivery role
  - Business category must be delivery-related (delivery, courier, logistics, transport)

#### General Users
- **What they can see**:
  - Items, services, rentals, and price check requests
- **Cannot see**:
  - Ride requests (driver-only)
  - Delivery requests (delivery business-only)

### 3. Vehicle Type Matching (Drivers Only)

Supports automatic normalization of vehicle type names:
- `three wheeler`, `three-wheeler`, `auto rickshaw`, `tuk tuk` → `threewheeler`
- `two wheeler`, `two-wheeler`, `motorcycle`, `bike`, `scooter` → `twowheeler`
- `four wheeler`, `car`, `sedan`, `hatchback`, `suv` → `car`
- `pickup truck`, `pickup` → `pickup-truck`
- `lorry` → `truck`
- `mini bus`, `mini-bus` → `minibus`

## Implementation

### Core Service: RequestFilteringService

```dart
// Main filtering method
Future<List<RequestModel>> filterRequestsForUser(List<RequestModel> allRequests)

// Check if user can respond to specific request
Future<bool> canUserRespondToRequest(RequestModel request)

// Get user's available request types for creation
Future<List<RequestType>> getUserAvailableRequestTypes()
```

### Enhanced Browse Screen

The `EnhancedBrowseScreen` automatically applies all filtering rules and provides:
- Role-based request visibility
- Country-based filtering
- Vehicle type matching for drivers
- User role indicator showing current filtering mode
- Type filters showing only available categories

## Integration

### Replace Existing Browse Screen

```dart
// Old way
import '../screens/browse_screen.dart';
const BrowseScreen()

// New way
import '../screens/enhanced_browse_screen.dart';
const EnhancedBrowseScreen()
```

### Use Filtering Service Directly

```dart
import '../services/request_filtering_service.dart';

final filteringService = RequestFilteringService.instance;

// Filter requests
final filteredRequests = await filteringService.filterRequestsForUser(allRequests);

// Check response permission
final canRespond = await filteringService.canUserRespondToRequest(request);

// Get available types for user
final availableTypes = await filteringService.getUserAvailableRequestTypes();
```

## User Experience Examples

### Driver with Three-Wheeler
- **Sees**: Three-wheeler ride requests + all general requests from Sri Lanka
- **Cannot see**: Car ride requests, delivery requests from other countries
- **Can create**: Ride requests, general requests

### Delivery Business
- **Sees**: Delivery requests + all general requests from Sri Lanka  
- **Cannot see**: Ride requests (any vehicle type)
- **Can create**: Delivery requests, general requests

### General User
- **Sees**: Items, services, rentals, price checks from Sri Lanka
- **Cannot see**: Ride requests, delivery requests
- **Can create**: General requests only

## Benefits

1. **Compliance**: Ensures only qualified providers see relevant requests
2. **User Experience**: Reduces noise by showing only actionable items
3. **Business Logic**: Enforces role-based access to specialized services
4. **Scalability**: Easy to add new roles or modify filtering rules
5. **Performance**: Client-side filtering after initial country-based server filtering

## Technical Details

- **Country Filtering**: Uses existing `CountryFilteredDataService`
- **Role Data**: Accesses user verification data through `EnhancedUserService`
- **Vehicle Matching**: Intelligent normalization handles variations in naming
- **Caching**: Minimal performance impact through efficient filtering
- **Error Handling**: Graceful degradation when user data unavailable

## Future Enhancements

- Geographic radius filtering for local services
- Skill-based matching for service requests
- Price range filtering integration
- Real-time filtering updates when user role changes
- Admin override capabilities for support scenarios
