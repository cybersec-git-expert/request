import React, { useContext, createContext, useCallback, useMemo } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { countryDataService } from '../services/CountryDataService';

// Create context for country filtering
const CountryFilterContext = createContext();

export const CountryFilterProvider = ({ children }) => {
  const { adminData } = useAuth();
  
  const value = useMemo(() => ({
    adminData,
    countryDataService,
  }), [adminData]);

  return (
    <CountryFilterContext.Provider value={value}>
      {children}
    </CountryFilterContext.Provider>
  );
};

// Hook to use country filtering throughout the app
export const useCountryFilter = () => {
  const context = useContext(CountryFilterContext);
  const { adminData, isSuperAdmin } = useAuth();
  
  if (!context) {
    throw new Error('useCountryFilter must be used within a CountryFilterProvider');
  }

  // Memoized functions to prevent unnecessary re-renders
  // Flexible wrapper to tolerate legacy/misused call signatures found in codebase:
  // Supported patterns now:
  //  1) getFilteredData('categories')
  //  2) getFilteredData('categories', { includeInactive: true })
  //  3) getFilteredData('categories', adminData, { includeInactive: true })  <-- legacy incorrect usage (adminData ignored)
  //  4) getFilteredData('categories', undefined, { includeInactive: true })
  // The second argument SHOULD be the params object. If an adminData-like object (with role) is detected
  // it will be ignored in favor of the third argument.
  const getFilteredData = useCallback(
    async (collection, maybeParams, maybeParams2) => {
      try {
        let params = {};
        if (maybeParams2) {
          // Signature (collection, adminData, params)
            params = maybeParams2 || {};
        } else if (maybeParams && !maybeParams.role) {
          // Signature (collection, params)
          params = maybeParams || {};
        }
        return await countryDataService.getFilteredData(collection, adminData, params);
      } catch (error) {
        console.error(`Error getting filtered data from ${collection}:`, error);
        throw error;
      }
    },
    [adminData]
  );

  const getCountryFilteredQuery = useCallback(
    (collection, additionalFilters = []) => {
      return countryDataService.getCountryFilteredQuery(collection, adminData, additionalFilters);
    },
    [adminData]
  );

  const hasCountryAccess = useCallback(
    (dataCountry) => {
      return countryDataService.hasCountryAccess(adminData, dataCountry);
    },
    [adminData]
  );

  const validateCountryAccess = useCallback(
    (dataCountry, operation = 'read') => {
      return countryDataService.validateCountryAccess(adminData, dataCountry, operation);
    },
    [adminData]
  );

  // Specialized data getters
  const getBusinesses = useCallback(
    (additionalFilters = []) => countryDataService.getBusinesses(adminData, additionalFilters),
    [adminData]
  );

  const getDrivers = useCallback(
    (additionalFilters = []) => countryDataService.getDrivers(adminData, additionalFilters),
    [adminData]
  );

  const getRequests = useCallback(
    (additionalFilters = []) => countryDataService.getRequests(adminData, additionalFilters),
    [adminData]
  );

  const getResponses = useCallback(
    (additionalFilters = []) => countryDataService.getResponses(adminData, additionalFilters),
    [adminData]
  );

  const getPriceListings = useCallback(
    (additionalFilters = []) => countryDataService.getPriceListings(adminData, additionalFilters),
    [adminData]
  );

  const getUsers = useCallback(
    (additionalFilters = []) => countryDataService.getUsers(adminData, additionalFilters),
    [adminData]
  );

  const getAdminUsers = useCallback(
    (additionalFilters = []) => countryDataService.getAdminUsers(adminData, additionalFilters),
    [adminData]
  );

  const getLegalDocuments = useCallback(
    (additionalFilters = []) => countryDataService.getLegalDocuments(adminData, additionalFilters),
    [adminData]
  );

  const getCountryStats = useCallback(
    () => countryDataService.getCountryStats(adminData),
    [adminData]
  );

  // Helper functions for UI
  const getCountryDisplayName = useCallback(() => {
    if (isSuperAdmin) return 'Global (All Countries)';
    return adminData?.country || 'Unknown Country';
  }, [isSuperAdmin, adminData]);

  const canCreateGlobalData = useCallback(() => {
    return isSuperAdmin;
  }, [isSuperAdmin]);

  const canEditData = useCallback((dataCountry) => {
    return isSuperAdmin || adminData?.country === dataCountry;
  }, [isSuperAdmin, adminData]);

  const getAccessibleCountries = useCallback(() => {
    if (isSuperAdmin) {
      return 'all'; // Super admin can access all countries
    }
    return [adminData?.country].filter(Boolean); // Country admin can only access their country
  }, [isSuperAdmin, adminData]);

  return {
    // Core filtering functions
    getFilteredData,
    getCountryFilteredQuery,
    hasCountryAccess,
    validateCountryAccess,
    
    // Specialized data getters
    getBusinesses,
    getDrivers,
    getRequests,
    getResponses,
    getPriceListings,
    getUsers,
    getAdminUsers,
    getLegalDocuments,
    getCountryStats,
    
    // UI helpers
    getCountryDisplayName,
    canCreateGlobalData,
    canEditData,
    getAccessibleCountries,
    
    // Admin info
    adminData,
    userRole: adminData?.role,
    userCountry: adminData?.country,
    isSuperAdmin,
    isCountryAdmin: adminData?.role === 'country_admin',
  };
};

export default useCountryFilter;
