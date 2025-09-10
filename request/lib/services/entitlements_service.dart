import 'dart:async';
import '../src/services/api_client.dart';

/// Entitlements service for managing user subscription and response limits
class EntitlementsService {
  final ApiClient _apiClient = ApiClient.instance;

  /// Get user's current entitlements (authenticated version)
  Future<UserEntitlements?> getUserEntitlements() async {
    try {
      // Let the API client handle authentication automatically
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/me/entitlements',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final responseData = response.data!;
        print('DEBUG: Full entitlements response: $responseData');

        // Handle both nested and flat data structures
        final data =
            responseData['data'] as Map<String, dynamic>? ?? responseData;
        print('DEBUG: Entitlements data to parse: $data');

        // Convert backend format to our UserEntitlements format with null safety
        final converted = {
          'canSeeContactDetails': data['canViewContact'] as bool? ?? false,
          'canSendMessages': data['canMessage'] as bool? ?? false,
          'canRespond': data['canRespond'] as bool? ?? false,
          'responseCount': data['responseCountThisMonth'] as int? ?? 0,
          'remainingResponses': data['remainingResponses'] as int? ?? 3,
          'subscriptionType': data['subscriptionType'] as String? ?? 'free',
          'planName': data['planName'] as String? ?? 'Free Plan',
        };
        print('DEBUG: Converted entitlements: $converted');
        return UserEntitlements.fromJson(converted);
      }

      // API failed - return restrictive defaults for security
      print('API failed for main entitlements, returning restrictive defaults');
      return UserEntitlements.fromJson({
        'canSeeContactDetails': false,
        'canSendMessages': false,
        'canRespond': false,
        'responseCount': 3,
        'remainingResponses': 0,
        'subscriptionType': 'free',
        'planName': 'Free Plan',
      });
    } catch (e) {
      print('Error fetching user entitlements: $e');
      // Return restrictive defaults for security when API fails
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
        final responseData = response.data!;
        print('DEBUG: Full entitlements response (simple): $responseData');

        // Handle both nested and flat data structures
        final data =
            responseData['data'] as Map<String, dynamic>? ?? responseData;
        print('DEBUG: Entitlements data to parse (simple): $data');

        // Convert backend format to our UserEntitlements format with null safety
        final converted = {
          'canSeeContactDetails': data['canViewContact'] as bool? ?? false,
          'canSendMessages': data['canMessage'] as bool? ?? false,
          'canRespond': data['canRespond'] as bool? ?? false,
          'responseCount': data['responseCountThisMonth'] as int? ?? 0,
          'remainingResponses': data['remainingResponses'] as int? ?? 3,
          'subscriptionType': data['subscriptionType'] as String? ?? 'free',
          'planName': data['planName'] as String? ?? 'Free Plan',
        };
        print('DEBUG: Converted entitlements (simple): $converted');
        return UserEntitlements.fromJson(converted);
      }

      // API failed - return restrictive defaults for security
      print('API failed for entitlements, returning restrictive defaults');
      return UserEntitlements.fromJson({
        'canSeeContactDetails': false,
        'canSendMessages': false,
        'canRespond': false,
        'responseCount': 3,
        'remainingResponses': 0,
        'subscriptionType': 'free',
        'planName': 'Free Plan',
      });
    } catch (e) {
      print('Error fetching user entitlements (simple): $e');
      // Return restrictive defaults for security when API fails
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
      // Always use the main authenticated endpoint
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/me/entitlements',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final responseData = response.data!;
        final data =
            responseData['data'] as Map<String, dynamic>? ?? responseData;
        return data['canRespond'] as bool? ?? false;
      }
    } catch (e) {
      print('Error checking respond permission: $e');
    }
    // Always return false when API fails for security
    return false;
  }

  /// Check if user can send messages
  Future<bool> canSendMessages([String? userId]) async {
    try {
      // Always use the main authenticated endpoint
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/me/entitlements',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final responseData = response.data!;
        final data =
            responseData['data'] as Map<String, dynamic>? ?? responseData;
        return data['canMessage'] as bool? ?? false;
      }
    } catch (e) {
      print('Error checking messaging permission: $e');
    }
    // Always return false when API fails for security
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
