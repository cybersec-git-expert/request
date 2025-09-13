import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../src/theme/glass_theme.dart';
import '../../src/services/simple_subscription_service.dart';
import '../../services/payment_gateway_service.dart';
import '../../models/payment_gateway.dart';
import '../../screens/payment_processing_screen.dart';
import '../../src/services/enhanced_user_service.dart';

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
      final statusResult = await service.getSubscriptionStatus();
      final plansResult = await service.getAvailablePlans();

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
          'Pro+ Plans',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
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
                          // Pro+ intro card with modern icons
                          _buildModernProIntroCard(),
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

                          // Plans list with modern cards
                          ...plans.map((plan) => _buildModernPlanCard(plan)),

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
                                  'Subscribe To ${_displayName(plans.firstWhere((p) => p.code == selectedPlanId).name)}',
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

  // Modern Pro+ intro card matching the design
  Widget _buildModernProIntroCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Business verification feature
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C7B7F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.business_center,
                  color: Color(0xFF6C7B7F),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Verify your business to add prices on listings without limits.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C7B7F),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Instant notifications feature
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C7B7F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Color(0xFF6C7B7F),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Get notified instantly when new requests arrive in your business categories.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C7B7F),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modern plan card matching the design
  Widget _buildModernPlanCard(SubscriptionPlan plan) {
    final isSelected = selectedPlanId == plan.code;
    final isCurrent = currentStatus?.planCode == plan.code;
    final isFree = plan.price == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              // Plan header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (plan.description?.isNotEmpty == true)
                        Text(
                          plan.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6C7B7F),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${plan.currency} ${plan.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        isFree ? 'Free' : '/month',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C7B7F),
                        ),
                      ),
                    ],
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
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    plan.responseLimit == -1
                        ? 'Unlimited responses per month'
                        : '${plan.responseLimit} responses per month',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6C7B7F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Selection indicator
              if (isSelected && !isCurrent) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Selected - Tap Subscribe below',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF007AFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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

      // Get the selected plan details
      final selectedPlan = plans.firstWhere(
        (plan) => plan.code == selectedPlanId,
        orElse: () => SubscriptionPlan(
          id: '',
          code: selectedPlanId,
          name: selectedPlanId,
          price: 0,
          currency: 'LKR',
          responseLimit: 3,
          features: [],
          isActive: true,
        ),
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
