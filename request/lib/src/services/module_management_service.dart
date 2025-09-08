import 'dart:convert';
import 'package:http/http.dart' as http;
import 'country_service.dart';

enum BusinessModule {
  itemRequest,
  serviceRequest,
  rentalRequest,
  deliveryRequest,
  rideSharing,
  priceRequest,
}

class ModuleConfiguration {
  final BusinessModule module;
  final String displayName;
  final String description;
  final List<String> requestTypes;
  final List<String> businessTypes;
  final List<String> navigationFeatures;
  final List<String> menuFeatures;
  final bool requiresDriverRegistration;

  const ModuleConfiguration({
    required this.module,
    required this.displayName,
    required this.description,
    required this.requestTypes,
    required this.businessTypes,
    required this.navigationFeatures,
    required this.menuFeatures,
    this.requiresDriverRegistration = false,
  });
}

class ModuleManagementService {
  static final ModuleManagementService _instance =
      ModuleManagementService._internal();
  factory ModuleManagementService() => _instance;
  ModuleManagementService._internal();

  static ModuleManagementService get instance => _instance;

  // Getter for module configurations
  static Map<BusinessModule, ModuleConfiguration> get moduleConfigurations =>
      _moduleConfigurations;

  // Cache for enabled modules
  Set<BusinessModule>? _enabledModules;
  DateTime? _lastFetchTime;
  static const Duration _cacheTimeout = Duration(minutes: 30);

  // Module configurations mapping
  static const Map<BusinessModule, ModuleConfiguration> _moduleConfigurations =
      {
    BusinessModule.itemRequest: ModuleConfiguration(
      module: BusinessModule.itemRequest,
      displayName: 'Item Request',
      description: 'Request for products or items',
      requestTypes: ['item'],
      businessTypes: [], // Available for all business types
      navigationFeatures: [],
      menuFeatures: [],
    ),
    BusinessModule.serviceRequest: ModuleConfiguration(
      module: BusinessModule.serviceRequest,
      displayName: 'Service Request',
      description: 'Request for services',
      requestTypes: ['service'],
      businessTypes: [], // Available for all business types
      navigationFeatures: [],
      menuFeatures: [],
    ),
    BusinessModule.rentalRequest: ModuleConfiguration(
      module: BusinessModule.rentalRequest,
      displayName: 'Rental Request',
      description: 'Rent vehicles, equipment, or items',
      requestTypes: ['rental', 'rent'],
      businessTypes: [], // Available for all business types
      navigationFeatures: [],
      menuFeatures: [],
    ),
    BusinessModule.deliveryRequest: ModuleConfiguration(
      module: BusinessModule.deliveryRequest,
      displayName: 'Delivery Request',
      description: 'Request for delivery services',
      requestTypes: ['delivery'],
      businessTypes: ['delivery'], // Only delivery businesses
      navigationFeatures: [],
      menuFeatures: [], // No menu features for delivery
    ),
    BusinessModule.rideSharing: ModuleConfiguration(
      module: BusinessModule.rideSharing,
      displayName: 'Ride Sharing',
      description: 'Taxi and ride sharing services',
      requestTypes: ['ride'],
      businessTypes: [], // Available for all business types
      navigationFeatures: [],
      menuFeatures: ['ride_alerts'], // Ride alerts in menu (CORRECTED)
      requiresDriverRegistration: true,
    ),
    BusinessModule.priceRequest: ModuleConfiguration(
      module: BusinessModule.priceRequest,
      displayName: 'Price Request',
      description: 'Compare prices across different sellers/services',
      requestTypes: ['price'],
      businessTypes: [
        'retail',
        'wholesale',
        'ecommerce'
      ], // Exclude delivery services
      navigationFeatures: [
        'price_comparison'
      ], // Price comparison icon in navigation
      menuFeatures: ['product_section'], // Product section in menu
    ),
  };

