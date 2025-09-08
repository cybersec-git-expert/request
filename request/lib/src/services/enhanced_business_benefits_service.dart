// Minimal no-op service to keep app compiling after removing benefits backend.
// All methods return empty data and do not perform network calls.
class EnhancedBusinessBenefitsService {
  static Future<Map<String, dynamic>> getBusinessTypeBenefits(
      String countryCode) async {
    return {
      'success': true,
      'data': {'plans': []}
    };
  }

  static Future<Map<String, dynamic>> getBusinessTypePlans(
      String countryCode, int businessTypeId) async {
    return {
      'success': true,
      'data': {'plans': []}
    };
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
