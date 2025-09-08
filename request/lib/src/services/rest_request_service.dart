import 'api_client.dart';
import 'rest_auth_service.dart';

// Robust converter for numeric fields that may arrive as int, double, String or null.
double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

class RequestModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? acceptedResponseId;
  final String title;
  final String description;
  final String categoryId;
  final String? categoryName;
  final String?
      categoryType; // Category type: item, service, rental, delivery, etc.
  final String? subcategoryId;
  final String? subcategoryName;
  final String? locationCityId;
  final String? cityName;
  final String? locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final String countryCode;
  final String status;
  final double? budget;
  final String? currency;
  final DateTime? deadline;
  final List<String>? imageUrls;
  final Map<String, dynamic>? metadata;
  final String? requestType; // Add request_type field from database
  final int responseCount; // Number of responses (from backend aggregate)
  // Subscription gating flags from backend responses
  final bool contactVisible;
  final bool canMessage;
  // Urgent flag for boosted visibility
  final bool isUrgent;
  final DateTime createdAt;
  final DateTime updatedAt;

  RequestModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.acceptedResponseId,
    required this.title,
    required this.description,
    required this.categoryId,
    this.categoryName,
    this.categoryType,
    this.subcategoryId,
    this.subcategoryName,
    this.locationCityId,
    this.cityName,
    this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    required this.countryCode,
    required this.status,
    this.budget,
    this.currency,
    this.deadline,
    this.imageUrls,
    this.metadata,
    this.requestType, // Add requestType to constructor
    this.responseCount = 0,
    this.contactVisible = false,
    this.canMessage = true,
    this.isUrgent = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      userName: json['user_name'],
      userEmail: json['user_email'],
      userPhone: json['user_phone'],
      acceptedResponseId: json['accepted_response_id']?.toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      categoryId: json['category_id'].toString(),
      categoryName: json['category_name'],
      categoryType: json['category_request_type'] ??
          json['category_type'], // Add category type from backend
      subcategoryId: json['subcategory_id']?.toString(),
      subcategoryName: json['subcategory_name'],
      locationCityId: json['location_city_id']?.toString(),
      cityName: json['city_name'],
      locationAddress: json['location_address'],
      locationLatitude: _asDouble(json['location_latitude']),
      locationLongitude: _asDouble(json['location_longitude']),
      countryCode: json['country_code'] ?? 'LK',
      status: json['status'] ?? 'active',
      budget: _asDouble(json['budget']),
      currency: json['currency'],
      deadline:
          json['deadline'] != null && json['deadline'].toString().isNotEmpty
              ? DateTime.tryParse(json['deadline'])
              : null,
      imageUrls: json['image_urls'] != null
          ? List<String>.from(json['image_urls'])
          : null,
      metadata: json['metadata'],
      requestType:
          json['request_type']?.toString(), // Add request_type from database
      responseCount: json['response_count'] is int
          ? (json['response_count'] as int)
          : int.tryParse((json['response_count'] ?? '0').toString()) ?? 0,
      contactVisible: (json['contact_visible'] == true),
      canMessage: (json['can_message'] != false),
      isUrgent: (json['is_urgent'] == true),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'user_phone': userPhone,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'location_city_id': locationCityId,
      'location_address': locationAddress,
      'location_latitude': locationLatitude,
      'location_longitude': locationLongitude,
      'country_code': countryCode,
      'status': status,
      'accepted_response_id': acceptedResponseId,
      'budget': budget,
      'currency': currency,
      'deadline': deadline?.toIso8601String(),
      'image_urls': imageUrls,
      'metadata': metadata,
      'response_count': responseCount,
      'contact_visible': contactVisible,
      'can_message': canMessage,
      'is_urgent': isUrgent,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class RequestsResponse {
  final List<RequestModel> requests;
  final PaginationInfo pagination;

  RequestsResponse({required this.requests, required this.pagination});

  factory RequestsResponse.fromJson(Map<String, dynamic> json) {
    final requestsData = json['requests'] as List? ?? [];
    final paginationData = json['pagination'] as Map<String, dynamic>? ?? {};

    return RequestsResponse(
      requests:
          requestsData.map((item) => RequestModel.fromJson(item)).toList(),
      pagination: PaginationInfo.fromJson(paginationData),
    );
  }
}

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
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}

