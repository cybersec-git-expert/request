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
        return {
          'success': true,
          'data': {
            'businessTypeId': 1, // Default business type
            'businessTypeName': 'General Business',
            'plans': data['plans'] ?? []
          }
        };
      }

      return {'success': false, 'error': 'Failed to load business benefits'};
    } catch (e) {
      print('Error loading business benefits: $e');
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
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
