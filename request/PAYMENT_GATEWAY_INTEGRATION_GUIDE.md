# Payment Gateway Integration Guide

This guide shows how to integrate the payment gateway system with the existing Flutter subscription system.

## Files Created

1. **Payment Gateway Models** (`lib/models/payment_gateway.dart`)
   - PaymentGateway: Core payment gateway data model
   - PaymentGatewayConfig: Configuration for manual payment methods
   - PaymentGatewayResponse: API response wrapper
   - PaymentSession: Payment session data

2. **Payment Gateway Service** (`lib/services/payment_gateway_service.dart`)
   - getConfiguredPaymentGateways(): Get available payment methods
   - createSubscriptionPaymentSession(): Create payment session
   - confirmPayment(): Confirm payment completion
   - getGatewayConfiguration(): Get payment instructions
   - formatAmount(): Format currency display

3. **Payment Method Selection Widget** (`lib/widgets/payment_method_selection_widget.dart`)
   - Interactive payment method selection UI
   - Shows available payment gateways with icons
   - Handles user selection and validation
   - Displays payment gateway information

4. **Payment Processing Screen** (`lib/screens/payment_processing_screen.dart`)
   - Handles the payment flow for selected gateway
   - Shows payment instructions for manual methods
   - Processes automatic payments
   - Provides payment confirmation interface

5. **Payment Integration Handler** (`lib/services/payment_integrated_subscription_handler.dart`)
   - PaymentIntegratedSubscriptionHandler: Main integration service
   - SubscriptionPagePaymentIntegration: Extension for existing pages
   - PaymentGatewayStatusWidget: Shows payment availability status

## Integration with Existing Subscription System

### Current Implementation

The existing `SimpleSubscriptionPage` has this TODO comment:

```dart
// If payment is required, handle payment flow
if (result.requiresPayment && result.paymentId != null) {
  // TODO: Navigate to payment screen with result.paymentId
  print('Payment required. Payment ID: ${result.paymentId}');
}
```

### Enhanced Implementation

Replace the TODO section with the payment gateway integration:

```dart
// If payment is required, handle payment flow
if (result.requiresPayment && result.paymentId != null) {
  // INTEGRATION: Use payment gateway system
  final selectedPlan = plans.firstWhere((plan) => plan.code == selectedPlanId);
  final userId = await _getCurrentUserId();
  
  final paymentSuccess = await PaymentIntegratedSubscriptionHandler.instance
      .handleSubscriptionWithPayment(
    context: context,
    planCode: selectedPlan.code,
    amount: selectedPlan.price,
    currency: selectedPlan.currency,
    userId: userId,
  );
  
  if (paymentSuccess) {
    await _loadSubscriptionData(); // Refresh subscription status
  }
}
```

### Alternative: Use Extension Method

For cleaner integration, use the extension method:

```dart
// Replace the entire _subscribeToPlan method with:
Future<void> _subscribeToPlan() async {
  if (selectedPlanId.isEmpty) return;
  
  final selectedPlan = plans.firstWhere((plan) => plan.code == selectedPlanId);
  final userId = await _getCurrentUserId();
  
  await subscribeToPlanWithPayment(
    planCode: selectedPlan.code,
    amount: selectedPlan.price,
    currency: selectedPlan.currency,
    userId: userId,
    onSuccess: () async {
      await _loadSubscriptionData();
    },
    onFailure: () {
      // Error handling is automatic
    },
  );
}
```

### Add Payment Status Widget

Add payment gateway availability indicator to the subscription page:

```dart
// In the build method, add:
Column(
  children: [
    const PaymentGatewayStatusWidget(), // Shows payment availability
    const SizedBox(height: 16),
    // ... existing subscription UI
  ],
)
```

## Payment Flow

1. **User selects a paid plan** → Triggers subscription process
2. **System checks payment requirement** → Determines if payment needed
3. **Payment gateway selection** → Shows available payment methods
4. **Payment processing** → Handles payment flow based on gateway type
5. **Subscription activation** → Activates subscription after successful payment

## Payment Gateway Types Supported

### Automatic Payment Gateways
- **Stripe**: Credit card processing
- **PayPal**: PayPal account payments
- **Razorpay**: Indian payment methods (UPI, cards, net banking)
- **PayHere**: Sri Lankan payment gateway

### Manual Payment Gateways
- **Bank Transfer**: Direct bank account transfers
- **Manual verification**: Admin-verified payments

## Admin Configuration

Payment gateways are configured through the admin panel:
1. Admin selects country
2. Admin configures available payment gateways
3. Admin sets gateway-specific settings (API keys, bank details)
4. Configuration is encrypted and stored securely

## API Integration

The payment gateway system integrates with these backend endpoints:

- `GET /api/admin/payment-gateways/gateways/{country}` - Get available gateways
- `POST /api/payments/create-session` - Create payment session
- `POST /api/payments/confirm` - Confirm payment
- `GET /api/admin/payment-gateways/gateways/{country}/{id}/config` - Get gateway config

## Security Features

1. **Encrypted credentials**: Gateway API keys stored encrypted
2. **Country-specific gateways**: Only relevant payment methods shown
3. **Payment verification**: Manual payments require admin verification
4. **Session management**: Secure payment session handling

## User Experience

1. **Seamless integration**: Works with existing subscription flow
2. **Multiple payment options**: Shows all configured payment methods
3. **Clear instructions**: Provides detailed payment instructions
4. **Status feedback**: Real-time payment status updates
5. **Error handling**: Comprehensive error messages and retry options

## Testing

Test the integration with different scenarios:

1. **Free plan subscription**: Should bypass payment flow
2. **Paid plan with no gateways**: Should show appropriate message
3. **Paid plan with gateways**: Should show payment method selection
4. **Successful payment**: Should activate subscription
5. **Failed payment**: Should allow retry

## Migration Steps

1. **Install the payment gateway files** in your Flutter project
2. **Update imports** in subscription pages
3. **Replace TODO comments** with payment gateway integration
4. **Test the complete flow** with different payment scenarios
5. **Configure payment gateways** in the admin panel

The integration is designed to be backward-compatible and enhance the existing subscription system without breaking changes.
