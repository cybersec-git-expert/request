import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import '../services/auth_service.dart';

class SimplePasswordChangeBottomSheet extends StatefulWidget {
  final String emailOrPhone;
  final String otp;
  final bool isEmail;

  const SimplePasswordChangeBottomSheet({
    super.key,
    required this.emailOrPhone,
    required this.otp,
    required this.isEmail,
  });

  @override
  State<SimplePasswordChangeBottomSheet> createState() =>
      _SimplePasswordChangeBottomSheetState();
}

class _SimplePasswordChangeBottomSheetState
    extends State<SimplePasswordChangeBottomSheet> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    // Validate inputs
    if (_newPasswordController.text.isEmpty) {
      _showError('New password is required');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.instance.resetPassword(
        emailOrPhone: widget.emailOrPhone,
        otp: widget.otp,
        newPassword: _newPasswordController.text,
        isEmail: widget.isEmail,
      );

      if (mounted) {
        if (result.isSuccess) {
          Navigator.pop(context); // Close the bottom sheet
          _showSuccess(result.message ??
              'Password reset successfully! You can now login with your new password.');

          // Navigate back to password screen after successful password reset
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              // Pop the OTP screen and go back to password screen
              Navigator.pop(context);
            }
          });
        } else {
          _showError(result.error ?? 'Failed to reset password');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to reset password: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: GlassTheme.glassContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Text(
            'Reset Password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: GlassTheme.colors.primaryBlue,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Enter your new password',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // New Password
          TextField(
            controller: _newPasswordController,
            obscureText: !_isNewPasswordVisible,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87, // Dark text for visibility
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'New Password',
              hintText: 'Enter new password',
              labelStyle: TextStyle(
                color: GlassTheme.colors.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
              hintStyle: TextStyle(
                color: Colors.grey[500],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: GlassTheme.colors.primaryBlue),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: GlassTheme.colors.primaryBlue.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: GlassTheme.colors.primaryBlue, width: 2),
              ),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: GlassTheme.colors.primaryBlue,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
                icon: Icon(
                  _isNewPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.6),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Confirm Password
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87, // Dark text for visibility
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Confirm new password',
              labelStyle: TextStyle(
                color: GlassTheme.colors.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
              hintStyle: TextStyle(
                color: Colors.grey[500],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: GlassTheme.colors.primaryBlue),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: GlassTheme.colors.primaryBlue.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: GlassTheme.colors.primaryBlue, width: 2),
              ),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: GlassTheme.colors.primaryBlue,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
                icon: Icon(
                  _isConfirmPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.6),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor:
                        GlassTheme.colors.primaryBlue, // Visible color
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87, // Dark text for visibility
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.colors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
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
                            SizedBox(width: 8),
                            Text('Resetting...'),
                          ],
                        )
                      : const Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

void showSimplePasswordChangeBottomSheet({
  required BuildContext context,
  required String emailOrPhone,
  required String otp,
  required bool isEmail,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SimplePasswordChangeBottomSheet(
      emailOrPhone: emailOrPhone,
      otp: otp,
      isEmail: isEmail,
    ),
  );
}
