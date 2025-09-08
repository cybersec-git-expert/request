import 'dart:convert';

class SubscriptionPlan {
  final String code;
  final String name;
  final String? description;
  final String planType; // unlimited | ppc | other
  final int? defaultResponsesPerMonth;
  final String? currency;
  final num? price; // monthly price if applicable
  final num? ppcPrice; // price per click if applicable
  final int? responsesPerMonth; // country override

  SubscriptionPlan({
    required this.code,
    required this.name,
    required this.planType,
    this.description,
    this.defaultResponsesPerMonth,
    this.currency,
    this.price,
    this.ppcPrice,
    this.responsesPerMonth,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString(),
        planType: j['plan_type']?.toString() ?? 'other',
        defaultResponsesPerMonth: _asInt(j['default_responses_per_month']),
        currency: j['currency']?.toString(),
        price: _asNum(j['price']),
        ppcPrice: _asNum(j['ppc_price']),
        responsesPerMonth: _asInt(j['responses_per_month']),
      );

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'description': description,
        'plan_type': planType,
        'default_responses_per_month': defaultResponsesPerMonth,
        'currency': currency,
        'price': price,
        'ppc_price': ppcPrice,
        'responses_per_month': responsesPerMonth,
      };

  @override
  String toString() => jsonEncode(toJson());
}

class RoleOption {
  final String type; // general | driver | delivery | product_seller
  final String name;
  final String? description;
  final List<String> allowedRequestTypes;
  final bool requiresSubscription;

  RoleOption({
    required this.type,
    required this.name,
    required this.allowedRequestTypes,
    required this.requiresSubscription,
    this.description,
  });

  factory RoleOption.fromJson(Map<String, dynamic> j) => RoleOption(
        type: j['type']?.toString() ?? 'general',
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString(),
        allowedRequestTypes: (j['allowed_request_types'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        requiresSubscription: j['requires_subscription'] == true,
      );
}

class MembershipInit {
  final String country;
  final List<RoleOption> roles;
  final List<SubscriptionPlan> plans;
  final List<String> sellerPlanCodes;

  MembershipInit({
    required this.country,
    required this.roles,
    required this.plans,
    required this.sellerPlanCodes,
  });

  factory MembershipInit.fromJson(Map<String, dynamic> j) => MembershipInit(
        country: j['country']?.toString() ?? 'LK',
        roles: (j['roles'] as List?)
                ?.whereType<Object>()
                .map((e) =>
                    RoleOption.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        plans: (j['plans'] as List?)
                ?.whereType<Object>()
                .map((e) => SubscriptionPlan.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        sellerPlanCodes: (j['seller_plan_codes'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

class Capabilities {
  final bool canRespondToRide;
  final bool canRespondToDelivery;
  final bool canAddPrice;
  final String registrationType;
  final String planCode;

  Capabilities({
    required this.canRespondToRide,
    required this.canRespondToDelivery,
    required this.canAddPrice,
    required this.registrationType,
    required this.planCode,
  });

  factory Capabilities.fromJson(Map<String, dynamic> j) => Capabilities(
        canRespondToRide: j['canRespondToRide'] == true,
        canRespondToDelivery: j['canRespondToDelivery'] == true,
        canAddPrice: j['canAddPrice'] == true,
        registrationType: j['registration_type']?.toString() ?? 'general',
        planCode: j['plan_code']?.toString() ?? 'free',
      );
}

class Eligibility {
  final bool canRespond;
  final bool canViewContact;
  final bool upgradeRequired;
  final bool needsRole;
  final String? reason;
  final String registrationType;
  final String planCode;
  final int responsesUsed;
  final int? responsesLimit;

  Eligibility({
    required this.canRespond,
    required this.canViewContact,
    required this.upgradeRequired,
    required this.needsRole,
    required this.registrationType,
    required this.planCode,
    required this.responsesUsed,
    this.responsesLimit,
    this.reason,
  });

  factory Eligibility.fromJson(Map<String, dynamic> j) => Eligibility(
        canRespond: j['can_respond'] == true,
        canViewContact: j['can_view_contact'] == true,
        upgradeRequired: j['upgrade_required'] == true,
        needsRole: j['needs_role'] == true,
        reason: j['reason']?.toString(),
        registrationType: j['registration_type']?.toString() ?? 'general',
        planCode: j['plan_code']?.toString() ?? 'free',
        responsesUsed: (j['responses_used'] is num)
            ? (j['responses_used'] as num).toInt()
            : int.tryParse(j['responses_used']?.toString() ?? '0') ?? 0,
        responsesLimit: j['responses_limit'] == null
            ? null
            : ((j['responses_limit'] is num)
                ? (j['responses_limit'] as num).toInt()
                : int.tryParse(j['responses_limit'].toString())),
      );
}
