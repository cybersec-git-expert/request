import 'package:flutter/material.dart';
import '../../services/rest_auth_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';

class PasswordScreen extends StatefulWidget {
  final bool isNewUser;
  final String emailOrPhone;
  final bool isEmail;
  final String? countryCode;
  final String? userId;

  const PasswordScreen({
    super.key,
    required this.isNewUser,
    required this.emailOrPhone,
    this.isEmail = false,
    this.countryCode,
    this.userId,
  });

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen>
    with TickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_passwordController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    print("=== PASSWORD SCREEN LOGIN START ===");
    print("Email/Phone: ${widget.emailOrPhone}");
    print("Password length: ${_passwordController.text.trim().length}");

    try {
      final result = await RestAuthService.instance.login(
        email: widget.emailOrPhone,
        password: _passwordController.text.trim(),
      );

      print("Login result: ${result.success ? 'SUCCESS' : 'FAILED'}");

      if (result.success) {
        print("Navigating to home screen...");
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        }
      } else {
        print("Login failed: ${result.error}");
        final err = (result.error ?? '').toLowerCase();
        if (err.contains('user_not_found') || err.contains('not found')) {
          // Seamless fallback: guide user to OTP to register/verify
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Account not found. Continue with verification to create one.'),
              backgroundColor: Colors.orange.shade600,
            ),
          );
          Navigator.pushNamed(
            context,
            '/otp',
            arguments: {
              'emailOrPhone': widget.emailOrPhone,
              'isNewUser': true,
              'isEmail': widget.isEmail,
              'countryCode': widget.countryCode ?? '',
            },
          );
          return;
        }
        _showErrorSnackBar(
            result.error ?? 'Login failed. Please check your credentials.');
      }
    } catch (e) {
      print("Exception caught in password screen: $e");
      String errorMessage = 'Login failed. Please try again.';

      if (e.toString().contains('invalid_credentials')) {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.toString().contains('user_not_found')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Account not found. Continue with verification to create one.'),
            backgroundColor: Colors.orange.shade600,
          ),
        );
        Navigator.pushNamed(
          context,
          '/otp',
          arguments: {
            'emailOrPhone': widget.emailOrPhone,
            'isNewUser': true,
            'isEmail': widget.isEmail,
            'countryCode': widget.countryCode ?? '',
          },
        );
        return;
      } else if (e.toString().contains('too_many_requests')) {
        errorMessage = 'Too many failed attempts. Please try again later.';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleForgotPassword() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Navigate to the existing OTP screen with password reset purpose
      Navigator.pushNamed(
        context,
        '/otp',
        arguments: {
          'emailOrPhone': widget.emailOrPhone,
          'isEmail': widget.isEmail,
          'isNewUser': false,
          'countryCode': widget.countryCode ?? '+94',
          'purpose':
              'password_reset', // This tells OTP screen it's for password reset
        },
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
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

  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header
                Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your password for\n${widget.emailOrPhone}',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 48),

                // Password Input - filled glass background, no borders
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon:
                        Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
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
                        horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _handleLogin(),
                ),

                const SizedBox(height: 12),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: GlassTheme.colors.primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassTheme.colors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
