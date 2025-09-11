import 'api_client.dart';

class SimpleSubscriptionService {
  SimpleSubscriptionService._();
  static SimpleSubscriptionService? _instance;
  static SimpleSubscriptionService get instance =>
      _instance ??= SimpleSubscriptionService._();

  /// Get user's subscription status
  Future<SimpleSubscriptionStatus?> getSubscriptionStatus() async {
    try {
      final response = await ApiClient.instance
          .get<Map<String, dynamic>>('/simple-subscription/status');

      if (response.isSuccess && response.data != null) {
        final subscription =
            response.data!['subscription'] as Map<String, dynamic>?;
        if (subscription != null) {
          return SimpleSubscriptionStatus.fromJson(subscription);
        }
      }
      return null;
    } catch (e) {
      print('Error getting subscription status: $e');
      return null;
    }
  }

  /// Check if user can respond to requests
  Future<ResponseEligibility> canRespond() async {
    try {
      final response = await ApiClient.instance
          .get<Map<String, dynamic>>('/simple-subscription/can-respond');

      if (response.isSuccess && response.data != null) {
        return ResponseEligibility.fromJson(response.data!);
      }
      return ResponseEligibility(
        canRespond: false,
        reason: 'error',
        message: response.error ?? 'Failed to check eligibility',
      );
    } catch (e) {
      print('Error checking response eligibility: $e');
      return ResponseEligibility(
        canRespond: false,
        reason: 'error',
        message: 'Failed to check eligibility',
      );
    }
  }

  /// Record a response (increment usage counter)
  Future<bool> recordResponse(String requestId) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/simple-subscription/record-response',
        data: {'request_id': requestId},
      );
      return response.isSuccess;
    } catch (e) {
      print('Error recording response: $e');
      return false;
    }
  }

  /// Get available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final response = await ApiClient.instance
          .get<Map<String, dynamic>>('/simple-subscription/plans');

      if (response.isSuccess && response.data != null) {
        final plans = response.data!['plans'] as List?;
        if (plans != null) {
          return plans
              .map((plan) =>
                  SubscriptionPlan.fromJson(Map<String, dynamic>.from(plan)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting subscription plans: $e');
      return [];
    }
  }

  /// Subscribe to a plan
  Future<bool> subscribeToPlan(String planCode) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/simple-subscription/subscribe',
        data: {'plan_code': planCode},
      );
      return response.isSuccess;
    } catch (e) {
      print('Error subscribing to plan: $e');
      return false;
    }
  }
}

class SimpleSubscriptionStatus {
  final String planCode;
  final String planName;
  final int responsesUsed;
  final int? responsesLimit; // null for unlimited
  final int? responsesRemaining; // null for unlimited
  final bool canRespond;
  final bool isVerifiedBusiness;
  final List<String> features;

  SimpleSubscriptionStatus({
    required this.planCode,
    required this.planName,
    required this.responsesUsed,
    this.responsesLimit,
    this.responsesRemaining,
    required this.canRespond,
    required this.isVerifiedBusiness,
    required this.features,
  });

  factory SimpleSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SimpleSubscriptionStatus(
      planCode: json['plan_code'] ?? '',
      planName: json['plan_name'] ?? '',
      responsesUsed: json['responses_used'] ?? 0,
      responsesLimit: json['responses_limit'],
      responsesRemaining: json['responses_remaining'],
      canRespond: json['can_respond'] ?? false,
      isVerifiedBusiness: json['is_verified_business'] ?? false,
      features: List<String>.from(json['features'] ?? []),
    );
  }

  bool get isUnlimited => responsesLimit == null;
  bool get isFree => planCode == 'free';
  bool get isPremium => planCode == 'premium';
}

class ResponseEligibility {
  final bool canRespond;
  final String reason;
  final String? message;
  final int? responsesUsed;
  final int? responsesLimit;
  final int? responsesRemaining;

  ResponseEligibility({
    required this.canRespond,
    required this.reason,
    this.message,
    this.responsesUsed,
    this.responsesLimit,
    this.responsesRemaining,
  });

  factory ResponseEligibility.fromJson(Map<String, dynamic> json) {
    return ResponseEligibility(
      canRespond: json['can_respond'] ?? false,
      reason: json['reason'] ?? '',
      message: json['message'],
      responsesUsed: json['responses_used'],
      responsesLimit: json['responses_limit'],
      responsesRemaining: json['responses_remaining'],
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String code;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int responseLimit; // -1 for unlimited
  final List<String> features;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.responseLimit,
    required this.features,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'USD',
      responseLimit: json['response_limit'] ?? 3,
      features: List<String>.from(json['features'] ?? []),
      isActive: json['is_active'] ?? true,
    );
  }

  bool get isUnlimited => responseLimit == -1;
  bool get isFree => price == 0;

  String get responseText {
    if (isUnlimited) return 'Unlimited responses';
    return '$responseLimit responses per month';
  }

  String get priceText {
    if (isFree) return 'Free';
    return '\$${price.toStringAsFixed(2)}/$currency';
  }
}
