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

  let type = (requestType || '').toLowerCase();
  if (type === 'hiring') type = 'job';
  const COMMON = ['item','service','tours','events','construction','education','hiring','job'];

      // For delivery requests, only notify delivery service businesses
      if (type === 'delivery') {
        return await this.getDeliveryBusinesses(countryCode);
      }

      // For ride requests, only notify ride service businesses
      if (type === 'ride') {
        console.log('🚗 Ride requests notify ride service businesses');
        return await this.getRideServiceBusinesses(countryCode);
      }

      // Price requests: product sellers should respond
      if (type === 'price') {
        return await this.getProductSellerBusinesses(countryCode);
      }

      // Common requests: anyone can respond by default, but respect country capability toggles if present
  if (COMMON.includes(type)) {
        return await this.getAllBusinessesWithCategoryPreference(categoryId, subcategoryId, countryCode, type);
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
      LEFT JOIN business_types bt ON bt.id = bv.business_type_id
      WHERE bv.is_verified = true
        AND bv.status = 'approved'
        AND bv.country = $1
        AND (
          LOWER(COALESCE(bt.name, '')) IN ('delivery service','delivery') OR
          LOWER(COALESCE(bv.business_category, '')) IN ('delivery service','delivery') OR
          bv.business_type = 'delivery_service' OR
          bv.business_type = 'both'
        )
        AND EXISTS (
          SELECT 1 FROM user_subscriptions us
          JOIN subscription_plans_new sp ON sp.id = us.plan_id AND sp.type='business'
          WHERE us.user_id = bv.user_id AND us.status IN ('active','trialing','past_due')
        )
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
   * Get ride service businesses
   */
  static async getRideServiceBusinesses(countryCode) {
    const query = `
      SELECT DISTINCT bv.user_id, bv.business_name, bv.business_email
      FROM business_verifications bv
      LEFT JOIN business_types bt ON bt.id = bv.business_type_id
      WHERE bv.is_verified = true
        AND bv.status = 'approved'
        AND bv.country = $1
        AND (
          LOWER(COALESCE(bt.name, '')) IN ('ride') OR
          LOWER(COALESCE(bv.business_category, '')) IN ('ride service','ride') OR
          bv.business_type = 'ride_service' OR
          bv.business_type = 'both'
        )
        AND EXISTS (
          SELECT 1 FROM user_subscriptions us
          JOIN subscription_plans_new sp ON sp.id = us.plan_id AND sp.type='business'
          WHERE us.user_id = bv.user_id AND us.status IN ('active','trialing','past_due')
        )
      ORDER BY bv.business_name
    `;

    const result = await database.query(query, [countryCode]);
    console.log(`🚗 Found ${result.rows.length} ride service businesses in ${countryCode}`);
    
    return result.rows.map(row => ({
      userId: row.user_id,
      businessName: row.business_name,
      businessEmail: row.business_email,
      notificationReason: 'ride_service'
    }));
  }

  /**
   * Get product seller businesses only
   */
  static async getProductSellerBusinesses(countryCode) {
    const query = `
      SELECT DISTINCT bv.user_id, bv.business_name, bv.business_email
      FROM business_verifications bv
      LEFT JOIN business_types bt ON bt.id = bv.business_type_id
      WHERE bv.is_verified = true
        AND bv.status = 'approved'
        AND bv.country = $1
        AND (
          LOWER(COALESCE(bt.name, '')) = 'product seller' OR
          LOWER(COALESCE(bv.business_category, '')) = 'product seller' OR
          bv.business_type = 'product_selling' OR
          bv.business_type = 'both'
        )
        AND EXISTS (
          SELECT 1 FROM user_subscriptions us
          JOIN subscription_plans_new sp ON sp.id = us.plan_id AND sp.type='business'
          WHERE us.user_id = bv.user_id AND us.status IN ('active','trialing','past_due')
        )
      ORDER BY bv.business_name
    `;

    const result = await database.query(query, [countryCode]);
    console.log(`🏷️ Found ${result.rows.length} product seller businesses in ${countryCode}`);
    return result.rows.map(row => ({
      userId: row.user_id,
      businessName: row.business_name,
      businessEmail: row.business_email,
      notificationReason: 'product_seller'
    }));
  }

  /**
   * Get businesses filtered by business type names (supports legacy and joined name)
   */
  static async getBusinessesByTypeNames(countryCode, names = []) {
    const lowered = names.map(n => String(n).toLowerCase());
    const query = `
      SELECT DISTINCT bv.user_id, bv.business_name, bv.business_email
      FROM business_verifications bv
      LEFT JOIN business_types bt ON bt.id = bv.business_type_id
      WHERE bv.is_verified = true
        AND bv.status = 'approved'
        AND bv.country = $1
        AND (
          LOWER(COALESCE(bt.name, '')) = ANY($2)
          OR LOWER(COALESCE(bv.business_category, '')) = ANY($2)
        )
        AND EXISTS (
          SELECT 1 FROM user_subscriptions us
          JOIN subscription_plans_new sp ON sp.id = us.plan_id AND sp.type='business'
          WHERE us.user_id = bv.user_id AND us.status IN ('active','trialing','past_due')
        )
      ORDER BY bv.business_name
    `;
    const result = await database.query(query, [countryCode, lowered]);
    console.log(`🏢 Found ${result.rows.length} businesses by types [${lowered.join(', ')}] in ${countryCode}`);
    return result.rows.map(row => ({
      userId: row.user_id,
      businessName: row.business_name,
      businessEmail: row.business_email,
      notificationReason: 'type_filtered'
    }));
  }

  /**
   * Get all businesses with category preference (for item/service/rent requests)
   * Anyone can respond, but prioritize category matches
   */
  static async getAllBusinessesWithCategoryPreference(categoryId, subcategoryId, countryCode, requestType = null) {
    const query = `
      SELECT DISTINCT bv.user_id, bv.business_name, bv.business_email, bv.categories, bv.business_type,
             cbt.country_code, cbt.name as cbt_name,
             cbt.can_respond_item, cbt.can_respond_service, cbt.can_respond_rent,
             cbt.can_respond_tours, cbt.can_respond_events, cbt.can_respond_construction,
             cbt.can_respond_education, cbt.can_respond_hiring, cbt.can_respond_ride,
             CASE 
               WHEN bv.categories @> $2::jsonb THEN 'category_match'
               WHEN bv.categories @> $3::jsonb THEN 'subcategory_match' 
               ELSE 'general_business'
             END as match_priority
      FROM business_verifications bv
      LEFT JOIN country_business_types cbt ON cbt.id = bv.country_business_type_id
      WHERE bv.is_verified = true
        AND bv.status = 'approved'
        AND bv.country = $1
        AND (cbt.country_code IS NULL OR cbt.country_code = $1)
        AND EXISTS (
          SELECT 1 FROM user_subscriptions us
          JOIN subscription_plans_new sp ON sp.id = us.plan_id AND sp.type='business'
          WHERE us.user_id = bv.user_id AND us.status IN ('active','trialing','past_due')
        )
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
    // Apply capability filter if requestType provided and country flags exist
    const filtered = result.rows.filter(row => {
      if (!requestType || !row.cbt_name) return true; // legacy/no country type, allow
      switch (requestType) {
        case 'item': return row.can_respond_item !== false; // default true
        case 'service': return row.can_respond_service !== false;
        case 'rent': return row.can_respond_rent !== false;
        case 'tours': return row.can_respond_tours !== false;
        case 'events': return row.can_respond_events !== false;
        case 'construction': return row.can_respond_construction !== false;
        case 'education': return row.can_respond_education !== false;
        case 'hiring': return row.can_respond_hiring !== false;
        case 'ride': return row.can_respond_ride === true; // only if explicitly enabled
        default: return true;
      }
    });

    return filtered.map(row => ({
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
      SELECT bv.business_type, bv.categories, bv.is_verified, bv.status,
             COALESCE(bt.name, '') as bt_name, COALESCE(bv.business_category, '') as bt_category
      FROM business_verifications bv
      LEFT JOIN business_types bt ON bt.id = bv.business_type_id
      WHERE bv.user_id = $1 AND bv.is_verified = true AND bv.status = 'approved'
    `;

    const result = await database.query(query, [userId]);
    if (result.rows.length === 0) {
      return { canRespond: false, reason: 'not_verified_business' };
    }

    const business = result.rows[0];

    // Check request type restrictions
    if (requestType === 'delivery') {
      // Only delivery service businesses can respond to delivery requests
      const name = (business.bt_name || '').toLowerCase();
      const cat = (business.bt_category || '').toLowerCase();
      const legacy = business.business_type;
      const isDelivery = ['delivery service','delivery'].includes(name) || ['delivery service','delivery'].includes(cat) || legacy === 'delivery_service' || legacy === 'both';
      if (isDelivery) return { canRespond: true, reason: 'delivery_service_authorized' };
      return { canRespond: false, reason: 'delivery_requires_delivery_service' };
    }

    if (requestType === 'ride') {
      // Check if this is a ride service business
      const name = (business.bt_name || '').toLowerCase();
      const cat = (business.bt_category || '').toLowerCase();
      const legacy = business.business_type;
      const isRideService = ['ride'].includes(name) || ['ride service','ride'].includes(cat) || legacy === 'ride_service' || legacy === 'both';
      if (isRideService) return { canRespond: true, reason: 'ride_service_authorized' };
      return { canRespond: false, reason: 'ride_requests_for_ride_services_only' };
    }

    // For common requests, respect per-country capabilities if available
  let rt = (requestType || '').toLowerCase();
  if (rt === 'hiring') rt = 'job';
  if (['item','service','rent','tours','events','construction','education','hiring','job'].includes(rt)) {
      const capQuery = `
        SELECT cbt.*
        FROM business_verifications bv
        LEFT JOIN country_business_types cbt ON cbt.id = bv.country_business_type_id
        WHERE bv.user_id = $1
      `;
      const capRes = await database.query(capQuery, [userId]);
      if (capRes.rows.length === 0 || !capRes.rows[0]) {
        return { canRespond: true, reason: 'open_to_all_businesses' };
      }
      const c = capRes.rows[0];
      const allowed = {
        item: c.can_respond_item !== false,
        service: c.can_respond_service !== false,
        rent: c.can_respond_rent !== false,
        tours: c.can_respond_tours !== false,
        events: c.can_respond_events !== false,
        construction: c.can_respond_construction !== false,
        education: c.can_respond_education !== false,
        hiring: c.can_respond_hiring !== false,
        job: c.can_respond_hiring !== false
      }[rt];
      return { canRespond: !!allowed, reason: allowed ? 'country_capability_enabled' : 'country_capability_disabled' };
    }

    return { canRespond: true, reason: 'general_business_request' };
  }

  /**
   * Get business access rights (what features they can use)
   * Updated: Product sellers can add prices AND send most requests
   */
  static async getBusinessAccessRights(userId) {
    const query = `
      SELECT bv.business_type, bv.categories, bv.is_verified, bv.status,
             COALESCE(bt.name, '') as bt_name, COALESCE(bv.business_category, '') as bt_category
      FROM business_verifications bv
      LEFT JOIN business_types bt ON bt.id = bv.business_type_id
      WHERE bv.user_id = $1
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

  // Determine access rights based on type (support both legacy string and new bt_name/category)
  const btName = (business.bt_name || '').toLowerCase();
  const btCat = (business.bt_category || '').toLowerCase();
  const legacy = (business.business_type || '').toLowerCase();
  const isProductSeller = btName === 'product seller' || btCat === 'product seller' || legacy === 'product_selling' || legacy === 'both';
  const isDeliveryService = ['delivery service','delivery'].includes(btName) || ['delivery service','delivery'].includes(btCat) || legacy === 'delivery_service' || legacy === 'both';
  const isRideService = ['ride'].includes(btName) || ['ride service','ride'].includes(btCat) || legacy === 'ride_service' || legacy === 'both';

    // Fetch country capability flags
    const capRes = await database.query(`
      SELECT cbt.can_manage_prices, cbt.can_respond_item, cbt.can_respond_service, cbt.can_respond_rent,
             cbt.can_respond_tours, cbt.can_respond_events, cbt.can_respond_construction,
             cbt.can_respond_education, cbt.can_respond_hiring, cbt.can_respond_delivery, cbt.can_respond_ride
      FROM country_business_types cbt
      WHERE cbt.id = $1
    `, [business.country_business_type_id || null]);

    const caps = capRes.rows[0] || {};

    return {
      // Price management (only product sellers)
      canAddPrices: isVerified && (caps.can_manage_prices ?? isProductSeller),

  // Request creation rights (any verified business can send any request except ride)
  canSendItemRequests: isVerified,
  canSendServiceRequests: isVerified,
  canSendRentRequests: isVerified,
  canSendDeliveryRequests: isVerified,
      canSendRideRequests: false,          // rides are for drivers only

  // Response rights (respect per-country caps)
  canRespondToDelivery: isVerified && (caps.can_respond_delivery ?? isDeliveryService),
  canRespondToRide: isVerified && (caps.can_respond_ride ?? isRideService), // Allow ride services to respond to ride requests
  canRespondToOther: isVerified && ((caps.can_respond_item ?? true) || (caps.can_respond_service ?? true) || (caps.can_respond_rent ?? true) || (caps.can_respond_tours ?? true) || (caps.can_respond_events ?? true) || (caps.can_respond_construction ?? true) || (caps.can_respond_education ?? true) || (caps.can_respond_hiring ?? true)),

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
