import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? message;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.message,
    required this.statusCode,
  });

  factory ApiResponse.success(T data, {String? message, int statusCode = 200}) {
    return ApiResponse<T>(
      success: true,
      data: data,
      message: message,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error(String error, {int statusCode = 500}) {
    return ApiResponse<T>(success: false, error: error, statusCode: statusCode);
  }
}

class HttpApiClient {
  static HttpApiClient? _instance;
  static HttpApiClient get instance => _instance ??= HttpApiClient._();

  HttpApiClient._();

  late http.Client _client;
  String? _authToken;

  void initialize() {
    _client = http.Client();
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  Map<String, String> _getHeaders({bool requireAuth = false}) {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);

    if (requireAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  String _buildUrl(String endpoint) {
    return '${ApiConfig.apiBaseUrl}$endpoint';
  }

  Future<ApiResponse<T>> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (jsonResponse['success'] == true) {
          final data = fromJson(jsonResponse);
          return ApiResponse.success(
            data,
            message: jsonResponse['message'],
            statusCode: response.statusCode,
          );
        } else {
          return ApiResponse.error(
            jsonResponse['error'] ?? 'Unknown error occurred',
            statusCode: response.statusCode,
          );
        }
      } else {
        return ApiResponse.error(
          jsonResponse['error'] ?? 'Request failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(
        'Failed to parse response: $e',
        statusCode: response.statusCode,
      );
    }
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = false,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      String url = _buildUrl(endpoint);

      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri.parse(url);
        url = uri.replace(queryParameters: queryParams).toString();
      }

      final response = await _client
          .get(Uri.parse(url), headers: _getHeaders(requireAuth: requireAuth))
          .timeout(ApiConfig.receiveTimeout);

      if (fromJson != null) {
        return _handleResponse<T>(response, fromJson);
      } else {
        // For dynamic responses
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          jsonResponse as T,
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Network error occurred');
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_buildUrl(endpoint)),
            headers: _getHeaders(requireAuth: requireAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(ApiConfig.receiveTimeout);

      if (fromJson != null) {
        return _handleResponse<T>(response, fromJson);
      } else {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          jsonResponse as T,
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Network error occurred');
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _client
          .put(
            Uri.parse(_buildUrl(endpoint)),
            headers: _getHeaders(requireAuth: requireAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(ApiConfig.receiveTimeout);

      if (fromJson != null) {
        return _handleResponse<T>(response, fromJson);
      } else {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          jsonResponse as T,
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Network error occurred');
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    bool requireAuth = false,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final response = await _client
          .delete(
            Uri.parse(_buildUrl(endpoint)),
            headers: _getHeaders(requireAuth: requireAuth),
          )
          .timeout(ApiConfig.receiveTimeout);

      if (fromJson != null) {
        return _handleResponse<T>(response, fromJson);
      } else {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          jsonResponse as T,
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('Network error occurred');
    } catch (e) {
      return ApiResponse.error('Request failed: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
