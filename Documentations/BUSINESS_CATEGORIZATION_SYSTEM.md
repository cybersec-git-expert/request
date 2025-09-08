# Business Categorization and Notification System

## Overview

This system implements intelligent business categorization and targeted notifications for the Request Marketplace platform. Businesses can now specify their type and operating categories to receive relevant request notifications.

## Database Changes

### New Columns in `business_verifications` Table

- `business_type`: VARCHAR(50) - Type of business operation
  - `'product_selling'`: Businesses that sell physical products
  - `'delivery_service'`: Businesses that provide delivery/logistics services  
  - `'both'`: Businesses that do both product selling and delivery
- `categories`: JSONB - Array of category IDs the business operates in

### Migration

The migration script (`add_business_type_and_categories.sql`) automatically:
1. Adds the new columns
2. Migrates existing `business_category` data to appropriate `business_type` values
3. Preserves backward compatibility with the old `business_category` field

## Business Types and Access Control

### Product Selling Businesses
- **Can**: 
  - Add price listings for price comparison
  - Send item/service/rent requests (not ride/delivery)
  - Respond to any item/service/rent requests
- **Cannot**: Respond to delivery requests, send ride requests
- **Notification**: Receive all item/service/rent requests (category preference for prioritization)

### Delivery Service Businesses  
- **Can**: 
  - Respond to delivery requests only
  - Send delivery requests
- **Cannot**: Add product price listings, respond to item/service/rent requests, send item/service/rent requests
- **Notification**: Receive all delivery requests in their country

### Both (Hybrid Businesses)
- **Can**: All features of both types
- **Example**: Logistics company that also sells packaging supplies

### Individual Users vs Businesses
- **Ride Requests**: Only individual drivers can respond (not businesses)
- **Item/Service/Rent**: Open to all verified businesses
- **Delivery**: Only delivery service businesses

## API Endpoints

### Business Categories Management

#### GET `/api/business-categories/business-types`
Returns available business types and categories for selection.

#### GET `/api/business-categories/access-rights`
Returns current user's business access rights and capabilities.

#### PUT `/api/business-categories/categories`
Updates business categories for the authenticated user.
```json
{
  "categories": ["category-id-1", "category-id-2"]
}
```

#### GET `/api/business-categories/can-respond/:requestId`
Checks if current business can respond to a specific request.

#### GET `/api/business-categories/notify/:requestId` (Admin only)
Returns list of businesses that should be notified for a request.

### Updated Business Verification Endpoints

The existing `/api/business-verifications` endpoints now accept:
- `business_type`: The new business type field
- `categories`: Array of category IDs
- `business_category`: Still accepted for backward compatibility

## Notification Targeting Logic

### For Item/Service/Rent Requests
1. Find all verified businesses (any type)
2. Prioritize businesses with matching categories for product sellers
3. All businesses can respond regardless of category match
4. Filter by country

### For Delivery Requests
1. Find verified businesses with `business_type` = 'delivery_service' or 'both'
2. Filter by country
3. Only these businesses can respond

### For Ride Requests
1. No business notifications sent
2. Only individual registered drivers can respond
3. Handled through driver system, not business system

## Integration Points

### Request Creation
When a new request is created (`POST /api/requests`), the system automatically:
1. Determines appropriate business type based on request_type
2. Finds matching businesses using `BusinessNotificationService.getBusinessesToNotify()`
3. Logs potential notifications (actual sending to be implemented)

### Business Access Control
The `BusinessNotificationService.getBusinessAccessRights()` method provides granular access control for:
- Adding price listings (product sellers only)
- Sending item/service/rent requests (product sellers only)
- Sending delivery requests (anyone)
- Responding to delivery requests (delivery services only)
- Responding to item/service/rent requests (anyone)
- Ride requests are excluded from business system

## Usage Examples

### 1. Electronics Store Setup
```javascript
// Business registers as product seller
{
  "business_type": "product_selling",
  "categories": ["electronics-category-id", "mobile-phones-subcategory-id"]
}

// They can now:
// - Add price listings for electronics
// - Receive notifications for mobile phone requests
// - Cannot respond to delivery requests
```

### 2. Delivery Company Setup
```javascript
// Business registers as delivery service
{
  "business_type": "delivery_service",
  "categories": [] // Not needed for delivery services
}

// They can now:
// - Receive all delivery request notifications
// - Cannot add product price listings
```

### 3. Marketplace Vendor Setup
```javascript
// Business that sells and delivers
{
  "business_type": "both", 
  "categories": ["electronics-category-id", "clothing-category-id"]
}

// They can now:
// - Add price listings for electronics and clothing
// - Receive product request notifications for their categories
// - Receive all delivery request notifications
```

## Testing

Run the test script to verify system functionality:
```bash
node test_business_categorization.js
```

This shows:
- Current business data and types
- Access rights for each business
- Notification targeting results
- Suggestions for improvements

## Migration Status

✅ Database schema updated
✅ Existing data migrated
✅ API endpoints created
✅ Notification service implemented
✅ Access control logic added
✅ Request integration completed

## Next Steps

1. **Frontend Integration**: Update admin panel and Flutter app to use new business type selection
2. **Notification Implementation**: Connect to actual email/SMS/push notification services
3. **Category Management**: Allow businesses to update their categories through the app
4. **Analytics**: Track notification effectiveness and business engagement

## Backward Compatibility

- The old `business_category` field is preserved and still functional
- Existing API calls continue to work
- New features are additive and don't break existing functionality
- Frontend apps can gradually adopt the new structure

## Performance Considerations

- GIN index on `categories` JSONB field for fast category matching
- Indexes on `business_type` for efficient filtering
- Queries are optimized for country-level filtering to minimize data transfer
