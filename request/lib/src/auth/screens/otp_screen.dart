import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/rest_auth_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';
import '../../widgets/simple_password_change_bottom_sheet.dart';

class OTPScreen extends StatefulWidget {
  final String emailOrPhone;
  final bool isEmail;
  final bool isNewUser;
  final String countryCode;
  final String? purpose;

  const OTPScreen({
    super.key,
    required this.emailOrPhone,
    required this.isEmail,
    required this.isNewUser,
    required this.countryCode,
    this.purpose,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  String _otpToken = '';

  @override
  void initState() {
    super.initState();
    _sendOTP();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() => _isResending = true);
    try {
      final result = await RestAuthService.instance.sendOTP(
        emailOrPhone: widget.emailOrPhone,
        isEmail: widget.isEmail,
        countryCode: widget.countryCode,
      );
      if (result.success) {
        _otpToken = result.otpToken ?? '';
        _showMessage('OTP sent', isError: false);
      } else {
        _showMessage(result.error ?? 'Failed to send OTP');
      }
    } catch (e) {
      _showMessage('Error sending OTP: $e');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showMessage('Please enter complete 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Check if this is a password reset flow
      if (widget.purpose == 'password_reset') {
        // For password reset, show dialog to enter new password
        _showPasswordResetDialog(otp);
      } else {
        // Normal OTP verification flow
        final result = await RestAuthService.instance.verifyOTP(
          emailOrPhone: widget.emailOrPhone,
          otp: otp,
          otpToken: _otpToken,
        );
        if (result.success) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/profile',
            arguments: {
              'isNewUser': widget.isNewUser,
              'emailOrPhone': widget.emailOrPhone,
              'isEmail': widget.isEmail,
              'countryCode': widget.countryCode,
              'otpToken': _otpToken,
            },
          );
        } else {
          _showMessage(result.error ?? 'Invalid OTP');
        }
      }
    } catch (e) {
      _showMessage('Error verifying OTP: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showPasswordResetDialog(String otp) {
    setState(() => _isLoading = false); // Reset loading state

    // Use the glass-themed bottom sheet for password reset
    showSimplePasswordChangeBottomSheet(
      context: context,
      emailOrPhone: widget.emailOrPhone,
      otp: otp,
      isEmail: widget.isEmail,
    );
  }

  void _onOTPChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (index == 5 && value.isNotEmpty) {
      final otp = _controllers.map((c) => c.text).join();
      if (otp.length == 6) _verifyOTP();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text('Verify ${widget.isEmail ? 'Email' : 'Phone'}'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppTheme.textPrimary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Enter Verification Code',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a 6-digit code to ${widget.emailOrPhone}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: GlassTheme.colors.glassBackground.first,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _onOTPChanged(index, value),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.colors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: _isResending ? null : _sendOTP,
                  child: _isResending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Resending...',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        )
                      : Text(
                          'Resend Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: GlassTheme.colors.primaryBlue,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
