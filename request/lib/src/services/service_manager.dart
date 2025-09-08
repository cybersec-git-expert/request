import 'package:flutter/foundation.dart';

// Import new REST API services
import 'rest_auth_service.dart';
import 'rest_category_service.dart';
import 'rest_city_service.dart';
import 'rest_vehicle_type_service.dart';
import 'rest_request_service.dart';

/// Service Manager to handle REST API services
/// Simplified version for REST API only
class ServiceManager {
  static ServiceManager? _instance;
  static ServiceManager get instance => _instance ??= ServiceManager._();

  ServiceManager._();

  Future<void> initialize() async {
    try {
      // REST API services are initialized automatically via their singletons
      // Just verify they're accessible
      RestAuthService.instance;
      RestCategoryService.instance;
      RestCityService.instance;
      RestVehicleTypeService.instance;
      RestRequestService.instance;

      if (kDebugMode) {
        print('✅ REST API services initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing REST API services: $e');
      }
      rethrow;
    }
  }

  // Helper methods for services
  RestAuthService get authService => RestAuthService.instance;
  RestCategoryService get categoryService => RestCategoryService.instance;
  RestCityService get cityService => RestCityService.instance;
  RestVehicleTypeService get vehicleTypeService =>
      RestVehicleTypeService.instance;
  RestRequestService get requestService => RestRequestService.instance;

  Future<bool> isAuthenticated() async {
    try {
      return await authService.isAuthenticated();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking authentication: $e');
      }
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await authService.logout();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
    }
  }
}
