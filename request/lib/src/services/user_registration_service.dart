import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'rest_auth_service.dart';

/// Service to fetch user registrations and determine user capabilities
class UserRegistrationService {
  UserRegistrationService._();
  static UserRegistrationService? _instance;
  static UserRegistrationService get instance =>
      _instance ??= UserRegistrationService._();

  final ApiClient _apiClient = ApiClient.instance;
  final RestAuthService _authService = RestAuthService.instance;

  // Cache for user registrations
  Map<String, UserRegistrations>? _cachedRegistrations;
  DateTime? _lastFetch;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Get current user's registrations and capabilities
  Future<UserRegistrations?> getUserRegistrations() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return null;

      // Check cache first
      if (_cachedRegistrations != null &&
          _lastFetch != null &&
          DateTime.now().difference(_lastFetch!) < _cacheTimeout) {
        return _cachedRegistrations![currentUser.id];
      }

      // Fetch fresh data
      final registrations = await _fetchUserRegistrations(currentUser.id);

      // Update cache
      _cachedRegistrations = {currentUser.id: registrations};
      _lastFetch = DateTime.now();

      return registrations;
    } catch (e) {
      if (kDebugMode) print('❌ Error getting user registrations: $e');
      return null;
    }
  }

  /// Fetch user registrations from backend
  Future<UserRegistrations> _fetchUserRegistrations(String userId) async {
    UserRegistrations registrations = UserRegistrations();
    if (kDebugMode)
      print(
          '🔍 UserRegistrationService: Fetching registrations for user $userId');

    try {
      // Check driver registration
      try {
        if (kDebugMode)
          print('🚗 UserRegistrationService: Checking driver registration...');
        final driverResponse =
            await _apiClient.get('/api/driver-verifications/user/$userId');
        if (kDebugMode)
          print(
              '🚗 UserRegistrationService: Driver response: ${driverResponse.isSuccess ? 'SUCCESS' : 'FAILED'}');
        if (driverResponse.isSuccess && driverResponse.data != null) {
          final driverData = driverResponse.data['data'];
          if (kDebugMode)
            print('🚗 UserRegistrationService: Driver data: $driverData');
          if (driverData['status'] == 'approved') {
            registrations.isApprovedDriver = true;
            registrations.driverVehicleTypes = [
              driverData['vehicle_type_display_name'] ?? 'Unknown'
            ];
            registrations.driverVehicleTypeIds = [
              driverData['vehicle_type_id']
            ];
            if (kDebugMode)
              print(
                  '✅ UserRegistrationService: User is approved driver with vehicle type: ${driverData['vehicle_type_display_name']}');
          } else if (driverData['status'] == 'pending') {
            registrations.hasPendingDriverApplication = true;
            if (kDebugMode)
              print(
                  '⏳ UserRegistrationService: User has pending driver application');
          }
        }
      } catch (e) {
        // Driver registration not found or error - user is not a driver
        if (kDebugMode)
          print(
              'ℹ️ UserRegistrationService: No driver registration found for user - $e');
      }

      // Check business registration
      try {
        if (kDebugMode)
          print(
              '🏢 UserRegistrationService: Checking business registration...');
        final businessResponse =
            await _apiClient.get('/api/business-verifications/user/$userId');
        if (kDebugMode)
          print(
              '🏢 UserRegistrationService: Business response: ${businessResponse.isSuccess ? 'SUCCESS' : 'FAILED'}');
        if (businessResponse.isSuccess && businessResponse.data != null) {
          final businessData = businessResponse.data['data'];
          if (kDebugMode)
            print('🏢 UserRegistrationService: Business data: $businessData');
          if (businessData['status'] == 'approved') {
            registrations.isApprovedBusiness = true;
            // Check if business category includes delivery
            final businessCategory =
                businessData['business_category']?.toString().toLowerCase();
            registrations.businessCategory = businessCategory;
            if (kDebugMode)
              print(
                  '🏢 UserRegistrationService: Business category: $businessCategory');
            if (businessCategory?.contains('delivery') == true ||
                businessCategory?.contains('logistics') == true ||
                businessCategory?.contains('courier') == true) {
              registrations.canHandleDeliveryRequests = true;
              if (kDebugMode)
                print(
                    '✅ UserRegistrationService: User is approved business with delivery capabilities: $businessCategory');
            } else {
              if (kDebugMode)
                print(
                    'ℹ️ UserRegistrationService: User is approved business but no delivery capabilities: $businessCategory');
            }

            // Determine if this is a product seller business
            if (businessCategory != null) {
              final productKeywords = [
                'retail',
                'wholesale',
                'ecommerce',
                'product',
                'shop',
                'store'
              ];
              registrations.isProductSeller =
                  productKeywords.any((kw) => businessCategory.contains(kw));
              if (kDebugMode) {
                print(
                    '🛒 UserRegistrationService: isProductSeller=${registrations.isProductSeller} based on category "$businessCategory"');
              }
            }
          } else if (businessData['status'] == 'pending') {
            registrations.hasPendingBusinessApplication = true;
            if (kDebugMode)
              print(
                  '⏳ UserRegistrationService: User has pending business application');
          }
        }
      } catch (e) {
        // Business registration not found or error - user is not a business
        if (kDebugMode)
          print(
              'ℹ️ UserRegistrationService: No business registration found for user - $e');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching user registrations: $e');
    }

    return registrations;
  }

  /// Clear cache to force refresh
  void clearCache() {
    _cachedRegistrations = null;
    _lastFetch = null;
  }

  /// Get allowed request types for current user based on their registrations
  Future<List<String>> getAllowedRequestTypes() async {
    final registrations = await getUserRegistrations();
    if (registrations == null) {
      // Default for unauthenticated users - only basic request types
      if (kDebugMode)
        print(
            '🔍 UserRegistrationService: No user registrations found, returning default types');
      return ['item', 'service', 'rent'];
    }

    if (kDebugMode)
      print('🔍 UserRegistrationService: Found registrations: $registrations');

    List<String> allowedTypes = [
      'item',
      'service',
      'rent'
    ]; // Base types for all users

    // Add delivery if user is approved business with delivery capabilities
    if (registrations.isApprovedBusiness &&
        registrations.canHandleDeliveryRequests) {
      allowedTypes.add('delivery');
      if (kDebugMode)
        print(
            '✅ UserRegistrationService: Added delivery type (approved business with delivery capabilities)');
    }

    // Add ride if user is approved driver
    if (registrations.isApprovedDriver) {
      allowedTypes.add('ride');
      if (kDebugMode)
        print('✅ UserRegistrationService: Added ride type (approved driver)');
    }

    if (kDebugMode)
      print('🎯 UserRegistrationService: Final allowed types: $allowedTypes');
    return allowedTypes;
  }

  /// Get vehicle type filter for ride requests (for drivers)
  Future<List<String>?> getDriverVehicleTypeIds() async {
    final registrations = await getUserRegistrations();
    return registrations?.driverVehicleTypeIds;
  }
}

/// Data class to hold user registration information
class UserRegistrations {
  bool isApprovedDriver = false;
  bool isApprovedBusiness = false;
  bool hasPendingDriverApplication = false;
  bool hasPendingBusinessApplication = false;
  bool canHandleDeliveryRequests = false;
  bool isProductSeller = false;
  String? businessCategory;
  List<String> driverVehicleTypes = [];
  List<String> driverVehicleTypeIds = [];

  @override
  String toString() {
    return 'UserRegistrations(driver: $isApprovedDriver, business: $isApprovedBusiness, '
        'vehicleTypes: $driverVehicleTypes, deliveryCapable: $canHandleDeliveryRequests, '
        'productSeller: $isProductSeller, businessCategory: $businessCategory)';
  }
}
