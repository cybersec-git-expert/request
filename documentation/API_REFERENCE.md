# API Reference - Subscription & Payment Gateway Management

## Base URL
- **Local Development**: `http://localhost:3001/api`
- **Production**: `http://3.92.216.149:3001/api`
- **Flutter Emulator**: `http://10.0.2.2:3001/api`

## Authentication

All protected endpoints require a Bearer token in the Authorization header:

```http
Authorization: Bearer {jwt_token}
```

### Roles and Permissions
- **super_admin**: Full access to all features
- **country_admin**: Access to country-specific features
- **user**: Basic subscription management

---

## Subscription Management APIs

### 1. Get User Subscription Status

**Endpoint:** `GET /simple-subscription/status`  
**Authentication:** Required  
**Role:** User, Admin

**Response:**
```json
{
  "success": true,
  "subscription": {
    "planCode": "Pro",
    "planName": "Pro Plan", 
    "status": "active",
    "startedAt": "2025-09-01T00:00:00.000Z",
    "expiresAt": "2025-10-01T00:00:00.000Z",
    "responsesUsed": 15,
    "responsesLimit": -1,
    "responsesRemaining": -1,
    "canRespond": true,
    "autoRenew": true,
    "paymentAmount": 3500.00,
    "paymentCurrency": "LKR",
    "nextPaymentDate": "2025-10-01T00:00:00.000Z"
  }
}
```

**Status Values:**
- `active` - Subscription is active and paid
- `pending_payment` - Awaiting payment processing
- `past_due` - Payment failed, in grace period
- `canceled` - User canceled subscription
- `expired` - Subscription has expired
- `free` - Free plan (default)

---

### 2. Get Available Subscription Plans

**Endpoint:** `GET /simple-subscription/plans`  
**Authentication:** Not required  
**Parameters:**
- `country` (optional) - Country code (e.g., LK, US, IN)

**Example:** `GET /simple-subscription/plans?country=LK`

**Response:**
```json
{
  "success": true,
  "plans": [
    {
      "code": "Free",
      "name": "Free Plan",
      "description": "Perfect for small businesses starting out",
      "features": [],
      "price": "0.00",
      "currency": "LKR",
      "response_limit": 3,
      "country_pricing_active": true,
      "pricing_created_at": "2025-09-12T10:31:07.582Z"
    },
    {
      "code": "Pro", 
      "name": "Pro Plan",
      "description": "Unlimited Responses",
      "features": ["unlimited_responses", "priority_support"],
      "price": "3500.00",
      "currency": "LKR", 
      "response_limit": -1,
      "country_pricing_active": true,
      "pricing_created_at": "2025-09-12T10:33:55.675Z"
    }
  ]
}
```

**Response Limit Values:**
- `-1` - Unlimited responses
- `n` - Limited to n responses per month

---

### 3. Subscribe to Plan

**Endpoint:** `POST /simple-subscription/subscribe`  
**Authentication:** Required  
**Role:** User

**Request Body:**
```json
{
  "planCode": "Pro"
}
```

**Response (Free Plan):**
```json
{
  "success": true,
  "requiresPayment": false,
  "message": "Successfully subscribed to Free plan",
  "subscription": {
    "planCode": "Free",
    "status": "active",
    "paymentAmount": 0.00,
    "paymentCurrency": "LKR"
  }
}
```

**Response (Paid Plan):**
```json
{
  "success": true,
  "requiresPayment": true,
  "paymentId": "pay_12345",
  "checkoutUrl": "https://checkout.stripe.com/pay/cs_...",
  "message": "Payment required for Pro plan",
  "subscription": {
    "planCode": "Pro",
    "status": "pending_payment",
    "paymentAmount": 3500.00,
    "paymentCurrency": "LKR"
  }
}
```

---

### 4. Check Response Eligibility

**Endpoint:** `GET /simple-subscription/can-respond`  
**Authentication:** Required  
**Role:** User

**Response:**
```json
{
  "success": true,
  "data": {
    "canRespond": true,
    "reason": "active_subscription",
    "message": "You can create responses",
    "responsesUsed": 15,
    "responsesLimit": -1,
    "responsesRemaining": -1
  }
}
```

