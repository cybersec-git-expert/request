const database = require('./database');

class BusinessNotificationService {
  /**
   * Find businesses that should be notified for a specific request
   * Updated logic: Most requests are open to all, only delivery is restricted
   * @param {string} requestId - The request ID
   * @param {string} categoryId - The category ID of the request
   * @param {string} subcategoryId - The subcategory ID of the request (optional)
   * @param {string} requestType - The type of request (item, service, ride, etc.)
   * @param {string} countryCode - The country code for the request
   * @returns {Array} Array of business user IDs to notify
   */
  static async getBusinessesToNotify(requestId, categoryId, subcategoryId, requestType, countryCode) {
    try {
      console.log(`🔍 Finding businesses to notify for request ${requestId}`);
      console.log(`   Category: ${categoryId}, Subcategory: ${subcategoryId}`);
      console.log(`   Request Type: ${requestType}, Country: ${countryCode}`);

      // For delivery requests, only notify delivery service businesses
      if (requestType === 'delivery') {
        return await this.getDeliveryBusinesses(countryCode);
      }

      // For ride requests, don't notify businesses (only drivers should respond)
      if (requestType === 'ride') {
        console.log('🚗 Ride requests only notify drivers, not businesses');
        return [];
      }

      // For item/service/rent requests, notify all verified businesses in country
      // (with optional category preference for product sellers)
      return await this.getAllBusinessesWithCategoryPreference(categoryId, subcategoryId, countryCode);

    } catch (error) {
      console.error('Error finding businesses to notify:', error);
      return [];
    }
  }

  /**
   * Get delivery service businesses
   */
  static async getDeliveryBusinesses(countryCode) {
    const query = `
      SELECT DISTINCT bv.user_id, bv.business_name, bv.business_email
      FROM business_verifications bv
      WHERE bv.is_verified = true
        AND bv.status = 'approved'
        AND (bv.business_type = 'delivery_service' OR bv.business_type = 'both')
        AND bv.country = $1
      ORDER BY bv.business_name
    `;

    const result = await database.query(query, [countryCode]);
    console.log(`📦 Found ${result.rows.length} delivery businesses in ${countryCode}`);
    
    return result.rows.map(row => ({
      userId: row.user_id,
      businessName: row.business_name,
      businessEmail: row.business_email,
      notificationReason: 'delivery_service'
    }));
  }

  /**
   * Get all businesses with category preference (for item/service/rent requests)
   * Anyone can respond, but prioritize category matches
   */
  static async getAllBusinessesWithCategoryPreference(categoryId, subcategoryId, countryCode) {
    const query = `
      SELECT DISTINCT bv.user_id, bv.business_name, bv.business_email, bv.categories, bv.business_type,
             CASE 
               WHEN bv.categories @> $2::jsonb THEN 'category_match'
               WHEN bv.categories @> $3::jsonb THEN 'subcategory_match' 
               ELSE 'general_business'
             END as match_priority
      FROM business_verifications bv
      WHERE bv.is_verified = true
        AND bv.status = 'approved'
        AND bv.country = $1
      ORDER BY 
        CASE 
          WHEN bv.categories @> $2::jsonb THEN 1
          WHEN bv.categories @> $3::jsonb THEN 2 
          ELSE 3
        END,
        bv.business_name
    `;

    const params = [
      countryCode, 
      JSON.stringify([categoryId]),
      subcategoryId ? JSON.stringify([subcategoryId]) : JSON.stringify([])
    ];

    const result = await database.query(query, params);
    console.log(`🏪 Found ${result.rows.length} businesses (all can respond, ${result.rows.filter(r => r.match_priority.includes('match')).length} have category preference)`);
    
    return result.rows.map(row => ({
      userId: row.user_id,
      businessName: row.business_name,
      businessEmail: row.business_email,
      categories: row.categories,
      businessType: row.business_type,
      notificationReason: row.match_priority
    }));
  }

  /**
   * Check if a business can respond to a specific request type
   * Updated logic: Most requests are open, only delivery/ride restricted
   */
  static async canBusinessRespondToRequest(userId, requestType, categoryId) {
    const query = `
      SELECT business_type, categories, is_verified, status
      FROM business_verifications 
      WHERE user_id = $1 AND is_verified = true AND status = 'approved'
    `;

    const result = await database.query(query, [userId]);
    if (result.rows.length === 0) {
      return { canRespond: false, reason: 'not_verified_business' };
    }

    const business = result.rows[0];

    // Check request type restrictions
    if (requestType === 'delivery') {
      // Only delivery service businesses can respond to delivery requests
      if (business.business_type === 'delivery_service' || business.business_type === 'both') {
        return { canRespond: true, reason: 'delivery_service_authorized' };
      }
      return { canRespond: false, reason: 'delivery_requires_delivery_service' };
    }

    if (requestType === 'ride') {
      // Ride requests are for drivers, not businesses
      return { canRespond: false, reason: 'ride_requests_for_drivers_only' };
    }

    // For item/service/rent requests, all verified businesses can respond
    if (['item', 'service', 'rent'].includes(requestType)) {
      return { canRespond: true, reason: 'open_to_all_businesses' };
    }

    return { canRespond: true, reason: 'general_business_request' };
  }

  /**
   * Get business access rights (what features they can use)
   * Updated: Product sellers can add prices AND send most requests
   */
  static async getBusinessAccessRights(userId) {
    const query = `
      SELECT business_type, categories, is_verified, status
      FROM business_verifications 
      WHERE user_id = $1
    `;

    const result = await database.query(query, [userId]);
    if (result.rows.length === 0) {
      return {
        canAddPrices: false,
        canSendItemRequests: false,
        canSendServiceRequests: false,
        canSendRentRequests: false,
        canSendDeliveryRequests: false,
        canSendRideRequests: false,
        canRespondToDelivery: false,
        canRespondToRide: false,
        canRespondToOther: false,
        categories: [],
        verified: false
      };
    }

    const business = result.rows[0];
    const isVerified = business.is_verified && business.status === 'approved';

    // Determine access rights based on business type
    const isProductSeller = business.business_type === 'product_selling' || business.business_type === 'both';
    const isDeliveryService = business.business_type === 'delivery_service' || business.business_type === 'both';

    return {
      // Price management (only product sellers)
      canAddPrices: isVerified && isProductSeller,
      
      // Request creation rights
      canSendItemRequests: isVerified && isProductSeller,    // Product sellers can request items
      canSendServiceRequests: isVerified && isProductSeller, // Product sellers can request services  
      canSendRentRequests: isVerified && isProductSeller,    // Product sellers can request rentals
      canSendDeliveryRequests: isVerified,                   // Anyone can request delivery
      canSendRideRequests: false,                            // Only individual users (drivers) handle rides
      
      // Response rights
      canRespondToDelivery: isVerified && isDeliveryService, // Only delivery services
      canRespondToRide: false,                               // Only registered drivers, not businesses
      canRespondToOther: isVerified,                         // Anyone can respond to item/service/rent
      
      // Metadata
      categories: business.categories || [],
      businessType: business.business_type,
      verified: isVerified
    };
  }

  /**
   * Update business categories
   */
  static async updateBusinessCategories(userId, categories) {
    const query = `
      UPDATE business_verifications 
      SET categories = $2, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1 AND is_verified = true
      RETURNING categories
    `;

    const result = await database.query(query, [userId, JSON.stringify(categories)]);
    return result.rows[0];
  }
}

module.exports = BusinessNotificationService;
