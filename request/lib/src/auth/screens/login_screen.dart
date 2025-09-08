import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../services/rest_auth_service.dart';
import '../../services/content_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final String countryCode;
  final String? phoneCode;

  const LoginScreen({
    super.key,
    required this.countryCode,
    this.phoneCode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isPhoneLogin = true;
  bool _isLoading = false;
  String completePhoneNumber = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isEmail = !_isPhoneLogin;
      final rawInput = isEmail
          ? _emailController.text.trim()
          : (completePhoneNumber.isNotEmpty
              ? completePhoneNumber
              : _phoneController.text.trim());
      // Normalize phone by removing spaces so the API receives a clean number
      final emailOrPhone =
          isEmail ? rawInput : rawInput.replaceAll(RegExp(r'\s+'), '');

      // Check if user exists to determine flow
      final exists =
          await RestAuthService.instance.checkUserExists(emailOrPhone);

      if (exists) {
        // Existing user -> go to password screen
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/password',
          arguments: {
            'emailOrPhone': emailOrPhone,
            'isNewUser': false,
            'isEmail': isEmail,
            'countryCode': widget.countryCode,
          },
        );
        return;
      }

      // New user -> proceed with OTP
      final otpResult = await RestAuthService.instance.sendOTP(
        emailOrPhone: emailOrPhone,
        isEmail: isEmail,
        countryCode: widget.countryCode,
      );

      if (!otpResult.success) {
        throw Exception(otpResult.error ?? 'Failed to send OTP');
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/otp',
        arguments: {
          'emailOrPhone': emailOrPhone,
          'isEmail': isEmail,
          'isNewUser': true,
          'countryCode': widget.countryCode,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showContentDialog(String title, String contentType) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: BoxDecoration(
            color: GlassTheme.colors.glassBackground.first,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: GlassTheme.colors.glassBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: GlassTheme.colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: GlassTheme.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: FutureBuilder<String>(
                    future: _loadContent(contentType),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text(
                          'Error loading content',
                          style: TextStyle(
                            color: GlassTheme.colors.textSecondary,
                          ),
                        );
                      } else {
                        return Text(
                          _cleanHtmlContent(snapshot.data ?? ''),
                          style: TextStyle(
                            color: GlassTheme.colors.textPrimary,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _loadContent(String contentType) async {
    try {
      final content = await ContentService.instance.getPageBySlug(contentType);
      return content?.content ?? _getDefaultContent(contentType);
    } catch (e) {
      return _getDefaultContent(contentType);
    }
  }

  String _getDefaultContent(String contentType) {
    if (contentType == 'terms') {
      return '''
Terms of Service

Effective Date: August 25, 2025

Welcome to Request! These Terms of Service ("Terms") constitute a legally binding agreement between you and Request Technologies ("Company", "we", "our", or "us") regarding your use of our mobile application and services.

## Acceptance of Terms
By accessing or using our services, you agree to be bound by these Terms.

## Use of Services
You may use our services for lawful purposes only. You agree not to use the services for any prohibited activities.

## User Accounts
You are responsible for maintaining the confidentiality of your account credentials.

## Privacy
Your privacy is important to us. Please review our Privacy Policy to understand how we collect and use your information.

## Termination
We may terminate your access to our services at any time for violation of these Terms.

## Contact Us
If you have questions about these Terms, please contact us.
''';
    } else {
      return '''
Privacy Policy

Effective Date: August 25, 2025

Our Commitment to Your Privacy
Welcome to Request! This Privacy Policy explains how Request Technologies ("Company", "we", "our", or "us") collects, uses, and protects your personal information.

## Information We Collect
We collect information you provide directly to us, such as when you create an account or contact us.

## How We Use Your Information
We use your information to provide and improve our services, communicate with you, and ensure security.

## Information Sharing
We do not sell, trade, or otherwise transfer your personal information to third parties without your consent.

## Data Security
We implement appropriate security measures to protect your personal information.

## Your Rights
You have the right to access, update, or delete your personal information.

## Contact Us
If you have questions about this Privacy Policy, please contact us.
''';
    }
  }

  String _cleanHtmlContent(String content) {
    return content
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Remove markdown headers
        .replaceAll(RegExp(r'\*\*([^*]*)\*\*'), r'$1') // Remove bold markdown
        .replaceAll(RegExp(r'\*([^*]*)\*'), r'$1') // Remove italic markdown
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n') // Normalize paragraph breaks
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        48,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // Back button
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back,
                            color: AppTheme.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Title
                        const Text(
                          'Welcome Back!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Phone/Email toggle
                        Container(
                          decoration: BoxDecoration(
                            color: GlassTheme.colors.glassBackground.first
                                .withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _isPhoneLogin = true);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _isPhoneLogin
                                          ? GlassTheme.colors.primaryBlue
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Phone',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _isPhoneLogin
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _isPhoneLogin = false);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: !_isPhoneLogin
                                          ? GlassTheme.colors.primaryBlue
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Email',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !_isPhoneLogin
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Input field form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _isPhoneLogin
                                    ? ((widget.phoneCode != null &&
                                            widget.phoneCode!.isNotEmpty)
                                        // LOCKED country code: simple text field with fixed prefix
                                        ? TextFormField(
                                            key: const ValueKey('phone_locked'),
                                            controller: _phoneController,
                                            decoration: InputDecoration(
                                              labelText: 'Phone Number',
                                              prefixIcon:
                                                  const Icon(Icons.phone),
                                              prefixText:
                                                  '${widget.phoneCode} ',
                                            ),
                                            keyboardType: TextInputType.phone,
                                            onChanged: (value) {
                                              final num = value.trim();
                                              completePhoneNumber =
                                                  '${widget.phoneCode}${num.isNotEmpty ? ' ' : ''}$num';
                                            },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Please enter a valid phone number';
                                              }
                                              return null;
                                            },
                                          )
                                        // Fallback: allow country selection (overlay blocks picker)
                                        : Stack(
                                            children: [
                                              IntlPhoneField(
                                                key: const ValueKey('phone'),
                                                controller: _phoneController,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Phone Number',
                                                  prefixIcon: Icon(Icons.phone),
                                                ),
                                                initialCountryCode: widget
                                                        .countryCode.isNotEmpty
                                                    ? widget.countryCode
                                                    : 'US',
                                                enabled: true,
                                                showCountryFlag: true,
                                                showDropdownIcon: false,
                                                disableLengthCheck: false,
                                                onChanged: (phone) {
                                                  completePhoneNumber =
                                                      phone.completeNumber;
                                                },
                                                validator: (phone) {
                                                  if (phone == null ||
                                                      phone.number.isEmpty) {
                                                    return 'Please enter a valid phone number';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              // Block taps on country selector
                                              const Positioned(
                                                left: 0,
                                                top: 0,
                                                bottom: 0,
                                                width:
                                                    100, // cover flag+code region
                                                child: IgnorePointer(
                                                  child: SizedBox.expand(),
                                                ),
                                              ),
                                            ],
                                          ))
                                    : TextFormField(
                                        key: const ValueKey('email'),
                                        controller: _emailController,
                                        decoration: const InputDecoration(
                                          labelText: 'Email Address',
                                          prefixIcon: Icon(Icons.email),
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your email address';
                                          }
                                          if (!RegExp(
                                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                              .hasMatch(value.trim())) {
                                            return 'Please enter a valid email address';
                                          }
                                          return null;
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlassTheme.colors.primaryBlue,
                              foregroundColor: Colors.white,
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
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Terms text
                        Text.rich(
                          TextSpan(
                            text: 'By continuing, you agree to our ',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Terms of Service',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showContentDialog(
                                      'Terms of Service', 'terms'),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showContentDialog(
                                      'Privacy Policy', 'privacy'),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