**Reason Values:**
- `active_subscription` - User has active paid subscription
- `within_limits` - User within free plan limits
- `no_subscription` - User has no active subscription
- `limit_exceeded` - Monthly response limit exceeded
- `subscription_expired` - Subscription has expired

---

### 5. Record Response Usage

**Endpoint:** `POST /simple-subscription/record-response`  
**Authentication:** Required  
**Role:** User

**Request Body:**
```json
{
  "requestId": "d552558a-58da-46f8-95cd-ceeffbd53f6c"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Response usage recorded",
  "usage": {
    "responsesUsed": 16,
    "responsesLimit": -1,
    "responsesRemaining": -1
  }
}
```

---

### 6. Confirm Payment

**Endpoint:** `POST /simple-subscription/confirm-payment`  
**Authentication:** Required  
**Role:** User

**Request Body:**
```json
{
  "paymentId": "pay_12345",
  "paymentIntentId": "pi_stripe_payment_intent",
  "status": "succeeded"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Payment confirmed and subscription activated",
  "subscription": {
    "planCode": "Pro",
    "status": "active",
    "startedAt": "2025-09-12T10:00:00.000Z",
    "expiresAt": "2025-10-12T10:00:00.000Z"
  }
}
```

---

## Admin Subscription APIs

### 1. Get All Plans (Admin)

**Endpoint:** `GET /admin/subscription/plans`  
**Authentication:** Required  
**Role:** super_admin, country_admin

**Response:**
```json
{
  "success": true,
  "plans": [
    {
      "code": "Free",
      "name": "Free Plan",
      "description": "Perfect for small businesses starting out",
      "features": [],
      "defaultPrice": 0.00,
      "defaultCurrency": "USD",
      "defaultResponseLimit": 3,
      "isActive": true,
      "createdAt": "2025-09-01T00:00:00.000Z"
    }
  ]
}
```

---

### 2. Create Plan Template

**Endpoint:** `POST /admin/subscription/plans`  
**Authentication:** Required  
**Role:** super_admin

**Request Body:**
```json
{
  "code": "Premium",
  "name": "Premium Plan",
  "description": "Advanced features for power users",
  "features": ["unlimited_responses", "priority_support", "analytics"],
  "defaultPrice": 99.99,
  "defaultCurrency": "USD",
  "defaultResponseLimit": -1
}
```

**Response:**
```json
{
  "success": true,
  "message": "Plan template created successfully",
  "plan": {
    "id": 3,
    "code": "Premium",
    "name": "Premium Plan",
    "createdAt": "2025-09-12T10:00:00.000Z"
  }
}
```

---

### 3. Update Plan Template

**Endpoint:** `PUT /admin/subscription/plans/{code}`  
**Authentication:** Required  
**Role:** super_admin

**Request Body:**
```json
{
  "name": "Premium Plus Plan",
  "description": "Enhanced premium features",
  "features": ["unlimited_responses", "priority_support", "analytics", "api_access"],
  "defaultPrice": 149.99
}
```

---

### 4. Set Country Pricing

**Endpoint:** `POST /admin/subscription/country-pricing`  
**Authentication:** Required  
**Role:** super_admin, country_admin

**Request Body:**
```json
{
  "planCode": "Pro",
  "countryCode": "LK", 
  "price": 3500.00,
  "currency": "LKR",
  "responseLimit": -1
}
```

**Response:**
```json
{
  "success": true,
  "message": "Country pricing set successfully",
  "pricing": {
    "id": 123,
    "planCode": "Pro",
    "countryCode": "LK",
    "price": 3500.00,
    "currency": "LKR",
    "approvalStatus": "pending"
  }
}
```

---

### 5. Approve Country Pricing

**Endpoint:** `PATCH /admin/subscription/country-pricing/{id}/approve`  
**Authentication:** Required  
**Role:** super_admin

**Response:**
```json
{
  "success": true,
  "message": "Country pricing approved successfully"
}
```

---

