import 'package:flutter/foundation.dart';
import '../models/enhanced_user_model.dart' as enhanced;
import '../models/request_model.dart';
import '../services/enhanced_user_service.dart';
import 'module_management_service.dart';

/// Request Filtering Service
/// Implements sophisticated filtering based on:
/// 1. Country-based filtering (user's registered country)
/// 2. Role-based filtering (driver, business, delivery)
/// 3. Vehicle type filtering for drivers
/// 4. Business category filtering for delivery services
class RequestFilteringService {
  static RequestFilteringService? _instance;
  static RequestFilteringService get instance =>
      _instance ??= RequestFilteringService._();

  RequestFilteringService._();

  final EnhancedUserService _userService = EnhancedUserService();

  /// Main method to filter requests based on user's role and country
  Future<List<RequestModel>> filterRequestsForUser(
      List<RequestModel> allRequests) async {
    try {
      // Get current user data
      final user = await _userService.getCurrentUserModel();
      final moduleService = ModuleManagementService.instance;
      final enabledModules = await moduleService.getEnabledModules();

      // Helper: gate by country-enabled modules
      List<RequestModel> _applyModuleGating(List<RequestModel> input) {
        // Build allowed request types from enabled modules
        final allowedTypes = <String>{};
        for (final m in enabledModules) {
          final cfg = ModuleManagementService.moduleConfigurations[m];
          if (cfg != null) {
            allowedTypes.addAll(cfg.requestTypes.map((e) => e.toLowerCase()));
          }
        }
        return input
            .where((r) => allowedTypes.contains(r.type.name.toLowerCase()))
            .toList();
      }

      if (user == null) {
        if (kDebugMode)
          print(
              '🚫 No authenticated user found; applying public visibility rules');
        // Public visibility: only show Price requests, still respect country module gating
        final moduleFiltered = _applyModuleGating(allRequests);
        return moduleFiltered
            .where((r) => r.type == enhanced.RequestType.price)
            .toList();
      }

      if (kDebugMode) {
        print('🔍 Filtering requests for user: ${user.id}');
        print('   User Roles: ${user.roles}');
        print('   Active Role: ${user.activeRole}');
        print('   Country: ${user.countryCode}');
      }

      List<RequestModel> filteredRequests = [];

      // Step 1: Filter by country (all authenticated users)
      filteredRequests = _filterByCountry(allRequests, user.countryCode);
      if (kDebugMode)
        print('🌍 After country filter: ${filteredRequests.length} requests');

      // Step 2: Apply role-based filtering
      filteredRequests = await _filterByUserRole(filteredRequests, user);
      if (kDebugMode)
        print('👤 After role filter: ${filteredRequests.length} requests');

      // Step 3: Apply vehicle type filtering for drivers
      if (user.hasRole(enhanced.UserRole.driver)) {
        filteredRequests = await _filterByVehicleType(filteredRequests, user);
        if (kDebugMode)
          print('🚗 After vehicle filter: ${filteredRequests.length} requests');
      }

      // Step 4: Apply business category filtering for delivery services
      if (user.hasRole(enhanced.UserRole.business) ||
          user.hasRole(enhanced.UserRole.delivery)) {
        filteredRequests =
            await _filterByBusinessCategory(filteredRequests, user);
        if (kDebugMode)
          print(
              '🏢 After business filter: ${filteredRequests.length} requests');
      }

      // Step 5: Apply country-enabled module gating
      filteredRequests = _applyModuleGating(filteredRequests);
      if (kDebugMode) {
        print('🧩 After module gating: ${filteredRequests.length} requests');
      }

      return filteredRequests;
    } catch (e) {
      if (kDebugMode) print('❌ Error filtering requests: $e');
      return [];
    }
  }

  /// Filter requests by user's registered country
  List<RequestModel> _filterByCountry(
      List<RequestModel> requests, String? userCountry) {
    if (userCountry == null) return [];

    return requests.where((request) {
      // Show only requests from user's country
      return request.country == userCountry ||
          request.country == null; // Legacy requests without country
    }).toList();
  }

  /// Apply role-based filtering logic
  Future<List<RequestModel>> _filterByUserRole(
      List<RequestModel> requests, enhanced.UserModel user) async {
    List<RequestModel> filteredRequests = [];

    for (RequestModel request in requests) {
      bool shouldShow = false;

      switch (request.type) {
        case enhanced.RequestType.ride:
          // Only drivers can see rider requests
          shouldShow = user.hasRole(enhanced.UserRole.driver) &&
              user.isRoleVerified(enhanced.UserRole.driver);
          break;

        case enhanced.RequestType.delivery:
          // Only delivery businesses can see delivery requests
          shouldShow = (user.hasRole(enhanced.UserRole.business) ||
                  user.hasRole(enhanced.UserRole.delivery)) &&
              await _isDeliveryServiceBusiness(user);
          break;

        case enhanced.RequestType.item:
        case enhanced.RequestType.service:
        case enhanced.RequestType.rental:
        case enhanced.RequestType.price:
          // These are available for all verified users to view and respond
          shouldShow = true;
          break;
      }

      if (shouldShow) {
        filteredRequests.add(request);
      }
    }

    return filteredRequests;
  }

