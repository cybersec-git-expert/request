import 'package:flutter/material.dart';
import '../../services/rest_auth_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final String? emailOrPhone;
  final bool? isNewUser;
  final bool? isEmail;
  final String? countryCode;
  final String? otpToken;

  const ProfileCompletionScreen({
    super.key,
    this.emailOrPhone,
    this.isNewUser,
    this.isEmail,
    this.countryCode,
    this.otpToken,
  });

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    print('🔧 [ProfileCompletion] Starting profile completion...');
    print('🔧 [ProfileCompletion] Form validation check...');

    if (!_formKey.currentState!.validate()) {
      print('🔧 [ProfileCompletion] Form validation failed');
      return;
    }
    print('🔧 [ProfileCompletion] Form validation passed');

    // Validate password confirmation
    if (_passwordController.text != _confirmPasswordController.text) {
      print('🔧 [ProfileCompletion] Password confirmation mismatch');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    print('🔧 [ProfileCompletion] Password confirmation matched');

    // Log form data
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = '$firstName $lastName';

    print('🔧 [ProfileCompletion] Form data:');
    print('🔧   firstName: "$firstName"');
    print('🔧   lastName: "$lastName"');
    print('🔧   displayName: "$displayName"');
    print('🔧   password length: ${password.length}');

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔧 [ProfileCompletion] Starting user registration...');

      // For new users, register directly instead of trying to authenticate first
      if (widget.isNewUser == true &&
          widget.emailOrPhone != null &&
          widget.emailOrPhone!.isNotEmpty) {
        print('🔧 [ProfileCompletion] Registering new user...');

        final result = await RestAuthService.instance.registerNewUser(
          emailOrPhone: widget.emailOrPhone!,
          firstName: firstName,
          lastName: lastName,
          displayName: displayName,
          password: password,
          isEmail: widget.isEmail ?? widget.emailOrPhone!.contains('@'),
          countryCode: widget.countryCode,
        );

        if (result.success) {
          print('🔧 [ProfileCompletion] User registered successfully');
          // After registration, navigate to membership onboarding to choose free/paid
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/onboarding/membership',
            (route) => false,
          );
          return;
        } else {
          print('🔧 [ProfileCompletion] Registration failed: ${result.error}');
          throw Exception(result.error ?? 'Failed to register user');
        }
      }

      // Fallback: try the old profile completion flow for existing users
      final result = await RestAuthService.instance.completeProfile(
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        password: password,
      );

      print('🔧 [ProfileCompletion] RestAuthService.completeProfile returned:');
      print('🔧   success: ${result.success}');
      print('🔧   error: ${result.error}');
      print('🔧   message: ${result.message}');
      print('🔧   user: ${result.user}');

      if (result.success) {
        print(
            '🔧 [ProfileCompletion] Profile completed successfully, navigating to home...');
        // Profile completed successfully
        // Existing user completing profile, send to membership screen too
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/onboarding/membership',
          (route) => false,
        );
      } else {
        print(
            '🔧 [ProfileCompletion] Profile completion failed: ${result.error}');
        throw Exception(result.error ?? 'Failed to complete profile');
      }
    } catch (e, stackTrace) {
      print('🔧 [ProfileCompletion] Exception caught: $e');
      print('🔧 [ProfileCompletion] Stack trace: $stackTrace');

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile completion failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Complete Profile'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppTheme.textPrimary,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Let\'s set up your profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'We need a few more details to complete your account',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // First Name field - filled glass, no border
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      prefixIcon: const Icon(Icons.person_outline),
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
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your first name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Last Name field - filled glass, no border
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      prefixIcon: const Icon(Icons.person),
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
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password field - filled glass, no border
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
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
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm Password field - filled glass, no border
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
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
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Complete button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _completeProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlassTheme.colors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Complete Profile',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Skip button
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                        );
                      },
                      child: Text(
                        'Skip for now',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),

                  // Extra padding at bottom for keyboard
                  SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