## Payment Gateway Management APIs

### 1. Get Available Gateways

**Endpoint:** `GET /admin/payment-gateways/gateways/{countryCode}`  
**Authentication:** Required  
**Role:** super_admin, country_admin

**Example:** `GET /admin/payment-gateways/gateways/LK`

**Response:**
```json
{
  "success": true,
  "gateways": [
    {
      "id": 1,
      "name": "Stripe",
      "code": "stripe", 
      "description": "Global payment processing platform",
      "configuration_fields": {
        "api_key": {
          "type": "text",
          "label": "Publishable Key",
          "required": true
        },
        "secret_key": {
          "type": "password", 
          "label": "Secret Key",
          "required": true
        }
      },
      "country_gateway_id": 123,
      "configured": true,
      "is_active": true,
      "is_primary": false,
      "configured_at": "2025-09-12T10:30:00.000Z"
    }
  ]
}
```

---

### 2. Configure Payment Gateway

**Endpoint:** `POST /admin/payment-gateways/gateways/{countryCode}/configure`  
**Authentication:** Required  
**Role:** super_admin, country_admin

**Request Body:**
```json
{
  "gatewayId": 1,
  "configuration": {
    "api_key": "pk_test_51234567890",
    "secret_key": "sk_test_09876543210", 
    "webhook_secret": "whsec_abcdef123456"
  },
  "isPrimary": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Payment gateway configured successfully",
  "gateway": {
    "id": 123,
    "countryCode": "LK",
    "gatewayId": 1,
    "isActive": true,
    "isPrimary": true,
    "configuredAt": "2025-09-12T10:30:00.000Z"
  }
}
```

---

### 3. Get Gateway Configuration

**Endpoint:** `GET /admin/payment-gateways/gateways/{countryCode}/{gatewayId}/config`  
**Authentication:** Required  
**Role:** super_admin, country_admin

**Response:**
```json
{
  "success": true,
  "gateway": {
    "id": 123,
    "name": "Stripe",
    "code": "stripe",
    "configuration": {
      "api_key": "pk_test_51234567890",
      "secret_key": "••••••••",
      "webhook_secret": "••••••••"
    },
    "isActive": true,
    "isPrimary": true
  }
}
```

**Note:** Sensitive fields are masked with bullets for security.

---

### 4. Toggle Gateway Status

**Endpoint:** `PATCH /admin/payment-gateways/gateways/{countryCode}/{gatewayId}/toggle`  
**Authentication:** Required  
**Role:** super_admin, country_admin

**Request Body:**
```json
{
  "isActive": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Payment gateway activated successfully"
}
```

---

### 5. Get Primary Gateway

**Endpoint:** `GET /admin/payment-gateways/gateways/{countryCode}/primary`  
**Authentication:** Not required (internal use)

**Response:**
```json
{
  "success": true,
  "gateway": {
    "id": 123,
    "name": "Stripe",
    "code": "stripe",
    "configuration": {
      "api_key": "pk_test_51234567890",
      "secret_key": "sk_test_09876543210"
    },
    "isActive": true,
    "isPrimary": true
  }
}
```

**Note:** This endpoint returns decrypted credentials for payment processing.

---

### 6. Configure Gateway Fees

**Endpoint:** `POST /admin/payment-gateways/gateways/{countryCode}/{gatewayId}/fees`  
**Authentication:** Required  
**Role:** super_admin, country_admin

**Request Body:**
```json
{
  "fees": [
    {
      "transactionType": "subscription",
      "feeType": "combined",
      "percentageFee": 2.9,
      "fixedFee": 0.30,
      "currency": "USD",
      "minimumAmount": 0.50,
      "maximumAmount": null
    },
    {
      "transactionType": "one_time", 
      "feeType": "percentage",
      "percentageFee": 3.5,
      "fixedFee": 0.00,
      "currency": "USD"
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Gateway fees configured successfully"
}
```

---

## Error Responses

### Common Error Codes

**400 Bad Request**
```json
{
  "success": false,
  "error": "Invalid request parameters",
  "details": {
    "planCode": "Plan code is required"
  }
}
```

