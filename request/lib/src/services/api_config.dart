// API Configuration for REST API Backend
class ApiConfig {
  // Base URL for the API
  static const String baseUrl = 'https://api.alphabet.lk/api';

  // Alternative URLs for different environments
  static const String developmentUrl = 'http://localhost:3001/api';
  static const String productionUrl = 'https://api.alphabet.lk/api';

  // Get the appropriate base URL based on environment
  static String get apiBaseUrl {
    // Use production URL for all builds
    return productionUrl;
  }

  // API Endpoints
  static const String authEndpoint = '/auth';
  static const String categoriesEndpoint = '/categories';
  static const String citiesEndpoint = '/cities';
  static const String vehicleTypesEndpoint = '/vehicle-types';
  static const String requestsEndpoint = '/requests';

  // Request timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Default headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Authenticated headers
  static Map<String, String> getAuthHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
}
