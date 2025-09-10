import 'dart:async';
import '../src/services/api_client.dart';
import 'auth_service.dart';

/// Entitlements service for managing user subscription and response limits
class EntitlementsService {
  final ApiClient _apiClient = ApiClient.instance;
  final AuthService _authService = AuthService();

  /// Get user's current entitlements (authenticated version)
  Future<UserEntitlements?> getUserEntitlements() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/me/entitlements',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        // Convert backend format to our UserEntitlements format
        final converted = {
          'canSeeContactDetails': data['canViewContact'] ?? false,
          'canSendMessages': data['canMessage'] ?? false,
          'canRespond': data['canRespond'] ?? false,
          'responseCount': data['responseCountThisMonth'] ?? 0,
          'remainingResponses': data['remainingResponses'] ?? 3,
          'subscriptionType': data['subscriptionType'] ?? 'free',
          'planName': data['planName'] ?? 'Free Plan',
        };
        return UserEntitlements.fromJson(converted);
      }

      return null;
    } catch (e) {
      print('Error fetching user entitlements: $e');
      // Return restrictive defaults when API fails to enforce limits
      return UserEntitlements.fromJson({
        'canSeeContactDetails': false,
        'canSendMessages': false,
        'canRespond': false,
        'responseCount': 3,
        'remainingResponses': 0,
        'subscriptionType': 'free',
        'planName': 'Free Plan',
      });
    }
  }

  /// Get user's current entitlements (simple version with user ID)
  Future<UserEntitlements?> getUserEntitlementsSimple(String userId) async {
    try {
      // Use the existing authenticated endpoint
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/me/entitlements',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        // Convert backend format to our UserEntitlements format
        final converted = {
          'canSeeContactDetails': data['canViewContact'] ?? false,
          'canSendMessages': data['canMessage'] ?? false,
          'canRespond': data['canRespond'] ?? false,
          'responseCount': data['responseCountThisMonth'] ?? 0,
          'remainingResponses': data['remainingResponses'] ?? 3,
          'subscriptionType': data['subscriptionType'] ?? 'free',
          'planName': data['planName'] ?? 'Free Plan',
        };
        return UserEntitlements.fromJson(converted);
      }

      return null;
    } catch (e) {
      print('Error fetching user entitlements (simple): $e');
      // Return restrictive defaults when API fails to enforce limits
      return UserEntitlements.fromJson({
        'canSeeContactDetails': false,
        'canSendMessages': false,
        'canRespond': false,
        'responseCount': 3,
        'remainingResponses': 0,
        'subscriptionType': 'free',
        'planName': 'Free Plan',
      });
    }
  }

  /// Check if user can see contact details
  Future<bool> canSeeContactDetails([String? userId]) async {
    try {
      if (userId != null) {
        // Use simple endpoint
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/api/entitlements-simple/contact-details',
          queryParameters: {'user_id': userId},
          fromJson: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!['data'] as Map<String, dynamic>;
          return data['canSeeContactDetails'] as bool? ?? false;
        }
      } else {
        // Use authenticated endpoint
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/api/entitlements/contact-details',
          fromJson: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!['data'] as Map<String, dynamic>;
          return data['canSeeContactDetails'] as bool? ?? false;
        }
      }
    } catch (e) {
      print('Error checking contact details permission: $e');
    }
    return false;
  }

  /// Check if user can respond to requests
  Future<bool> canRespond([String? userId]) async {
    try {
      if (userId != null) {
        // Use simple endpoint
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/api/entitlements-simple/respond',
          queryParameters: {'user_id': userId},
          fromJson: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!['data'] as Map<String, dynamic>;
          return data['canRespond'] as bool? ?? false;
        }
      } else {
        // Use authenticated endpoint
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/api/entitlements/respond',
          fromJson: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!['data'] as Map<String, dynamic>;
          return data['canRespond'] as bool? ?? false;
        }
      }
    } catch (e) {
      print('Error checking respond permission: $e');
    }
    return false;
  }

  /// Check if user can send messages
  Future<bool> canSendMessages([String? userId]) async {
    try {
      if (userId != null) {
        // Use simple endpoint
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/api/entitlements-simple/messaging',
          queryParameters: {'user_id': userId},
          fromJson: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!['data'] as Map<String, dynamic>;
          return data['canSendMessages'] as bool? ?? false;
        }
      } else {
        // Use authenticated endpoint
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/api/entitlements/messaging',
          fromJson: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!['data'] as Map<String, dynamic>;
          return data['canSendMessages'] as bool? ?? false;
        }
      }
    } catch (e) {
      print('Error checking messaging permission: $e');
    }
    return false;
  }

  /// Check if user has reached response limit
  Future<bool> hasReachedResponseLimit([String? userId]) async {
    final entitlements = userId != null
        ? await getUserEntitlementsSimple(userId)
        : await getUserEntitlements();

    if (entitlements == null)
      return true; // Assume limit reached if can't check

    return entitlements.remainingResponses <= 0;
  }

  /// Get user's remaining responses count
  Future<int> getRemainingResponses([String? userId]) async {
    final entitlements = userId != null
        ? await getUserEntitlementsSimple(userId)
        : await getUserEntitlements();

    return entitlements?.remainingResponses ?? 0;
  }
}

/// User entitlements data model
class UserEntitlements {
  final bool canSeeContactDetails;
  final bool canSendMessages;
  final bool canRespond;
  final int responseCount;
  final int remainingResponses;
  final String subscriptionType;
  final String planName;

  UserEntitlements({
    required this.canSeeContactDetails,
    required this.canSendMessages,
    required this.canRespond,
    required this.responseCount,
    required this.remainingResponses,
    required this.subscriptionType,
    required this.planName,
  });

  factory UserEntitlements.fromJson(Map<String, dynamic> json) {
    return UserEntitlements(
      canSeeContactDetails: json['canSeeContactDetails'] as bool? ?? false,
      canSendMessages: json['canSendMessages'] as bool? ?? false,
      canRespond: json['canRespond'] as bool? ?? false,
      responseCount: json['responseCount'] as int? ?? 0,
      remainingResponses: json['remainingResponses'] as int? ?? 0,
      subscriptionType: json['subscriptionType'] as String? ?? 'free',
      planName: json['planName'] as String? ?? 'Free Plan',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canSeeContactDetails': canSeeContactDetails,
      'canSendMessages': canSendMessages,
      'canRespond': canRespond,
      'responseCount': responseCount,
      'remainingResponses': remainingResponses,
      'subscriptionType': subscriptionType,
      'planName': planName,
    };
  }

  /// Check if user is on free plan
  bool get isFreePlan => subscriptionType == 'free';

  /// Check if user is on paid plan
  bool get isPaidPlan => subscriptionType != 'free';

  /// Check if user has any responses left
  bool get hasResponsesLeft => remainingResponses > 0;

  @override
  String toString() {
    return 'UserEntitlements(plan: $planName, remaining: $remainingResponses, canRespond: $canRespond)';
  }
}
