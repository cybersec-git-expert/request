import apiClient from './apiClient';

class DynamicBusinessTypeService {
  // Get all available modules
  static async getAvailableModules() {
    try {
      const response = await apiClient.get('/modules/list');
      return response.data.data;
    } catch (error) {
      console.error('Error fetching modules:', error);
      return [];
    }
  }

  // Get capabilities for a business type
  static async getBusinessTypeCapabilities(businessTypeId, countryCode) {
    try {
      const response = await apiClient.get(`/business-types/${businessTypeId}/capabilities`, {
        params: { country_code: countryCode }
      });
      return response.data.data;
    } catch (error) {
      console.error('Error fetching capabilities:', error);
      return null;
    }
  }

  // Update capabilities for a business type
  static async updateBusinessTypeCapabilities(businessTypeId, countryCode, capabilities) {
    try {
      const response = await apiClient.put(`/business-types/${businessTypeId}/capabilities`, capabilities, {
        params: { country_code: countryCode }
      });
      return response.data;
    } catch (error) {
      console.error('Error updating capabilities:', error);
      throw error;
    }
  }

  // Get modules for a business type
  static async getBusinessTypeModules(businessTypeId, countryCode) {
    try {
      const response = await apiClient.get(`/business-types/${businessTypeId}/modules`, {
        params: { country_code: countryCode }
      });
      return response.data.data;
    } catch (error) {
      console.error('Error fetching business type modules:', error);
      return [];
    }
  }

  // Update modules for a business type
  static async updateBusinessTypeModules(businessTypeId, countryCode, moduleIds) {
    try {
      const response = await apiClient.put(`/business-types/${businessTypeId}/modules`, { moduleIds }, {
        params: { country_code: countryCode }
      });
      return response.data;
    } catch (error) {
      console.error('Error updating business type modules:', error);
      throw error;
    }
  }

  // Get modules mapped to a business type name (fallback to static mapping)
  static getModulesForBusinessTypeName(typeName, availableModules) {
    const moduleMapping = {
      'Product Seller': ['item', 'service', 'rent', 'price'],
      'Delivery': ['item', 'service', 'rent', 'delivery'],
      'Ride': ['ride'],
      'Tours': ['tours'],
      'Events': ['events'],
      'Construction': ['construction'],
      'Education': ['education'],
      'Hiring': ['hiring'],
      'Other': ['other'],
      'Item': ['item'],
      'Rent': ['rent']
    };

    const moduleIds = moduleMapping[typeName] || [];
    return availableModules.filter(module => moduleIds.includes(module.id));
  }

  // Get capabilities for a business type name (fallback to static logic)
  static getCapabilitiesForBusinessTypeName(typeName) {
    const name = (typeName || '').toLowerCase();
    const isProductSeller = name === 'product seller';
    const isDeliveryService = name === 'delivery' || name === 'delivery service';
    const isRideService = name === 'ride';

    return {
      managePrices: isProductSeller,
      respondItem: true,
      respondService: true,
      respondRent: true,
      respondTours: true,
      respondEvents: true,
      respondConstruction: true,
      respondEducation: true,
      respondHiring: true,
      respondDelivery: isDeliveryService,
      respondRide: isRideService,
      sendRide: false
    };
  }
}

export default DynamicBusinessTypeService;
