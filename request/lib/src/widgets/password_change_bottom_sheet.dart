import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import '../services/auth_service.dart';

class PasswordChangeBottomSheet extends StatefulWidget {
  final bool isResetMode; // true for forgot password, false for change password
  final String? emailOrPhone;
  final bool? isEmail;

  const PasswordChangeBottomSheet({
    super.key,
    this.isResetMode = false,
    this.emailOrPhone,
    this.isEmail,
  });

  @override
  State<PasswordChangeBottomSheet> createState() =>
      _PasswordChangeBottomSheetState();
}

class _PasswordChangeBottomSheetState extends State<PasswordChangeBottomSheet> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    // Validate inputs
    if (!widget.isResetMode && _currentPasswordController.text.isEmpty) {
      _showError('Current password is required');
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      _showError('New password is required');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('New passwords do not match');
      return;
    }

    if (widget.isResetMode && _otpController.text.isEmpty) {
      _showError('OTP is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      late final result;

      if (widget.isResetMode) {
        // Reset password with OTP
        result = await AuthService.instance.resetPassword(
          emailOrPhone: widget.emailOrPhone!,
          otp: _otpController.text,
          newPassword: _newPasswordController.text,
          isEmail: widget.isEmail!,
        );
      } else {
        // Change password with current password
        result = await AuthService.instance.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
      }

      if (result.isSuccess) {
        if (mounted) {
          Navigator.pop(context);
          _showSuccess(result.message ?? 'Password updated successfully');

          if (widget.isResetMode) {
            // Navigate to login for reset mode
            Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false);
          }
        }
      } else {
        _showError(result.error ?? 'Failed to update password');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GlassTheme.glassContainer,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
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
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Text(
                widget.isResetMode ? 'Reset Password' : 'Change Password',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Current Password (only for change mode)
              if (!widget.isResetMode) ...[
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: 'Current Password',
                  isVisible: _isCurrentPasswordVisible,
                  onToggleVisibility: () => setState(() =>
                      _isCurrentPasswordVisible = !_isCurrentPasswordVisible),
                ),
                const SizedBox(height: 16),
              ],

              // OTP Field (only for reset mode)
              if (widget.isResetMode) ...[
                _buildTextField(
                  controller: _otpController,
                  label: 'OTP Code',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 16),
              ],

              // New Password
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'New Password',
                isVisible: _isNewPasswordVisible,
                onToggleVisibility: () => setState(
                    () => _isNewPasswordVisible = !_isNewPasswordVisible),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                isVisible: _isConfirmPasswordVisible,
                onToggleVisibility: () => setState(() =>
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(
                            color:
                                GlassTheme.colors.primaryBlue.withOpacity(0.5)),
                        backgroundColor: Colors.white.withOpacity(0.9),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Text(widget.isResetMode ? 'Reset' : 'Update'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GlassTheme.colors.primaryBlue.withOpacity(0.3),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: GlassTheme.colors.primaryBlue,
            fontWeight: FontWeight.w500,
          ),
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GlassTheme.colors.primaryBlue.withOpacity(0.3),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: GlassTheme.colors.primaryBlue,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(16),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility_off : Icons.visibility,
              color: GlassTheme.colors.primaryBlue,
            ),
            onPressed: onToggleVisibility,
          ),
        ),
      ),
    );
  }
}

// Helper function to show the bottom sheet
void showPasswordChangeBottomSheet({
  required BuildContext context,
  bool isResetMode = false,
  String? emailOrPhone,
  bool? isEmail,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PasswordChangeBottomSheet(
      isResetMode: isResetMode,
      emailOrPhone: emailOrPhone,
      isEmail: isEmail,
    ),
  );
}
