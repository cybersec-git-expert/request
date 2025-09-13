import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_gateway.dart';
import '../src/theme/glass_theme.dart';
import '../src/services/simple_subscription_service.dart';
import '../services/subscription/response_limit_service.dart';
import 'payment_success_screen.dart';

class CardPaymentScreen extends StatefulWidget {
  final PaymentGateway paymentGateway;
  final String planCode;
  final double amount;
  final String currency;
  final String userId;
  final String paymentId;

  const CardPaymentScreen({
    Key? key,
    required this.paymentGateway,
    required this.planCode,
    required this.amount,
    required this.currency,
    required this.userId,
    required this.paymentId,
  }) : super(key: key);

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _holderNameController = TextEditingController();

  String _selectedCardType = 'debit';
  bool _isProcessing = false;
  bool _saveCard = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _holderNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlassTheme.backgroundColor,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: _buildActionButtons(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and title
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back,
                        color: GlassTheme.colors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 56),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Debit / Credit\nCard',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.colors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card type tabs
                      _buildCardTypeTabs(),
                      const SizedBox(height: 25),

                      // Card number field
                      _buildCardNumberField(),
                      const SizedBox(height: 16),

                      // Expiry date and CVV row
                      Row(
                        children: [
                          Expanded(child: _buildExpiryField()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildCvvField()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cardholder name
                      _buildNameField(),
                      const SizedBox(height: 25),

                      // Save card checkbox
                      _buildSaveCardCheckbox(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTypeTabs() {
    // Glass pill container with two tabs and an accent underline for the selected tab
    return Container(
      decoration: GlassTheme.glassContainerSubtle,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCardType = 'debit'),
              child: SizedBox(
                height: 36,
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        'Debit Card',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedCardType == 'debit'
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedCardType == 'debit'
                              ? GlassTheme.colors.textPrimary
                              : GlassTheme.colors.textSecondary,
                        ),
                      ),
                    ),
                    // Accent underline indicator
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 2,
                        decoration: BoxDecoration(
                          color: _selectedCardType == 'debit'
                              ? GlassTheme.colors.primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCardType = 'credit'),
              child: SizedBox(
                height: 36,
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        'Credit Card',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedCardType == 'credit'
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedCardType == 'credit'
                              ? GlassTheme.colors.textPrimary
                              : GlassTheme.colors.textSecondary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 2,
                        decoration: BoxDecoration(
                          color: _selectedCardType == 'credit'
                              ? GlassTheme.colors.primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: GlassTheme.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cardNumberController,
                  decoration: InputDecoration(
                    hintText: '5534  2834  8857  5370',
                    hintStyle: TextStyle(
                      color: GlassTheme.colors.textTertiary,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: GlassTheme.colors.textPrimary,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _CardNumberFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter card number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5F00),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB001B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expiry date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: GlassTheme.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextFormField(
            controller: _expiryController,
            decoration: InputDecoration(
              hintText: 'Jan • 2023',
              hintStyle: TextStyle(
                color: GlassTheme.colors.textTertiary,
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              fontSize: 13,
              color: GlassTheme.colors.textPrimary,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _ExpiryDateFormatter(),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCvvField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CVV',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: GlassTheme.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextFormField(
            controller: _cvvController,
            decoration: InputDecoration(
              hintText: '• • •',
              hintStyle: TextStyle(
                color: GlassTheme.colors.textTertiary,
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              fontSize: 13,
              color: GlassTheme.colors.textPrimary,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: GlassTheme.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextFormField(
            controller: _holderNameController,
            decoration: InputDecoration(
              hintText: 'ADDISON NELSON',
              hintStyle: TextStyle(
                color: GlassTheme.colors.textTertiary,
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              fontSize: 13,
              color: GlassTheme.colors.textPrimary,
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter cardholder name';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveCardCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _saveCard,
          onChanged: (v) => setState(() => _saveCard = v ?? false),
          activeColor: GlassTheme.colors.textAccent,
          checkColor: Colors.white,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: Colors.transparent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Save card for future checkouts',
            style: TextStyle(
              fontSize: 13,
              color: GlassTheme.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: GlassTheme.secondaryButton,
            child: Text(
              'Cancel payment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: GlassTheme.colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: GlassTheme.primaryButton,
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }

  void _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      // TODO: Implement actual payment gateway processing
      // For now, simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // Simulate successful payment and confirm with backend
      final paymentConfirmed = await SimpleSubscriptionService.instance
          .confirmPayment(widget.paymentId);

      if (!paymentConfirmed) {
        throw Exception('Payment confirmation failed');
      }

      // Update local subscription status for Pro plan
      if (widget.planCode.toLowerCase() == 'pro') {
        await ResponseLimitService.setUnlimitedPlan(true);
      }

      if (mounted) {
        // Generate invoice number and date
        final invoiceNumber =
            'INV${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        final paymentDate =
            'Paid at ${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}';

        // Navigate to success screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              amount: widget.amount.toStringAsFixed(2),
              currency: widget.currency,
              invoiceNumber: invoiceNumber,
              paymentDate: paymentDate,
              planCode: widget.planCode,
              note:
                  'Please ensure payment is made by the due date to avoid any late fees.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: GlassTheme.colors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\s+\b|\b\s'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write('  ');
      }
      buffer.write(text[i]);
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (text.length >= 3) {
      final month = text.substring(0, 2);
      final year = text.substring(2);
      return newValue.copyWith(
        text: '$month • $year',
        selection: TextSelection.collapsed(offset: '$month • $year'.length),
      );
    }

    return newValue;
  }
}
