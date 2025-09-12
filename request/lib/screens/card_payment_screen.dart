import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_gateway.dart';
import '../src/theme/glass_theme.dart';

class CardPaymentScreen extends StatefulWidget {
  final PaymentGateway paymentGateway;
  final String planCode;
  final double amount;
  final String currency;
  final String userId;

  const CardPaymentScreen({
    Key? key,
    required this.paymentGateway,
    required this.planCode,
    required this.amount,
    required this.currency,
    required this.userId,
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

            // Title
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Debit / Credit\nCard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 35),

                      // Action buttons
                      _buildActionButtons(),
                      const SizedBox(height: 30),
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
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedCardType = 'debit'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _selectedCardType == 'debit'
                        ? GlassTheme.colors.primaryBlue
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                'Debit Card',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _selectedCardType == 'debit'
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: _selectedCardType == 'debit'
                      ? GlassTheme.colors.textPrimary
                      : GlassTheme.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedCardType = 'credit'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _selectedCardType == 'credit'
                        ? GlassTheme.colors.primaryBlue
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                'Credit Card',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _selectedCardType == 'credit'
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: _selectedCardType == 'credit'
                      ? GlassTheme.colors.textPrimary
                      : GlassTheme.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
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
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 14,
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
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 20,
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: _expiryController,
            decoration: InputDecoration(
              hintText: 'Jan • 2023',
              hintStyle: TextStyle(
                color: GlassTheme.colors.textTertiary,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              fontSize: 14,
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: _cvvController,
            decoration: InputDecoration(
              hintText: '• • •',
              hintStyle: TextStyle(
                color: GlassTheme.colors.textTertiary,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              fontSize: 14,
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: _holderNameController,
            decoration: InputDecoration(
              hintText: 'ADDISON NELSON',
              hintStyle: TextStyle(
                color: GlassTheme.colors.textTertiary,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              fontSize: 14,
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
        GestureDetector(
          onTap: () => setState(() => _saveCard = !_saveCard),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _saveCard ? GlassTheme.colors.primaryBlue : Colors.white,
              border: Border.all(
                color: _saveCard
                    ? GlassTheme.colors.primaryBlue
                    : Colors.grey.shade300,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _saveCard
                ? const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Save card for future checkouts',
          style: TextStyle(
            fontSize: 14,
            color: GlassTheme.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel payment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: GlassTheme.colors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.colors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
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
                : Text(
                    'Pay Now',
                    style: const TextStyle(
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
      // TODO: Implement actual payment processing
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processed successfully'),
            backgroundColor: GlassTheme.colors.successColor,
          ),
        );
        Navigator.pop(context);
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
