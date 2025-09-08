# Country-Wise Implementation Guide

This document outlines the country-wise functionality implementation across the Request Marketplace platform.

## Overview
We've implemented country support across all major collections:
- ✅ Business registrations (already implemented)
- ✅ Driver registrations (already implemented)  
- 🆕 Requests collection
- 🆕 Responses collection
- 🆕 Price listings collection
- 🆕 Ride requests (part of requests)

## Database Changes

### Collections Updated
1. **requests** - Added `country` and `countryName` fields
2. **responses** - Added `country` and `countryName` fields
3. **price_listings** - Added `country` and `countryName` fields

### Migration Script
Run the migration script to add country information to existing records:
```bash
node add_country_support.js
```

## Flutter App Changes

### Models Updated
1. **RequestModel** - Added country and countryName fields
2. **ResponseModel** - Added country and countryName fields
3. **PriceListing** - Added country and countryName fields

### Services Updated
1. **EnhancedRequestService** - Now includes country info when creating requests/responses
2. **AddPriceListingScreen** - Now includes country info when creating price listings

## Country Filtering Implementation

### For Requests
```dart
// Filter requests by country
Query requestsQuery = FirebaseFirestore.instance
    .collection('requests')
    .where('country', isEqualTo: userCountryCode);
```

### For Responses
```dart
// Filter responses by country
Query responsesQuery = FirebaseFirestore.instance
    .collection('responses')
    .where('country', isEqualTo: userCountryCode);
```

### For Price Listings
```dart
// Filter price listings by country
Query priceListingsQuery = FirebaseFirestore.instance
    .collection('price_listings')
    .where('country', isEqualTo: userCountryCode);
```

## Admin Panel Updates Needed

### Request Management
Update admin panels to filter requests by country:
- Country admins should only see requests from their country
- Super admins can see all countries
- Add country filter dropdown for super admins

### Response Management
Similar filtering for responses:
- Filter by responder's country
- Show country information in response listings

### Price Listings Management
For business/product management:
- Filter price listings by country
- Show business country in listings

## Usage Examples

### Creating a Request (automatically includes country)
```dart
final requestId = await requestService.createRequest(
  title: 'Need a ride',
  description: 'From airport to hotel',
  type: RequestType.ride,
  // country fields are automatically added from CountryService
);
```

### Creating a Response (automatically includes country)
```dart
final responseId = await requestService.createResponse(
  requestId: requestId,
  message: 'I can help with this',
  price: 1500.0,
  // country fields are automatically added from CountryService
);
```

### Creating a Price Listing (automatically includes country)
```dart
final priceListing = PriceListing(
  // ... other fields
  country: userCountryCode,
  countryName: userCountryName,
);
```

## Benefits

1. **Country-Specific Content**: Users only see relevant content for their country
2. **Admin Management**: Country admins can manage their region effectively
3. **Scalability**: Easy to add new countries
4. **Data Integrity**: All new records automatically include country information
5. **Compliance**: Meets regional data requirements

## Next Steps

1. ✅ Run migration script to update existing data
2. 🔄 Update admin React panels to include country filtering
3. 🔄 Test country filtering functionality
4. 🔄 Update mobile app to use country filtering in queries
5. 🔄 Add country selection in admin interfaces

## Files Changed

### Flutter App
- `lib/src/models/request_model.dart` - Added country fields to RequestModel and ResponseModel
- `lib/src/models/price_listing.dart` - Added country fields to PriceListing
- `lib/src/services/enhanced_request_service.dart` - Added country service integration
- `lib/src/screens/pricing/add_price_listing_screen.dart` - Added country info to price listings

### Migration Scripts
- `add_country_support.js` - Migrates existing records to include country information

## Testing Checklist

- [ ] Verify migration script updates existing records correctly
- [ ] Test new request creation includes country
- [ ] Test new response creation includes country  
- [ ] Test new price listing creation includes country
- [ ] Verify admin panels filter by country correctly
- [ ] Test country selection in admin interfaces
- [ ] Verify cross-country isolation works properly