  /// Filter ride requests by driver's vehicle type
  Future<List<RequestModel>> _filterByVehicleType(
      List<RequestModel> requests, enhanced.UserModel user) async {
    // Get user's registered vehicle type from driver verification
    String? userVehicleType = await _getUserVehicleType(user);

    if (userVehicleType == null) {
      if (kDebugMode) print('⚠️ No vehicle type found for driver');
      return requests
          .where((r) => r.type != enhanced.RequestType.ride)
          .toList();
    }

    if (kDebugMode) print('🚗 User vehicle type: $userVehicleType');

    return requests.where((request) {
      if (request.type != enhanced.RequestType.ride) {
        return true; // Non-ride requests pass through
      }

      // For ride requests, match vehicle type
      String? requestVehicleType = request.rideData?.vehicleType;
      if (requestVehicleType == null) {
        return true; // Show requests without specific vehicle type requirement
      }

      // Normalize vehicle type names for comparison
      String normalizedUserType = _normalizeVehicleType(userVehicleType);
      String normalizedRequestType = _normalizeVehicleType(requestVehicleType);

      bool matches = normalizedUserType == normalizedRequestType;

      if (kDebugMode && matches) {
        print(
            '✅ Vehicle type match: $normalizedUserType == $normalizedRequestType');
      }

      return matches;
    }).toList();
  }

  /// Filter delivery requests by business category
  Future<List<RequestModel>> _filterByBusinessCategory(
      List<RequestModel> requests, enhanced.UserModel user) async {
    // Check if user is registered as delivery service
    bool isDeliveryService = await _isDeliveryServiceBusiness(user);

    return requests.where((request) {
      if (request.type != enhanced.RequestType.delivery) {
        return true; // Non-delivery requests pass through
      }

      // Only show delivery requests to verified delivery service businesses
      return isDeliveryService;
    }).toList();
  }

  /// Get user's registered vehicle type from driver verification
  Future<String?> _getUserVehicleType(enhanced.UserModel user) async {
    try {
      // Get driver verification data
      final driverData =
          user.getRoleData<Map<String, dynamic>>(enhanced.UserRole.driver);
      if (driverData == null) return null;

      // Look for vehicle type in different possible field names
      String? vehicleType = driverData['vehicle_type'] ??
          driverData['vehicleType'] ??
          driverData['vehicle_type_name'] ??
          driverData['vehicleTypeName'];

      if (kDebugMode)
        print('🔍 Found vehicle type in driver data: $vehicleType');
      return vehicleType;
    } catch (e) {
      if (kDebugMode) print('❌ Error getting vehicle type: $e');
      return null;
    }
  }

