import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/request_model.dart' as models;
import '../models/enhanced_user_model.dart' as enhanced;
import 'rest_request_service.dart'
    show RestRequestService, RequestModel, RequestsResponse;
import 'country_service.dart';
import 'user_registration_service.dart';
import 'api_client.dart';

/// Provides country-scoped data streams for all app content
/// Ensures users only see content from their selected country
class CountryFilteredDataService {
  CountryFilteredDataService._();
  static final CountryFilteredDataService instance =
      CountryFilteredDataService._();

  final RestRequestService _requests = RestRequestService.instance;
  final UserRegistrationService _registrationService =
      UserRegistrationService.instance;

  /// Get the current user's country filter
  String? get currentCountry => CountryService.instance.countryCode;

  /// Get country-filtered requests with pagination (direct method for compatibility)
  Future<RequestsResponse?> getRequests({
    int page = 1,
    int limit = 20,
    String? categoryId,
    String? status,
    String? requestType, // Add request_type parameter
  }) async {
    if (currentCountry == null) {
      if (kDebugMode) print('⚠️ No country selected, returning empty requests');
      return null;
    }

    try {
      final result = await _requests.getRequests(
        page: page,
        limit: limit,
        categoryId: categoryId,
        hasAccepted: false,
        requestType: requestType, // Pass request_type to backend
        countryCode: currentCountry!, // Pass country to backend
      );

      if (result == null) return null;

      // No need for client-side country filtering since backend now handles it
      return result;
    } catch (e) {
      if (kDebugMode) print('❌ Error loading country requests: $e');
      return null;
    }
  }

  /// Get country-filtered requests stream with role-based filtering
  Stream<List<models.RequestModel>> getCountryRequestsStream({
    String? status,
    String? type,
    String? category,
    String? subcategory,
    int limit = 50,
    String? searchQuery,
  }) async* {
    if (currentCountry == null) {
      if (kDebugMode) print('⚠️ No country selected, returning empty requests');
      yield <models.RequestModel>[];
      return;
    }

    try {
      // Check user's registration status and allowed request types
      final allowedTypes = await _registrationService.getAllowedRequestTypes();
      final driverVehicleTypeIds =
          await _registrationService.getDriverVehicleTypeIds();

      if (kDebugMode) {
        print(
            '🔐 CountryFilteredDataService: User allowed request types: $allowedTypes');
        print(
            '🚗 CountryFilteredDataService: Driver vehicle types: $driverVehicleTypeIds');
        print('🎯 CountryFilteredDataService: Requested type filter: $type');
      }

      // Convert type parameter for backend filtering
      String? requestTypeFilter;
      if (type != null) {
        // Only allow filtering for types the user is allowed to see
        final normalizedType = type.toLowerCase();
        String backendType;
        switch (normalizedType) {
          case 'item':
            backendType = 'item';
            break;
          case 'service':
            backendType = 'service';
            break;
          case 'rental':
            backendType = 'rent'; // Map rental to rent
            break;
          case 'delivery':
            backendType = 'delivery';
            break;
          case 'ride':
            backendType = 'ride';
            break;
          case 'price':
            backendType = 'price';
            break;
          default:
            backendType = normalizedType;
        }

        // Check if user is allowed to see this type
        if (allowedTypes.contains(backendType)) {
          requestTypeFilter = backendType;
        } else {
          if (kDebugMode)
            print('🚫 User not allowed to see $backendType requests');
          yield <models.RequestModel>[];
          return;
        }
      }

      // Use backend filtering with request_type parameter
      final result = await _requests.getRequests(
        page: 1,
        limit: limit,
        hasAccepted: false,
        requestType: requestTypeFilter, // Use request_type filtering
        countryCode: currentCountry!, // Pass country to backend
      );

      if (result == null) {
        yield <models.RequestModel>[];
      } else {
        // Apply additional client-side filters
        var filtered = result.requests;

        // Filter by user's allowed request types
        filtered = filtered.where((r) {
          final requestType = r.requestType ??
              r.metadata?['request_type']?.toString() ??
              'item';
          return allowedTypes.contains(requestType);
        }).toList();

        // For drivers: filter ride requests by vehicle type (regardless of requestTypeFilter)
        if (driverVehicleTypeIds != null && driverVehicleTypeIds.isNotEmpty) {
          filtered = filtered.where((r) {
            final requestType = r.requestType ??
                r.metadata?['request_type']?.toString() ??
                'item';

            // Only apply vehicle filtering to ride requests
            if (requestType == 'ride') {
              final vehicleTypeId = r.metadata?['vehicle_type_id']?.toString();
              bool matches = vehicleTypeId != null &&
                  driverVehicleTypeIds.contains(vehicleTypeId);

              if (kDebugMode) {
                print(
                    '🚗 CountryFilteredDataService: Ride request ${r.id} - vehicle_type_id: $vehicleTypeId, matches: $matches');
              }

              return matches;
            }

            // For non-ride requests, include them
            return true;
          }).toList();

          if (kDebugMode) {
            final rideCount = filtered
                .where((r) =>
                    (r.requestType ??
                        r.metadata?['request_type']?.toString() ??
                        'item') ==
                    'ride')
                .length;
            print(
                '🚗 CountryFilteredDataService: Filtered to $rideCount ride requests for vehicle types: $driverVehicleTypeIds');
          }
        }

        if (status != null) {
          filtered = filtered
              .where((r) => r.status.toLowerCase() == status.toLowerCase())
              .toList();
        }
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          filtered = filtered
              .where((r) =>
                  r.title.toLowerCase().contains(query) ||
                  r.description.toLowerCase().contains(query))
              .toList();
        }
        final converted = filtered.map(_convertToRequestModel).toList();
        if (kDebugMode)
          print(
              '🌍 Returning ${converted.length} requests for country: $currentCountry');
        yield converted;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading country requests: $e');
      yield <models.RequestModel>[];
    }
  }

