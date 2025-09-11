import 'package:flutter/material.dart';
import 'dart:async';
// New service imports for REST API
import 'src/services/service_manager.dart';
import 'src/auth/screens/splash_screen.dart';
import 'src/auth/screens/welcome_screen.dart';
import 'src/auth/screens/login_screen.dart';
import 'src/auth/screens/otp_screen.dart';
import 'src/auth/screens/password_screen.dart';
import 'src/auth/screens/profile_completion_screen.dart';
import 'src/navigation/main_navigation_screen.dart';
import 'src/screens/pricing/price_comparison_screen.dart';
import 'src/screens/pricing/business_product_dashboard.dart';
import 'src/screens/profile/business_profile_edit_screen.dart';
import 'src/screens/settings/payment_methods_settings_screen.dart';
import 'src/screens/unified_request_response/unified_response_edit_screen.dart';
import 'src/screens/business_verification_screen.dart';
import 'src/screens/business_registration_screen.dart';
import 'src/screens/delivery_verification_screen.dart';
import 'src/screens/verification_status_screen.dart';
import 'src/screens/modern_menu_screen.dart';
import 'src/screens/content_page_screen.dart';
import 'src/screens/legal_page_screen.dart';
import 'src/screens/privacy_policy_screen.dart';
import 'src/screens/terms_conditions_screen.dart';
import 'src/theme/app_theme.dart';
import 'src/screens/chat/chat_conversations_screen.dart';
import 'src/screens/notification_screen.dart';
import 'src/services/notification_service.dart';
import 'src/services/notification_center.dart';
import 'src/screens/simple_subscription_screen.dart';
import 'src/screens/role_registration_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling for better crash resilience
  FlutterError.onError = (FlutterErrorDetails details) {
    // In release, avoid red error screen; just log
    FlutterError.dumpErrorToConsole(details);
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            SizedBox(height: 8),
            Text('Something went wrong',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    try {
      // Initialize REST API services
      await ServiceManager.instance.initialize();

      // Initialize local notifications
      await NotificationService.instance.initialize(
        onSelect: (payload) {
          if (payload != null && payload.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              navigatorKey.currentState?.pushNamed(payload);
            });
          }
        },
      );

      // Ask for notification permission when needed
      await NotificationService.instance.ensurePermission();

      // Start foreground polling (badges + local toasts)
      await NotificationCenter.instance.start();

      debugPrint('✅ REST API services initialized successfully');
    } catch (e, s) {
      debugPrint('❌ Service initialization failed: $e\n$s');
    }

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Request Marketplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      // Import for subscription screen
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => const SplashScreen(),
            );
          case '/dev-notification-test':
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Notification Test')),
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await NotificationService.instance.showLocalNotification(
                        title: 'Hello from Request',
                        body: 'This is a test notification',
                        payload: '/notifications',
                      );
                    },
                    child: const Text('Show test notification'),
                  ),
                ),
              ),
            );
          case '/welcome':
            return MaterialPageRoute(
              builder: (context) => const WelcomeScreen(),
            );
          case '/login':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => LoginScreen(
                countryCode: args?['countryCode'] ?? 'LK',
                phoneCode: args?['phoneCode'],
              ),
            );
          case '/otp':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => OTPScreen(
                emailOrPhone: args?['emailOrPhone'] ?? '',
                isEmail: args?['isEmail'] ?? false,
                isNewUser: args?['isNewUser'] ?? false,
                countryCode: args?['countryCode'] ?? 'LK',
                purpose: args?['purpose'],
              ),
            );
          case '/password':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => PasswordScreen(
                isNewUser: args?['isNewUser'] ?? false,
                emailOrPhone: args?['emailOrPhone'] ?? '',
                isEmail: args?['isEmail'] ?? false,
                countryCode: args?['countryCode'],
              ),
            );
          case '/profile':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => ProfileCompletionScreen(
                emailOrPhone: args?['emailOrPhone'],
                isNewUser: args?['isNewUser'],
                isEmail: args?['isEmail'],
                countryCode: args?['countryCode'],
                otpToken: args?['otpToken'],
              ),
            );
          case '/business-verification':
            return MaterialPageRoute(
              builder: (context) => const BusinessVerificationScreen(),
            );
          case '/business-registration':
            return MaterialPageRoute(
              builder: (context) => const BusinessRegistrationScreen(),
            );
          case '/delivery-verification':
            return MaterialPageRoute(
              builder: (context) => const DeliveryVerificationScreen(),
            );
          case '/verification-status':
            return MaterialPageRoute(
              builder: (context) => const VerificationStatusScreen(),
            );
          // Commented out - Role Management screen bypassed in favor of Role Selection
          // case '/role-management':
          //   return MaterialPageRoute(
          //     builder: (context) => const RoleManagementScreen(),
          //   );
          case '/main-dashboard':
          case '/home':
            final args = settings.arguments as Map<String, dynamic>?;
            final initialIndex = args?['initialIndex'] as int? ?? 0;
            return MaterialPageRoute(
              builder: (context) => MainNavigationScreen(
                initialIndex: initialIndex,
              ),
            );
          case '/price':
            // Redirect to price comparison screen
            return MaterialPageRoute(
              builder: (context) => const PriceComparisonScreen(),
            );
          case '/pricing-search':
            return MaterialPageRoute(
              builder: (context) => const PriceComparisonScreen(),
            );
          case '/pricing-comparison':
            return MaterialPageRoute(
              builder: (context) => const PriceComparisonScreen(),
            );
          case '/messages':
            return MaterialPageRoute(
              builder: (context) => const ChatConversationsScreen(),
            );
          case '/notifications':
            return MaterialPageRoute(
              builder: (context) => const NotificationScreen(),
            );
          case '/simple-subscription':
            return MaterialPageRoute(
              builder: (context) => const SimpleSubscriptionScreen(),
            );
          case '/role-registration':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => RoleRegistrationScreen(
                selectedRole: args?['selectedRole'] ?? 'business',
                professionalArea: args?['professionalArea'],
              ),
            );
          case '/business-pricing':
            return MaterialPageRoute(
              builder: (context) => const BusinessProductDashboard(),
            );
          case '/business-profile':
            return MaterialPageRoute(
              builder: (context) => const BusinessProfileEditScreen(),
            );
          case '/settings/payment-methods':
            return MaterialPageRoute(
              builder: (context) => const PaymentMethodsSettingsScreen(),
            );
          case '/edit-response':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => UnifiedResponseEditScreen(
                response: args?['response'],
                request: args?['request'],
              ),
            );
          case '/menu':
            return MaterialPageRoute(
              builder: (context) => const ModernMenuScreen(),
            );
          case '/content-page':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => ContentPageScreen(
                slug: args?['slug'] ?? '',
                title: args?['title'],
              ),
            );
          // Placeholder routes for menu items
          case '/saved':
          case '/marketplace':
          case '/memories':
          case '/groups':
          case '/reels':
          case '/find-friends':
          case '/feeds':
          case '/events':
          case '/avatars':
          case '/birthdays':
          case '/finds':
          case '/games':
          case '/messenger-kids':
          case '/help':
          case '/settings':
          case '/meta-apps':
          case '/search':
            return MaterialPageRoute(
              builder: (context) => _buildPlaceholderScreen(settings.name!),
            );
          case '/privacy-policy':
            return MaterialPageRoute(
              builder: (context) => const PrivacyPolicyScreen(),
            );
          case '/terms-conditions':
            return MaterialPageRoute(
              builder: (context) => const TermsConditionsScreen(),
            );
          case '/legal':
            return MaterialPageRoute(
              builder: (context) => const LegalPageScreen(
                pageSlug: 'legal',
                pageTitle: 'Legal',
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const WelcomeScreen(),
            );
        }
      },
    );
  }

  Widget _buildPlaceholderScreen(String routeName) {
    final title =
        routeName.replaceAll('/', '').replaceAll('-', ' ').toUpperCase();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              '$title - Coming Soon!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This feature is under development',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
