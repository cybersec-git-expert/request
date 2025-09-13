import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../src/theme/glass_theme.dart';
import '../../src/services/simple_subscription_service.dart';
import '../../services/payment_gateway_service.dart';
import '../../models/payment_gateway.dart';
import '../../screens/payment_processing_screen.dart';
import '../../src/services/enhanced_user_service.dart';

// Feature item helper class for subscription features
class _FeatureItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class SimpleSubscriptionPage extends StatefulWidget {
  const SimpleSubscriptionPage({Key? key}) : super(key: key);

  @override
  State<SimpleSubscriptionPage> createState() => _SimpleSubscriptionPageState();
}

class _SimpleSubscriptionPageState extends State<SimpleSubscriptionPage> {
  String selectedPlanId = '';
  bool isLoading = true;
  List<SubscriptionPlan> plans = [];
  SimpleSubscriptionStatus? currentStatus;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final service = SimpleSubscriptionService.instance;

      // Load plans first (this usually works)
      final plansResult = await service.getAvailablePlans();

      // Try to load subscription status (this might fail)
      SimpleSubscriptionStatus? statusResult;
      try {
        statusResult = await service.getSubscriptionStatus();
      } catch (e) {
        print('Warning: Failed to load subscription status: $e');
        // Continue without status - we can still show plans
        statusResult = null;
      }

