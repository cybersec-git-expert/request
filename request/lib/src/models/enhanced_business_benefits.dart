class EnhancedBenefitPlan {
  final int planId;
  final String planCode;
  final String planName;
  final String pricingModel;
  final Map<String, dynamic> features;
  final Map<String, dynamic> pricing;
  final List<String> allowedResponseTypes;
  final bool isActive;

  EnhancedBenefitPlan({
    required this.planId,
    required this.planCode,
    required this.planName,
    required this.pricingModel,
    required this.features,
    required this.pricing,
    required this.allowedResponseTypes,
    required this.isActive,
  });

  factory EnhancedBenefitPlan.fromJson(Map<String, dynamic> json) {
    return EnhancedBenefitPlan(
      planId: json['planId'] ?? 0,
      planCode: json['planCode'] ?? '',
      planName: json['planName'] ?? '',
      pricingModel: json['pricingModel'] ?? '',
      features: Map<String, dynamic>.from(json['features'] ?? {}),
      pricing: Map<String, dynamic>.from(json['pricing'] ?? {}),
      allowedResponseTypes:
          List<String>.from(json['allowedResponseTypes'] ?? []),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'planCode': planCode,
      'planName': planName,
      'pricingModel': pricingModel,
      'features': features,
      'pricing': pricing,
      'allowedResponseTypes': allowedResponseTypes,
      'isActive': isActive,
    };
  }

  // Helper methods for specific pricing models
  bool get isPayPerClick => pricingModel == 'pay_per_click';
  bool get isMonthlySubscription => pricingModel == 'monthly_subscription';
  bool get isBundle => pricingModel == 'bundle';
  bool get isResponseBased => pricingModel == 'response_based';

  // Get pricing information based on model
  double? get costPerClick =>
      isPayPerClick ? pricing['cost_per_click']?.toDouble() : null;
  double? get monthlyFee =>
      isMonthlySubscription ? pricing['monthly_fee']?.toDouble() : null;
  double? get bundlePrice =>
      isBundle ? pricing['bundle_price']?.toDouble() : null;
  double? get costPerResponse =>
      isResponseBased ? pricing['cost_per_response']?.toDouble() : null;

  int? get clicksIncluded => isBundle ? pricing['clicks_included'] : null;
  double? get minimumBudget =>
      isPayPerClick ? pricing['minimum_budget']?.toDouble() : null;
  double? get setupFee =>
      isMonthlySubscription ? pricing['setup_fee']?.toDouble() : null;

  String get currency => pricing['currency'] ?? 'LKR';

  // Get feature flags
  bool hasFeature(String feature) => features[feature] == true;

  // Common features
  bool get hasClickTracking => hasFeature('click_tracking');
  bool get hasAnalyticsDashboard => hasFeature('analytics_dashboard');
  bool get hasProductShowcase => hasFeature('product_showcase');
  bool get hasCustomerMessaging => hasFeature('customer_messaging');
  bool get hasUnlimitedProducts => hasFeature('unlimited_products');
  bool get hasPriorityListing => hasFeature('priority_listing');
  bool get hasAdvancedAnalytics => hasFeature('advanced_analytics');
  bool get hasCustomerSupport => hasFeature('customer_support');
  bool get hasPromotionTools => hasFeature('promotion_tools');
  bool get hasFeaturedListing => hasFeature('featured_listing');
}

class BusinessTypeBenefits {
  final int businessTypeId;
  final String businessTypeName;
  final List<EnhancedBenefitPlan> plans;

  BusinessTypeBenefits({
    required this.businessTypeId,
    required this.businessTypeName,
    required this.plans,
  });

  factory BusinessTypeBenefits.fromJson(Map<String, dynamic> json) {
    return BusinessTypeBenefits(
      businessTypeId: json['businessTypeId'] ?? 0,
      businessTypeName: json['businessTypeName'] ?? '',
      plans: (json['plans'] as List<dynamic>? ?? [])
          .map((plan) => EnhancedBenefitPlan.fromJson(plan))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessTypeId': businessTypeId,
      'businessTypeName': businessTypeName,
      'plans': plans.map((plan) => plan.toJson()).toList(),
    };
  }

  // Helper methods
  List<EnhancedBenefitPlan> get activePlans =>
      plans.where((plan) => plan.isActive).toList();

  List<EnhancedBenefitPlan> getPlansByModel(String pricingModel) =>
      plans.where((plan) => plan.pricingModel == pricingModel).toList();

  List<EnhancedBenefitPlan> get payPerClickPlans =>
      getPlansByModel('pay_per_click');
  List<EnhancedBenefitPlan> get monthlySubscriptionPlans =>
      getPlansByModel('monthly_subscription');
  List<EnhancedBenefitPlan> get bundlePlans => getPlansByModel('bundle');
  List<EnhancedBenefitPlan> get responseBasedPlans =>
      getPlansByModel('response_based');
}

class EnhancedBusinessBenefitsResponse {
  final bool success;
  final int countryId;
  final Map<String, BusinessTypeBenefits> businessTypeBenefits;
  final String timestamp;

  EnhancedBusinessBenefitsResponse({
    required this.success,
    required this.countryId,
    required this.businessTypeBenefits,
    required this.timestamp,
  });

  factory EnhancedBusinessBenefitsResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, BusinessTypeBenefits> benefits = {};

    if (json['businessTypeBenefits'] != null) {
      (json['businessTypeBenefits'] as Map<String, dynamic>)
          .forEach((key, value) {
        benefits[key] = BusinessTypeBenefits.fromJson(value);
      });
    }

    return EnhancedBusinessBenefitsResponse(
      success: json['success'] ?? false,
      countryId: json['countryId'] ?? 0,
      businessTypeBenefits: benefits,
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'countryId': countryId,
      'businessTypeBenefits': businessTypeBenefits
          .map((key, value) => MapEntry(key, value.toJson())),
      'timestamp': timestamp,
    };
  }

  // Helper methods
  BusinessTypeBenefits? getBenefitsForType(String businessTypeName) {
    return businessTypeBenefits[businessTypeName];
  }

  List<String> get availableBusinessTypes => businessTypeBenefits.keys.toList();
}
