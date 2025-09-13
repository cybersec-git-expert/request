# Subscription & Promo Code API Reference

## Authentication
All endpoints require Bearer token authentication:
```
Authorization: Bearer <jwt_token>
```

## Promo Code User APIs

### POST /api/promo-codes/validate
Validate a promo code and check user eligibility.

**Request:**
```json
{
  "code": "WELCOME30"
}
```

**Response:**
```json
{
  "success": true,
  "valid": true,
  "user_can_use": true,
  "message": "Get 30 days of Pro access for free!",
  "promo": {
    "name": "Welcome Free Month",
    "description": "Welcome new users with free Pro access",
    "benefit_type": "free_plan",
    "benefit_duration_days": 30,
    "benefit_plan_code": "Pro",
    "discount_percentage": null,
    "user_usage_count": 0,
    "max_uses_per_user": 1,
    "valid_until": "2025-12-31T23:59:59Z"
  }
}
```

**Error Response:**
```json
{
  "success": true,
  "valid": false,
  "message": "Invalid promo code"
}
```

---

### POST /api/promo-codes/redeem
Redeem a promo code and activate benefits.

**Request:**
```json
{
  "code": "WELCOME30"
}
```

**Success Response:**
```json
{
  "success": true,
  "redemption_id": "abc123",
  "benefit_plan": "Pro",
  "benefit_start_date": "2025-09-13T00:00:00Z",
  "benefit_end_date": "2025-10-13T00:00:00Z",
  "granted_plan_code": "Pro",
  "message": "Successfully redeemed WELCOME30! Enjoy 30 days of Pro access."
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "You have already used this promo code the maximum number of times"
}
```

---

### GET /api/promo-codes/my-redemptions
Get user's promo code redemption history.

**Response:**
```json
{
  "success": true,
  "redemptions": [
    {
      "id": "123",
      "code": "WELCOME30",
      "name": "Welcome Free Month",
      "description": "Welcome new users with free Pro access",
      "benefit_type": "free_plan",
      "benefit_duration_days": 30,
      "granted_plan_code": "Pro",
      "status": "active",
      "redeemed_at": "2025-09-13T10:30:00Z",
      "benefit_start_date": "2025-09-13T00:00:00Z",
      "benefit_end_date": "2025-10-13T00:00:00Z",
      "is_active": true,
      "days_remaining": 30
    }
  ]
}
```

---

### GET /api/promo-codes/check-active
Check if user has any active promo benefits.

**Response (with active promo):**
```json
{
  "success": true,
  "has_active_promo": true,
  "active_promo": {
    "id": "123",
    "code": "WELCOME30",
    "name": "Welcome Free Month",
    "granted_plan_code": "Pro",
    "benefit_end_date": "2025-10-13T00:00:00Z",
    "days_remaining": 30
  }
}
```

**Response (no active promo):**
```json
{
  "success": true,
  "has_active_promo": false
}
```

---

## Promo Code Admin APIs

### GET /api/promo-codes/admin/list
Get all promo codes with usage statistics (Admin only).

**Response:**
```json
{
  "success": true,
  "codes": [
    {
      "id": 1,
      "code": "WELCOME30",
      "name": "Welcome Free Month",
      "description": "Welcome new users with free Pro access",
      "benefit_type": "free_plan",
      "benefit_duration_days": 30,
      "benefit_plan_code": "Pro",
      "discount_percentage": null,
      "max_uses": null,
      "max_uses_per_user": 1,
      "current_uses": 25,
      "unique_users": 25,
      "valid_from": "2025-09-01T00:00:00Z",
      "valid_until": "2025-12-31T23:59:59Z",
      "is_active": true,
      "created_at": "2025-09-01T12:00:00Z",
      "updated_at": "2025-09-13T10:30:00Z"
    }
  ]
}
```

---

### POST /api/promo-codes/admin/create
Create a new promo code (Admin only).

**Request:**
```json
{
  "code": "SUMMER2025",
  "name": "Summer Special",
  "description": "Special summer promotion for new users",
  "benefit_type": "free_plan",
  "benefit_duration_days": 60,
  "benefit_plan_code": "Pro",
  "discount_percentage": null,
  "max_uses": 1000,
  "max_uses_per_user": 1,
  "valid_from": "2025-06-01T00:00:00Z",
  "valid_until": "2025-08-31T23:59:59Z",
  "is_active": true
}
```

