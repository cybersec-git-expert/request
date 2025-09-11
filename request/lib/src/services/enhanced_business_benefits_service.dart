import '../services/api_client.dart';

class EnhancedBusinessBenefitsService {
  static final ApiClient _apiClient = ApiClient.instance;

  static Future<Map<String, dynamic>> getBusinessTypeBenefits(
      String countryCode) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/enhanced-business-benefits/$countryCode',
      );

      if (response.isSuccess && response.data != null) {
        // Transform the backend response to match our expected format
        final data = response.data!;

        // Check if there are any plans in the response
        if (data['plans'] != null && (data['plans'] as List).isNotEmpty) {
          return {
            'success': true,
            'data': {
              'businessTypeId': 1,
              'businessTypeName': 'General Business',
              'plans': data['plans']
            }
          };
        }
      }

      // If no plans found or API failed, return sample data for testing
      return _getSampleBusinessBenefits();
    } catch (e) {
      print('Error loading business benefits: $e');
      // Return sample data as fallback
      return _getSampleBusinessBenefits();
    }
  }

  static Map<String, dynamic> _getSampleBusinessBenefits() {
    return {
      'success': true,
      'data': {
        'businessTypeId': 1,
        'businessTypeName': 'General Business',
        'plans': [
          {
            'planId': 1,
            'planCode': 'free',
            'planName': 'Free Plan',
            'pricingModel': 'response_based',
            'features': {
              'monthly_requests': 5,
              'featured_listing': false,
              'priority_support': false,
              'analytics_dashboard': false,
            },
            'pricing': {
              'currency': 'LKR',
              'setup_fee': 0,
              'monthly_fee': 0,
            },
            'allowedResponseTypes': ['item', 'service'],
            'isActive': true
          },
          {
            'planId': 2,
            'planCode': 'basic',
            'planName': 'Basic Plan',
            'pricingModel': 'monthly_subscription',
            'features': {
              'monthly_requests': 50,
              'featured_listing': true,
              'priority_support': false,
              'analytics_dashboard': true,
            },
            'pricing': {
              'currency': 'LKR',
              'setup_fee': 500,
              'monthly_fee': 2500,
            },
            'allowedResponseTypes': ['item', 'service', 'delivery'],
            'isActive': true
          },
          {
            'planId': 3,
            'planCode': 'premium',
            'planName': 'Premium Plan',
            'pricingModel': 'monthly_subscription',
            'features': {
              'monthly_requests': 200,
              'featured_listing': true,
              'priority_support': true,
              'analytics_dashboard': true,
              'promotion_tools': true,
            },
            'pricing': {
              'currency': 'LKR',
              'setup_fee': 1000,
              'monthly_fee': 7500,
            },
            'allowedResponseTypes': ['item', 'service', 'delivery', 'rental'],
            'isActive': true
          }
        ]
      }
    };
  }

  static Future<Map<String, dynamic>> getBusinessTypePlans(
      String countryCode, int businessTypeId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/enhanced-business-benefits/$countryCode/$businessTypeId',
      );

      if (response.isSuccess && response.data != null) {
        return {'success': true, 'data': response.data};
      }

      return {'success': false, 'error': 'Failed to load business type plans'};
    } catch (e) {
      print('Error loading business type plans: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> createBenefitPlan({
    required String countryCode,
    required int businessTypeId,
    required String planCode,
    required String planName,
    required String pricingModel,
    Map<String, dynamic>? features,
    Map<String, dynamic>? pricing,
    List<String>? allowedResponseTypes,
  }) async {
    return {'success': false, 'error': 'benefits_disabled'};
  }

  static Future<Map<String, dynamic>> updateBenefitPlan(
    String planId, {
    String? planName,
    String? pricingModel,
    Map<String, dynamic>? features,
    Map<String, dynamic>? pricing,
    List<String>? allowedResponseTypes,
    bool? isActive,
  }) async {
    return {'success': false, 'error': 'benefits_disabled'};
  }

  static Future<void> deleteBenefitPlan(dynamic planId) async {
    // no-op
  }
}
