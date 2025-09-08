import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Categories API Service
class CategoriesApiService {
  static final ApiClient _apiClient = ApiClient.instance;
  static CategoriesApiService? _instance;
  static CategoriesApiService get instance => _instance ??= CategoriesApiService._internal();
  
  CategoriesApiService._internal();
  
  /// Get all categories
  Future<List<CategoryModel>> getCategories({String countryCode = 'LK'}) async {
    try {
      final response = await _apiClient.get<List<CategoryModel>>(
        '/api/categories',
        queryParameters: {'country': countryCode},
      );
      
      if (response.isSuccess && response.data != null) {
        return response.data!;
      }
      
      // Parse manually if needed
      final rawResponse = await _apiClient.get('/api/categories', 
        queryParameters: {'country': countryCode});
      
      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final categoriesJson = data['data'] as List<dynamic>?;
        
        if (categoriesJson != null) {
          return categoriesJson
              .map((json) => CategoryModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Get categories error: $e');
      }
      return [];
    }
  }
  
  /// Get subcategories for a category
  Future<List<SubcategoryModel>> getSubcategories({
    required String categoryId,
    String countryCode = 'LK',
  }) async {
    try {
      final rawResponse = await _apiClient.get('/api/categories/subcategories',
        queryParameters: {
          'category_id': categoryId,
          'country': countryCode,
        });
      
      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final subcategoriesJson = data['data'] as List<dynamic>?;
        
        if (subcategoriesJson != null) {
          return subcategoriesJson
              .map((json) => SubcategoryModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Get subcategories error: $e');
      }
      return [];
    }
  }
}

/// Cities API Service
class CitiesApiService {
  static final ApiClient _apiClient = ApiClient.instance;
  static CitiesApiService? _instance;
  static CitiesApiService get instance => _instance ??= CitiesApiService._internal();
  
  CitiesApiService._internal();
  
  /// Get all cities
  Future<List<CityModel>> getCities({String countryCode = 'LK'}) async {
    try {
      final rawResponse = await _apiClient.get('/api/cities',
        queryParameters: {'country': countryCode});
      
      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final citiesJson = data['data'] as List<dynamic>?;
        
        if (citiesJson != null) {
          return citiesJson
              .map((json) => CityModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Get cities error: $e');
      }
      return [];
    }
  }
  
  /// Get city by ID
  Future<CityModel?> getCityById(String cityId) async {
    try {
      final rawResponse = await _apiClient.get('/api/cities/$cityId');
      
      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final cityData = data['data'] as Map<String, dynamic>?;
        
        if (cityData != null) {
          return CityModel.fromJson(cityData);
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Get city error: $e');
      }
      return null;
    }
  }
}

/// Vehicle Types API Service
class VehicleTypesApiService {
  static final ApiClient _apiClient = ApiClient.instance;
  static VehicleTypesApiService? _instance;
  static VehicleTypesApiService get instance => _instance ??= VehicleTypesApiService._internal();
  
  VehicleTypesApiService._internal();
  
  /// Get all vehicle types
  Future<List<VehicleTypeModel>> getVehicleTypes({String countryCode = 'LK'}) async {
    try {
      final rawResponse = await _apiClient.get('/api/vehicle-types',
        queryParameters: {'country': countryCode});
      
      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final vehicleTypesJson = data['data'] as List<dynamic>?;
        
        if (vehicleTypesJson != null) {
          return vehicleTypesJson
              .map((json) => VehicleTypeModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Get vehicle types error: $e');
      }
      return [];
    }
  }
}

/// Category Model
class CategoryModel {
  final String id;
  final String? firebaseId;
  final String name;
  final String? description;
  final String? icon;
  final int displayOrder;
  final bool isActive;
  final String countryCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  CategoryModel({
    required this.id,
    this.firebaseId,
    required this.name,
    this.description,
    this.icon,
    required this.displayOrder,
    required this.isActive,
    required this.countryCode,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      firebaseId: json['firebase_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      countryCode: json['country_code'] as String? ?? 'LK',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebase_id': firebaseId,
      'name': name,
      'description': description,
      'icon': icon,
      'display_order': displayOrder,
      'is_active': isActive,
      'country_code': countryCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  @override
  String toString() => 'CategoryModel(id: $id, name: $name)';
}

/// Subcategory Model
class SubcategoryModel {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final bool isActive;
  final String countryCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  SubcategoryModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.isActive,
    required this.countryCode,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    return SubcategoryModel(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      countryCode: json['country_code'] as String? ?? 'LK',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  
  @override
  String toString() => 'SubcategoryModel(id: $id, name: $name)';
}

/// City Model
class CityModel {
  final String id;
  final String? firebaseId;
  final String name;
  final String countryCode;
  final String? province;
  final String? district;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  CityModel({
    required this.id,
    this.firebaseId,
    required this.name,
    required this.countryCode,
    this.province,
    this.district,
    this.latitude,
    this.longitude,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'] as String,
      firebaseId: json['firebase_id'] as String?,
      name: json['name'] as String,
      countryCode: json['country_code'] as String,
      province: json['province'] as String?,
      district: json['district'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  
  @override
  String toString() => 'CityModel(id: $id, name: $name)';
}

/// Vehicle Type Model
class VehicleTypeModel {
  final String id;
  final String? firebaseId;
  final String name;
  final String? description;
  final String? icon;
  final int? passengerCapacity;
  final int? displayOrder;
  final bool isActive;
  final String countryCode;
  final bool countryEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  VehicleTypeModel({
    required this.id,
    this.firebaseId,
    required this.name,
    this.description,
    this.icon,
    this.passengerCapacity,
    this.displayOrder,
    required this.isActive,
    required this.countryCode,
    required this.countryEnabled,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: json['id'] as String,
      firebaseId: json['firebase_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      passengerCapacity: json['passenger_capacity'] as int?,
      displayOrder: json['display_order'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      countryCode: json['country_code'] as String? ?? 'LK',
      countryEnabled: json['country_enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  
  @override
  String toString() => 'VehicleTypeModel(id: $id, name: $name)';
}
