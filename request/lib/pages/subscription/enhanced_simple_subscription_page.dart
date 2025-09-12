/*
 * PAYMENT GATEWAY INTEGRATION GUIDE
 * 
 * This file demonstrates how to enhance the existing SimpleSubscriptionPage
 * to support payment gateway functionality. The integration replaces the TODO
 * comment for payment handling with a complete payment gateway workflow.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../src/theme/glass_theme.dart';
import '../src/services/simple_subscription_service.dart';
import '../services/payment_integrated_subscription_handler.dart';
import '../src/services/auth_service.dart';

class EnhancedSimpleSubscriptionPage extends StatefulWidget {
  const EnhancedSimpleSubscriptionPage({Key? key}) : super(key: key);

  @override
  State<EnhancedSimpleSubscriptionPage> createState() =>
      _EnhancedSimpleSubscriptionPageState();
}

class _EnhancedSimpleSubscriptionPageState
    extends State<EnhancedSimpleSubscriptionPage> {
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
          title: Text(
            'Choose Your Plan',
            style: GlassTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Payment gateway status widget
                      const PaymentGatewayStatusWidget(),

                      const SizedBox(height: 16),

                      // Current status section
                      if (currentStatus != null) ...[
                        _buildCurrentStatusCard(),
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

                      const SizedBox(height: 24),

                      // Subscribe button - ENHANCED WITH PAYMENT GATEWAY INTEGRATION
                      if (selectedPlanId.isNotEmpty &&
                          selectedPlanId != currentStatus?.planCode)
                        _buildEnhancedSubscribeButton(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GlassTheme.colors.glassBackground.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GlassTheme.colors.glassBorder.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                currentStatus!.isUnlimited ? Icons.star : Icons.person,
                color: currentStatus!.isUnlimited
                    ? GlassTheme.colors.accentGold
                    : GlassTheme.colors.primaryBlue,
              ),
              const SizedBox(width: 12),
              Text(
                'Current Plan: ${currentStatus!.planName ?? currentStatus!.planCode}',
                style: GlassTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Usage progress
          if (!currentStatus!.isUnlimited &&
              currentStatus!.responsesLimit != null) ...[
            LinearProgressIndicator(
              value: (currentStatus!.responsesUsed ?? 0) /
                  (currentStatus!.responsesLimit ?? 1),
              backgroundColor: GlassTheme.colors.glassBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                currentStatus!.canRespond
                    ? GlassTheme.colors.successColor
                    : GlassTheme.colors.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${currentStatus!.responsesUsed ?? 0} of ${currentStatus!.responsesLimit ?? 0} responses used',
              style: GlassTheme.bodySmall,
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
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = selectedPlanId == plan.code;
    final isCurrent = currentStatus?.planCode == plan.code;

    return GestureDetector(
      onTap: isCurrent
          ? null
          : () {
              setState(() {
                selectedPlanId = plan.code;
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: GlassTheme.colors.glassBackground.withOpacity(
            isSelected ? 0.95 : 0.8,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? GlassTheme.colors.primaryBlue
                : GlassTheme.colors.glassBorder.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                            style: GlassTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: GlassTheme.colors.primaryBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Current',
                                style: GlassTheme.bodySmall.copyWith(
                                  color: Colors.white,
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
                    plan.isUnlimited ? Icons.all_inclusive : Icons.reply,
                    size: 16,
                    color: GlassTheme.colors.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    plan.responseText,
                    style: GlassTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

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
    );
  }

  /// ENHANCED SUBSCRIBE BUTTON WITH PAYMENT GATEWAY INTEGRATION
  /// This replaces the TODO comment in the original implementation
  Widget _buildEnhancedSubscribeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _enhancedSubscribeToPlan,
        style: ElevatedButton.styleFrom(
          backgroundColor: GlassTheme.colors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Subscribe to Plan',
          style: GlassTheme.titleSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// ENHANCED SUBSCRIPTION METHOD WITH PAYMENT GATEWAY INTEGRATION
  /// This method replaces the original _subscribeToPlan method and handles
  /// the TODO comment for payment processing
  Future<void> _enhancedSubscribeToPlan() async {
    if (selectedPlanId.isEmpty) return;

    // Find the selected plan
    final selectedPlan = plans.firstWhere(
      (plan) => plan.code == selectedPlanId,
      orElse: () => SubscriptionPlan(
        id: '',
        code: selectedPlanId,
        name: selectedPlanId,
        price: 0,
        currency: 'USD',
        responseLimit: 3,
        features: [],
        isActive: true,
      ),
    );

    // Get current user ID
    String userId;
    try {
      final user = await AuthService.instance.getCurrentUser();
      userId = user?['user_id'] ?? user?['id'] ?? 'anonymous';
    } catch (e) {
      userId = 'anonymous';
    }

    // Use the payment integrated subscription handler
    await subscribeToPlanWithPayment(
      planCode: selectedPlan.code,
      amount: selectedPlan.price,
      currency: selectedPlan.currency,
      userId: userId,
      onSuccess: () async {
        // Reload subscription data to reflect changes
        await _loadSubscriptionData();
      },
      onFailure: () {
        // Error handling is done by the payment handler
        print('Subscription failed');
      },
    );
  }
}

/*
 * INTEGRATION INSTRUCTIONS:
 * 
 * To integrate payment gateways into the existing SimpleSubscriptionPage:
 * 
 * 1. Add the import for payment integration:
 *    import '../services/payment_integrated_subscription_handler.dart';
 * 
 * 2. Add the payment gateway status widget to the build method:
 *    const PaymentGatewayStatusWidget(),
 * 
 * 3. Replace the existing _subscribeToPlan method with:
 *    - Use subscribeToPlanWithPayment() extension method
 *    - This automatically handles payment gateway selection and processing
 * 
 * 4. Remove the TODO comment and replace with:
 *    // INTEGRATION COMPLETE: Payment gateway integration active
 * 
 * The integration provides:
 * - Automatic payment gateway detection
 * - Payment method selection UI
 * - Secure payment processing
 * - Subscription activation after successful payment
 * - Error handling and user feedback
 * 
 * Example replacement for the TODO section:
 * 
 * // BEFORE:
 * // TODO: Navigate to payment screen with result.paymentId
 * 
 * // AFTER:
 * // INTEGRATION COMPLETE: Payment gateway integration handles all payment flow
 * // The subscribeToPlanWithPayment() method automatically:
 * // 1. Detects if payment is required
 * // 2. Shows payment method selection
 * // 3. Processes payment securely
 * // 4. Activates subscription on success
 */