**401 Unauthorized**
```json
{
  "success": false,
  "error": "Authentication required"
}
```

**403 Forbidden**
```json
{
  "success": false,
  "error": "Insufficient permissions for this operation"
}
```

**404 Not Found**
```json
{
  "success": false,
  "error": "Resource not found",
  "resource": "subscription_plan",
  "identifier": "InvalidPlan"
}
```

**409 Conflict**
```json
{
  "success": false,
  "error": "User already has an active subscription",
  "currentPlan": "Pro"
}
```

**500 Internal Server Error**
```json
{
  "success": false,
  "error": "Internal server error",
  "message": "Database connection failed"
}
```

---

## Rate Limiting

All APIs are rate-limited to prevent abuse:

- **General APIs**: 100 requests per 15 minutes per IP
- **Payment APIs**: 10 requests per minute per user  
- **Admin APIs**: 200 requests per 15 minutes per admin

**Rate Limit Headers:**
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1641835200
```

---

## Webhooks

### Payment Confirmation Webhook

**Endpoint:** `POST /api/webhooks/payment-confirmation`  
**Authentication:** Webhook signature verification

**Payload:**
```json
{
  "event": "payment.succeeded",
  "paymentId": "pay_12345",
  "userId": "user-uuid",
  "planCode": "Pro",
  "amount": 3500.00,
  "currency": "LKR",
  "gateway": "stripe",
  "timestamp": "2025-09-12T10:30:00.000Z"
}
```

### Subscription Renewal Webhook

**Payload:**
```json
{
  "event": "subscription.renewed",
  "userId": "user-uuid", 
  "planCode": "Pro",
  "renewedAt": "2025-10-12T10:00:00.000Z",
  "expiresAt": "2025-11-12T10:00:00.000Z"
}
```

---

## SDK Examples

### JavaScript/TypeScript
```typescript
const api = new RequestMarketplaceAPI({
  baseURL: 'http://localhost:3001/api',
  token: 'your-jwt-token'
});

// Get subscription status
const status = await api.subscriptions.getStatus();

// Subscribe to plan
const result = await api.subscriptions.subscribe('Pro');

// Check if user can respond
const eligibility = await api.subscriptions.canRespond();
```

### Dart/Flutter
```dart
final subscriptionService = SimpleSubscriptionService.instance;

// Get subscription status
final status = await subscriptionService.getSubscriptionStatus();

// Get available plans
final plans = await subscriptionService.getAvailablePlans();

// Subscribe to plan
final result = await subscriptionService.subscribeToPlan('Pro');
```

### cURL Examples

**Get subscription status:**
```bash
curl -X GET "http://localhost:3001/api/simple-subscription/status" \
  -H "Authorization: Bearer your-jwt-token"
```

**Subscribe to plan:**
```bash
curl -X POST "http://localhost:3001/api/simple-subscription/subscribe" \
  -H "Authorization: Bearer your-jwt-token" \
  -H "Content-Type: application/json" \
  -d '{"planCode": "Pro"}'
```

**Configure payment gateway:**
```bash
curl -X POST "http://localhost:3001/api/admin/payment-gateways/gateways/LK/configure" \
  -H "Authorization: Bearer admin-jwt-token" \
  -H "Content-Type: application/json" \
  -d '{
    "gatewayId": 1,
    "configuration": {
      "api_key": "pk_test_123",
      "secret_key": "sk_test_456"
    },
    "isPrimary": true
  }'
```

---

## Postman Collection

Import the following collection for easy API testing:

```json
{
  "info": {
    "name": "Request Marketplace - Subscription & Payment Gateway APIs",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "auth": {
    "type": "bearer",
    "bearer": [
      {
        "key": "token",
        "value": "{{jwt_token}}",
        "type": "string"
      }
    ]
  },
  "variable": [
    {
      "key": "base_url",
      "value": "http://localhost:3001/api"
    }
  ]
}
```

Download the complete Postman collection from: [API Collection Link]

---

For more information, visit our [Developer Documentation](https://docs.requestmarketplace.com) or contact our support team.
