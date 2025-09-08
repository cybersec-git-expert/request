# 🚀 Comprehensive Subscription Plan System with Promo Codes

## Overview

This system provides a complete subscription management solution with promotional codes, usage limits, and country-specific pricing. It includes both mandatory subscriptions for businesses and optional subscriptions for riders with generous free tiers.

## 🎯 Key Features

### **Subscription Plans**
- **3-month free trial** for all user types
- **Country-specific pricing** with local currency support
- **Flexible payment models**: Monthly, Yearly, Pay-per-click
- **Different tiers** for riders and businesses

### **Promotional Codes**
- **Backend-controlled** promotional campaigns
- **Multiple discount types**: Percentage, fixed amount, free trial extensions
- **Usage tracking** and limits
- **Country-specific** and user-type-specific codes
- **Time-bound** offers with automatic expiration

### **Usage Limitations**
- **Riders**: 3 free responses/month after trial (no notifications)
- **Businesses**: Pay-per-click model after trial
- **Smart enforcement** with real-time checking
- **Promo code benefits** override standard limits

## 📱 Implementation Guide

### **1. Registration Flow Integration**

```dart
// In your registration process
import '../screens/registration_subscription_flow.dart';

// After user completes basic registration
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => RegistrationSubscriptionFlow(
      userType: 'rider', // or 'business'
      countryCode: 'LK',
      registrationData: userRegistrationData,
      onComplete: () {
        // Navigate to main app
        Navigator.pushReplacementNamed(context, '/dashboard');
      },
    ),
  ),
);
```

### **2. Usage Checking Before Actions**

```dart
import '../services/usage_limiter_service.dart';

// Before allowing ride response
Future<void> respondToRide() async {
  final canRespond = await UsageLimiterService.canRiderRespond();
  
  if (!canRespond['canRespond']) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Subscription Required'),
        content: Text(canRespond['message']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/subscription'),
            child: Text('Subscribe Now'),
          ),
        ],
      ),
    );
    return;
  }
  
  // Proceed with ride response
  await submitRideResponse();
  await UsageLimiterService.recordRideResponse(rideId, responseData);
}

// For business clicks
Future<void> handleBusinessClick(String businessId) async {
  final clickResult = await UsageLimiterService.recordBusinessClick(
    businessId,
    'customer_inquiry',
    {'source': 'app', 'timestamp': DateTime.now().toIso8601String()}
  );
  
  if (clickResult['charged']) {
    // Show user the cost
    showSnackBar('Click charged: ${clickResult['cost']} ${clickResult['currency']}');
  }
}
```

### **3. Notification System Integration**

```dart
// In your notification service
import '../services/usage_limiter_service.dart';

Future<void> sendNotificationToUser(String userId, NotificationModel notification) async {
  final canReceiveNotifications = await UsageLimiterService.canReceiveNotifications(userId);
  
  if (!canReceiveNotifications) {
    // Don't send notification to free users
    print('Notification skipped for user $userId - no active subscription');
    return;
  }
  
  // Send notification as usual
  await ComprehensiveNotificationService.sendNotification(userId, notification);
}
```

## 🎫 Promo Code Management

### **Backend Administration**

You can manage promo codes through Firebase Console or create an admin panel:

```javascript
// Example: Create a new promo code
const admin = require('firebase-admin');
const db = admin.firestore();

async function createPromoCode() {
  await db.collection('promoCodes').add({
    code: 'SUMMER2025',
    title: 'Summer Special',
    description: '3 months extra free trial',
    type: 'freeTrialExtension',
    status: 'active',
    value: 90, // 90 days
    validFrom: admin.firestore.Timestamp.now(),
    validTo: admin.firestore.Timestamp.fromDate(new Date('2025-09-30')),
    maxUses: 1000,
    currentUses: 0,
    applicableUserTypes: ['rider', 'business'],
    applicableCountries: ['LK', 'IN'], // Sri Lanka and India only
    conditions: {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
```

### **Promo Code Types**

1. **percentageDiscount**: X% off subscription price
2. **fixedDiscount**: Fixed amount discount
3. **freeTrialExtension**: Additional free days
4. **unlimitedResponses**: Unlimited ride responses for X days
5. **businessFreeClicks**: Free clicks for businesses

## 📊 Business Model Implementation

### **Riders**
- **Free Trial**: 3 months full access
- **Post-Trial Options**:
  - Subscribe for unlimited access + notifications
  - Use free tier: 3 responses/month, no notifications
- **Pricing**: Country-specific monthly/yearly plans

