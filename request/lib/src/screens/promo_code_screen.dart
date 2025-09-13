import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../../services/subscription/response_limit_service.dart';
import '../theme/app_theme.dart';

class PromoCodeScreen extends StatefulWidget {
  const PromoCodeScreen({Key? key}) : super(key: key);

  @override
  _PromoCodeScreenState createState() => _PromoCodeScreenState();
}

class _PromoCodeScreenState extends State<PromoCodeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _promoCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isValidating = false;
  bool _isCodeValid = false;
  String? _validationMessage;
  Map<String, dynamic>? _promoDetails;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPromoCodeChanged(String value) {
    setState(() {
      _isCodeValid = false;
      _validationMessage = null;
      _promoDetails = null;
    });

    if (value.length >= 3) {
      _validatePromoCode(value);
    }
  }

  Future<void> _validatePromoCode(String code) async {
    if (_isValidating) return;

    setState(() {
      _isValidating = true;
    });

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/promo-codes/validate',
        data: {'code': code.trim().toUpperCase()},
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _isCodeValid = response.data!['valid'] == true &&
              response.data!['user_can_use'] == true;
          _validationMessage = response.data!['message'];
          _promoDetails = response.data!['promo'];
        });
      } else {
        setState(() {
          _isCodeValid = false;
          _validationMessage = response.error ?? 'Error validating promo code';
          _promoDetails = null;
        });
      }
    } catch (e) {
      setState(() {
        _isCodeValid = false;
        _validationMessage = 'Error validating promo code';
        _promoDetails = null;
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _redeemPromoCode() async {
    if (!_isCodeValid || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/promo-codes/redeem',
        data: {'code': _promoCodeController.text.trim().toUpperCase()},
      );

      if (response.isSuccess &&
          response.data != null &&
          response.data!['success'] == true) {
        // Show success message
        _showSuccessDialog(response.data!);

        // Refresh subscription status
        await ResponseLimitService.syncWithBackend();

        // Clear the form
        _promoCodeController.clear();
        setState(() {
          _isCodeValid = false;
          _validationMessage = null;
          _promoDetails = null;
        });
      } else {
        _showErrorSnackBar(response.data?['error'] ??
            response.error ??
            'Failed to redeem promo code');
      }
    } catch (e) {
      _showErrorSnackBar('Error redeeming promo code: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(Map<String, dynamic> response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.celebration, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text('Promo Code Redeemed!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                response['message'] ??
                    'Your promo code has been successfully applied!',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (response['benefit_plan'] != null) ...[
                Row(
                  children: [
                    Icon(Icons.verified,
                        color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Plan: ${response['benefit_plan']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (response['benefit_end_date'] != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule,
                        color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Valid until: ${_formatDate(response['benefit_end_date'])}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Great!'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildValidationIndicator() {
    if (_isValidating) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_promoCodeController.text.length < 3) {
      return const SizedBox.shrink();
    }

    return Icon(
      _isCodeValid ? Icons.check_circle : Icons.error,
      color: _isCodeValid ? Colors.green : Colors.red,
      size: 20,
    );
  }

  Widget _buildPromoDetails() {
    if (!_isCodeValid || _promoDetails == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _promoDetails!['name'] ?? 'Special Offer',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_promoDetails!['description'] != null) ...[
            Text(
              _promoDetails!['description'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_promoDetails!['benefit_duration_days'] != null) ...[
            Row(
              children: [
                Icon(Icons.timer, color: AppTheme.primaryColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_promoDetails!['benefit_duration_days']} days access',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (_promoDetails!['benefit_plan_code'] != null) ...[
            Row(
              children: [
                Icon(Icons.star, color: AppTheme.primaryColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_promoDetails!['benefit_plan_code']} Plan Benefits',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Enter Promo Code'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Header illustration and text
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.1),
                        AppTheme.primaryColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.redeem,
                        size: 80,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Have a Promo Code?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your promo code below to unlock special benefits and free access!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Promo code input
                TextField(
                  controller: _promoCodeController,
                  onChanged: _onPromoCodeChanged,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Promo Code',
                    hintText: 'Enter your promo code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildValidationIndicator(),
                    ),
                  ),
                ),

                // Validation message
                if (_validationMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _validationMessage!,
                    style: TextStyle(
                      color: _isCodeValid ? Colors.green : Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                // Promo details
                _buildPromoDetails(),

                const SizedBox(height: 32),

                // Redeem button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _isCodeValid && !_isLoading ? _redeemPromoCode : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Redeem Promo Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Help text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[600], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'How it works',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• Enter your promo code in the field above\n'
                        '• We\'ll validate it and show you the benefits\n'
                        '• Tap "Redeem" to apply it to your account\n'
                        '• Enjoy your free access and premium features!',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
