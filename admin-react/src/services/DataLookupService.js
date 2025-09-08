import api from './apiClient';

// Cache for user data to avoid repeated fetches
const userCache = new Map();
const productCache = new Map();
const businessCache = new Map();

export class DataLookupService {
  // Get user data by ID
  static async getUserData(userId) {
    if (!userId) return null;
    
    if (userCache.has(userId)) {
      return userCache.get(userId);
    }

    try {
      const res = await api.get(`/users/${userId}`);
      const userData = res.data?.data || res.data;
      userCache.set(userId, userData);
      return userData;
    } catch (error) {
      console.error('Error fetching user data:', error);
      return null;
    }
  }

  // Get product data by ID
  static async getProductData(productId) {
    if (!productId) return null;
    
    if (productCache.has(productId)) {
      return productCache.get(productId);
    }

    try {
      const res = await api.get(`/products/${productId}`);
      const productData = res.data?.data || res.data;
      productCache.set(productId, productData);
      return productData;
    } catch (error) {
      console.error('Error fetching product data:', error);
      return null;
    }
  }

  // Get business data by ID
  static async getBusinessData(businessId) {
    if (!businessId) return null;
    
    if (businessCache.has(businessId)) {
      return businessCache.get(businessId);
    }

    try {
      const res = await api.get(`/businesses/${businessId}`);
      const businessData = res.data?.data || res.data;
      businessCache.set(businessId, businessData);
      return businessData;
    } catch (error) {
      console.error('Error fetching business data:', error);
      return null;
    }
  }

  // Get multiple users at once
  static async getMultipleUsers(userIds) {
    const userPromises = userIds.map(id => this.getUserData(id));
    return await Promise.all(userPromises);
  }

  // Get multiple products at once
  static async getMultipleProducts(productIds) {
    const productPromises = productIds.map(id => this.getProductData(id));
    return await Promise.all(productPromises);
  }

  // Get multiple businesses at once
  static async getMultipleBusinesses(businessIds) {
    const businessPromises = businessIds.map(id => this.getBusinessData(id));
    return await Promise.all(businessPromises);
  }

  // Clear cache when needed
  static clearCache() {
    userCache.clear();
    productCache.clear();
    businessCache.clear();
  }

  // Format user display name
  static formatUserDisplayName(userData) {
    if (!userData) return 'Unknown User';
    
    if (userData.displayName) {
      return userData.displayName;
    }
    
    if (userData.firstName && userData.lastName) {
      return `${userData.firstName} ${userData.lastName}`;
    }
    
    if (userData.firstName) {
      return userData.firstName;
    }
    
    if (userData.email) {
      return userData.email.split('@')[0];
    }
    
    return 'Anonymous User';
  }

  // Format product display name
  static formatProductDisplayName(productData) {
    if (!productData) return 'Unknown Product';
    
    return productData.name || productData.title || 'Untitled Product';
  }

  // Format business display name
  static formatBusinessDisplayName(businessData) {
    if (!businessData) return 'Unknown Business';
    
    return businessData.businessName || businessData.name || 'Unnamed Business';
  }

  // Get all products
  static async getAllProducts() {
    try {
      const res = await api.get('/products');
      const data = Array.isArray(res.data) ? res.data : (res.data.data || []);
      return data;
    } catch (error) {
      console.error('Error fetching all products:', error);
      return [];
    }
  }

  // Get all categories
  static async getAllCategories() {
    try {
      const res = await api.get('/categories');
      const data = Array.isArray(res.data) ? res.data : (res.data.data || []);
      return data;
    } catch (error) {
      console.error('Error fetching all categories:', error);
      return [];
    }
  }

  // Get all subcategories
  static async getAllSubcategories() {
    try {
      const res = await api.get('/subcategories');
      const data = Array.isArray(res.data) ? res.data : (res.data.data || []);
      return data;
    } catch (error) {
      console.error('Error fetching all subcategories:', error);
      return [];
    }
  }

  // Get all brands
  static async getAllBrands() {
    try {
      const res = await api.get('/brands');
      const data = Array.isArray(res.data) ? res.data : (res.data.data || []);
      return data;
    } catch (error) {
      console.error('Error fetching all brands:', error);
      return [];
    }
  }

  // Get all variable types
  static async getAllVariableTypes() {
    try {
      const res = await api.get('/custom-product-variables');
      const data = Array.isArray(res.data) ? res.data : (res.data.data || []);
      return data;
    } catch (error) {
      console.error('Error fetching all variable types:', error);
      return [];
    }
  }
}

export default DataLookupService;
