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
        selectedPlanId = currentStatus?.planCode ?? '';
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
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F9FA),
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
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
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Get ${_displayName(selectedPlan.name)}',
            key: ValueKey(selectedPlan.code),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dynamic intro card based on selected plan
                          _buildDynamicIntroCard(selectedPlan),
                          const SizedBox(height: 24),

                          // Available Plans section
                          const Text(
                            'Available Plans',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Horizontal plans list with modern cards
                          SizedBox(
                            height: 200, // Fixed height for horizontal scroll
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: plans.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  width: 280, // Fixed width for each card
                                  margin: EdgeInsets.only(
                                    right: index == plans.length - 1 ? 0 : 16,
                                  ),
                                  child: _buildHorizontalPlanCard(plans[index]),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 100), // Extra space for button
                        ],
                      ),
                    ),
                  ),

                  // Fixed bottom button
                  if (selectedPlanId.isNotEmpty &&
                      selectedPlanId != currentStatus?.planCode)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      color: const Color(0xFFF8F9FA),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _subscribeToPlan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.download, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Subscribe To ${_getSelectedPlanName()}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
          icon: Icons.business_center,
          color: const Color(0xFF007AFF),
          title: 'Business verification enabled',
          subtitle: 'Add prices on listings without limits',
        ),
        _FeatureItem(
          icon: Icons.notifications_active,
          color: const Color(0xFF007AFF),
          title: 'Instant notifications',
          subtitle: 'For new requests in your business categories',
        ),
        _FeatureItem(
          icon: Icons.all_inclusive,
          color: const Color(0xFF007AFF),
          title: 'Unlimited responses',
          subtitle: 'Respond to as many requests as you want',
        ),
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          key: ValueKey(plan.code),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFree ? 'Free Plan Features' : 'Pro+ Features',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFree
                  ? 'Start with essential features'
                  : 'Unlock the most powerful business tools',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6C7B7F),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ...planFeatures.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: feature.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          feature.icon,
                          color: feature.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feature.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: feature.color,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feature.subtitle,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6C7B7F),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // Horizontal plan card for better mobile experience
  Widget _buildHorizontalPlanCard(SubscriptionPlan plan) {
    final isSelected = selectedPlanId == plan.code;
    final isCurrent = currentStatus?.planCode == plan.code;
    final isFree = plan.price == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: const Color(0xFF007AFF), width: 2)
            : Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (!isCurrent) {
            setState(() {
              selectedPlanId = plan.code;
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Plan header with price
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Text(
                              _displayName(plan.name),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${plan.currency} ${plan.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            isFree ? 'Free' : '/month',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6C7B7F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (plan.description?.isNotEmpty == true)
                    Text(
                      plan.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6C7B7F),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Response limit info with icon
              Row(
                children: [
                  Icon(
                    plan.responseLimit == -1
                        ? Icons.all_inclusive
                        : Icons.reply,
                    color: const Color(0xFF6C7B7F),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.responseLimit == -1
                          ? 'Unlimited responses per month'
                          : '${plan.responseLimit} responses per month',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6C7B7F),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}
