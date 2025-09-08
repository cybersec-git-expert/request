class EnhancedBenefitPlan {
  final String id;
  final String planCode;
  final String planName;
  final String planDescription;
  final String planType; // 'response_based', 'pricing_based', 'hybrid'
  final String businessTypeId;
  final String businessTypeName;
  final String countryId;
  final Map<String, dynamic> config;
  final List<String> allowedResponseTypes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EnhancedBenefitPlan({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.planDescription,
    required this.planType,
    required this.businessTypeId,
    required this.businessTypeName,
    required this.countryId,
    required this.config,
    required this.allowedResponseTypes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EnhancedBenefitPlan.fromJson(Map<String, dynamic> json) {
    return EnhancedBenefitPlan(
      id: json['id']?.toString() ?? '',
      planCode: json['plan_code']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      planDescription: json['plan_description']?.toString() ?? '',
      planType: json['plan_type']?.toString() ?? 'response_based',
      businessTypeId: json['business_type_id']?.toString() ?? '',
      businessTypeName: json['business_type_name']?.toString() ?? '',
      countryId: json['country_id']?.toString() ?? '',
      config: json['config_data'] as Map<String, dynamic>? ?? {},
      allowedResponseTypes: (json['allowed_response_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: json['is_active'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_code': planCode,
      'plan_name': planName,
      'plan_description': planDescription,
      'plan_type': planType,
      'business_type_id': businessTypeId,
      'business_type_name': businessTypeName,
      'country_id': countryId,
      'config_data': config,
      'allowed_response_types': allowedResponseTypes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EnhancedBenefitPlan copyWith({
    String? id,
    String? planCode,
    String? planName,
    String? planDescription,
    String? planType,
    String? businessTypeId,
    String? businessTypeName,
    String? countryId,
    Map<String, dynamic>? config,
    List<String>? allowedResponseTypes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnhancedBenefitPlan(
      id: id ?? this.id,
      planCode: planCode ?? this.planCode,
      planName: planName ?? this.planName,
      planDescription: planDescription ?? this.planDescription,
      planType: planType ?? this.planType,
      businessTypeId: businessTypeId ?? this.businessTypeId,
      businessTypeName: businessTypeName ?? this.businessTypeName,
      countryId: countryId ?? this.countryId,
      config: config ?? this.config,
      allowedResponseTypes: allowedResponseTypes ?? this.allowedResponseTypes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedBenefitPlan && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'EnhancedBenefitPlan(id: $id, planName: $planName, planType: $planType, businessType: $businessTypeName)';
  }
}

/// Model for user's current benefit subscription
class BenefitSubscription {
  final String id;
  final String userId;
  final String planId;
  final EnhancedBenefitPlan plan;
  final DateTime subscriptionDate;
  final DateTime? expiryDate;
  final bool isActive;
  final Map<String, dynamic> usageStats;
  final Map<String, dynamic> subscriptionData;

  BenefitSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.plan,
    required this.subscriptionDate,
    this.expiryDate,
    required this.isActive,
    required this.usageStats,
    required this.subscriptionData,
  });

  factory BenefitSubscription.fromJson(Map<String, dynamic> json) {
    return BenefitSubscription(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? '',
      plan: EnhancedBenefitPlan.fromJson(json['plan'] as Map<String, dynamic>),
      subscriptionDate:
          DateTime.tryParse(json['subscription_date']?.toString() ?? '') ??
              DateTime.now(),
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'].toString())
          : null,
      isActive: json['is_active'] == true,
      usageStats: json['usage_stats'] as Map<String, dynamic>? ?? {},
      subscriptionData:
          json['subscription_data'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_id': planId,
      'plan': plan.toJson(),
      'subscription_date': subscriptionDate.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'is_active': isActive,
      'usage_stats': usageStats,
      'subscription_data': subscriptionData,
    };
  }
}

/// Model for pricing calculation results
class PricingCalculation {
  final String action;
  final double cost;
  final String currency;
  final Map<String, dynamic> breakdown;
  final bool canAfford;
  final String? message;

  PricingCalculation({
    required this.action,
    required this.cost,
    required this.currency,
    required this.breakdown,
    required this.canAfford,
    this.message,
  });

  factory PricingCalculation.fromJson(Map<String, dynamic> json) {
    return PricingCalculation(
      action: json['action']?.toString() ?? '',
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'USD',
      breakdown: json['breakdown'] as Map<String, dynamic>? ?? {},
      canAfford: json['can_afford'] == true,
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'cost': cost,
      'currency': currency,
      'breakdown': breakdown,
      'can_afford': canAfford,
      if (message != null) 'message': message,
    };
  }
}