  /// Get country-filtered businesses stream
  Stream<List<Map<String, dynamic>>> getCountryBusinessesStream({
    bool verifiedOnly = false,
    String? category,
  }) async* {
    if (currentCountry == null) {
      if (kDebugMode)
        print('⚠️ No country selected, returning empty businesses');
      yield <Map<String, dynamic>>[];
      return;
    }

    // TODO: Implement when business REST endpoint is available
    // For now, return empty stream
    if (kDebugMode) print('🏢 Business filtering not yet implemented');
    yield <Map<String, dynamic>>[];
  }

  /// Get country-filtered price listings stream
  Stream<List<Map<String, dynamic>>> getCountryPriceListingsStream({
    String? category,
    String? subcategory,
    double? minPrice,
    double? maxPrice,
  }) async* {
    if (currentCountry == null) {
      if (kDebugMode)
        print('⚠️ No country selected, returning empty price listings');
      yield <Map<String, dynamic>>[];
      return;
    }

    // TODO: Implement when price listings REST endpoint is available
    // For now, return empty stream
    if (kDebugMode) print('💰 Price listings filtering not yet implemented');
    yield <Map<String, dynamic>>[];
  }

  /// Get country-filtered categories
  Future<List<Map<String, dynamic>>> getCountryCategories() async {
    if (currentCountry == null) {
      if (kDebugMode)
        print('⚠️ No country selected, returning empty categories');
      return [];
    }

    try {
      // TODO: Implement REST call to /api/categories with country filter
      // For now, return default categories
      if (kDebugMode)
        print(
            '📂 Categories filtering not yet implemented for country: $currentCountry');
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error loading country categories: $e');
      return [];
    }
  }

  /// Get country-filtered subcategories for a category
  Future<List<Map<String, dynamic>>> getCountrySubcategories(
      String categoryId) async {
    if (currentCountry == null) {
      if (kDebugMode)
        print('⚠️ No country selected, returning empty subcategories');
      return [];
    }

    try {
      // TODO: Implement REST call to /api/subcategories with country filter
      if (kDebugMode)
        print(
            '📁 Subcategories filtering not yet implemented for country: $currentCountry');
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ Error loading country subcategories: $e');
      return [];
    }
  }

