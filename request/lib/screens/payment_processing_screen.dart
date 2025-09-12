import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_gateway.dart';
import '../services/payment_gateway_service.dart';
import '../src/theme/glass_theme.dart';

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

  // Card form controllers
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Payment method selection
  String _selectedPaymentMethod = 'card'; // 'card', 'bank'
  String _selectedCardType = 'debit'; // 'debit', 'credit'

  @override
  void initState() {
    super.initState();
    _createPaymentSession();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _holderNameController.dispose();
    super.dispose();
  }

  Future<void> _createPaymentSession() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final session =
          await PaymentGatewayService.instance.createSubscriptionPaymentSession(
        subscriptionId:
            '${widget.userId}_${widget.planCode}_${DateTime.now().millisecondsSinceEpoch}',
        gatewayCode: widget.paymentGateway.code,
      );

      setState(() {
        _paymentSession = session;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize payment: $e';
      });
    }
  }

  // Card number formatter
  String _formatCardNumber(String value) {
    value = value.replaceAll(RegExp(r'\s+\b|\b\s'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      buffer.write(value[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != value.length) {
        buffer.write('  ');
      }
    }
    return buffer.toString();
  }

  // Expiry formatter
  String _formatExpiry(String value) {
    value = value.replaceAll('/', '');
    if (value.length >= 2) {
      return '${value.substring(0, 2)}/${value.substring(2)}';
    }
    return value;
  }

  // Validate card number (basic Luhn algorithm check)
  bool _isValidCardNumber(String number) {
    number = number.replaceAll(' ', '');
    if (number.length < 13 || number.length > 19) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n = (n % 10) + 1;
      }
      sum += n;
      alternate = !alternate;
    }
    return (sum % 10 == 0);
  }

  // Get card type from number
  String _getCardType(String number) {
    number = number.replaceAll(' ', '');
    if (number.startsWith('4')) return 'Visa';
    if (number.startsWith('5') || number.startsWith(RegExp(r'^2[2-7]')))
      return 'Mastercard';
    if (number.startsWith('3')) return 'American Express';
    return 'Unknown';
  }

  Future<void> _processCardPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_paymentSession == null) return;

    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // For demonstration purposes, we'll always approve the payment
      // In a real implementation, you would integrate with actual payment processors
      final result = await PaymentGatewayService.instance.confirmPayment(
        paymentId: _paymentSession!.id,
        transactionId: 'CARD_TXN_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'plan_code': widget.planCode,
          'user_id': widget.userId,
          'amount': widget.amount,
          'currency': widget.currency,
          'payment_method': 'card',
          'card_type': _getCardType(_cardNumberController.text),
          'card_last4': _cardNumberController.text
              .replaceAll(' ', '')
              .substring(
                  _cardNumberController.text.replaceAll(' ', '').length - 4),
        },
      );

      if (result) {
        setState(() {
          _isProcessing = false;
          _successMessage =
              'Payment successful! Your subscription has been activated.';
        });

        // Navigate back with success result
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context)
              .pop({'success': true, 'paymentId': _paymentSession!.id});
        }
      } else {
        setState(() {
          _isProcessing = false;
          _error = 'Payment failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Payment processing failed: $e';
      });
    }
  }

  Future<void> _confirmPayment() async {
    // For card payments, use the card processing method
    if (_selectedPaymentMethod == 'card') {
      await _processCardPayment();
      return;
    }

    // For manual payments, use the original method
    if (_paymentSession == null) return;

    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      final result = await PaymentGatewayService.instance.confirmPayment(
        paymentId: _paymentSession!.id,
        transactionId: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'plan_code': widget.planCode,
          'user_id': widget.userId,
          'amount': widget.amount,
          'currency': widget.currency,
        },
      );

      if (result) {
        setState(() {
          _isProcessing = false;
          _successMessage =
              'Payment successful! Your subscription has been activated.';
        });

        // Navigate back with success result
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context)
              .pop({'success': true, 'paymentId': _paymentSession!.id});
        }
      } else {
        setState(() {
          _isProcessing = false;
          _error = 'Payment failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Payment processing failed: $e';
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
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

    if (_paymentSession == null) {
      return _buildErrorView();
    }

    return _buildPaymentView();
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: GlassTheme.colors.primaryBlue,
          ),
          const SizedBox(height: 16),
          Text(
            'Preparing payment...',
            style: GlassTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: GlassTheme.colors.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Error',
              style: GlassTheme.titleLarge.copyWith(
                color: GlassTheme.colors.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred',
              style: GlassTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _createPaymentSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: GlassTheme.colors.successColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Successful!',
              style: GlassTheme.titleLarge.copyWith(
                color: GlassTheme.colors.successColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _successMessage!,
              style: GlassTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: GlassTheme.colors.successColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Redirecting...',
              style: GlassTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header with back button
              _buildHeader(),
              const SizedBox(height: 30),

              // Payment Gateway Card
              _buildPaymentGatewayCard(),
              const SizedBox(height: 20),

              // Order Summary
              _buildOrderSummary(),
              const SizedBox(height: 20),

              // Payment Method Selection
              _buildPaymentMethodSelection(),
              const SizedBox(height: 20),

              // Card Form or Other Payment Methods
              if (_selectedPaymentMethod == 'card') ...[
                _buildCardPaymentForm(),
              ] else if (_selectedPaymentMethod == 'bank') ...[
                _buildManualPaymentInstructions(),
              ] else if (_selectedPaymentMethod == 'gpay') ...[
                _buildUPIPaymentForm('Google Pay'),
              ] else if (_selectedPaymentMethod == 'phonepe') ...[
                _buildUPIPaymentForm('PhonePe'),
              ] else ...[
                _buildManualPaymentInstructions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Payment',
          style: GlassTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildPaymentGatewayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: GlassTheme.glassContainer,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.paymentGateway.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.paymentGateway.name,
                  style: GlassTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Secure Payment',
                  style: GlassTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: GlassTheme.glassContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GlassTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subscription Plan',
                style: GlassTheme.bodyMedium,
              ),
              Text(
                widget.planCode,
                style: GlassTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount',
                style: GlassTheme.bodyMedium,
              ),
              Text(
                PaymentGatewayService.instance
                    .formatAmount(widget.amount, widget.currency),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: GlassTheme.colors.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return FutureBuilder<List<PaymentGateway>>(
      future: PaymentGatewayService.instance.getConfiguredPaymentGateways(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: GlassTheme.glassContainer,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: GlassTheme.glassContainer,
            child: Text(
              'Error loading payment methods: ${snapshot.error}',
              style: GlassTheme.bodyMedium.copyWith(
                color: GlassTheme.colors.errorColor,
              ),
            ),
          );
        }

        final activeGateways = snapshot.data ?? [];

        if (activeGateways.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: GlassTheme.glassContainer,
            child: Text(
              'No payment methods available',
              style: GlassTheme.bodyMedium,
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: GlassTheme.glassContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your preferred payment method:',
                style: GlassTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),

              // Build payment options from active gateways
              ...activeGateways
                  .map((gateway) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildModernPaymentOption(
                          gateway.code,
                          gateway.name,
                          _getIconForGateway(gateway.code),
                          _getColorForGateway(gateway.code),
                          subtitle: _getSubtitleForGateway(gateway.code),
                        ),
                      ))
                  .toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernPaymentOption(
    String value,
    String title,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GlassTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GlassTheme.bodySmall.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper methods to get appropriate icons, colors, and subtitles for different gateways
  IconData _getIconForGateway(String gatewayCode) {
    switch (gatewayCode.toLowerCase()) {
      case 'stripe':
        return Icons.credit_card;
      case 'payhere':
        return Icons.payment;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'manual':
        return Icons.receipt;
      default:
        return Icons.payment;
    }
  }

  Color _getColorForGateway(String gatewayCode) {
    switch (gatewayCode.toLowerCase()) {
      case 'stripe':
        return const Color(0xFF635BFF);
      case 'payhere':
        return const Color(0xFF00A651);
      case 'bank_transfer':
        return const Color(0xFF1976D2);
      case 'manual':
        return const Color(0xFF757575);
      default:
        return const Color(0xFF4285F4);
    }
  }

  String? _getSubtitleForGateway(String gatewayCode) {
    switch (gatewayCode.toLowerCase()) {
      case 'stripe':
        return 'Credit/Debit Cards';
      case 'payhere':
        return 'Local Cards & Banking';
      case 'bank_transfer':
        return 'Direct Bank Transfer';
      case 'manual':
        return 'Manual Verification';
      default:
        return null;
    }
  }

  Widget _buildCardPaymentForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: GlassTheme.glassContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security indicator
          Row(
            children: [
              Icon(Icons.security,
                  color: GlassTheme.colors.successColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Secure Card Payment',
                style: GlassTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your card information is encrypted and secure',
            style: GlassTheme.bodySmall,
          ),
          const SizedBox(height: 20),

          // Debit/Credit Card Selection
          _buildCardTypeSelection(),
          const SizedBox(height: 20),

          // Card Number
          _buildModernTextField(
            controller: _cardNumberController,
            label: 'Card Number',
            hint: '0000  0000  0000  0000',
            keyboardType: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return TextEditingValue(
                  text: _formatCardNumber(newValue.text),
                  selection: TextSelection.collapsed(
                    offset: _formatCardNumber(newValue.text).length,
                  ),
                );
              }),
            ],
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter card number';
              }
              if (!_isValidCardNumber(value!)) {
                return 'Please enter a valid card number';
              }
              return null;
            },
            suffixWidget: _cardNumberController.text.isNotEmpty
                ? _buildCardBrandIcon()
                : null,
          ),

          const SizedBox(height: 16),

          // Cardholder Name
          _buildModernTextField(
            controller: _holderNameController,
            label: 'Cardholder Name',
            hint: 'ADDISON NELSON',
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter cardholder name';
              }
              if (value!.length < 2) {
                return 'Please enter a valid name';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Expiry and CVV
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  controller: _expiryController,
                  label: 'Expiry Date',
                  hint: 'MM / YY',
                  keyboardType: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: _formatExpiry(newValue.text),
                        selection: TextSelection.collapsed(
                          offset: _formatExpiry(newValue.text).length,
                        ),
                      );
                    }),
                  ],
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Required';
                    }
                    if (!_isValidExpiry(value!)) {
                      return 'Invalid date';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildModernTextField(
                  controller: _cvvController,
                  label: 'CVV',
                  hint: '123',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Required';
                    }
                    if (value!.length < 3) {
                      return 'Invalid CVV';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Payment Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processCardPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Pay Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTypeSelection() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCardType = 'debit';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _selectedCardType == 'debit'
                    ? const Color(0xFF4285F4)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedCardType == 'debit'
                      ? const Color(0xFF4285F4)
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                'Debit Card',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _selectedCardType == 'debit'
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCardType = 'credit';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _selectedCardType == 'credit'
                    ? const Color(0xFF4285F4)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedCardType == 'credit'
                      ? const Color(0xFF4285F4)
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                'Credit Card',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _selectedCardType == 'credit'
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUPIPaymentForm(String upiApp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay with $upiApp',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You will be redirected to $upiApp to complete the payment.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _handleUPIPayment(upiApp),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Pay with $upiApp'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleUPIPayment(String upiApp) {
    // Handle UPI payment logic here
    print('Processing UPI payment with $upiApp');
    _confirmPayment();
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    Widget? suffixWidget,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GlassTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          obscureText: obscureText,
          textCapitalization: textCapitalization,
          style: GlassTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: suffixWidget,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: GlassTheme.colors.errorColor),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildCardBrandIcon() {
    String cardType = _getCardType(_cardNumberController.text);
    Color color = const Color(0xFF4285F4);

    if (cardType.toLowerCase().contains('visa')) {
      color = const Color(0xFF1A1F71);
    } else if (cardType.toLowerCase().contains('master')) {
      color = const Color(0xFFEB001B);
    }

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        cardType,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildManualPaymentInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: GlassTheme.glassContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: GlassTheme.colors.primaryBlue),
              const SizedBox(width: 12),
              Text(
                'Bank Transfer',
                style: GlassTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your payment via bank transfer using the details below',
            style: GlassTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _buildBankDetail('Bank Name', 'Commercial Bank'),
          const SizedBox(height: 12),
          _buildBankDetail('Account Number', '1234567890'),
          const SizedBox(height: 12),
          _buildBankDetail('Account Name', 'Your Company Ltd'),
          const SizedBox(height: 12),
          _buildBankDetail(
              'Amount',
              PaymentGatewayService.instance
                  .formatAmount(widget.amount, widget.currency)),
          const SizedBox(height: 12),
          _buildBankDetail('Reference', _paymentSession?.id ?? 'N/A'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GlassTheme.colors.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: GlassTheme.colors.infoColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Notes:',
                  style: GlassTheme.labelLarge.copyWith(
                    color: GlassTheme.colors.infoColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Please include the reference number in your transfer\n'
                  '• Payment processing may take 1-2 business days\n'
                  '• Keep your payment receipt for verification',
                  style: GlassTheme.bodySmall.copyWith(
                    color: GlassTheme.colors.infoColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processManualPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'I have completed the transfer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GlassTheme.bodyMedium,
        ),
        Row(
          children: [
            Text(
              value,
              style: GlassTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _copyToClipboard(value, label),
              child: Icon(
                Icons.copy,
                size: 16,
                color: GlassTheme.colors.primaryBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Card validation methods
  bool _isValidExpiry(String expiry) {
    if (expiry.length != 5) return false;
    final parts = expiry.split('/');
    if (parts.length != 2) return false;

    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);

    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;

    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;

    if (year < currentYear) return false;
    if (year == currentYear && month < currentMonth) return false;

    return true;
  }

  Future<void> _processManualPayment() async {
    if (_paymentSession == null) return;

    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      final result = await PaymentGatewayService.instance.confirmPayment(
        paymentId: _paymentSession!.id,
        transactionId: 'MANUAL_TXN_${DateTime.now().millisecondsSinceEpoch}',
        metadata: {
          'plan_code': widget.planCode,
          'user_id': widget.userId,
          'amount': widget.amount,
          'currency': widget.currency,
          'payment_method': 'manual',
        },
      );

      if (result) {
        setState(() {
          _isProcessing = false;
          _successMessage =
              'Payment verification submitted! Your subscription will be activated once payment is confirmed.';
        });

        // Navigate back with success result
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context)
              .pop({'success': true, 'paymentId': _paymentSession!.id});
        }
      } else {
        setState(() {
          _isProcessing = false;
          _error = 'Payment verification failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Payment verification failed: $e';
      });
    }
  }
}
