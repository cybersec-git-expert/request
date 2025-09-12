import 'api_client.dart';
import 'country_service.dart';

class SimpleSubscriptionService {
  SimpleSubscriptionService._();
  static SimpleSubscriptionService? _instance;
  static SimpleSubscriptionService get instance =>
      _instance ??= SimpleSubscriptionService._();

  /// Get user's subscription status
  Future<SimpleSubscriptionStatus?> getSubscriptionStatus() async {
    try {
      final response = await ApiClient.instance
          .get<Map<String, dynamic>>('/api/simple-subscription/status');

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
          .get<Map<String, dynamic>>('/api/simple-subscription/can-respond');

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
        '/api/simple-subscription/record-response',
        data: {'request_id': requestId},
      );
      return response.isSuccess;
    } catch (e) {
      print('Error recording response: $e');
      return false;
    }
  }

  /// Get available subscription plans with country-specific pricing
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      // Get current country code
      final countryService = CountryService.instance;
      final countryCode =
          countryService.countryCode ?? 'LK'; // Default to Sri Lanka

      print('DEBUG: Getting plans for country: $countryCode');

      final response = await ApiClient.instance.get<Map<String, dynamic>>(
          '/api/simple-subscription/plans',
          queryParameters: {'country': countryCode});

      print('DEBUG: API Response success: ${response.isSuccess}');
      print('DEBUG: API Response data: ${response.data}');
      print('DEBUG: API Response error: ${response.error}');

      if (response.isSuccess && response.data != null) {
        final plans = response.data!['plans'] as List?;
        print('DEBUG: Plans list: $plans');
        if (plans != null) {
          final subscriptionPlans = plans
              .map((plan) =>
                  SubscriptionPlan.fromJson(Map<String, dynamic>.from(plan)))
              .toList();
          print(
              'DEBUG: Converted to SubscriptionPlan objects: ${subscriptionPlans.length} plans');
          return subscriptionPlans;
        }
      }
      print('DEBUG: Returning empty list');
      return [];
    } catch (e) {
      print('Error getting subscription plans: $e');
      return [];
    }
  }

  /// Subscribe to a plan
  Future<SubscriptionResult> subscribeToPlan(String planCode) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/simple-subscription/subscribe',
        data: {'planCode': planCode},
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;

        if (data['requiresPayment'] == true) {
          return SubscriptionResult(
            success: true,
            requiresPayment: true,
            subscription: data['subscription'],
            plan: data['plan'],
            message: data['message'],
          );
        } else {
          return SubscriptionResult(
            success: true,
            requiresPayment: false,
            subscription: data['subscription'],
            message: data['message'],
          );
        }
      }

      return SubscriptionResult(
        success: false,
        message: response.error ?? 'Failed to subscribe',
      );
    } catch (e) {
      print('Error subscribing to plan: $e');
      return SubscriptionResult(
        success: false,
        message: 'Failed to subscribe to plan',
      );
    }
  }

  /// Confirm payment for subscription
  Future<bool> confirmPayment(String paymentId, {String? transactionId}) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/simple-subscription/confirm-payment',
        data: {
          'paymentId': paymentId,
          if (transactionId != null) 'transactionId': transactionId,
        },
      );

      return response.isSuccess;
    } catch (e) {
      print('Error confirming payment: $e');
      return false;
    }
  }
}

class SubscriptionResult {
  final bool success;
  final bool requiresPayment;
  final Map<String, dynamic>? subscription;
  final Map<String, dynamic>? plan;
  final String? message;

  SubscriptionResult({
    required this.success,
    this.requiresPayment = false,
    this.subscription,
    this.plan,
    this.message,
  });
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
      price: _parsePrice(json['price']),
      currency: json['currency'] ?? 'USD',
      responseLimit: json['response_limit'] ?? 3,
      features: List<String>.from(json['features'] ?? []),
      isActive: json['is_active'] ?? true,
    );
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
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
