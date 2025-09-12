import 'package:flutter/material.dart';
import '../src/theme/glass_theme.dart';
import '../models/payment_gateway.dart';
import '../services/payment_gateway_service.dart';
import 'card_payment_screen.dart';

class PaymentProcessingScreen extends StatefulWidget {
  final PaymentGateway paymentGateway;
  final String planCode;
  final double amount;
  final String currency;
  final String userId;

  const PaymentProcessingScreen({
    Key? key,
    required this.paymentGateway,
    required this.planCode,
    required this.amount,
    required this.currency,
    required this.userId,
  }) : super(key: key);

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  PaymentSession? _paymentSession;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  String? _successMessage;
  String _selectedPaymentMethod = '';

  @override
  void initState() {
    super.initState();
    _createPaymentSession();
  }

  Future<void> _createPaymentSession() async {
    try {
      final session =
          await PaymentGatewayService.instance.createSubscriptionPaymentSession(
        subscriptionId: 'sub_${DateTime.now().millisecondsSinceEpoch}',
        gatewayCode: widget.paymentGateway.code,
      );

      setState(() {
        _paymentSession = session;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to create payment session: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlassTheme.backgroundColor,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_successMessage != null) {
      return _buildSuccessView();
    }

    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_error != null) {
      return _buildErrorView();
    }

    return _buildPaymentView();
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Setting up payment...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Setup Failed',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _successMessage ?? 'Your subscription has been activated.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(
                  Icons.arrow_back,
                  color: GlassTheme.colors.textPrimary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Title
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Payment\noption',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: GlassTheme.colors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),

        // Payment options list
        Expanded(
          child: FutureBuilder<List<PaymentGateway>>(
            future:
                PaymentGatewayService.instance.getConfiguredPaymentGateways(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No payment methods available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                );
              }

              final paymentGateways = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: paymentGateways.length,
                itemBuilder: (context, index) {
                  final gateway = paymentGateways[index];
                  return _buildCleanPaymentOption(gateway);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCleanPaymentOption(PaymentGateway gateway) {
    return GestureDetector(
      onTap: () => _selectPaymentMethod(gateway),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        margin: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            // Payment method icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getPaymentMethodColor(gateway.code),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getPaymentMethodIcon(gateway.code),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Payment method name
            Expanded(
              child: Text(
                _getPaymentMethodDisplayName(gateway.code),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: GlassTheme.colors.textPrimary,
                ),
              ),
            ),

            // Payment method logo (if applicable)
            if (_getPaymentMethodLogo(gateway.code) != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getPaymentMethodLogo(gateway.code)!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectPaymentMethod(PaymentGateway gateway) {
    // Handle payment method selection
    setState(() {
      _selectedPaymentMethod = gateway.code;
    });

    // Navigate to card payment screen for card-based gateways
    if (gateway.code.toLowerCase() == 'stripe' ||
        gateway.code.toLowerCase() == 'payhere') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CardPaymentScreen(
            paymentGateway: gateway,
            planCode: widget.planCode,
            amount: widget.amount,
            currency: widget.currency,
            userId: widget.userId,
          ),
        ),
      );
    } else {
      // For other payment methods, show success message for now
      setState(() {
        _successMessage =
            'Payment method ${gateway.name} selected successfully!';
      });
    }
  }

  IconData _getPaymentMethodIcon(String gatewayCode) {
    switch (gatewayCode.toLowerCase()) {
      case 'stripe':
      case 'payhere':
        return Icons.credit_card;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'gpay':
        return Icons.payment;
      case 'phonepe':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor(String gatewayCode) {
    switch (gatewayCode.toLowerCase()) {
      case 'stripe':
      case 'payhere':
        return Colors.blue;
      case 'bank_transfer':
        return Colors.purple;
      case 'gpay':
        return Colors.green;
      case 'phonepe':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMethodDisplayName(String gatewayCode) {
    switch (gatewayCode.toLowerCase()) {
      case 'stripe':
      case 'payhere':
        return 'Debit / Credit card';
      case 'bank_transfer':
        return 'Internet Banking';
      case 'gpay':
        return 'G Pay';
      case 'phonepe':
        return 'PhonePe';
      default:
        return gatewayCode;
    }
  }

  String? _getPaymentMethodLogo(String gatewayCode) {
    switch (gatewayCode.toLowerCase()) {
      case 'stripe':
      case 'payhere':
        return 'VISA';
      case 'bank_transfer':
        return null;
      case 'gpay':
        return 'UPI';
      case 'phonepe':
        return 'RuPay';
      default:
        return null;
    }
  }
}
