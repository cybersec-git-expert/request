import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Base API client for REST API communication
class ApiClient {
  late final Dio _dio;
  // In-memory GET cache (small & short-lived)
  final Map<String, _CacheEntry> _getCache = {};
  int _cacheCap = 50; // max entries
  Duration _cacheTtl = const Duration(seconds: 60);

  // Platform-specific base URLs
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://3.92.216.149:3001'; // Production Web
    } else if (Platform.isAndroid) {
      // For production release
      return 'http://3.92.216.149:3001';
    } else if (Platform.isIOS) {
      return 'http://3.92.216.149:3001'; // Production iOS
    } else {
      return 'http://3.92.216.149:3001'; // Production Desktop/other
    }
  }

  static const String _tokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._internal();

  // Public accessor for base URL (used to compose absolute asset URLs)
  static String get baseUrlPublic => _baseUrl;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Encourage intermediate caches for idempotent GETs; individual calls can override
        'Cache-Control': 'no-cache',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Request interceptor - Add auth token to headers
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Apply shorter timeouts for GETs to keep UI snappy
        if (options.method.toUpperCase() == 'GET') {
          options.connectTimeout = const Duration(seconds: 12);
          options.receiveTimeout = const Duration(seconds: 12);

          // Lightweight cache for idempotent GETs unless disabled
          final noCache = options.extra['noCache'] == true;
          if (!noCache) {
            final cacheKey = _cacheKey(options);
            final cached = _getCache[cacheKey];
            if (cached != null &&
                DateTime.now().difference(cached.at) < _cacheTtl) {
              // Serve from cache
              return handler.resolve(Response(
                requestOptions: options,
                data: cached.data,
                statusCode: 200,
              ));
            }
          }
        }
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        if (kDebugMode) {
          print('🚀 API Request: ${options.method} ${options.path}');
          if (options.data != null) {
            print('📤 Request Data: ${options.data}');
          }
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          print(
              '✅ API Response: ${response.statusCode} ${response.requestOptions.path}');
          print('📥 Response Data: ${response.data}');
        }
        // Store in cache if GET and successful
        final req = response.requestOptions;
        if (req.method.toUpperCase() == 'GET' &&
            response.statusCode == 200 &&
            req.extra['noCache'] != true) {
          final key = _cacheKey(req);
          _getCache[key] = _CacheEntry(response.data, DateTime.now());
          // Evict oldest if over capacity
          if (_getCache.length > _cacheCap) {
            String? oldestKey;
            DateTime oldestAt = DateTime.now();
            _getCache.forEach((k, v) {
              if (v.at.isBefore(oldestAt)) {
                oldestAt = v.at;
                oldestKey = k;
              }
            });
            if (oldestKey != null) _getCache.remove(oldestKey);
          }
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          print(
              '❌ API Error: ${error.response?.statusCode} ${error.requestOptions.path}');
          print('🔥 Error Data: ${error.response?.data}');
        }

        // Handle 401 Unauthorized - token expired
        if (error.response?.statusCode == 401) {
          final reqOptions = error.requestOptions;
          // Avoid infinite loop by marking retried flag
          if (reqOptions.extra['retried'] == true) {
            return handler.next(error);
          }
          final refreshed = await _handleTokenExpired();
          if (refreshed) {
            try {
              reqOptions.extra['retried'] = true;
              final newToken = await getToken();
              if (newToken != null) {
                reqOptions.headers['Authorization'] = 'Bearer $newToken';
              }
              final cloneResponse = await _dio.fetch(reqOptions);
              return handler.resolve(cloneResponse);
            } catch (e) {
              // fall through to next
            }
          }
        }
        // Lightweight retry policy for transient failures on idempotent GET
        final req = error.requestOptions;
        final isGet = req.method.toUpperCase() == 'GET';
        final status = error.response?.statusCode ?? 0;
        final transient = status == 0 || (status >= 500 && status < 600);
        final alreadyRetried = (req.extra['retryCount'] ?? 0) as int;
        if (isGet && transient && alreadyRetried < 2) {
          try {
            await Future.delayed(
                Duration(milliseconds: 200 * (alreadyRetried + 1)));
            req.extra['retryCount'] = alreadyRetried + 1;
            final retried = await _dio.fetch(req);
            return handler.resolve(retried);
          } catch (_) {
            // fallthrough
          }
        }
        handler.next(error);
      },
    ));
  }

  String _cacheKey(RequestOptions options) {
    final qp = options.queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final qpStr = qp.map((e) => '${e.key}=${e.value}').join('&');
    return '${options.baseUrl}${options.path}?$qpStr';
  }

  /// Store JWT token securely
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Retrieve stored JWT token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Clear stored token (logout)
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Handle token expiration
  Future<bool> _handleTokenExpired() async {
    return await _attemptRefresh();
  }

  bool _refreshInProgress = false;
  Future<bool> _attemptRefresh() async {
    if (_refreshInProgress) {
      // Wait for existing refresh to complete
      while (_refreshInProgress) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return (await getToken()) != null; // if token present assume success
    }
    _refreshInProgress = true;
    try {
      final refresh = await getRefreshToken();
      final token = await getToken();
      if (refresh == null || token == null) {
        await clearToken();
        return false;
      }
      final payload = _decodeJwt(token);
      final userId = payload['userId'];
      final dioLocal = Dio(BaseOptions(baseUrl: _baseUrl));
      final resp = await dioLocal.post('/api/auth/refresh', data: {
        'userId': userId,
        'refreshToken': refresh,
      });
      if (resp.data is Map && resp.data['success'] == true) {
        final data = resp.data['data'] as Map<String, dynamic>;
        final newToken = data['token'];
        final newRefresh = data['refreshToken'];
        if (newToken != null) await saveToken(newToken);
        if (newRefresh != null) await saveRefreshToken(newRefresh);
        return true;
      } else {
        await clearToken();
        return false;
      }
    } catch (_) {
      await clearToken();
      return false;
    } finally {
      _refreshInProgress = false;
    }
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Generic GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
    bool noCache = false,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(extra: {'noCache': noCache}),
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  /// Generic POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  /// Generic PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  /// Generic PATCH request
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  /// Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response =
          await _dio.delete(path, queryParameters: queryParameters);
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  /// Handle successful responses
  ApiResponse<T> _handleResponse<T>(
    Response response,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    if (kDebugMode) {
      print('🌐 [ApiClient._handleResponse] Processing response...');
      print('🌐   statusCode: ${response.statusCode}');
      print('🌐   response.data type: ${response.data.runtimeType}');
      print('🌐   response.data: ${response.data}');
    }

    final data = response.data;

    // 1) If response is a plain List (e.g., public listings), treat as success
    if (data is List) {
      try {
        final parsed = data as T; // Typically T is dynamic or List
        return ApiResponse<T>(success: true, data: parsed);
      } catch (_) {
        // Fallback: wrap in a map under 'data'
        return ApiResponse<T>(success: true, data: ({'data': data} as dynamic));
      }
    }

    // 2) If response is a Map
    if (data is Map<String, dynamic>) {
      final hasSuccessField =
          data.containsKey('success') && data['success'] is bool;
      final message = data['message'] ?? '';

      // 2a) Our typical API wrapper { success, data, message }
      if (hasSuccessField) {
        final success = data['success'] as bool;
        if (success) {
          T? parsedData;
          // If a transformer is provided AND a nested 'data' object exists, parse that.
          if (fromJson != null && data['data'] is Map<String, dynamic>) {
            if (kDebugMode) {
              print(
                  '🌐 [ApiClient._handleResponse] Using fromJson transformer with data["data"]');
            }
            parsedData = fromJson(data['data'] as Map<String, dynamic>);
          } else {
            // If caller didn't provide a transformer, try to return the whole map as T
            try {
              if (fromJson == null) {
                if (kDebugMode) {
                  print(
                      '🌐 [ApiClient._handleResponse] No fromJson, returning raw map as T');
                }
                parsedData = data as T;
              }
            } catch (e) {
              if (kDebugMode) {
                print('🌐 [ApiClient._handleResponse] Cast error: $e');
              }
            }
          }
          if (kDebugMode) {
            print(
                '🌐 [ApiClient._handleResponse] parsedData type: ${parsedData.runtimeType}');
            print('🌐 [ApiClient._handleResponse] parsedData: $parsedData');
          }
          return ApiResponse<T>(
              success: true, data: parsedData, message: message);
        } else {
          if (kDebugMode) {
            print(
                '🌐 [ApiClient._handleResponse] Response success=false, returning error');
          }
          return ApiResponse<T>(success: false, error: message);
        }
      }

      // 2b) Plain map without 'success' field -> treat as success
      try {
        if (fromJson != null) {
          final parsed = fromJson(data);
          return ApiResponse<T>(success: true, data: parsed);
        }
        final parsed = data as T; // Caller likely requested dynamic/Map
        return ApiResponse<T>(success: true, data: parsed);
      } catch (_) {
        // As a safe fallback, still mark success and attach raw map under 'data'
        return ApiResponse<T>(success: true, data: (data as dynamic));
      }
    }

    // 3) Primitive or other types -> treat as success and pass through
    try {
      final parsed = data as T;
      return ApiResponse<T>(success: true, data: parsed);
    } catch (_) {
      if (kDebugMode) {
        print(
            '🌐 [ApiClient._handleResponse] Unrecognized response type: ${data.runtimeType}');
      }
      return ApiResponse<T>(success: false, error: 'Invalid response format');
    }
  }

  /// Get signed URL for document viewing
  Future<String?> getSignedUrl(String fileUrl) async {
    try {
      print('🔗 Requesting signed URL for: $fileUrl');

      final response = await post<Map<String, dynamic>>(
        '/api/driver-verifications/signed-url',
        data: {'fileUrl': fileUrl},
      );

      if (response.success && response.data != null) {
        final signedUrl = response.data!['signedUrl'] as String?;
        print('✅ Received signed URL: $signedUrl');
        return signedUrl;
      } else {
        print('❌ Failed to get signed URL: ${response.error}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting signed URL: $e');
      return null;
    }
  }

  /// Handle error responses
  ApiResponse<T> _handleError<T>(DioException error) {
    String errorMessage = 'An error occurred';

    if (error.response?.data is Map<String, dynamic>) {
      final data = error.response!.data as Map<String, dynamic>;
      errorMessage = data['message'] ?? data['error'] ?? errorMessage;
    } else if (error.type == DioExceptionType.connectionTimeout) {
      errorMessage = 'Connection timeout';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'Request timeout';
    } else if (error.type == DioExceptionType.connectionError) {
      errorMessage = 'No internet connection';
    }

    return ApiResponse<T>(
      success: false,
      error: errorMessage,
      statusCode: error.response?.statusCode,
    );
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime at;
  const _CacheEntry(this.data, this.at);
}

/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.statusCode,
  });

  bool get isSuccess => success;
  bool get isError => !success;

  @override
  String toString() {
    return 'ApiResponse(success: $success, data: $data, error: $error)';
  }
}

/// Pagination response wrapper
class PaginatedResponse<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginatedResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final data = json['data'] as Map<String, dynamic>;
    final itemsJson = data['requests'] ?? data['items'] ?? [];
    final pagination = data['pagination'] as Map<String, dynamic>;

    return PaginatedResponse<T>(
      items: (itemsJson as List)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      page: pagination['page'] ?? 1,
      limit: pagination['limit'] ?? 20,
      total: pagination['total'] ?? 0,
      totalPages: pagination['totalPages'] ?? 1,
    );
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}
