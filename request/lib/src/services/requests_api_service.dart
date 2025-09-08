import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Requests API Service
class RequestsApiService {
  static final ApiClient _apiClient = ApiClient.instance;
  static RequestsApiService? _instance;
  static RequestsApiService get instance =>
      _instance ??= RequestsApiService._internal();

  RequestsApiService._internal();

  /// Get requests with filtering and pagination
  Future<PaginatedRequestsResult> getRequests({
    String? categoryId,
    String? subcategoryId,
    String? cityId,
    String countryCode = 'LK',
    String? status,
    String? userId,
    int page = 1,
    int limit = 20,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'country_code': countryCode,
        'page': page.toString(),
        'limit': limit.toString(),
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };

      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (subcategoryId != null) queryParams['subcategory_id'] = subcategoryId;
      if (cityId != null) queryParams['city_id'] = cityId;
      if (status != null) queryParams['status'] = status;
      if (userId != null) queryParams['user_id'] = userId;

      final rawResponse =
          await _apiClient.get('/api/requests', queryParameters: queryParams);

      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final responseData = data['data'] as Map<String, dynamic>;

        final requestsJson = responseData['requests'] as List<dynamic>? ?? [];
        final pagination =
            responseData['pagination'] as Map<String, dynamic>? ?? {};

        final requests = requestsJson
            .map((json) => RequestModel.fromJson(json as Map<String, dynamic>))
            .toList();

        return PaginatedRequestsResult(
          success: true,
          requests: requests,
          pagination: PaginationInfo.fromJson(pagination),
        );
      }

      return PaginatedRequestsResult(
        success: false,
        error: rawResponse.error ?? 'Failed to fetch requests',
        requests: [],
        pagination: PaginationInfo.empty(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Get requests error: $e');
      }
      return PaginatedRequestsResult(
        success: false,
        error: 'Failed to fetch requests: ${e.toString()}',
        requests: [],
        pagination: PaginationInfo.empty(),
      );
    }
  }

  /// Get a single request by ID
  Future<RequestResult> getRequestById(String requestId) async {
    try {
      final rawResponse = await _apiClient.get('/api/requests/$requestId');

      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final requestData = data['data'] as Map<String, dynamic>?;

        if (requestData != null) {
          return RequestResult(
            success: true,
            request: RequestModel.fromJson(requestData),
          );
        }
      }

      return RequestResult(
        success: false,
        error: rawResponse.error ?? 'Failed to fetch request',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Get request error: $e');
      }
      return RequestResult(
        success: false,
        error: 'Failed to fetch request: ${e.toString()}',
      );
    }
  }

  /// Create a new request
  Future<RequestResult> createRequest({
    required String title,
    required String description,
    required String categoryId,
    required String cityId,
    String? subcategoryId,
    double? budget,
    String currency = 'LKR',
    String priority = 'normal',
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    DateTime? expiresAt,
    bool isUrgent = false,
  }) async {
    try {
      final requestData = {
        'title': title,
        'description': description,
        'category_id': categoryId,
        'city_id': cityId,
        'currency': currency,
        'priority': priority,
        'is_urgent': isUrgent,
      };

      if (subcategoryId != null) requestData['subcategory_id'] = subcategoryId;
      if (budget != null) requestData['budget'] = budget;
      if (locationAddress != null)
        requestData['location_address'] = locationAddress;
      if (locationLatitude != null)
        requestData['location_latitude'] = locationLatitude;
      if (locationLongitude != null)
        requestData['location_longitude'] = locationLongitude;
      if (expiresAt != null)
        requestData['expires_at'] = expiresAt.toIso8601String();

      final rawResponse =
          await _apiClient.post('/api/requests', data: requestData);

      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final requestData = data['data'] as Map<String, dynamic>?;

        if (requestData != null) {
          return RequestResult(
            success: true,
            request: RequestModel.fromJson(requestData),
            message: data['message'] as String?,
          );
        }
      }

      return RequestResult(
        success: false,
        error: rawResponse.error ?? 'Failed to create request',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Create request error: $e');
      }
      return RequestResult(
        success: false,
        error: 'Failed to create request: ${e.toString()}',
      );
    }
  }

  /// Update an existing request
  Future<RequestResult> updateRequest({
    required String requestId,
    String? title,
    String? description,
    String? categoryId,
    String? subcategoryId,
    String? cityId,
    double? budget,
    String? currency,
    String? priority,
    String? status,
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    DateTime? expiresAt,
    bool? isUrgent,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (categoryId != null) updateData['category_id'] = categoryId;
      if (subcategoryId != null) updateData['subcategory_id'] = subcategoryId;
      if (cityId != null) updateData['city_id'] = cityId;
      if (budget != null) updateData['budget'] = budget;
      if (currency != null) updateData['currency'] = currency;
      if (priority != null) updateData['priority'] = priority;
      if (status != null) updateData['status'] = status;
      if (locationAddress != null)
        updateData['location_address'] = locationAddress;
      if (locationLatitude != null)
        updateData['location_latitude'] = locationLatitude;
      if (locationLongitude != null)
        updateData['location_longitude'] = locationLongitude;
      if (expiresAt != null)
        updateData['expires_at'] = expiresAt.toIso8601String();
      if (isUrgent != null) updateData['is_urgent'] = isUrgent;

      final rawResponse =
          await _apiClient.put('/api/requests/$requestId', data: updateData);

      if (rawResponse.isSuccess && rawResponse.data is Map<String, dynamic>) {
        final data = rawResponse.data as Map<String, dynamic>;
        final requestData = data['data'] as Map<String, dynamic>?;

        if (requestData != null) {
          return RequestResult(
            success: true,
            request: RequestModel.fromJson(requestData),
            message: data['message'] as String?,
          );
        }
      }

      return RequestResult(
        success: false,
        error: rawResponse.error ?? 'Failed to update request',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Update request error: $e');
      }
      return RequestResult(
        success: false,
        error: 'Failed to update request: ${e.toString()}',
      );
    }
  }

  /// Delete a request
  Future<bool> deleteRequest(String requestId) async {
    try {
      final rawResponse = await _apiClient.delete('/api/requests/$requestId');
      return rawResponse.isSuccess;
    } catch (e) {
      if (kDebugMode) {
        print('Delete request error: $e');
      }
      return false;
    }
  }
}