  /// Check if user is registered as a delivery service business
  Future<bool> _isDeliveryServiceBusiness(enhanced.UserModel user) async {
    try {
      // Check if user has delivery role
      if (user.hasRole(enhanced.UserRole.delivery) &&
          user.isRoleVerified(enhanced.UserRole.delivery)) {
        return true;
      }

      // Check if user has business role and is specifically delivery category
      if (user.hasRole(enhanced.UserRole.business) &&
          user.isRoleVerified(enhanced.UserRole.business)) {
        final businessData =
            user.getRoleData<Map<String, dynamic>>(enhanced.UserRole.business);
        if (businessData != null) {
          String? businessCategory = businessData['business_category'] ??
              businessData['businessCategory'] ??
              businessData['category'];

          // Check if business category is delivery-related
          if (businessCategory != null) {
            String normalizedCategory = businessCategory.toLowerCase();
            bool isDelivery = normalizedCategory.contains('delivery') ||
                normalizedCategory.contains('courier') ||
                normalizedCategory.contains('logistics') ||
                normalizedCategory.contains('transport');

            if (kDebugMode)
              print(
                  '🏢 Business category: $businessCategory, isDelivery: $isDelivery');
            return isDelivery;
          }
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Error checking delivery service: $e');
      return false;
    }
  }

  /// Normalize vehicle type names for comparison
  String _normalizeVehicleType(String vehicleType) {
    String normalized = vehicleType.toLowerCase().trim();

    // Handle common variations
    Map<String, String> typeMapping = {
      'three wheeler': 'threewheeler',
      'three-wheeler': 'threewheeler',
      'auto rickshaw': 'threewheeler',
      'auto-rickshaw': 'threewheeler',
      'tuk tuk': 'threewheeler',
      'tuktuk': 'threewheeler',
      'two wheeler': 'twowheeler',
      'two-wheeler': 'twowheeler',
      'motorcycle': 'twowheeler',
      'motorbike': 'twowheeler',
      'bike': 'twowheeler',
      'scooter': 'twowheeler',
      'four wheeler': 'car',
      'four-wheeler': 'car',
      'automobile': 'car',
      'sedan': 'car',
      'hatchback': 'car',
      'suv': 'car',
      'pickup': 'pickup-truck',
      'pickup truck': 'pickup-truck',
      'lorry': 'truck',
      'mini bus': 'minibus',
      'mini-bus': 'minibus',
    };

    return typeMapping[normalized] ?? normalized;
  }

  /// Check if user can respond to a specific request
  Future<bool> canUserRespondToRequest(RequestModel request) async {
    final user = await _userService.getCurrentUserModel();
    if (user == null) return false;

    // Module gating: ensure this request's type is enabled for the country
    final enabledModules =
        await ModuleManagementService.instance.getEnabledModules();
    final allowedTypes = <String>{};
    for (final m in enabledModules) {
      final cfg = ModuleManagementService.moduleConfigurations[m];
      if (cfg != null)
        allowedTypes.addAll(cfg.requestTypes.map((e) => e.toLowerCase()));
    }
    if (!allowedTypes.contains(request.type.name.toLowerCase())) {
      return false;
    }

    // Country check
    if (request.country != null && request.country != user.countryCode) {
      return false;
    }

    // Role-based response permissions
    switch (request.type) {
      case enhanced.RequestType.ride:
        // Only verified drivers with matching vehicle type
        if (!user.hasRole(enhanced.UserRole.driver) ||
            !user.isRoleVerified(enhanced.UserRole.driver)) {
          return false;
        }

        String? userVehicleType = await _getUserVehicleType(user);
        if (userVehicleType == null) return false;

        String? requestVehicleType = request.rideData?.vehicleType;
        if (requestVehicleType != null) {
          String normalizedUserType = _normalizeVehicleType(userVehicleType);
          String normalizedRequestType =
              _normalizeVehicleType(requestVehicleType);
          return normalizedUserType == normalizedRequestType;
        }
        return true;

      case enhanced.RequestType.delivery:
        // Only verified delivery service businesses
        return await _isDeliveryServiceBusiness(user);

      case enhanced.RequestType.item:
      case enhanced.RequestType.service:
      case enhanced.RequestType.rental:
      case enhanced.RequestType.price:
        // Available for all verified users
        return user.roles.isNotEmpty;
    }
  }

  /// Get user's available request types based on their roles
  Future<List<enhanced.RequestType>> getUserAvailableRequestTypes() async {
    final user = await _userService.getCurrentUserModel();
    if (user == null) return [];

    List<enhanced.RequestType> availableTypes = [];

    // Country-enabled module gating
    final enabledModules =
        await ModuleManagementService.instance.getEnabledModules();
    final enabledTypesSet = <String>{};
    for (final m in enabledModules) {
      final cfg = ModuleManagementService.moduleConfigurations[m];
      if (cfg != null)
        enabledTypesSet.addAll(cfg.requestTypes.map((e) => e.toLowerCase()));
    }

    // All users can create these types
    void addIfEnabled(enhanced.RequestType t) {
      if (enabledTypesSet.contains(t.name.toLowerCase())) {
        availableTypes.add(t);
      }
    }

    // Base types (if enabled for country)
    addIfEnabled(enhanced.RequestType.item);
    addIfEnabled(enhanced.RequestType.service);
    addIfEnabled(enhanced.RequestType.rental);
    addIfEnabled(enhanced.RequestType.price);

    // Only verified drivers can create ride requests
    if (user.hasRole(enhanced.UserRole.driver) &&
        user.isRoleVerified(enhanced.UserRole.driver)) {
      addIfEnabled(enhanced.RequestType.ride);
    }

    // Only verified businesses can create delivery requests
    if ((user.hasRole(enhanced.UserRole.business) &&
            user.isRoleVerified(enhanced.UserRole.business)) ||
        (user.hasRole(enhanced.UserRole.delivery) &&
            user.isRoleVerified(enhanced.UserRole.delivery))) {
      addIfEnabled(enhanced.RequestType.delivery);
    }

    return availableTypes;
  }

  /// Debug method to log filtering decisions
  void debugFilteringDecision(RequestModel request, enhanced.UserModel user,
      bool shouldShow, String reason) {
    if (kDebugMode) {
      print('🔍 Request: ${request.title} (${request.type.name})');
      print('   User: ${user.name} (${user.activeRole.name})');
      print('   Show: $shouldShow - $reason');
      print('   Country: ${request.country} vs ${user.countryCode}');
      if (request.type == enhanced.RequestType.ride) {
        print('   Vehicle: ${request.rideData?.vehicleType}');
      }
      print('---');
    }
  }
}
