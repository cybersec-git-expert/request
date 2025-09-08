import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/enhanced_benefit_plan.dart';
import '../services/auth_service.dart';

class EnhancedBusinessBenefitsService {
  static const String baseUrl =
      'https://api.alphabet.lk/api/enhanced-business-benefits';

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get available benefit plans for a specific business type in a country
  Future<List<EnhancedBenefitPlan>> getBenefitPlans({
    required String countryId,
    required String businessTypeId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$countryId/$businessTypeId/plans'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> plans = data['plans'] ?? [];

        return plans.map((plan) => EnhancedBenefitPlan.fromJson(plan)).toList();
      } else {
        throw Exception('Failed to load benefit plans: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading benefit plans: $e');
    }
  }

  /// Get all benefit plans grouped by business type for a country
  Future<Map<String, List<EnhancedBenefitPlan>>> getAllBenefitPlans({
    required String countryId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$countryId/plans'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, dynamic> plansByType =
            data['plansByBusinessType'] ?? {};

        Map<String, List<EnhancedBenefitPlan>> result = {};

        plansByType.forEach((businessType, plans) {
          if (plans is List) {
            result[businessType] = plans
                .map((plan) => EnhancedBenefitPlan.fromJson(plan))
                .toList();
          }
        });

        return result;
      } else {
        throw Exception(
            'Failed to load all benefit plans: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading all benefit plans: $e');
    }
  }

  /// Get user's current benefit plan
  Future<EnhancedBenefitPlan?> getCurrentBenefitPlan() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user/current-plan'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['plan'] != null) {
          return EnhancedBenefitPlan.fromJson(data['plan']);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null; // No current plan
      } else {
        throw Exception(
            'Failed to load current benefit plan: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading current benefit plan: $e');
    }
  }

  /// Subscribe user to a benefit plan
  Future<bool> subscribeToPlan({
    required String planId,
    Map<String, dynamic>? subscriptionData,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'planId': planId,
        if (subscriptionData != null) ...subscriptionData,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/user/subscribe'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to subscribe to plan');
      }
    } catch (e) {
      throw Exception('Error subscribing to plan: $e');
    }
  }

  /// Check if user can respond to a specific business type
  Future<bool> canRespondTo({
    required String businessTypeId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user/can-respond/$businessTypeId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['canRespond'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking response permission: $e');
      return false;
    }
  }

  /// Get user's usage statistics for current plan
  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/user/usage-stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load usage stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading usage stats: $e');
    }
  }

  /// Calculate pricing for a specific action (for pricing-based plans)
  Future<Map<String, dynamic>> calculatePricing({
    required String action,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'action': action,
        if (parameters != null) ...parameters,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/user/calculate-pricing'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to calculate pricing');
      }
    } catch (e) {
      throw Exception('Error calculating pricing: $e');
    }
  }

  /// Process a charged action (for pricing-based plans)
  Future<bool> processChargedAction({
    required String action,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'action': action,
        if (actionData != null) ...actionData,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/user/process-action'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to process action');
      }
    } catch (e) {
      throw Exception('Error processing action: $e');
    }
  }

  /// Get plan recommendations based on user's business type and usage
  Future<List<EnhancedBenefitPlan>> getPlanRecommendations({
    required String countryId,
    required String businessTypeId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$countryId/$businessTypeId/recommendations'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> recommendations = data['recommendations'] ?? [];

        return recommendations
            .map((plan) => EnhancedBenefitPlan.fromJson(plan))
            .toList();
      } else {
        throw Exception(
            'Failed to load recommendations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading recommendations: $e');
    }
  }
}

/// Helper extension for benefit plan features
extension EnhancedBenefitPlanHelpers on EnhancedBenefitPlan {
  /// Check if plan has unlimited responses
  bool get hasUnlimitedResponses {
    final responsesConfig = config['responses'];
    if (responsesConfig is Map<String, dynamic>) {
      return responsesConfig['unlimited'] == true ||
          responsesConfig['responses_per_month'] == -1;
    }
    return false;
  }

  /// Get response limit for the plan
  int? get responseLimit {
    final responsesConfig = config['responses'];
    if (responsesConfig is Map<String, dynamic>) {
      final limit = responsesConfig['responses_per_month'];
      if (limit is int && limit > 0) return limit;
    }
    return null;
  }

  /// Check if plan allows contact revealing
  bool get allowsContactRevealing {
    final responsesConfig = config['responses'];
    if (responsesConfig is Map<String, dynamic>) {
      return responsesConfig['contact_revealed'] == true;
    }
    return false;
  }

  /// Check if plan allows messaging requesters
  bool get allowsMessagingRequesters {
    final responsesConfig = config['responses'];
    if (responsesConfig is Map<String, dynamic>) {
      return responsesConfig['can_message_requester'] == true;
    }
    return false;
  }

  /// Get pricing model for pricing-based plans
  String? get pricingModel {
    final pricingConfig = config['pricing'];
    if (pricingConfig is Map<String, dynamic>) {
      return pricingConfig['model'] as String?;
    }
    return null;
  }

  /// Get price per click for pay-per-click models
  double? get pricePerClick {
    final pricingConfig = config['pricing'];
    if (pricingConfig is Map<String, dynamic>) {
      final price = pricingConfig['price_per_click'];
      if (price is num) return price.toDouble();
    }
    return null;
  }

  /// Get monthly price for subscription models
  double? get monthlyPrice {
    final pricingConfig = config['pricing'];
    if (pricingConfig is Map<String, dynamic>) {
      final price = pricingConfig['monthly_price'];
      if (price is num) return price.toDouble();
    }
    return null;
  }

  /// Get currency for pricing
  String get currency {
    final pricingConfig = config['pricing'];
    if (pricingConfig is Map<String, dynamic>) {
      return pricingConfig['currency'] as String? ?? 'USD';
    }
    return 'USD';
  }

  /// Check if plan has specific feature
  bool hasFeature(String featureName) {
    final featuresConfig = config['features'];
    if (featuresConfig is Map<String, dynamic>) {
      return featuresConfig[featureName] == true;
    }
    return false;
  }

  /// Get formatted price display
  String get priceDisplay {
    switch (pricingModel) {
      case 'per_click':
        final price = pricePerClick;
        return price != null
            ? '$currency ${price.toStringAsFixed(2)}/click'
            : 'Pay per click';
      case 'monthly':
        final price = monthlyPrice;
        return price != null
            ? '$currency ${price.toStringAsFixed(2)}/month'
            : 'Monthly subscription';
      case 'bundle':
        final price = monthlyPrice;
        return price != null
            ? '$currency ${price.toStringAsFixed(2)}/month (unlimited)'
            : 'Unlimited bundle';
      default:
        return planType == 'response_based'
            ? 'Response based'
            : 'Custom pricing';
    }
  }
}
