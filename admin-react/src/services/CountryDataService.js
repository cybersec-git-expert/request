import api from './apiClient';

/**
 * Centralized Country-Based Data Filtering Service
 * Handles all country-wise data filtering for admin panel
 */
export class CountryDataService {
  constructor() {
    this.cache = new Map();
  }

  /**
   * Get country-filtered query based on user role
   * @param {string} collectionName - Collection name
   * @param {Object} adminData - Admin user data { role, country }
   * @param {Array} additionalFilters - Additional query filters
   * @returns {Object} Query parameters with country filtering applied
   */
  getCountryFilteredQuery(collectionName, adminData) {
    // For REST we just build query params. Keeping method for backward compatibility.
    const params = {};
    if (adminData?.role === 'country_admin' && adminData?.country) {
      params.country = adminData.country;
    }
    return params;
  }

  /**
   * Get filtered data based on user role and country
   * @param {string} collectionName - Collection to query
   * @param {Object} adminData - Admin data
   * @param {Array} additionalFilters - Additional filters
   * @returns {Promise<Array>} Filtered documents
   */
  async getFilteredData(collectionName, adminData, params = {}) {
    try {
      const countryParams = this.getCountryFilteredQuery(collectionName, adminData);
      const queryParams = { ...countryParams, ...params };
      const endpointMap = {
        categories: '/categories',
        subcategories: '/subcategories',
        brands: '/brands',
        vehicles: '/vehicles',
        vehicle_types: '/vehicle-types',
        master_products: '/master-products',
        country_products: '/country-products',
        country_categories: '/country-categories',
        country_subcategories: '/country-subcategories',
        country_brands: '/country-brands',
        country_variable_types: '/country-variable-types',
        variables: '/variables',
        requests: '/requests',
        responses: '/responses',
        users: '/users',
        admin_users: '/admin-users',
        cities: '/cities',
        price_listings: '/price-listings'
      };
      const path = endpointMap[collectionName] || `/${collectionName}`;
      const res = await api.get(path, { params: queryParams });
      // Assume API returns { data: [...] } or array directly
      let data;
      if (Array.isArray(res.data)) {
        data = res.data;
      } else if (res.data && Array.isArray(res.data.data)) {
        data = res.data.data;
      } else if (res.data && res.data.data && Array.isArray(res.data.data.requests)) {
        data = res.data.data.requests; // nested shape (requests endpoint)
      } else if (res.data && res.data.requests && Array.isArray(res.data.requests)) {
        data = res.data.requests;
      } else {
        data = [];
      }
      return data;
    } catch (error) {
      console.error(`Error fetching filtered data from ${collectionName}:`, error);
      throw error;
    }
  }

  /**
   * Check if admin has access to specific country data
   * @param {Object} adminData - Admin data
   * @param {string} dataCountry - Country of the data being accessed
   * @returns {boolean} Has access or not
   */
  hasCountryAccess(adminData, dataCountry) {
    // Super admin has access to all countries
    if (adminData?.role === 'super_admin') {
      return true;
    }

    // Country admin only has access to their country
    if (adminData?.role === 'country_admin') {
      return adminData?.country === dataCountry;
    }

    return false;
  }

  /**
   * Get businesses filtered by country
   */
  async getBusinesses(adminData, additionalFilters = []) {
  return this.getFilteredData('businesses', adminData, additionalFilters);
  }

  /**
   * Get drivers filtered by country
   */
  async getDrivers(adminData, additionalFilters = []) {
  return this.getFilteredData('drivers', adminData, additionalFilters);
  }

  /**
   * Get requests filtered by country
   */
  async getRequests(adminData, additionalFilters = []) {
    return this.getFilteredData('requests', adminData, additionalFilters);
  }

  /**
   * Get responses filtered by country
   */
  async getResponses(adminData, additionalFilters = []) {
    return this.getFilteredData('responses', adminData, additionalFilters);
  }

  /**
   * Get price listings filtered by country
   */
  async getPriceListings(adminData, additionalFilters = []) {
  return this.getFilteredData('price_listings', adminData, additionalFilters);
  }

  /**
   * Get users filtered by country
   */
  async getUsers(adminData, additionalFilters = []) {
    return this.getFilteredData('users', adminData, additionalFilters);
  }

  /**
   * Get admin users (super admin only)
   */
  async getAdminUsers(adminData, additionalFilters = []) {
    const params = {};
    if (adminData?.role !== 'super_admin') {
      // Country admin can only see admins from their country
      params.country = adminData?.country;
    }
    return this.getFilteredData('admin_users', adminData, additionalFilters, params);
  }

  /**
   * Get legal documents filtered by country
   */
  async getLegalDocuments(adminData, additionalFilters = []) {
    return this.getFilteredData('legal_documents', adminData, additionalFilters);
  }

  /**
   * Get country-specific statistics
   */
  async getCountryStats(adminData) {
    try {
      const stats = {};

      // Get counts for different collections
      const [businesses, drivers, requests, responses, users] = await Promise.all([
        this.getBusinesses(adminData),
        this.getDrivers(adminData),
        this.getRequests(adminData),
        this.getResponses(adminData),
        this.getUsers(adminData),
      ]);

      stats.businesses = {
        total: businesses.length,
        approved: businesses.filter(b => b.verificationStatus === 'approved').length,
        pending: businesses.filter(b => b.verificationStatus === 'pending').length,
        rejected: businesses.filter(b => b.verificationStatus === 'rejected').length,
      };

      stats.drivers = {
        total: drivers.length,
        approved: drivers.filter(d => d.verificationStatus === 'approved').length,
        pending: drivers.filter(d => d.verificationStatus === 'pending').length,
        rejected: drivers.filter(d => d.verificationStatus === 'rejected').length,
      };

      stats.requests = {
        total: requests.length,
        active: requests.filter(r => r.status === 'active').length,
        completed: requests.filter(r => r.status === 'completed').length,
        cancelled: requests.filter(r => r.status === 'cancelled').length,
      };

      stats.responses = {
        total: responses.length,
        accepted: responses.filter(r => r.status === 'accepted').length,
        pending: responses.filter(r => r.status === 'pending').length,
      };

      stats.users = {
        total: users.length,
        active: users.filter(u => u.isActive !== false).length,
        emailVerified: users.filter(u => u.isEmailVerified).length,
        phoneVerified: users.filter(u => u.isPhoneVerified).length,
      };

      return stats;
    } catch (error) {
      console.error('Error fetching country stats:', error);
      throw error;
    }
  }

  /**
   * Validate country access for data operations
   */
  validateCountryAccess(adminData, dataCountry, operation = 'read') {
    if (!this.hasCountryAccess(adminData, dataCountry)) {
      throw new Error(`Access denied: ${adminData?.role || 'User'} cannot ${operation} data from country ${dataCountry}`);
    }
  }
}

// Export singleton instance
export const countryDataService = new CountryDataService();
export default countryDataService;