  /// Check if country filtering is properly set up
  bool get isCountryFilteringActive => currentCountry != null;

  /// Get country display info
  Map<String, String> getCountryInfo() {
    final service = CountryService.instance;
    return {
      'countryCode': service.countryCode ?? 'unknown',
      'countryName':
          service.countryName.isNotEmpty ? service.countryName : 'Unknown',
      'currency': service.currency.isNotEmpty ? service.currency : 'LKR',
      'phoneCode': service.phoneCode.isNotEmpty ? service.phoneCode : '+94',
    };
  }

  /// Convert REST RequestModel to UI RequestModel
  models.RequestModel _convertToRequestModel(RequestModel r) {
    // Merge backend metadata with computed response_count for UI consumption
    final Map<String, dynamic> meta = {
      ...(r.metadata ?? const {}),
      'response_count': r.responseCount,
    };

    return models.RequestModel(
      id: r.id,
      requesterId: r.userId,
      title: r.title,
      description: r.description,
      type: _convertRequestType(_getRequestTypeFromMetadata(
          r)), // Use metadata first, then category name
      status: _convertRequestStatus(r.status),
      priority: models.Priority.medium,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      images: r.imageUrls ?? const [],
      typeSpecificData: meta,
      budget: r.budget,
      currency: r.currency ?? CountryService.instance.currency,
      country: r.countryCode,
      countryName: CountryService.instance.countryName,
      isPublic: true,
      responses: const [],
      tags: const [],
      contactMethod: null,
      location: null,
      destinationLocation: null,
    );
  }

  String? _getRequestTypeFromMetadata(RequestModel r) {
    // Priority 1: explicit DB column
    final dbType = r.requestType;
    if (dbType != null && dbType.toString().isNotEmpty) return dbType;

    // Priority 2: metadata explicit key 'request_type'
    final meta = r.metadata;
    final metaReqType = meta != null ? meta['request_type'] : null;
    if (metaReqType != null && metaReqType.toString().isNotEmpty) {
      return metaReqType.toString();
    }

    // Priority 3: legacy metadata key 'type' (often like 'RequestType.rental')
    final metaType = meta != null ? meta['type'] : null;
    if (metaType != null && metaType.toString().isNotEmpty) {
      return metaType.toString();
    }

    // Priority 4: backend-provided category type
    final catType = r.categoryType;
    if (catType != null && catType.toString().isNotEmpty) return catType;

    // Fallback: category name (very loose)
    return r.categoryName;
  }

  enhanced.RequestType _convertRequestType(String? type) {
    if (type == null) return enhanced.RequestType.item;
    var t = type.toString().trim().toLowerCase();
    // Handle formats like "RequestType.rental"
    if (t.startsWith('requesttype.')) {
      t = t.substring('requesttype.'.length);
    }
    // Normalize common aliases/plurals
    switch (t) {
      case 'items':
      case 'product':
      case 'products':
        t = 'item';
        break;
      case 'services':
        t = 'service';
        break;
      case 'rental':
      case 'rent':
      case 'rentals':
        t = 'rental';
        break;
      case 'deliver':
      case 'courier':
      case 'parcel':
        t = 'delivery';
        break;
      case 'rides':
      case 'transport':
      case 'trip':
        t = 'ride';
        break;
      case 'price_comparison':
      case 'pricing':
        t = 'price';
        break;
    }

    switch (t) {
      case 'item':
        return enhanced.RequestType.item;
      case 'service':
        return enhanced.RequestType.service;
      case 'rental':
        return enhanced.RequestType.rental;
      case 'delivery':
        return enhanced.RequestType.delivery;
      case 'ride':
        return enhanced.RequestType.ride;
      case 'price':
        return enhanced.RequestType.price;
      default:
        return enhanced.RequestType.item;
    }
  }

