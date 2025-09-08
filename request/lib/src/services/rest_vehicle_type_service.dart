import 'api_client.dart';

class VehicleType {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int? passengerCapacity;
  final bool isActive;
  final bool? countryEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleType({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.passengerCapacity,
    required this.isActive,
    this.countryEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'],
      // Support both snake_case and camelCase keys
      iconUrl: (json['icon_url'] ?? json['icon']) as String?,
      passengerCapacity: (json['passenger_capacity'] ??
          json['passengerCapacity'] ??
          json['capacity']) as int?,
      isActive: (json['is_active'] ?? json['isActive'] ?? true) as bool,
      countryEnabled:
          (json['country_enabled'] ?? json['countryEnabled']) as bool?,
      createdAt:
          DateTime.parse((json['created_at'] ?? json['createdAt']).toString()),
      updatedAt:
          DateTime.parse((json['updated_at'] ?? json['updatedAt']).toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'passenger_capacity': passengerCapacity,
      'is_active': isActive,
      'country_enabled': countryEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class RestVehicleTypeService {
  static RestVehicleTypeService? _instance;
  static RestVehicleTypeService get instance =>
      _instance ??= RestVehicleTypeService._();

  RestVehicleTypeService._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Cache for vehicle types to improve performance
  final Map<String, _VehCache> _vehicleTypesCache = {};
  Duration cacheTtl = const Duration(minutes: 15);

  /// Get all vehicle types for a specific country
  Future<List<VehicleType>> getVehicleTypes(
      {String countryCode = 'LK', bool forceRefresh = false}) async {
    try {
      final now = DateTime.now();
      final cached = _vehicleTypesCache[countryCode];
      if (!forceRefresh &&
          cached != null &&
          now.difference(cached.at) < cacheTtl) {
        return cached.items;
      }
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/vehicle-types',
        queryParameters: {'country': countryCode},
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as List?;
        if (data != null) {
          final items = data.map((json) => VehicleType.fromJson(json)).toList();
          _vehicleTypesCache[countryCode] = _VehCache(items, now);
          return items;
        }
      }

      return [];
    } catch (e) {
      print('Error fetching vehicle types: $e');
      final cached = _vehicleTypesCache[countryCode];
      if (cached != null) return cached.items;
      return [];
    }
  }

  /// Get vehicle type by ID
  Future<VehicleType?> getVehicleTypeById(String vehicleTypeId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/vehicle-types/$vehicleTypeId',
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>?;
        if (data != null) {
          return VehicleType.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching vehicle type: $e');
      return null;
    }
  }

  /// Get vehicle types with caching
  Future<List<VehicleType>> getVehicleTypesWithCache({
    String countryCode = 'LK',
    bool forceRefresh = false,
  }) async {
    final items = await getVehicleTypes(
        countryCode: countryCode, forceRefresh: forceRefresh);
    return items;
  }

  /// Get only enabled vehicle types for a country
  Future<List<VehicleType>> getEnabledVehicleTypes({
    String countryCode = 'LK',
  }) async {
    final vehicleTypes = await getVehicleTypesWithCache(
      countryCode: countryCode,
    );

    return vehicleTypes.where((vehicleType) {
      return vehicleType.isActive && (vehicleType.countryEnabled ?? true);
    }).toList();
  }

  /// Search vehicle types by name
  Future<List<VehicleType>> searchVehicleTypes({
    required String query,
    String countryCode = 'LK',
  }) async {
    final vehicleTypes = await getVehicleTypesWithCache(
      countryCode: countryCode,
    );

    return vehicleTypes.where((vehicleType) {
      return vehicleType.name.toLowerCase().contains(query.toLowerCase()) ||
          (vehicleType.description?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
              false);
    }).toList();
  }

  /// Clear cache
  void clearCache() {
    _vehicleTypesCache.clear();
  }

  /// Get vehicle types for dropdown/picker
  Future<List<Map<String, dynamic>>> getVehicleTypesForPicker({
    String countryCode = 'LK',
    bool onlyEnabled = true,
  }) async {
    List<VehicleType> vehicleTypes;

    if (onlyEnabled) {
      vehicleTypes = await getEnabledVehicleTypes(countryCode: countryCode);
    } else {
      vehicleTypes = await getVehicleTypesWithCache(countryCode: countryCode);
    }

    return vehicleTypes
        .map(
          (vehicleType) => {
            'id': vehicleType.id,
            'name': vehicleType.name,
            'value': vehicleType.id,
            'label': vehicleType.name,
            'description': vehicleType.description,
            'iconUrl': vehicleType.iconUrl,
          },
        )
        .toList();
  }
}

class _VehCache {
  final List<VehicleType> items;
  final DateTime at;
  _VehCache(this.items, this.at);
}
