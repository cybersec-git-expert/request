import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_gateway.dart';
import '../services/payment_gateway_service.dart';

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
  String _selectedPaymentMethod = 'card'; // 'card', 'bank', 'wallet'

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
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Preparing payment...',
            style: TextStyle(fontSize: 16),
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
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _createPaymentSession,
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
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _successMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text('Redirecting...'),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payment method header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Secure Payment',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Order summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subscription Plan',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        widget.planCode,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        PaymentGatewayService.instance
                            .formatAmount(widget.amount, widget.currency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Payment method selection
            _buildPaymentMethodSelection(),

            const SizedBox(height: 24),

            // Payment form based on selected method
            if (_selectedPaymentMethod == 'card') ...[
              _buildCardPaymentForm(),
            ] else ...[
              _buildManualPaymentInstructions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = 'card';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == 'card'
                          ? Colors.blue.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedPaymentMethod == 'card'
                            ? Colors.blue
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.credit_card,
                          color: _selectedPaymentMethod == 'card'
                              ? Colors.blue
                              : Colors.grey.shade600,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Credit/Debit Card',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _selectedPaymentMethod == 'card'
                                ? Colors.blue
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = 'manual';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == 'manual'
                          ? Colors.orange.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedPaymentMethod == 'manual'
                            ? Colors.orange
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance,
                          color: _selectedPaymentMethod == 'manual'
                              ? Colors.orange
                              : Colors.grey.shade600,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bank Transfer',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _selectedPaymentMethod == 'manual'
                                ? Colors.orange
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Secure Card Payment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your card information is encrypted and secure',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // Card Number
          TextFormField(
            controller: _cardNumberController,
            decoration: InputDecoration(
              labelText: 'Card Number',
              hintText: '1234 5678 9012 3456',
              prefixIcon: const Icon(Icons.credit_card),
              suffixIcon: _cardNumberController.text.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _getCardType(_cardNumberController.text),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
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
            onChanged: (value) {
              setState(() {});
            },
          ),

          const SizedBox(height: 16),

          // Cardholder Name
          TextFormField(
            controller: _holderNameController,
            decoration: InputDecoration(
              labelText: 'Cardholder Name',
              hintText: 'John Doe',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
            textCapitalization: TextCapitalization.words,
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

          // Expiry and CVV Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  decoration: InputDecoration(
                    labelText: 'Expiry Date',
                    hintText: 'MM/YY',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
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
                    if (value!.length != 5) {
                      return 'Invalid format';
                    }
                    // Basic validation for month (01-12)
                    final month = int.tryParse(value.substring(0, 2));
                    if (month == null || month < 1 || month > 12) {
                      return 'Invalid month';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  obscureText: true,
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

          // Security note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Demo Payment Mode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This is a demo payment system. All card details will be approved automatically.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Test Cards: 4242 4242 4242 4242 (Visa), 5555 5555 5555 4444 (Mastercard)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pay button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processCardPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Processing Payment...'),
                      ],
                    )
                  : Text(
                      'Pay ${PaymentGatewayService.instance.formatAmount(widget.amount, widget.currency)}',
                      style: const TextStyle(
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

  Widget _buildManualPaymentInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Instructions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Please complete the payment using the details below and then confirm your payment.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Payment details - get from gateway configuration if manual payment
        if (widget.paymentGateway.requiresManualVerification) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  PaymentGatewayService.instance.getPaymentInstructions(
                    widget.paymentGateway,
                    null, // Could fetch config here if needed
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Reference ID
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reference ID (Important)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _paymentSession!.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        _copyToClipboard(_paymentSession!.id, 'Reference ID'),
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy Reference ID',
                  ),
                ],
              ),
              const Text(
                'Please include this reference ID when making the payment.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Confirm payment button
        ElevatedButton(
          onPressed: _isProcessing ? null : _confirmPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isProcessing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Verifying Payment...'),
                  ],
                )
              : const Text(
                  'I have completed the payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