**Response:**
```json
{
  "success": true,
  "code": {
    "id": 4,
    "code": "SUMMER2025",
    "name": "Summer Special",
    "description": "Special summer promotion for new users",
    "benefit_type": "free_plan",
    "benefit_duration_days": 60,
    "benefit_plan_code": "Pro",
    "discount_percentage": null,
    "max_uses": 1000,
    "max_uses_per_user": 1,
    "current_uses": 0,
    "valid_from": "2025-06-01T00:00:00Z",
    "valid_until": "2025-08-31T23:59:59Z",
    "is_active": true,
    "created_at": "2025-09-13T12:00:00Z",
    "updated_at": "2025-09-13T12:00:00Z"
  },
  "message": "Promo code created successfully"
}
```

---

### PUT /api/promo-codes/admin/:id
Update an existing promo code (Admin only).

**Request:**
```json
{
  "name": "Updated Summer Special",
  "description": "Updated description",
  "max_uses": 1500,
  "is_active": false
}
```

**Response:**
```json
{
  "success": true,
  "code": {
    // Updated promo code object
  },
  "message": "Promo code updated successfully"
}
```

---

### DELETE /api/promo-codes/admin/:id
Delete a promo code (Admin only). Only works if code has never been used.

**Response (successful):**
```json
{
  "success": true,
  "message": "Promo code TESTCODE deleted successfully"
}
```

**Response (error - code has been used):**
```json
{
  "success": false,
  "error": "Cannot delete promo code that has been used 5 times. Consider deactivating instead."
}
```

---

## Subscription Status APIs

### GET /api/simple-subscription/status
Get user's current subscription status.

**Response:**
```json
{
  "subscription": {
    "planCode": "Pro",
    "planName": "Pro Plan",
    "responsesUsed": 15,
    "responsesLimit": -1,
    "responsesRemaining": -1,
    "canRespond": true,
    "isVerifiedBusiness": false,
    "features": ["unlimited_responses", "priority_support"]
  }
}
```

---

### GET /api/simple-subscription/can-respond
Check if user can respond to requests.

**Response:**
```json
{
  "canRespond": true,
  "reason": "unlimited",
  "message": "You have unlimited responses",
  "responsesUsed": 15,
  "responsesLimit": -1,
  "responsesRemaining": -1
}
```

---

## Error Codes

| HTTP Status | Error Type | Description |
|-------------|------------|-------------|
| 400 | Bad Request | Invalid request parameters |
| 401 | Unauthorized | Missing or invalid authentication token |
| 403 | Forbidden | Admin access required |
| 404 | Not Found | Promo code or resource not found |
| 409 | Conflict | Promo code already exists |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server-side error |

## Rate Limits

- **Validation requests**: 10 per minute per user
- **Redemption attempts**: 3 per minute per user
- **Admin operations**: 100 per minute per admin

## Sample Integration Code

### Flutter/Dart
```dart
// Validate promo code
final response = await ApiClient.instance.post<Map<String, dynamic>>(
  '/api/promo-codes/validate',
  data: {'code': 'WELCOME30'},
);

if (response.isSuccess && response.data!['valid'] == true) {
  // Show promo details
  showPromoDetails(response.data!['promo']);
}

// Redeem promo code
final redeemResponse = await ApiClient.instance.post<Map<String, dynamic>>(
  '/api/promo-codes/redeem',
  data: {'code': 'WELCOME30'},
);

if (redeemResponse.isSuccess) {
  // Refresh subscription status
  await ResponseLimitService.syncWithBackend();
  showSuccessDialog();
}
```

### JavaScript/React
```javascript
// Validate promo code
const validatePromo = async (code) => {
  try {
    const response = await api.post('/promo-codes/validate', { code });
    return response.data;
  } catch (error) {
    console.error('Validation failed:', error);
    return { success: false, error: error.message };
  }
};

// Create promo code (Admin)
const createPromoCode = async (promoData) => {
  try {
    const response = await api.post('/promo-codes/admin/create', promoData);
    return response.data;
  } catch (error) {
    console.error('Creation failed:', error);
    return { success: false, error: error.message };
  }
};
```

---

*For complete implementation details, see the main documentation: `SUBSCRIPTION_PROMO_SYSTEM.md`*