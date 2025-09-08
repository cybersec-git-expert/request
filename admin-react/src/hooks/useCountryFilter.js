import { useContext, useCallback } from 'react';
import { AuthContext } from '../contexts/AuthContext';
import { CountryDataService } from '../services/CountryDataService';

/**
 * Hook for centralized country filtering across admin panel
 * Provides easy access to country-filtered data operations
 */
const useCountryFilter = () => {
  const { adminData } = useContext(AuthContext);
  const dataService = new CountryDataService();

  const isSuperAdmin = adminData?.role === 'super_admin';
  const isCountryAdmin = adminData?.role === 'country_admin';
  const userCountry = adminData?.country;

  /**
   * Get display name for current country/scope
   */
  const getCountryDisplayName = useCallback(() => {
    if (isSuperAdmin) return 'Global (All Countries)';
    if (userCountry) return `${userCountry.toUpperCase()}`;
    return 'Unknown Country';
  }, [isSuperAdmin, userCountry]);

  /**
   * Check if user can edit data from specific country
   */
  const canEditData = useCallback((dataCountry) => {
    if (isSuperAdmin) return true;
    if (isCountryAdmin) return userCountry === dataCountry;
    return false;
  }, [isSuperAdmin, isCountryAdmin, userCountry]);

  /**
   * Get country-filtered data for any collection
   */
  const getFilteredData = useCallback(async (collectionName, params = {}) => {
    return await dataService.getFilteredData(collectionName, adminData, params);
  }, [adminData]);

  // Specific data getters for each module
  const getRequests = useCallback((params = {}) => 
    getFilteredData('requests', params), [getFilteredData]);

  const getResponses = useCallback((params = {}) => 
    getFilteredData('responses', params), [getFilteredData]);

  const getBusinesses = useCallback((params = {}) => 
    getFilteredData('business_verifications', params), [getFilteredData]);

  const getDrivers = useCallback((params = {}) => 
    getFilteredData('driver_verifications', params), [getFilteredData]);

  const getUsers = useCallback((params = {}) => 
    getFilteredData('users', params), [getFilteredData]);

  const getSubscriptions = useCallback((params = {}) => 
    getFilteredData('subscriptions', params), [getFilteredData]);

  const getPriceListings = useCallback((params = {}) => 
    getFilteredData('price_listings', params), [getFilteredData]);

  const getCategories = useCallback((params = {}) => 
    getFilteredData('categories', params), [getFilteredData]);

  const getSubcategories = useCallback((params = {}) => 
    getFilteredData('subcategories', params), [getFilteredData]);

  const getBrands = useCallback((params = {}) => 
    getFilteredData('brands', params), [getFilteredData]);

  const getProducts = useCallback((params = {}) => 
    getFilteredData('master_products', params), [getFilteredData]);

  const getVehicles = useCallback((params = {}) => 
    getFilteredData('vehicles', params), [getFilteredData]);

  const getVehicleTypes = useCallback((params = {}) => 
    getFilteredData('vehicle_types', params), [getFilteredData]);

  const getVariables = useCallback((params = {}) => 
    getFilteredData('variables', params), [getFilteredData]);

  const getPromoCodes = useCallback((params = {}) => 
    getFilteredData('promo_codes', params), [getFilteredData]);

  const getPaymentMethods = useCallback((params = {}) => 
    getFilteredData('payment_methods', params), [getFilteredData]);

  /**
   * Get country-specific statistics
   */
  const getCountryStats = useCallback(async () => {
    try {
      const requests = await getRequests();
      const responses = await getResponses();
      const businesses = await getBusinesses();
      const drivers = await getDrivers();
      const users = await getUsers();

      return {
        requests: requests?.length || 0,
        responses: responses?.length || 0,
        businesses: businesses?.length || 0,
        drivers: drivers?.length || 0,
        users: users?.length || 0,
        country: userCountry || 'global'
      };
    } catch (error) {
      console.error('Error getting country stats:', error);
      return {
        requests: 0,
        responses: 0,
        businesses: 0,
        drivers: 0,
        users: 0,
        country: userCountry || 'global'
      };
    }
  }, [getRequests, getResponses, getBusinesses, getDrivers, getUsers, userCountry]);

  return {
    // User info
    isSuperAdmin,
    isCountryAdmin,
    userCountry,
    adminData,

    // Utility functions
    getCountryDisplayName,
    canEditData,

    // Data access functions
    getFilteredData,
    getRequests,
    getResponses,
    getBusinesses,
    getDrivers,
    getUsers,
    getSubscriptions,
    getPriceListings,
    getCategories,
    getSubcategories,
    getBrands,
    getProducts,
    getVehicles,
    getVehicleTypes,
    getVariables,
    getPromoCodes,
    getPaymentMethods,

    // Statistics
    getCountryStats
  };
};

export default useCountryFilter;
