# Mobile payments and subscriptions wiring (Flutter)

This app already includes `ApiClient` and service scaffolding. Use the following flow to connect membership and boosts to the new backend endpoints.

## Subscribe flow
1. List plans by type (rider/business):
   - GET `/api/subscription-plans?type=rider`
   - Flutter: `SubscriptionServiceApi.instance.fetchPlans(type: 'rider')`
2. Create a subscription (server computes country pricing and promo):
   - POST `/api/subscriptions` with `{ plan_id, country_code, promo_code? }`
   - Flutter: `createSubscription(planId: ..., countryCode: 'LK', promoCode: ...)` → returns subscription row (status = `active` for free, else `pending_payment`).
3. If `pending_payment`, create checkout:
   - Optional: GET `/api/country-payment-gateways?country=LK` to let user pick a provider.
   - POST `/api/payments/checkout-subscription` with `{ subscription_id, provider? }` → returns `{ transaction, gateway, payment }` and a `provider_ref`.
4. Hand off to provider SDK using the returned `gateway.public_config` and `payment`.
5. On success, call webhook (preferred) or poll `/api/subscriptions/me` until `status = active`.

## Urgent boost flow
1. Start boost:
   - POST `/api/requests/:id/urgent-boost/start` → returns `transaction.id` and `provider_ref`.
2. Complete payment via the provider SDK.
3. Confirm boost:
   - POST `/api/requests/:id/urgent-boost/confirm` with `{ transaction_id }`.
   - Alternatively if using webhooks, the backend will set `is_urgent=true` automatically when it receives a `paid` status.

## Entitlements & visibility
- The app should check `contact_visible` and `can_message` on request payloads to decide whether to show phone or message icons.
- Creating a response will be blocked after 3 free responses unless user subscribes.

## Sample usage
```dart
final svc = SubscriptionServiceApi.instance;
final plans = await svc.fetchPlans(type: 'rider');
final created = await svc.createSubscription(planId: plans.first.id, countryCode: 'LK');
if (created != null && (created['status'] == 'pending_payment')) {
  final checkout = await svc.checkoutSubscription(subscriptionId: created['id']);
  // TODO: open provider SDK using checkout['gateway'] and checkout['payment']
}
```

Notes
- Back-end supports country-specific gateway registry at `/api/country-payment-gateways`.
- Webhook endpoint: `/api/payments/webhook/generic` (protect with `X-Webhook-Secret`).
