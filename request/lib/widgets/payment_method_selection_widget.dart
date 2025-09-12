import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_gateway.dart';
import '../services/payment_gateway_service.dart';
import '../src/theme/glass_theme.dart';

class PaymentMethodSelectionWidget extends StatefulWidget {
  final String planCode;
  final double amount;
  final String currency;
  final Function(PaymentGateway) onPaymentMethodSelected;
  final VoidCallback? onCancel;

  const PaymentMethodSelectionWidget({
    Key? key,
    required this.planCode,
    required this.amount,
    required this.currency,
    required this.onPaymentMethodSelected,
    this.onCancel,
  }) : super(key: key);

  @override
  State<PaymentMethodSelectionWidget> createState() =>
      _PaymentMethodSelectionWidgetState();
}

class _PaymentMethodSelectionWidgetState
    extends State<PaymentMethodSelectionWidget> {
  List<PaymentGateway> _paymentGateways = [];
  PaymentGateway? _selectedGateway;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaymentGateways();
  }

  Future<void> _loadPaymentGateways() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final gatewayResponse =
          await PaymentGatewayService.instance.getConfiguredPaymentGateways();

      setState(() {
        _paymentGateways = gatewayResponse;
        _isLoading = false;

        // Auto-select primary gateway if available
        final primaryGateway = _paymentGateways.firstWhere(
          (gateway) => gateway.isPrimary,
          orElse: () => _paymentGateways.isNotEmpty
              ? _paymentGateways.first
              : PaymentGateway(
                  id: 0,
                  name: '',
                  code: '',
                  description: '',
                  configurationFields: {},
                  configured: false,
                  isPrimary: false),
        );

        if (primaryGateway.id > 0) {
          _selectedGateway = primaryGateway;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load payment methods: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.payment, color: GlassTheme.colors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Select Payment Method',
                style: GlassTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onCancel,
                icon: Icon(Icons.close, color: GlassTheme.colors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Plan details (simplified - no amount)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription Plan:',
                  style: GlassTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: Rs. 0.00',
                  style: GlassTheme.bodyLarge.copyWith(
                    color: GlassTheme.colors.successColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: GlassTheme.colors.errorColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.error, color: GlassTheme.colors.errorColor),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GlassTheme.bodyMedium
                        .copyWith(color: GlassTheme.colors.errorColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadPaymentGateways,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassTheme.colors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_paymentGateways.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GlassTheme.colors.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: GlassTheme.colors.warningColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.payment_outlined,
                      color: GlassTheme.colors.warningColor, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'No Payment Methods Available',
                    style: GlassTheme.titleSmall.copyWith(
                      color: GlassTheme.colors.warningColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Payment methods are not configured for your region yet. Please contact support.',
                    style: GlassTheme.bodyMedium
                        .copyWith(color: GlassTheme.colors.warningColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose your preferred payment method:',
                  style: GlassTheme.titleSmall,
                ),
                const SizedBox(height: 12),

                // Payment methods list (clean design)
                ...(_paymentGateways
                    .map((gateway) => _buildCleanPaymentMethodTile(gateway))),

                const SizedBox(height: 24),

                // Continue button
                ElevatedButton(
                  onPressed: _selectedGateway != null
                      ? () => widget.onPaymentMethodSelected(_selectedGateway!)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.colors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _selectedGateway?.requiresManualVerification == true
                        ? 'Get Payment Details'
                        : 'Continue to Payment',
                    style: GlassTheme.bodyLarge.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCleanPaymentMethodTile(PaymentGateway gateway) {
    final isSelected = _selectedGateway?.id == gateway.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGateway = gateway;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? GlassTheme.colors.primaryBlue
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            children: [
              // Payment method icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Icon(
                    _getPaymentMethodIcon(gateway),
                    color: Colors.grey.shade600,
                    size: 24,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Payment method details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayName(gateway),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getDisplaySubtitle(gateway),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              Radio<PaymentGateway>(
                value: gateway,
                groupValue: _selectedGateway,
                onChanged: (PaymentGateway? value) {
                  setState(() {
                    _selectedGateway = value;
                  });
                },
                activeColor: GlassTheme.colors.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(PaymentGateway gateway) {
    switch (gateway.code.toLowerCase()) {
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

  String _getDisplayName(PaymentGateway gateway) {
    switch (gateway.code.toLowerCase()) {
      case 'stripe':
      case 'payhere':
        return 'PayHere';
      case 'bank_transfer':
        return 'Internet Banking';
      case 'gpay':
        return 'G Pay';
      case 'phonepe':
        return 'PhonePe';
      default:
        return gateway.name;
    }
  }

  String _getDisplaySubtitle(PaymentGateway gateway) {
    switch (gateway.code.toLowerCase()) {
      case 'stripe':
      case 'payhere':
        return 'PayHere (Local Cards & Banking)';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'gpay':
        return 'UPI Payment';
      case 'phonepe':
        return 'UPI Payment';
      default:
        return gateway.description;
    }
  }
}