### **Businesses (Mandatory Subscription)**
- **Free Trial**: 3 months full access
- **Post-Trial**: Must choose a plan
  - **Pay-per-click**: Pay only for customer interactions
  - **Monthly**: Fixed fee with unlimited interactions
- **Special**: Delivery businesses might have different rules

### **Usage Enforcement**

```dart
// Example enforcement in ride response screen
class RideResponseScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: UsageLimiterService.canRiderRespond(),
      builder: (context, snapshot) {
        if (snapshot.data?['canRespond'] != true) {
          return _buildSubscriptionPrompt(snapshot.data?['message']);
        }
        return _buildRideResponseForm();
      },
    );
  }
}
```

## 🗃️ Firebase Collections Structure

### **subscription_plans**
```javascript
{
  name: "Rider Premium Monthly",
  description: "Unlimited access with premium features",
  type: "rider", // or "business"
  paymentModel: "monthly", // "yearly", "payPerClick"
  countryPrices: {
    "LK": 500.0,
    "US": 9.99,
    // ... other countries
  },
  currencySymbols: {
    "LK": "Rs",
    "US": "$",
    // ... other countries
  },
  features: ["Unlimited responses", "Notifications", ...],
  limitations: {},
  isActive: true,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### **promoCodes**
```javascript
{
  code: "WELCOME2025",
  title: "Welcome Bonus",
  description: "Extra month free for new users",
  type: "freeTrialExtension", // "percentageDiscount", "fixedDiscount", etc.
  status: "active", // "expired", "disabled"
  value: 30, // 30 days or percentage/amount
  validFrom: timestamp,
  validTo: timestamp,
  maxUses: 1000,
  currentUses: 0,
  applicableUserTypes: ["rider", "business"],
  applicableCountries: [], // Empty = all countries
  conditions: {}, // Additional conditions
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### **user_subscriptions**
```javascript
{
  userId: "user123",
  planId: "plan456",
  type: "rider",
  status: "trial", // "active", "expired", "cancelled"
  trialStartDate: timestamp,
  trialEndDate: timestamp,
  subscriptionStartDate: timestamp,
  subscriptionEndDate: timestamp,
  countryCode: "LK",
  currency: "LKR",
  usageStats: {
    rideResponses: 5,
    freeClicksUsed: 10,
    totalSpent: 1500.0
  },
  limitations: {
    monthlyResponses: 3 // For free tier
  },
  promoCodeApplied: "WELCOME2025",
  promoCodeBenefits: {
    extraTrialDays: 30,
    type: "freeTrialExtension",
    appliedAt: "2025-08-15T10:30:00Z"
  },
  isTrialExtended: true,
  trialExtendedUntil: timestamp,
  autoRenew: true,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## 🚀 Setup Instructions

### **1. Initialize the System**

```bash
# Install dependencies
npm install firebase-admin

# Run initialization script
node initialize_subscription_system.js
```

### **2. Update Firebase Security Rules**

```javascript
// Firestore rules additions
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Subscription plans (read-only for users)
    match /subscription_plans/{planId} {
      allow read: if request.auth != null;
      allow write: if hasRole('admin');
    }
    
    // Promo codes (read with validation)
    match /promoCodes/{codeId} {
      allow read: if request.auth != null;
      allow write: if hasRole('admin');
    }
    
    // User subscriptions
    match /user_subscriptions/{subscriptionId} {
      allow read, write: if request.auth != null && 
        (resource.data.userId == request.auth.uid || hasRole('admin'));
    }
    
    // Usage tracking
    match /ride_responses/{responseId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    match /business_clicks/{clickId} {
      allow read, write: if request.auth != null && 
        resource.data.businessId == request.auth.uid;
    }
  }
}
```

### **3. Integration Points**

1. **Registration Process**: Add subscription flow after user registration
2. **Main App**: Check usage limits before key actions
3. **Notification System**: Verify subscription before sending notifications
4. **Payment Integration**: Handle subscription payments and click charges

## 💡 Best Practices

1. **Always check limits** before allowing actions
2. **Graceful degradation** for free users
3. **Clear messaging** about subscription benefits
4. **Analytics tracking** for usage patterns
5. **Regular promo code management** to drive engagement

## 🔧 Customization Options

- **Country-specific pricing** adjustments
- **Custom promo code types** for special campaigns
- **Different trial periods** per region
- **Feature-specific limitations** for free tiers
- **Integration with payment gateways** (Stripe, PayPal, etc.)

This system provides a solid foundation for monetizing your app while maintaining a great user experience with generous free tiers and promotional opportunities.