  /// Get enabled modules from backend
  Future<Set<BusinessModule>> getEnabledModules(
      {bool forceRefresh = false}) async {
    // Return cached data if available and not expired
    if (!forceRefresh &&
        _enabledModules != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTimeout) {
      return _enabledModules!;
    }

    try {
      final country = CountryService.instance.countryCode;
      final response = await http.get(
        Uri.parse(
            '${CountryService.instance.baseUrl}/api/modules/enabled?country=$country'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final enabledModuleNames =
            List<String>.from(data['enabled_modules'] ?? []);

        _enabledModules = enabledModuleNames
            .map(_parseModuleName)
            .where((module) => module != null)
            .cast<BusinessModule>()
            .toSet();

        _lastFetchTime = DateTime.now();
        return _enabledModules!;
      } else {
        throw Exception(
            'Failed to fetch enabled modules: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching enabled modules: $e');
      // Return all modules as enabled if there's an error (fallback)
      _enabledModules = BusinessModule.values.toSet();
      return _enabledModules!;
    }
  }

  /// Parse module name string to BusinessModule enum
  BusinessModule? _parseModuleName(String moduleName) {
    switch (moduleName.toLowerCase()) {
      case 'item_request':
      case 'item':
        return BusinessModule.itemRequest;
      case 'service_request':
      case 'service':
        return BusinessModule.serviceRequest;
      case 'rental_request':
      case 'rent':
      case 'rental':
        return BusinessModule.rentalRequest;
      case 'delivery_request':
      case 'delivery':
        return BusinessModule.deliveryRequest;
      case 'ride_sharing':
      case 'ride':
        return BusinessModule.rideSharing;
      case 'price_request':
      case 'price':
        return BusinessModule.priceRequest;
      default:
        return null;
    }
  }

  /// Check if a specific module is enabled
  Future<bool> isModuleEnabled(BusinessModule module) async {
    final enabledModules = await getEnabledModules();
    return enabledModules.contains(module);
  }

  /// Check if a request type is enabled
  Future<bool> isRequestTypeEnabled(String requestType) async {
    final enabledModules = await getEnabledModules();

    for (final module in enabledModules) {
      final config = _moduleConfigurations[module];
      if (config != null &&
          config.requestTypes.contains(requestType.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Check if a business type is enabled
  Future<bool> isBusinessTypeEnabled(String businessType) async {
    final enabledModules = await getEnabledModules();

    for (final module in enabledModules) {
      final config = _moduleConfigurations[module];
      if (config != null) {
        // If no specific business types defined, it's available for all
        if (config.businessTypes.isEmpty) continue;
        // If business type is in the list, it's enabled
        if (config.businessTypes.contains(businessType.toLowerCase())) {
          return true;
        }
      }
    }

    // Special case for price requests - exclude delivery services
    if (businessType.toLowerCase() == 'delivery') {
      return await isModuleEnabled(BusinessModule.deliveryRequest);
    }

    return true; // Default to enabled if no restrictions
  }

  /// Check if a navigation feature is enabled
  Future<bool> isNavigationFeatureEnabled(String feature) async {
    final enabledModules = await getEnabledModules();

    for (final module in enabledModules) {
      final config = _moduleConfigurations[module];
      if (config != null &&
          config.navigationFeatures.contains(feature.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Check if a menu feature is enabled
  Future<bool> isMenuFeatureEnabled(String feature) async {
    final enabledModules = await getEnabledModules();

    for (final module in enabledModules) {
      final config = _moduleConfigurations[module];
      if (config != null &&
          config.menuFeatures.contains(feature.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Check if driver registration is enabled
  Future<bool> isDriverRegistrationEnabled() async {
    final enabledModules = await getEnabledModules();

    for (final module in enabledModules) {
      final config = _moduleConfigurations[module];
      if (config != null && config.requiresDriverRegistration) {
        return true;
      }
    }
    return false;
  }

  /// Get configuration for a specific module
  ModuleConfiguration? getModuleConfiguration(BusinessModule module) {
    return _moduleConfigurations[module];
  }

  /// Get all enabled module configurations
  Future<List<ModuleConfiguration>> getEnabledModuleConfigurations() async {
    final enabledModules = await getEnabledModules();
    return enabledModules
        .map((module) => _moduleConfigurations[module])
        .where((config) => config != null)
        .cast<ModuleConfiguration>()
        .toList();
  }

  /// Clear cache (useful for testing or forced refresh)
  void clearCache() {
    _enabledModules = null;
    _lastFetchTime = null;
  }
}