      setState(() {
        currentStatus = statusResult;
        plans = plansResult;
        // Default to Pro plan if available, otherwise use current status or empty
        if (plans.isNotEmpty) {
          final proPlan =
              plans.where((p) => p.code.toLowerCase() == 'pro').firstOrNull;
          selectedPlanId = proPlan?.code ?? currentStatus?.planCode ?? '';
        } else {
          selectedPlanId = currentStatus?.planCode ?? '';
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading subscription data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safe plan selection with proper null checks
    SubscriptionPlan? selectedPlan;

    if (plans.isNotEmpty) {
      if (selectedPlanId.isNotEmpty) {
        selectedPlan =
            plans.where((p) => p.code == selectedPlanId).firstOrNull ??
                plans.where((p) => p.price == 0).firstOrNull ??
                plans.first;
      } else {
        selectedPlan =
            plans.where((p) => p.price == 0).firstOrNull ?? plans.first;
      }
    }

    // Return loading state if no plans available yet
    if (selectedPlan == null) {
      return Scaffold(
        backgroundColor: GlassTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: GlassTheme.backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Subscription Plans',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B5563)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: GlassTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: GlassTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: null, // Remove the title from app bar
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B5563)),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        children: [
                          // Top icon - simple and clean
                          Icon(
                            Icons.auto_awesome,
                            size: 60,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 24),

                          // Main heading
                          Text(
                            'Try Pro+ Features for free',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Features list with checkmarks
                          _buildFeaturesList(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // Bottom plan cards
                  Container(
                    padding: const EdgeInsets.all(24),
                    color: GlassTheme.backgroundColor,
                    child: Column(
                      children: [
                        // Vertical plan cards
                        ...plans.map((plan) =>
                            _buildVerticalPlanCard(plan, selectedPlan)),
                        const SizedBox(height: 24),

                        // Subscribe button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _subscribeToPlan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlassTheme.colors.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Dynamic intro card that updates based on selected plan
  Widget _buildDynamicIntroCard(SubscriptionPlan plan) {
    final isFree = plan.price == 0;
    final planFeatures = [
      if (isFree) ...[
        _FeatureItem(
          icon: Icons.reply_outlined,
          color: const Color(0xFF6C7B7F),
          title: '${plan.responseLimit} responses per month',
          subtitle: 'Perfect for small businesses starting out',
        ),
        _FeatureItem(
          icon: Icons.notifications_outlined,
          color: const Color(0xFF6C7B7F),
          title: 'Basic notifications',
          subtitle: 'Get notified about new requests',
        ),
      ] else ...[
        _FeatureItem(
          icon: Icons.all_inclusive,
          color: const Color(0xFFFF3B30), // Red/Pink
          title: 'Unlimited responses',
          subtitle: 'Respond to as many requests as you want',
        ),
        _FeatureItem(
          icon: Icons.verified,
          color: const Color(0xFF007AFF), // Blue
          title: 'Premium support',
          subtitle: 'Priority customer support and assistance',
        ),
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Removed shadow for cleaner modern look
      ),
      padding: const EdgeInsets.all(20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          key: ValueKey(plan.code),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top icon for Pro features
            if (!isFree) ...[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.15),
                      Colors.purple.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              isFree ? 'Free Plan Features' : 'Pro+ Features',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFree
                  ? 'Start with essential features'
                  : 'Unlock the most powerful business tools',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6C7B7F),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ...planFeatures.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Checkmark icon like in reference
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          feature.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            // Additional verification features section for Pro plan
            if (!isFree) ...[
              const SizedBox(height: 32),

              // Business verification features with checkmark style
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Unlimited pricing',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Instant notifications',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Compact horizontal plan card
  Widget _buildHorizontalPlanCard(SubscriptionPlan plan) {
    final isSelected = selectedPlanId == plan.code;
    final isCurrent = currentStatus?.planCode == plan.code;
    final isFree = plan.price == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Keep box white always
        borderRadius: BorderRadius.circular(
            16), // Increased border radius for more rounded look
        border: isSelected
            ? Border.all(color: const Color(0xFF007AFF), width: 2)
            : Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 1), // Light gray border for unselected cards
      ),
      child: InkWell(
        onTap: () {
          if (!isCurrent) {
            setState(() {
              selectedPlanId = plan.code;
            });
          }
        },
        borderRadius:
            BorderRadius.circular(16), // Match container border radius
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top section with current badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon or empty space
                  Icon(
                    plan.responseLimit == -1 ? Icons.bolt : Icons.star_border,
                    color: plan.responseLimit == -1
                        ? const Color(0xFF007AFF)
                        : const Color(0xFF6C7B7F),
                    size: 20,
                  ),
                  if (isSelected && !isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Pro Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Free 2 months',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Plan name and details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(plan.name) +
                        (isFree
                            ? ''
                            : ' ${plan.responseLimit == -1 ? "monthly" : "yearly"}'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.currency} ${plan.price.toStringAsFixed(2)} ${isFree ? "Free" : "per ${plan.responseLimit == -1 ? "month" : "year"}"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plan.description?.isNotEmpty == true
                        ? plan.description!
                        : plan.responseLimit == -1
                            ? 'Perfect for individual with daily pro search needs'
                            : 'Most of the user choose yearly subscription',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6C7B7F),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName(String name) {
    final lower = name.trim().toLowerCase();
    if (lower == 'pro') return 'Pro+';
    return name;
  }

  String _getSelectedPlanName() {
    if (selectedPlanId.isEmpty || plans.isEmpty) return 'Plan';
    final plan = plans.where((p) => p.code == selectedPlanId).firstOrNull;
    return _displayName(plan?.name ?? 'Plan');
  }

  Future<void> _subscribeToPlan() async {
    if (selectedPlanId.isEmpty) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    GlassTheme.colors.primaryBlue),
              ),
              const SizedBox(width: 16),
              const Text('Updating subscription...'),
            ],
          ),
        ),
      );

      final service = SimpleSubscriptionService.instance;
      final result = await service.subscribeToPlan(selectedPlanId);

      Navigator.pop(context); // Close loading dialog

      if (result.success) {
        // Reload data to reflect changes
        await _loadSubscriptionData();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.requiresPayment
                  ? 'Redirecting to payment...'
                  : 'Successfully subscribed!',
              style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: GlassTheme.colors.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // If payment is required, handle payment flow
        if (result.requiresPayment) {
          print('🚀 [Payment Flow] Payment required - starting payment flow');
          print('🚀 [Payment Flow] Payment ID: ${result.paymentId}');
          // INTEGRATION COMPLETE: Navigate to payment gateway system
          await _handlePaymentFlow(result);
        }
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? 'Failed to subscribe. Please try again.',
              style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: GlassTheme.colors.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      print('Error subscribing: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'An error occurred. Please try again.',
            style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: GlassTheme.colors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Handle payment flow for paid subscriptions
  Future<void> _handlePaymentFlow(SubscriptionResult result) async {
    try {
      print('🚀 [Payment Flow] Starting payment flow...');

      // Get the selected plan details with safe fallback
      final selectedPlan =
          plans.where((plan) => plan.code == selectedPlanId).firstOrNull ??
              SubscriptionPlan(
                id: '',
                code: selectedPlanId,
                name: selectedPlanId,
                price: 0,
                currency: 'LKR',
                responseLimit: 3,
                features: [],
                isActive: true,
              );

      print(
          '🚀 [Payment Flow] Selected plan: ${selectedPlan.code} - ${selectedPlan.price}');

      // Get current user ID
      String userId;
      try {
        final user = await EnhancedUserService.instance.getCurrentUser();
        userId = user?.id ?? 'anonymous';
        print('🚀 [Payment Flow] User ID: $userId');
      } catch (e) {
        print('🚀 [Payment Flow] Error getting user: $e');
        userId = 'anonymous';
      }

      // Get available payment gateways
      print('🚀 [Payment Flow] Fetching payment gateways...');
      final gateways =
          await PaymentGatewayService.instance.getConfiguredPaymentGateways();

      print('🚀 [Payment Flow] Found ${gateways.length} gateways');

      if (gateways.isEmpty) {
        print(
            '🚀 [Payment Flow] No gateways available, using fallback direct navigation');

        // Fallback: Create a simple demo gateway for testing
        final demoGateway = PaymentGateway(
          id: 999,
          code: 'demo',
          name: 'Demo Payment Gateway',
          description: 'Demo payment gateway for testing',
          configurationFields: {},
          configured: true,
          isPrimary: true,
        );

        // Navigate directly to payment processing screen with demo gateway
        print(
            '🚀 [Payment Flow] Navigating to payment processing with demo gateway...');
        final paymentResult =
            await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) => PaymentProcessingScreen(
              paymentGateway: demoGateway,
              planCode: selectedPlan.code,
              amount: selectedPlan.price,
              currency: selectedPlan.currency,
              userId: userId,
            ),
          ),
        );

        print('🚀 [Payment Flow] Demo payment result: $paymentResult');

        if (paymentResult != null && paymentResult['success'] == true) {
          // Payment successful, reload subscription data
          await _loadSubscriptionData();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment successful! Your subscription has been activated.',
                style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: GlassTheme.colors.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Skip payment method selection modal and go directly to payment processing screen
      print('🚀 [Payment Flow] Going directly to payment processing...');

      // Get the first available payment gateway or create a default one
      final gatewayResponse =
          await PaymentGatewayService.instance.getConfiguredPaymentGateways();
      PaymentGateway selectedGateway;

      if (gatewayResponse.isNotEmpty) {
        // Use the first available gateway or primary gateway
        selectedGateway = gatewayResponse.firstWhere(
          (gateway) => gateway.isPrimary,
          orElse: () => gatewayResponse.first,
        );
      } else {
        // Create a default gateway if none available
        selectedGateway = PaymentGateway(
          id: 1,
          name: 'PayHere',
          code: 'payhere',
          description: 'PayHere Payment Gateway',
          configurationFields: {},
          configured: true,
          isPrimary: true,
        );
      }

      print('🚀 [Payment Flow] Using gateway: ${selectedGateway.name}');

      // Navigate directly to payment processing screen
      print('🚀 [Payment Flow] Navigating to payment processing screen...');
      final paymentResult =
          await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => PaymentProcessingScreen(
            paymentGateway: selectedGateway,
            planCode: selectedPlan.code,
            amount: selectedPlan.price,
            currency: selectedPlan.currency,
            userId: userId,
          ),
        ),
      );

      print('🚀 [Payment Flow] Payment result: $paymentResult');

      if (paymentResult != null && paymentResult['success'] == true) {
        // Payment successful, reload subscription data
        await _loadSubscriptionData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment successful! Your subscription has been activated.',
              style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: GlassTheme.colors.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Payment was not successful or user cancelled
        print('🚀 [Payment Flow] Payment not completed or cancelled');
        // Do NOT reload subscription data - keep current state
      }
    } catch (e) {
      print('🚀 [Payment Flow] ERROR: $e');
      print('🚀 [Payment Flow] Stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment setup failed. Please try again.',
            style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: GlassTheme.colors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Build features list with checkmarks
  Widget _buildFeaturesList() {
    final features = [
      'Unlimited responses',
      'Premium support',
      'Unlimited pricing',
      'Instant notifications',
    ];

    return Column(
      children: features
          .map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // Build vertical plan card like in reference
  Widget _buildVerticalPlanCard(
      SubscriptionPlan plan, SubscriptionPlan? selectedPlan) {
    final isSelected = plan.code == selectedPlan?.code;
    final isFree = plan.price == 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlanId = plan.code;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isFree ? 'Free Plan' : '${plan.name} Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (!isFree && isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Best value',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isFree
                  ? 'LKR 0.00 Free'
                  : 'LKR ${plan.price.toStringAsFixed(2)} per month',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