class CreateRequestData {
  final String title;
  final String description;
  final String? categoryId; // Made optional for ride requests
  final String? subcategoryId;
  final String? locationCityId;
  final String? locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final String countryCode;
  final double? budget;
  final String? currency;
  final DateTime? deadline;
  final List<String>? imageUrls;
  final Map<String, dynamic>? metadata;
  final String? requestType; // Add request_type field

  CreateRequestData({
    required this.title,
    required this.description,
    this.categoryId, // Made optional
    this.subcategoryId,
    this.locationCityId,
    this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    this.countryCode = 'LK',
    this.budget,
    this.currency,
    this.deadline,
    this.imageUrls,
    this.metadata,
    this.requestType, // Add request_type parameter
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      // Backend expects 'city_id' (error message: Title, description, category_id, and city_id are required)
      if (locationCityId != null) 'city_id': locationCityId,
      if (locationAddress != null && locationAddress!.isNotEmpty)
        'location_address': locationAddress,
      if (locationLatitude != null) 'location_latitude': locationLatitude,
      if (locationLongitude != null) 'location_longitude': locationLongitude,
      'country_code': countryCode,
      if (budget != null) 'budget': budget,
      if (currency != null) 'currency': currency,
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
      if (imageUrls != null) 'image_urls': imageUrls,
      if (metadata != null) 'metadata': metadata,
      if (requestType != null)
        'request_type': requestType, // Add request_type to JSON
    };
  }
}

