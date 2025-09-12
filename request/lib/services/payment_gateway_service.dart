import '../models/payment_gateway.dart';
import '../src/services/api_client.dart';
import '../src/services/country_service.dart';

class PaymentGatewayService {
  PaymentGatewayService._();
  static PaymentGatewayService? _instance;
  static PaymentGatewayService get instance =>
      _instance ??= PaymentGatewayService._();

  /// Get available payment gateways for the user's country
  Future<PaymentGatewayResponse> getAvailablePaymentGateways(
      {String? countryCode}) async {
    try {
      // Use provided country code or get from country service
      final country =
          countryCode ?? await CountryService.instance.getCurrentCountryCode();

      final response = await ApiClient.instance.get<Map<String, dynamic>>(
          '/api/admin/payment-gateways/gateways/$country');

      if (response.isSuccess && response.data != null) {
        return PaymentGatewayResponse.fromJson(response.data!);
      }

      return PaymentGatewayResponse(
        success: false,
        gateways: [],
        error: response.error ?? 'Failed to fetch payment gateways',
      );
    } catch (e) {
      print('Error fetching payment gateways: $e');
      return PaymentGatewayResponse(
        success: false,
        gateways: [],
        error: 'Failed to fetch payment gateways',
      );
    }
  }

  /// Get the primary payment gateway for a country
  Future<PaymentGateway?> getPrimaryPaymentGateway(
      {String? countryCode}) async {
    try {
      final country =
          countryCode ?? await CountryService.instance.getCurrentCountryCode();

      final response = await ApiClient.instance.get<Map<String, dynamic>>(
          '/api/admin/payment-gateways/gateways/$country/primary');

      if (response.isSuccess && response.data != null) {
        final gatewayData = response.data!['gateway'] as Map<String, dynamic>?;
        if (gatewayData != null) {
          return PaymentGateway.fromJson(gatewayData);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching primary payment gateway: $e');
      return null;
    }
  }

  /// Get configured payment gateways (only ones that are set up)
  Future<List<PaymentGateway>> getConfiguredPaymentGateways(
      {String? countryCode}) async {
    try {
      final gatewayResponse =
          await getAvailablePaymentGateways(countryCode: countryCode);

      if (gatewayResponse.success) {
        // Filter to only configured gateways
        return gatewayResponse.gateways
            .where((gateway) => gateway.configured)
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching configured payment gateways: $e');
      return [];
    }
  }

  /// Create a payment session for subscription
  Future<PaymentSession?> createSubscriptionPaymentSession({
    required String subscriptionId,
    required String gatewayCode,
    String? countryCode,
  }) async {
    try {
      final country =
          countryCode ?? await CountryService.instance.getCurrentCountryCode();

      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/payments/create-session',
        data: {
          'subscription_id': subscriptionId,
          'gateway_code': gatewayCode,
          'country_code': country,
        },
      );

      if (response.isSuccess && response.data != null) {
        return PaymentSession.fromJson(response.data!);
      }

      return null;
    } catch (e) {
      print('Error creating payment session: $e');
      return null;
    }
  }

  /// Confirm payment completion
  Future<bool> confirmPayment({
    required String paymentId,
    required String transactionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/payments/confirm',
        data: {
          'payment_id': paymentId,
          'transaction_id': transactionId,
          if (metadata != null) 'metadata': metadata,
        },
      );

      return response.isSuccess;
    } catch (e) {
      print('Error confirming payment: $e');
      return false;
    }
  }

  /// Get payment gateway configuration (for bank transfer details)
  Future<PaymentGatewayConfig?> getGatewayConfiguration({
    required int gatewayId,
    String? countryCode,
  }) async {
    try {
      final country =
          countryCode ?? await CountryService.instance.getCurrentCountryCode();

      final response = await ApiClient.instance.get<Map<String, dynamic>>(
          '/api/admin/payment-gateways/gateways/$country/$gatewayId/config');

      if (response.isSuccess && response.data != null) {
        final gatewayData = response.data!['gateway'] as Map<String, dynamic>?;
        if (gatewayData != null) {
          final configData =
              gatewayData['configuration'] as Map<String, dynamic>?;
          if (configData != null) {
            return PaymentGatewayConfig.fromJson(configData);
          }
        }
      }

      return null;
    } catch (e) {
      print('Error fetching gateway configuration: $e');
      return null;
    }
  }

  /// Check if payment is required for a subscription plan
  Future<bool> isPaymentRequired(String planCode) async {
    // Free plans don't require payment
    if (planCode.toLowerCase() == 'free') {
      return false;
    }

    // All other plans require payment
    return true;
  }

  /// Get payment method recommendation based on country
  String getRecommendedPaymentMethod(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'LK':
        return 'payhere'; // PayHere for Sri Lanka
      case 'IN':
        return 'razorpay'; // Razorpay for India
      case 'US':
      case 'CA':
      case 'GB':
      case 'AU':
        return 'stripe'; // Stripe for developed countries
      default:
        return 'stripe'; // Default to Stripe
    }
  }

  /// Format amount for display
  String formatAmount(double amount, String currency) {
    final currencySymbols = {
      'USD': '\$',
      'LKR': 'Rs. ',
      'INR': '₹',
      'GBP': '£',
      'EUR': '€',
      'CAD': 'C\$',
      'AUD': 'A\$',
    };

    final symbol = currencySymbols[currency.toUpperCase()] ?? '$currency ';

    // Format with appropriate decimal places
    if (currency.toLowerCase() == 'lkr' || currency.toLowerCase() == 'inr') {
      return '$symbol${amount.toStringAsFixed(2)}';
    } else {
      return '$symbol${amount.toStringAsFixed(2)}';
    }
  }

  /// Get payment instructions for manual payment methods
  String getPaymentInstructions(
      PaymentGateway gateway, PaymentGatewayConfig? config) {
    if (gateway.code.toLowerCase() == 'bank_transfer' && config != null) {
      return '''
Please transfer the subscription amount to the following bank account:

Bank: ${config.bankName}
Account Name: ${config.accountName}
Account Number: ${config.accountNumber}
${config.branchCode != null ? 'Branch Code: ${config.branchCode}\n' : ''}${config.swiftCode != null ? 'SWIFT Code: ${config.swiftCode}\n' : ''}
${config.instructions != null ? '\nAdditional Instructions:\n${config.instructions}' : ''}

After making the payment, please contact support with your transaction reference for verification.
''';
    }

    return 'Please follow the payment instructions provided by ${gateway.name}.';
  }
}