  models.RequestStatus _convertRequestStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return models.RequestStatus.active;
      case 'completed':
        return models.RequestStatus.completed;
      case 'cancelled':
        return models.RequestStatus.cancelled;
      default:
        return models.RequestStatus.active;
    }
  }

  /// Get active variable types for the current country
  Future<List<Map<String, dynamic>>> getActiveVariableTypes() async {
    if (currentCountry == null) {
      if (kDebugMode)
        print('⚠️ No country selected, returning empty variable types');
      return <Map<String, dynamic>>[];
    }

    try {
      // Get base URL from platform configuration
      String baseUrl;
      if (kIsWeb) {
        baseUrl = 'https://api.alphabet.lk';
      } else if (Platform.isAndroid) {
        baseUrl = 'https://api.alphabet.lk';
      } else if (Platform.isIOS) {
        baseUrl = 'https://api.alphabet.lk';
      } else {
        baseUrl = 'https://api.alphabet.lk';
      }

      final url = Uri.parse(
          '$baseUrl/api/country-variable-types?country=$currentCountry');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final allVariableTypes = data['data'] as List;

          // Process the response data which now includes possibleValues
          final variableTypes = allVariableTypes
              .where((vt) =>
                  vt['country_code'] == currentCountry &&
                  (vt['is_active'] == true || vt['is_active'] == 1))
              .map((vt) => {
                    'id': vt['id']?.toString() ?? '',
                    'name': vt['name'] ?? '',
                    'type': vt['type'] ?? 'select',
                    'required': vt['required'] ?? false,
                    'possibleValues': vt['possibleValues'] ?? [],
                    'description': vt['description'] ?? '',
                  })
              .toList();

          if (kDebugMode)
            print(
                '✅ Loaded ${variableTypes.length} active variable types for country $currentCountry');
          return variableTypes;
        }
      }

      if (kDebugMode)
        print('❌ Failed to load variable types: ${response.statusCode}');
      return <Map<String, dynamic>>[];
    } catch (e) {
      if (kDebugMode) print('❌ Error loading variable types: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Get available vehicle types for ride requests in the current country
  /// Returns only vehicle types that are:
  /// 1. Enabled by country admin in country_vehicle_types
  /// 2. Actually registered by verified drivers in that country
  Future<List<Map<String, dynamic>>> getAvailableVehicleTypes() async {
    if (currentCountry == null) {
      if (kDebugMode)
        print('⚠️ No country selected, returning empty vehicle types');
      return <Map<String, dynamic>>[];
    }

    try {
      // Use centralized, production-safe base URL
      // Avoid localhost/10.0.2.2 which causes hangs on real devices
      final String baseUrl = ApiClient.baseUrlPublic;

      final url =
          Uri.parse('$baseUrl/api/vehicle-types/available/$currentCountry');

      final response = await http.get(
        url,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      )
          // Add a timeout so UI doesn't hang indefinitely
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final vehicleTypes = data['data'] as List;

          // Convert to expected format
          final formattedTypes = vehicleTypes
              .map((vt) => {
                    'id': vt['id']?.toString() ?? '',
                    'name': vt['name'] ?? '',
                    'description': vt['description'] ?? '',
                    'icon': vt['icon'] ?? 'DirectionsCar',
                    'displayOrder': vt['displayOrder'] ?? 0,
                    'passengerCapacity': vt['passengerCapacity'] ?? 1,
                    'isActive': vt['isActive'] ?? true,
                    'registeredDriversCount': vt['registeredDriversCount'] ?? 0,
                  })
              .toList();

          if (kDebugMode) {
            print(
                '✅ Loaded ${formattedTypes.length} available vehicle types for country $currentCountry');
            for (final vt in formattedTypes) {
              print(
                  '   ${vt['name']}: ${vt['registeredDriversCount']} drivers');
            }
          }
          return formattedTypes;
        }
      }

      if (kDebugMode)
        print(
            '❌ Failed to load available vehicle types: ${response.statusCode}');
      return <Map<String, dynamic>>[];
    } catch (e) {
      if (kDebugMode) print('❌ Error loading available vehicle types: $e');
      return <Map<String, dynamic>>[];
    }
  }
}