class ResponseModel {
  final String id;
  final String requestId;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String message;
  final double? price;
  final String? currency;
  final Map<String, dynamic>? metadata;
  final List<String>? imageUrls;
  final String? locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? countryCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResponseModel({
    required this.id,
    required this.requestId,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    required this.message,
    this.price,
    this.currency,
    this.metadata,
    this.imageUrls,
    this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    this.countryCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ResponseModel.fromJson(Map<String, dynamic> json) => ResponseModel(
        id: json['id'].toString(),
        requestId: json['request_id'].toString(),
        userId: json['user_id'].toString(),
        userName: json['user_name'],
        userEmail: json['user_email'],
        userPhone: json['user_phone'],
        message: json['message'] ?? '',
        price: _asDouble(json['price']),
        currency: json['currency'],
        metadata: json['metadata'],
        imageUrls: json['image_urls'] != null
            ? List<String>.from(json['image_urls'])
            : null,
        locationAddress: json['location_address'],
        locationLatitude: _asDouble(json['location_latitude']),
        locationLongitude: _asDouble(json['location_longitude']),
        countryCode: json['country_code'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'request_id': requestId,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'user_phone': userPhone,
        'message': message,
        'price': price,
        'currency': currency,
        'metadata': metadata,
        'image_urls': imageUrls,
        'location_address': locationAddress,
        'location_latitude': locationLatitude,
        'location_longitude': locationLongitude,
        'country_code': countryCode,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class CreateResponseData {
  final String message;
  final double? price;
  final String? currency;
  final Map<String, dynamic>? metadata;
  final List<String>? imageUrls;
  final String? locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final String? countryCode;
  CreateResponseData({
    required this.message,
    this.price,
    this.currency,
    this.metadata,
    this.imageUrls,
    this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    this.countryCode,
  });
  Map<String, dynamic> toJson() => {
        'message': message,
        if (price != null) 'price': price,
        if (currency != null) 'currency': currency,
        if (metadata != null) 'metadata': metadata,
        if (imageUrls != null) 'image_urls': imageUrls,
        if (locationAddress != null && locationAddress!.isNotEmpty)
          'location_address': locationAddress,
        if (locationLatitude != null) 'location_latitude': locationLatitude,
        if (locationLongitude != null) 'location_longitude': locationLongitude,
        if (countryCode != null) 'country_code': countryCode,
      };
}

class ResponsesPage {
  final List<ResponseModel> responses;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  ResponsesPage(
      {required this.responses,
      required this.page,
      required this.limit,
      required this.total,
      required this.totalPages});
  factory ResponsesPage.empty() => ResponsesPage(
      responses: const [], page: 1, limit: 20, total: 0, totalPages: 0);
}

class RestRequestService {
  static RestRequestService? _instance;
  static RestRequestService get instance =>
      _instance ??= RestRequestService._();

  RestRequestService._();

  final ApiClient _apiClient = ApiClient.instance;

  /// Get requests with filtering and pagination
  Future<RequestsResponse?> getRequests({
    String? categoryId,
    String? subcategoryId,
    String? cityId,
    String countryCode = 'LK',
    String? status,
    String? userId,
    bool? hasAccepted,
    String? requestType, // Add request_type filtering parameter
    int page = 1,
    int limit = 20,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sort_by': sortBy,
        'sort_order': sortOrder,
        'country_code': countryCode,
      };

      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (subcategoryId != null) queryParams['subcategory_id'] = subcategoryId;
      if (cityId != null) queryParams['city_id'] = cityId;
      if (status != null) queryParams['status'] = status;
      if (userId != null) queryParams['user_id'] = userId;
      if (hasAccepted == true) queryParams['has_accepted'] = 'true';
      if (requestType != null)
        queryParams['request_type'] = requestType; // Add request_type parameter

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/requests',
        queryParameters: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>?;
        if (data != null) {
          return RequestsResponse.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching requests: $e');
      return null;
    }
  }

  /// Get request by ID
  Future<RequestModel?> getRequestById(String requestId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/requests/$requestId',
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>?;
        if (data != null) {
          return RequestModel.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching request: $e');
      return null;
    }
  }

  /// Create a new request
  Future<RequestModel?> createRequest(CreateRequestData requestData) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/requests',
        data: requestData.toJson(),
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>?;
        if (data != null) {
          return RequestModel.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error creating request: $e');
      return null;
    }
  }

  /// Update an existing request
  Future<RequestModel?> updateRequest(
    String requestId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/api/requests/$requestId',
        data: updates,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>?;
        if (data != null) {
          return RequestModel.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error updating request: $e');
      return null;
    }
  }

  /// Delete a request
  Future<bool> deleteRequest(String requestId) async {
    try {
      final response = await _apiClient.delete<Map<String, dynamic>>(
        '/api/requests/$requestId',
      );

      return response.isSuccess;
    } catch (e) {
      print('Error deleting request: $e');
      return false;
    }
  }

  /// Get user's own requests
  Future<RequestsResponse?> getUserRequests({
    int page = 1,
    int limit = 20,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
  }) async {
    // Filter by authenticated user's ID; backend will return only their requests
    final uid = RestAuthService.instance.currentUser?.uid;
    return await getRequests(
      page: page,
      limit: limit,
      sortBy: sortBy,
      sortOrder: sortOrder,
      userId: uid,
    );
  }

  /// Search requests by title or description
  Future<RequestsResponse?> searchRequests({
    required String query,
    String? categoryId,
    String? cityId,
    String countryCode = 'LK',
    bool? hasAccepted,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        'country_code': countryCode,
      };

      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (cityId != null) queryParams['city_id'] = cityId;
      if (hasAccepted == true) queryParams['has_accepted'] = 'true';

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/requests/search',
        queryParameters: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>?;
        if (data != null) {
          return RequestsResponse.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error searching requests: $e');
      return null;
    }
  }

  Future<ResponsesPage> getResponses(String requestId,
      {int page = 1, int limit = 20}) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
          '/api/requests/$requestId/responses',
          queryParameters: {
            'page': page.toString(),
            'limit': limit.toString()
          });
      if (res.isSuccess && res.data != null) {
        final data = res.data!['data'] as Map<String, dynamic>?;
        if (data != null) {
          final list = (data['responses'] as List? ?? [])
              .map((e) => ResponseModel.fromJson(e))
              .toList();
          final pag = data['pagination'] as Map<String, dynamic>?;
          return ResponsesPage(
            responses: list,
            page: pag?['page'] ?? page,
            limit: pag?['limit'] ?? limit,
            total: pag?['total'] ?? list.length,
            totalPages: pag?['totalPages'] ?? 1,
          );
        }
      }
      return ResponsesPage.empty();
    } catch (e) {
      print('Error fetching responses: $e');
      return ResponsesPage.empty();
    }
  }

  Future<ResponseModel?> createResponse(
      String requestId, CreateResponseData data) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
          '/api/requests/$requestId/responses',
          data: data.toJson());
      if (res.isSuccess && res.data != null) {
        final json = res.data!['data'] as Map<String, dynamic>?;
        if (json != null) return ResponseModel.fromJson(json);
        // If success but no data, treat as failure
        throw Exception('Failed to parse response');
      } else {
        // Bubble up clear error for UI (e.g., monthly limit reached)
        final msg = res.error ?? res.message ?? 'Failed to create response';
        throw Exception(msg);
      }
    } catch (e) {
      print('Error creating response: $e');
      rethrow;
    }
  }

  Future<ResponseModel?> updateResponse(
      String requestId, String responseId, Map<String, dynamic> updates) async {
    try {
      final res = await _apiClient.put<Map<String, dynamic>>(
          '/api/requests/$requestId/responses/$responseId',
          data: updates);
      if (res.isSuccess && res.data != null) {
        final json = res.data!['data'] as Map<String, dynamic>?;
        if (json != null) return ResponseModel.fromJson(json);
      }
      return null;
    } catch (e) {
      print('Error updating response: $e');
      return null;
    }
  }

  Future<bool> deleteResponse(String requestId, String responseId) async {
    try {
      final res = await _apiClient.delete<Map<String, dynamic>>(
          '/api/requests/$requestId/responses/$responseId');
      return res.isSuccess;
    } catch (e) {
      print('Error deleting response: $e');
      return false;
    }
  }

  // Accept a response
  Future<RequestModel?> acceptResponse(
      String requestId, String responseId) async {
    try {
      final res = await _apiClient.put<Map<String, dynamic>>(
          '/api/requests/$requestId/accept-response',
          data: {'response_id': responseId});
      if (res.isSuccess && res.data != null) {
        final data = res.data!['data'] as Map<String, dynamic>?;
        if (data != null) return RequestModel.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error accepting response: $e');
      return null;
    }
  }

  // Clear accepted response
  Future<RequestModel?> clearAcceptedResponse(String requestId) async {
    try {
      final res = await _apiClient
          .put<Map<String, dynamic>>('/api/requests/$requestId/clear-accepted');
      if (res.isSuccess && res.data != null) {
        final data = res.data!['data'] as Map<String, dynamic>?;
        if (data != null) return RequestModel.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error clearing accepted response: $e');
      return null;
    }
  }

  /// Mark a request as completed (owner only)
  Future<RequestModel?> markRequestCompleted(String requestId) async {
    try {
      final res = await _apiClient.put<Map<String, dynamic>>(
        '/api/requests/$requestId/mark-completed',
      );
      if (res.isSuccess && res.data != null) {
        final data = res.data!['data'] as Map<String, dynamic>?;
        if (data != null) return RequestModel.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error marking request completed: $e');
      return null;
    }
  }
}

class ReviewsService {
  ReviewsService._();
  static final ReviewsService instance = ReviewsService._();
  final ApiClient _apiClient = ApiClient.instance;

  Future<bool> createReview({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/api/reviews',
        data: {
          'request_id': requestId,
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
        },
      );
      return res.isSuccess == true;
    } catch (e) {
      print('Error creating review: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserReviewStats(String userId) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        '/api/reviews/stats/$userId',
      );
      if (res.isSuccess && res.data != null) {
        return res.data!['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error fetching review stats: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMyReviewForRequest(String requestId) async {
    try {
      final res = await _apiClient
          .get<Map<String, dynamic>>('/api/reviews/request/$requestId/mine');
      if (res.isSuccess && res.data != null) {
        return res.data!['data'] as Map<String, dynamic>?; // can be null
      }
      return null;
    } catch (e) {
      print('Error fetching my review for request: $e');
      return null;
    }
  }
}
