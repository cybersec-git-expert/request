import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../services/content_service.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  final String? emailOrPhone;
  final bool? isNewUser;
  final bool? isEmail;
  final String? countryCode;
  final String? otpToken;

  const TermsAndConditionsScreen({
    super.key,
    this.emailOrPhone,
    this.isNewUser,
    this.isEmail,
    this.countryCode,
    this.otpToken,
  });

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen>
    with TickerProviderStateMixin {
  final ContentService _contentService = ContentService.instance;
  bool _loading = true;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  String? _termsContent;
  String? _privacyContent;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadContent();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _slideController.forward();
    });
  }

  Future<void> _loadContent() async {
    try {
      final pages = await _contentService.getPages(status: 'published');

      // Find Terms and Conditions content
      final termsPage = pages
          .where((page) =>
              page.slug.toLowerCase().contains('terms') ||
              page.slug.toLowerCase().contains('legal') ||
              page.title.toLowerCase().contains('terms'))
          .firstOrNull;

      // Find Privacy Policy content
      final privacyPage = pages
          .where((page) =>
              page.slug.toLowerCase().contains('privacy') ||
              page.title.toLowerCase().contains('privacy'))
          .firstOrNull;

      if (mounted) {
        setState(() {
          _termsContent = termsPage?.content ?? _getDefaultTermsContent();
          _privacyContent = privacyPage?.content ?? _getDefaultPrivacyContent();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _termsContent = _getDefaultTermsContent();
          _privacyContent = _getDefaultPrivacyContent();
          _loading = false;
        });
      }
    }
  }

  String _getDefaultTermsContent() {
    return '''
# Terms and Conditions

## 1. Acceptance of Terms
By using our application, you agree to be bound by these Terms and Conditions.

## 2. Use License
Permission is granted to temporarily use the application for personal, non-commercial transitory viewing only.

## 3. User Accounts
Users are responsible for maintaining the confidentiality of their account and password.

## 4. Privacy Policy
Your privacy is important to us. Please review our Privacy Policy, which also governs your use of the Service.

## 5. Modifications
We reserve the right to modify these terms at any time. Continued use constitutes acceptance of modified terms.

## 6. Contact Information
If you have any questions about these Terms and Conditions, please contact our support team.
''';
  }

  String _getDefaultPrivacyContent() {
    return '''
# Privacy Policy

## Information We Collect
We collect information you provide directly to us, such as when you create an account or contact us.

## How We Use Your Information
We use the information we collect to provide, maintain, and improve our services.

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

  String _getPreviewText(String content) {
    // Remove HTML tags and markdown headers, get first few lines
    String cleanContent = content
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Remove markdown headers
        .replaceAll(RegExp(r'\*\*([^*]*)\*\*'), r'$1') // Remove bold markdown
        .replaceAll(RegExp(r'\*([^*]*)\*'), r'$1') // Remove italic markdown
        .replaceAll(RegExp(r'\n\s*\n'), '\n') // Remove extra newlines
        .trim();

    final lines = cleanContent
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(3)
        .join(' ');

    if (lines.length > 150) {
      return '${lines.substring(0, 150)}...';
    }
    return lines;
  }

  String _getFullCleanText(String content) {
    // Clean the full content for display (remove HTML tags but keep formatting)
    return content
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Remove markdown headers
        .replaceAll(RegExp(r'\*\*([^*]*)\*\*'), r'$1') // Remove bold markdown
        .replaceAll(RegExp(r'\*([^*]*)\*'), r'$1') // Remove italic markdown
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n') // Normalize paragraph breaks
        .trim();
  }

  void _viewFullContent(String title, String content) {
    // Use a simple dialog to show the full content with proper Glass theme styling
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
                  child: Text(
                    _getFullCleanText(content), // Show cleaned full content
                    style: TextStyle(
                      color: GlassTheme.colors.textPrimary,
                      fontSize: 16,
                      height: 1.6,
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

  void _proceedToProfile() {
    if (_termsAccepted && _privacyAccepted) {
      Navigator.pushReplacementNamed(
        context,
        '/profile',
        arguments: {
          'isNewUser': widget.isNewUser,
          'emailOrPhone': widget.emailOrPhone,
          'isEmail': widget.isEmail,
          'countryCode': widget.countryCode,
          'otpToken': widget.otpToken,
        },
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: GlassTheme.colors.textPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: GlassTheme.backgroundGradient,
        ),
      ),
      body: GlassTheme.backgroundContainer(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome message card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: GlassTheme.colors.glassBackground.first,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: GlassTheme.colors.glassBorder,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Terms & Privacy Agreement',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: GlassTheme.colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please review and accept our terms and privacy policy to continue',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: GlassTheme.colors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Content Cards
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  // Terms and Conditions Card
                                  _buildPolicyCard(
                                    title: 'Terms and Conditions',
                                    content: _termsContent ?? '',
                                    isAccepted: _termsAccepted,
                                    onAcceptedChanged: (value) {
                                      setState(() {
                                        _termsAccepted = value ?? false;
                                      });
                                    },
                                    onViewFull: () => _viewFullContent(
                                      'Terms and Conditions',
                                      _termsContent ?? '',
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Privacy Policy Card
                                  _buildPolicyCard(
                                    title: 'Privacy Policy',
                                    content: _privacyContent ?? '',
                                    isAccepted: _privacyAccepted,
                                    onAcceptedChanged: (value) {
                                      setState(() {
                                        _privacyAccepted = value ?? false;
                                      });
                                    },
                                    onViewFull: () => _viewFullContent(
                                      'Privacy Policy',
                                      _privacyContent ?? '',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Continue Button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _termsAccepted && _privacyAccepted
                                    ? [
                                        GlassTheme.colors.primaryBlue,
                                        GlassTheme.colors.primaryBlue
                                            .withOpacity(0.8),
                                      ]
                                    : [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _termsAccepted && _privacyAccepted
                                  ? [
                                      BoxShadow(
                                        color: GlassTheme.colors.primaryBlue
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _termsAccepted && _privacyAccepted
                                    ? _proceedToProfile
                                    : null,
                                child: Center(
                                  child: Text(
                                    'Continue',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPolicyCard({
    required String title,
    required String content,
    required bool isAccepted,
    required ValueChanged<bool?> onAcceptedChanged,
    required VoidCallback onViewFull,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GlassTheme.colors.glassBackground.first,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted
              ? GlassTheme.colors.primaryBlue.withOpacity(0.3)
              : GlassTheme.colors.glassBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and View Full Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: GlassTheme.colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: onViewFull,
                child: Text(
                  'View Full',
                  style: TextStyle(
                    color: GlassTheme.colors.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Preview Content
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GlassTheme.colors.glassBackgroundSubtle.first
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: GlassTheme.colors.glassBorder.withOpacity(0.5),
              ),
            ),
            child: Text(
              _getPreviewText(content),
              style: TextStyle(
                color: GlassTheme.colors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Acceptance Checkbox
          GestureDetector(
            onTap: () => onAcceptedChanged(!isAccepted),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isAccepted
                        ? GlassTheme.colors.primaryBlue
                        : Colors.transparent,
                    border: Border.all(
                      color: isAccepted
                          ? GlassTheme.colors.primaryBlue
                          : GlassTheme.colors.glassBorder,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: isAccepted
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I have read and agree to the $title',
                    style: TextStyle(
                      color: GlassTheme.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
