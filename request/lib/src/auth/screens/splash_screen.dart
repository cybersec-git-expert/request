import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_client.dart';
import '../../services/rest_support_services.dart' show CountryService;
import '../../services/rest_auth_service.dart';
import '../../widgets/custom_logo.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _controller.forward();

    // After animation, decide where to go based on auth + last tab
    _startNavigation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    // Ensure splash shows for ~2s while we do work
    final splashDelay = Future.delayed(const Duration(milliseconds: 2000));

    // Prefer a local token check to avoid network dependency on cold start
    final authFuture = ApiClient.instance.isAuthenticated();
    final prefsFuture = SharedPreferences.getInstance();

    final results = await Future.wait([authFuture, prefsFuture, splashDelay]);
    if (!mounted || _navigated) return;

    final bool isAuthed = results[0] as bool;
    final SharedPreferences prefs = results[1] as SharedPreferences;

    bool goHome = false;
    // If we have a token, validate by loading profile so we keep the SAME account
    if (isAuthed) {
      final profile = await RestAuthService.instance.getUserProfile();
      if (profile.success && RestAuthService.instance.currentUser != null) {
        goHome = true;
        // Prefer user's country, otherwise ensure default LK
        final user = RestAuthService.instance.currentUser!;
        await _ensureDefaultCountryIfMissing(prefs,
            preferCode: user.countryCode);
      } else {
        // Token invalid: clear it to avoid ghost sessions
        await RestAuthService.instance.logout();
      }
    } else {
      // Not authed; ensure default country for smoother onboarding
      await _ensureDefaultCountryIfMissing(prefs);
    }

    _navigated = true;
    if (goHome) {
      // Go to home/main with last tab restored
      Navigator.of(context).pushReplacementNamed(
        '/home',
        // Cold start should always land on Home tab (index 0)
        arguments: {'initialIndex': 0},
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/welcome');
    }
  }

  Future<void> _ensureDefaultCountryIfMissing(SharedPreferences prefs,
      {String? preferCode}) async {
    const key = 'selected_country_code';
    var code = prefs.getString(key);
    if (code == null || code.isEmpty) {
      // Prefer user's country if provided; otherwise default to LK
      final toSet =
          (preferCode != null && preferCode.isNotEmpty) ? preferCode : 'LK';
      final phone = toSet.toUpperCase() == 'LK'
          ? '+94'
          : (prefs.getString('selected_country_phone_code') ?? '+94');
      await prefs.setString('selected_country_code', toSet);
      await prefs.setString('selected_country_phone_code', phone);
      final cs = CountryService.instance;
      cs.countryCode = toSet;
      cs.phoneCode = phone;
      cs.currency = toSet.toUpperCase() == 'LK' ? 'LKR' : cs.currency;
      if (cs.countryName.isEmpty && toSet.toUpperCase() == 'LK') {
        cs.countryName = 'Sri Lanka';
      }
    } else {
      // Sync runtime cache from persisted values if needed
      final cs = CountryService.instance;
      if (cs.countryCode == null) {
        cs.countryCode = code;
        cs.phoneCode =
            prefs.getString('selected_country_phone_code') ?? cs.phoneCode;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with animation
                      CustomLogo.splash(),
                      const SizedBox(height: 24),
                      // App name
                      Text(
                        'Request',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tagline
                      Text(
                        'Get what you need',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).pushNamed('/api-test');
          },
          backgroundColor: GlassTheme.colors.primaryBlue,
          foregroundColor: Colors.white,
          child: const Icon(Icons.api),
          tooltip: 'Test API',
        ),
      ),
    );
  }
}
