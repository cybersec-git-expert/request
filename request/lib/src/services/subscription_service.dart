import 'api_client.dart';

class SubscriptionStatus {
  final String plan;
  final int responsesUsed;
  final int responsesLimit;
  final int remainingResponses;
  final bool canRespond;
  final String currentMonth;

  SubscriptionStatus({
    required this.plan,
    required this.responsesUsed,
    required this.responsesLimit,
    required this.remainingResponses,
    required this.canRespond,
    required this.currentMonth,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      plan: json['plan'] ?? 'free',
      responsesUsed: json['responsesUsed'] ?? 0,
      responsesLimit: json['responsesLimit'] ?? 3,
      remainingResponses: json['remainingResponses'] ?? 3,
      canRespond: json['canRespond'] ?? true,
      currentMonth: json['currentMonth'] ?? '',
    );
  }
}

class UpgradeInfo {
  final String currentPlan;
  final int freeLimit;
  final Map<String, dynamic> premiumPlan;
  final String message;

  UpgradeInfo({
    required this.currentPlan,
    required this.freeLimit,
    required this.premiumPlan,
    required this.message,
  });

  factory UpgradeInfo.fromJson(Map<String, dynamic> json) {
    return UpgradeInfo(
      currentPlan: json['currentPlan'] ?? 'free',
      freeLimit: json['freeLimit'] ?? 3,
      premiumPlan: Map<String, dynamic>.from(json['premiumPlan'] ?? {}),
      message: json['message'] ?? '',
    );
  }
}

class SimpleSubscriptionService {
  static final SimpleSubscriptionService _instance =
      SimpleSubscriptionService._internal();
  static SimpleSubscriptionService get instance => _instance;
  SimpleSubscriptionService._internal();

  /// Get user's current subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      final response = await ApiClient.instance
          .get<Map<String, dynamic>>('/subscription/status');

      if (response.isSuccess && response.data != null) {
        return SubscriptionStatus.fromJson(response.data!['data']);
      } else {
        throw Exception(response.error ?? 'Failed to get subscription status');
      }
    } catch (e) {
      print('Error getting subscription status: $e');
      rethrow;
    }
  }

  /// Check if user can make a response
  Future<Map<String, dynamic>> checkResponseLimit() async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
          '/subscription/check-response-limit',
          data: {});

      if (response.isSuccess && response.data != null) {
        return response.data!['data'];
      } else {
        throw Exception(response.error ?? 'Failed to check response limit');
      }
    } catch (e) {
      print('Error checking response limit: $e');
      rethrow;
    }
  }

  /// Get upgrade information
  Future<UpgradeInfo> getUpgradeInfo() async {
    try {
      final response = await ApiClient.instance
          .get<Map<String, dynamic>>('/subscription/upgrade-info');

      if (response.isSuccess && response.data != null) {
        return UpgradeInfo.fromJson(response.data!['data']);
      } else {
        throw Exception(response.error ?? 'Failed to get upgrade info');
      }
    } catch (e) {
      print('Error getting upgrade info: $e');
      rethrow;
    }
  }
}