/// Request Model
class RequestModel {
  final String id;
  final String? firebaseId;
  final String? userId;
  final String categoryId;
  final String? subcategoryId;
  final String title;
  final String description;
  final double? budget;
  final String currency;
  final String locationCityId;
  final String? locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final String status;
  final String priority;
  final DateTime? expiresAt;
  final bool isUrgent;
  final int viewCount;
  final int responseCount;
  final String countryCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data from joins
  final String? userName;
  final String? userEmail;
  final String? categoryName;
  final String? subcategoryName;
  final String? cityName;

  RequestModel({
    required this.id,
    this.firebaseId,
    this.userId,
    required this.categoryId,
    this.subcategoryId,
    required this.title,
    required this.description,
    this.budget,
    required this.currency,
    required this.locationCityId,
    this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    required this.status,
    required this.priority,
    this.expiresAt,
    required this.isUrgent,
    required this.viewCount,
    required this.responseCount,
    required this.countryCode,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userEmail,
    this.categoryName,
    this.subcategoryName,
    this.cityName,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'] as String,
      firebaseId: json['firebase_id'] as String?,
      userId: json['user_id'] as String?,
      categoryId: json['category_id'] as String,
      subcategoryId: json['subcategory_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      budget: json['budget'] != null
          ? double.tryParse(json['budget'].toString())
          : null,
      currency: json['currency'] as String? ?? 'LKR',
      locationCityId: json['location_city_id'] as String,
      locationAddress: json['location_address'] as String?,
      locationLatitude: json['location_latitude'] != null
          ? double.tryParse(json['location_latitude'].toString())
          : null,
      locationLongitude: json['location_longitude'] != null
          ? double.tryParse(json['location_longitude'].toString())
          : null,
      status: json['status'] as String? ?? 'active',
      priority: json['priority'] as String? ?? 'normal',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isUrgent: json['is_urgent'] as bool? ?? false,
      viewCount: json['view_count'] as int? ?? 0,
      responseCount: json['response_count'] as int? ?? 0,
      countryCode: json['country_code'] as String? ?? 'LK',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
      categoryName: json['category_name'] as String?,
      subcategoryName: json['subcategory_name'] as String?,
      cityName: json['city_name'] as String?,
    );
  }

  String get budgetDisplay {
    if (budget != null) {
      return '$currency ${budget!.toStringAsFixed(0)}';
    }
    return 'Budget not specified';
  }

  @override
  String toString() => 'RequestModel(id: $id, title: $title)';
}

/// Pagination Info
class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }

  factory PaginationInfo.empty() {
    return PaginationInfo(page: 1, limit: 20, total: 0, totalPages: 1);
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}

/// Paginated Requests Result
class PaginatedRequestsResult {
  final bool success;
  final List<RequestModel> requests;
  final PaginationInfo pagination;
  final String? error;

  PaginatedRequestsResult({
    required this.success,
    required this.requests,
    required this.pagination,
    this.error,
  });
}

/// Single Request Result
class RequestResult {
  final bool success;
  final RequestModel? request;
  final String? message;
  final String? error;

  RequestResult({
    required this.success,
    this.request,
    this.message,
    this.error,
  });
}
