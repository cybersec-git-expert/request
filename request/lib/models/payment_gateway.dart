class PaymentGateway {
  final int id;
  final String name;
  final String code;
  final String description;
  final Map<String, dynamic> configurationFields;
  final int? countryGatewayId;
  final bool configured;
  final bool isPrimary;
  final DateTime? configuredAt;

  PaymentGateway({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.configurationFields,
    this.countryGatewayId,
    required this.configured,
    required this.isPrimary,
    this.configuredAt,
  });

  factory PaymentGateway.fromJson(Map<String, dynamic> json) {
    return PaymentGateway(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String? ?? '',
      configurationFields:
          json['configuration_fields'] as Map<String, dynamic>? ?? {},
      countryGatewayId: json['country_gateway_id'] as int?,
      configured: json['configured'] as bool? ?? false,
      isPrimary: json['is_primary'] as bool? ?? false,
      configuredAt: json['configured_at'] != null
          ? DateTime.parse(json['configured_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'configuration_fields': configurationFields,
      'country_gateway_id': countryGatewayId,
      'configured': configured,
      'is_primary': isPrimary,
      'configured_at': configuredAt?.toIso8601String(),
    };
  }

  /// Get icon for payment gateway
  String get icon {
    switch (code.toLowerCase()) {
      case 'stripe':
        return '💳'; // In real app, use Image.asset or Icon
      case 'paypal':
        return '🅿️';
      case 'payhere':
        return '🏦';
      case 'bank_transfer':
        return '🏛️';
      case 'razorpay':
        return '💰';
      default:
        return '💳';
    }
  }

  /// Check if this gateway requires special handling
  bool get requiresManualVerification {
    return code.toLowerCase() == 'bank_transfer';
  }

  /// Get user-friendly description
  String get userDescription {
    switch (code.toLowerCase()) {
      case 'stripe':
        return 'Credit/Debit Cards via Stripe';
      case 'paypal':
        return 'PayPal Account';
      case 'payhere':
        return 'PayHere (Local Cards & Banking)';
      case 'bank_transfer':
        return 'Direct Bank Transfer';
      case 'razorpay':
        return 'Razorpay (UPI, Cards, Net Banking)';
      default:
        return description.isNotEmpty ? description : name;
    }
  }
}

class PaymentGatewayConfig {
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? branchCode;
  final String? swiftCode;
  final String? instructions;

  PaymentGatewayConfig({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.branchCode,
    this.swiftCode,
    this.instructions,
  });

  factory PaymentGatewayConfig.fromJson(Map<String, dynamic> json) {
    return PaymentGatewayConfig(
      bankName: json['bank_name'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      branchCode: json['branch_code'] as String?,
      swiftCode: json['swift_code'] as String?,
      instructions: json['instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'account_name': accountName,
      'account_number': accountNumber,
      if (branchCode != null) 'branch_code': branchCode,
      if (swiftCode != null) 'swift_code': swiftCode,
      if (instructions != null) 'instructions': instructions,
    };
  }
}

class PaymentGatewayResponse {
  final bool success;
  final List<PaymentGateway> gateways;
  final String? warning;
  final String? error;

  PaymentGatewayResponse({
    required this.success,
    required this.gateways,
    this.warning,
    this.error,
  });

  factory PaymentGatewayResponse.fromJson(Map<String, dynamic> json) {
    final gatewaysList = json['gateways'] as List<dynamic>? ?? [];

    return PaymentGatewayResponse(
      success: json['success'] as bool? ?? false,
      gateways: gatewaysList
          .map((gateway) =>
              PaymentGateway.fromJson(gateway as Map<String, dynamic>))
          .toList(),
      warning: json['warning'] as String?,
      error: json['error'] as String?,
    );
  }
}

class PaymentSession {
  final String paymentId;
  final String gatewayCode;
  final String status;
  final double amount;
  final String currency;
  final String? checkoutUrl;
  final Map<String, dynamic>? metadata;

  PaymentSession({
    required this.paymentId,
    required this.gatewayCode,
    required this.status,
    required this.amount,
    required this.currency,
    this.checkoutUrl,
    this.metadata,
  });

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      paymentId: json['payment_id'] as String,
      gatewayCode: json['gateway_code'] as String,
      status: json['status'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      checkoutUrl: json['checkout_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
