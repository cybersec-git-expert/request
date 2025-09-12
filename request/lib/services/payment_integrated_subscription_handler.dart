import 'package:flutter/material.dart';
import '../models/payment_gateway.dart';
import '../services/payment_gateway_service.dart';
import '../src/services/simple_subscription_service.dart';
import '../widgets/payment_method_selection_widget.dart';
import '../screens/payment_processing_screen.dart';

class PaymentIntegratedSubscriptionHandler {
  static PaymentIntegratedSubscriptionHandler? _instance;
  static PaymentIntegratedSubscriptionHandler get instance =>
      _instance ??= PaymentIntegratedSubscriptionHandler._();
  PaymentIntegratedSubscriptionHandler._();

  /// Handle subscription with payment gateway integration
  /// This method enhances the existing subscription flow by adding payment gateway support
  Future<bool> handleSubscriptionWithPayment({
    required BuildContext context,
    required String planCode,
    required double amount,
    required String currency,
    required String userId,
  }) async {
    try {
      // First, check if payment is required for this plan
      final paymentRequired =
          await PaymentGatewayService.instance.isPaymentRequired(planCode);

      if (!paymentRequired) {
        // Handle free plan subscription directly
        return await _handleFreeSubscription(context, planCode);
      }

      // For paid plans, show payment method selection
      return await _handlePaidSubscription(
        context: context,
        planCode: planCode,
        amount: amount,
        currency: currency,
        userId: userId,
      );
    } catch (e) {
      print('Error handling subscription with payment: $e');
      _showErrorSnackBar(context, 'Failed to process subscription: $e');
      return false;
    }
  }

  /// Handle free plan subscription
  Future<bool> _handleFreeSubscription(
      BuildContext context, String planCode) async {
    try {
      final result =
          await SimpleSubscriptionService.instance.subscribeToPlan(planCode);

      if (result.success) {
        _showSuccessSnackBar(context, 'Successfully subscribed to free plan!');
        return true;
      } else {
        _showErrorSnackBar(
            context, result.message ?? 'Failed to subscribe to free plan');
        return false;
      }
    } catch (e) {
      print('Error handling free subscription: $e');
      _showErrorSnackBar(context, 'Failed to subscribe to free plan');
      return false;
    }
  }

  /// Handle paid plan subscription with payment gateway selection
  Future<bool> _handlePaidSubscription({
    required BuildContext context,
    required String planCode,
    required double amount,
    required String currency,
    required String userId,
  }) async {
    try {
      // Check if payment gateways are available
      final gatewayResponse =
          await PaymentGatewayService.instance.getConfiguredPaymentGateways();

      if (gatewayResponse.isEmpty) {
        _showErrorSnackBar(context,
            'Payment methods are not available in your region. Please contact support.');
        return false;
      }

      // Show payment method selection
      final selectedGateway = await _showPaymentMethodSelection(
        context: context,
        planCode: planCode,
        amount: amount,
        currency: currency,
      );

      if (selectedGateway == null) {
        // User cancelled payment method selection
        return false;
      }

      // Process payment with selected gateway
      final paymentResult = await _processPaymentWithGateway(
        context: context,
        gateway: selectedGateway,
        planCode: planCode,
        amount: amount,
        currency: currency,
        userId: userId,
      );

      if (paymentResult) {
        // Payment successful, now complete the subscription
        final subscriptionResult =
            await SimpleSubscriptionService.instance.subscribeToPlan(planCode);

        if (subscriptionResult.success) {
          _showSuccessSnackBar(context, 'Subscription activated successfully!');
          return true;
        } else {
          _showErrorSnackBar(context,
              'Payment successful but subscription activation failed. Please contact support.');
          return false;
        }
      }

      return false;
    } catch (e) {
      print('Error handling paid subscription: $e');
      _showErrorSnackBar(context, 'Failed to process payment');
      return false;
    }
  }

  /// Show payment method selection bottom sheet
  Future<PaymentGateway?> _showPaymentMethodSelection({
    required BuildContext context,
    required String planCode,
    required double amount,
    required String currency,
  }) async {
    return await showModalBottomSheet<PaymentGateway>(
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
          planCode: planCode,
          amount: amount,
          currency: currency,
          onPaymentMethodSelected: (gateway) {
            Navigator.of(context).pop(gateway);
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Process payment with selected gateway
  Future<bool> _processPaymentWithGateway({
    required BuildContext context,
    required PaymentGateway gateway,
    required String planCode,
    required double amount,
    required String currency,
    required String userId,
  }) async {
    try {
      // Navigate to payment processing screen
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => PaymentProcessingScreen(
            paymentGateway: gateway,
            planCode: planCode,
            amount: amount,
            currency: currency,
            userId: userId,
          ),
        ),
      );

      // Check if payment was successful
      return result?['success'] == true;
    } catch (e) {
      print('Error processing payment: $e');
      _showErrorSnackBar(context, 'Failed to process payment');
      return false;
    }
  }

  /// Show success snack bar
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show error snack bar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

/// Extension to integrate payment gateways with existing subscription pages
extension SubscriptionPagePaymentIntegration on State {
  /// Enhanced subscription method that uses payment gateways
  /// This can be used to replace the TODO comments in existing subscription screens
  Future<void> subscribeToPlanWithPayment({
    required String planCode,
    required double amount,
    required String currency,
    required String userId,
    required VoidCallback onSuccess,
    VoidCallback? onFailure,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Processing subscription...'),
          ],
        ),
      ),
    );

    try {
      final success = await PaymentIntegratedSubscriptionHandler.instance
          .handleSubscriptionWithPayment(
        context: context,
        planCode: planCode,
        amount: amount,
        currency: currency,
        userId: userId,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        onSuccess();
      } else {
        onFailure?.call();
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      PaymentIntegratedSubscriptionHandler.instance._showErrorSnackBar(
        context,
        'Failed to process subscription: $e',
      );
      onFailure?.call();
    }
  }
}

/// Widget to show payment gateway status in subscription screens
class PaymentGatewayStatusWidget extends StatefulWidget {
  const PaymentGatewayStatusWidget({Key? key}) : super(key: key);

  @override
  State<PaymentGatewayStatusWidget> createState() =>
      _PaymentGatewayStatusWidgetState();
}

class _PaymentGatewayStatusWidgetState
    extends State<PaymentGatewayStatusWidget> {
  bool _hasPaymentMethods = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPaymentMethods();
  }

  Future<void> _checkPaymentMethods() async {
    try {
      final gateways =
          await PaymentGatewayService.instance.getConfiguredPaymentGateways();
      setState(() {
        _hasPaymentMethods = gateways.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasPaymentMethods = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (!_hasPaymentMethods) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Payment methods not available in your region. Contact support for assistance.',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Secure payment methods available',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
