import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../src/theme/glass_theme.dart';
import '../../src/services/simple_subscription_service.dart';
import '../../services/payment_gateway_service.dart';
import '../../models/payment_gateway.dart';
import '../../screens/payment_processing_screen.dart';
import '../../widgets/payment_method_selection_widget.dart';
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
    return Container(
      decoration: GlassTheme.backgroundGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                GlassTheme.isDarkMode ? Brightness.light : Brightness.dark,
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: GlassTheme.colors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Choose Your Plan',
            style: GlassTheme.titleMedium,
          ),
          centerTitle: true,
        ),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      GlassTheme.colors.primaryBlue),
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
                            // Current status header
                            if (currentStatus != null) ...[
                              GlassTheme.glassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user,
                                          color: GlassTheme.colors.primaryBlue,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Current Plan: ${currentStatus!.planName}',
                                          style: GlassTheme.titleSmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (currentStatus!.responsesLimit !=
                                        null) ...[
                                      Text(
                                        'Responses Used: ${currentStatus!.responsesUsed}/${currentStatus!.responsesLimit}',
                                        style: GlassTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: currentStatus!.responsesUsed /
                                            (currentStatus!.responsesLimit ??
                                                1),
                                        backgroundColor:
                                            GlassTheme.colors.glassBorder,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          currentStatus!.canRespond
                                              ? GlassTheme.colors.successColor
                                              : GlassTheme.colors.errorColor,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'Unlimited Responses',
                                        style: GlassTheme.bodyMedium.copyWith(
                                          color: GlassTheme.colors.successColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Plans section
                            Text(
                              'Available Plans',
                              style: GlassTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),

                            // Plans list
                            ...plans.map((plan) => _buildPlanCard(plan)),

                            const SizedBox(
                                height: 100), // Extra space for button
                          ],
                        ),
                      ),
                    ),

                    // Fixed bottom button
                    if (selectedPlanId.isNotEmpty &&
                        selectedPlanId != currentStatus?.planCode)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            height: 50, // Smaller button height
                            child: ElevatedButton(
                              onPressed: _subscribeToPlan,
                              style: GlassTheme.primaryButton.copyWith(
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              child: Text(
                                'Subscribe to ${plans.firstWhere((p) => p.code == selectedPlanId).name}',
                                style: const TextStyle(
                                  fontSize: 16,
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
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = selectedPlanId == plan.code;
    final isCurrent = currentStatus?.planCode == plan.code;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassTheme.glassCard(
        child: InkWell(
          onTap: () {
            if (!isCurrent) {
              setState(() {
                selectedPlanId = plan.code;
              });
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isSelected || isCurrent
                  ? Border.all(
                      color: isCurrent
                          ? GlassTheme.colors.successColor
                          : GlassTheme.colors.primaryBlue,
                      width: 2,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  plan.name,
                                  style: GlassTheme.titleSmall,
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: GlassTheme.colors.successColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'CURRENT',
                                      style: const TextStyle(
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
                                style: GlassTheme.bodyMedium,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${plan.currency} ${plan.price.toStringAsFixed(0)}',
                            style: GlassTheme.titleMedium.copyWith(
                              color: GlassTheme.colors.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            plan.price == 0 ? 'Free' : '/month',
                            style: GlassTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Response limit info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GlassTheme.colors.glassBorder.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          plan.responseLimit == -1
                              ? Icons.all_inclusive
                              : Icons.reply,
                          color: GlassTheme.colors.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          plan.responseLimit == -1
                              ? 'Unlimited responses per month'
                              : '${plan.responseLimit} responses per month',
                          style: GlassTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Features list
                  if (plan.features.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...plan.features.map((feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: GlassTheme.colors.successColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: GlassTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],

                  // Selection indicator
                  if (isSelected && !isCurrent) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: GlassTheme.colors.primaryBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Selected - Tap Subscribe below',
                        textAlign: TextAlign.center,
                        style: GlassTheme.bodyMedium.copyWith(
                          color: GlassTheme.colors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

      // Show payment method selection
      print('🚀 [Payment Flow] Showing payment method selection...');
      final selectedGateway = await showModalBottomSheet<PaymentGateway>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => PaymentMethodSelectionWidget(
            planCode: selectedPlan.code,
            amount: selectedPlan.price,
            currency: selectedPlan.currency,
            onPaymentMethodSelected: (gateway) {
              print('🚀 [Payment Flow] Gateway selected: ${gateway.name}');
              Navigator.of(context).pop(gateway);
            },
            onCancel: () {
              print('🚀 [Payment Flow] Payment selection cancelled');
              Navigator.of(context).pop();
            },
          ),
        ),
      );

      print(
          '🚀 [Payment Flow] Gateway selection result: ${selectedGateway?.name ?? "null"}');

      if (selectedGateway == null) {
        // User cancelled payment method selection
        print('🚀 [Payment Flow] User cancelled payment selection');
        return;
      }

      // Navigate to payment processing screen
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
