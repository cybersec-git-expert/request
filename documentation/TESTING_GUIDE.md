# Testing Guide - Subscription & Payment Gateway System

## Overview

This comprehensive testing guide covers all aspects of the subscription and payment gateway management system, including unit tests, integration tests, API testing, and end-to-end testing scenarios.

## Testing Environment Setup

### Prerequisites

```bash
# Install testing dependencies
cd backend
npm install --save-dev jest supertest
npm install --save-dev @testing-library/react @testing-library/jest-dom

cd ../admin-react
npm install --save-dev jest @testing-library/react @testing-library/user-event

cd ../request
flutter pub add flutter_test --dev
flutter pub add mockito --dev
```

### Test Database Setup

Create a separate test database:
```sql
CREATE DATABASE request_marketplace_test;
```

Environment configuration for testing:
```env
# .env.test
DATABASE_URL=postgresql://username:password@localhost:5432/request_marketplace_test
NODE_ENV=test
JWT_SECRET=test-jwt-secret
GATEWAY_ENCRYPTION_KEY=test-encryption-key-32-characters
```

---

## Backend API Testing

### 1. Unit Tests

#### Authentication Tests
```javascript
// backend/tests/auth.test.js
const request = require('supertest');
const app = require('../app');
const db = require('../services/database');

describe('Authentication', () => {
  beforeEach(async () => {
    await db.query('DELETE FROM users WHERE email = $1', ['test@example.com']);
  });

  test('should register new user', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        password: 'password123',
        first_name: 'Test',
        last_name: 'User'
      });

    expect(response.status).toBe(201);
    expect(response.body.token).toBeDefined();
  });

  test('should login with valid credentials', async () => {
    // First register
    await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        password: 'password123',
        first_name: 'Test',
        last_name: 'User'
      });

    // Then login
    const response = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'test@example.com',
        password: 'password123'
      });

    expect(response.status).toBe(200);
    expect(response.body.token).toBeDefined();
  });

  test('should reject invalid credentials', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'invalid@example.com',
        password: 'wrongpassword'
      });

    expect(response.status).toBe(401);
  });
});
```

#### Subscription API Tests
```javascript
// backend/tests/subscription.test.js
const request = require('supertest');
const app = require('../app');
const db = require('../services/database');

describe('Subscription API', () => {
  let userToken;
  let adminToken;

  beforeAll(async () => {
    // Setup test data
    await db.query(`
      INSERT INTO simple_subscription_plans (code, name, default_price, default_currency, default_response_limit)
      VALUES ('TestPlan', 'Test Plan', 9.99, 'USD', 10)
      ON CONFLICT (code) DO NOTHING
    `);

    await db.query(`
      INSERT INTO simple_subscription_country_pricing (plan_code, country_code, price, currency, response_limit, approval_status)
      VALUES ('TestPlan', 'US', 9.99, 'USD', 10, 'approved')
      ON CONFLICT (plan_code, country_code) DO NOTHING
    `);

    // Create test user and get token
    const userResponse = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'user@test.com',
        password: 'password123',
        first_name: 'Test',
        last_name: 'User'
      });
    userToken = userResponse.body.token;

    // Create test admin and get token
    const adminResponse = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'admin@test.com',
        password: 'password123',
        first_name: 'Admin',
        last_name: 'User',
        role: 'country_admin',
        country_code: 'US'
      });
    adminToken = adminResponse.body.token;
  });

  test('should get subscription plans for country', async () => {
    const response = await request(app)
      .get('/api/simple-subscription/plans?country=US')
      .set('Authorization', `Bearer ${userToken}`);

    expect(response.status).toBe(200);
    expect(response.body.plans).toHaveLength(1);
    expect(response.body.plans[0].code).toBe('TestPlan');
  });

  test('should subscribe to a plan', async () => {
    const response = await request(app)
      .post('/api/simple-subscription/subscribe')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        plan_code: 'TestPlan',
        country_code: 'US',
        payment_method: 'stripe',
        payment_token: 'test_token'
      });

    expect(response.status).toBe(200);
    expect(response.body.subscription).toBeDefined();
  });

  test('should get user subscription status', async () => {
    const response = await request(app)
      .get('/api/simple-subscription/status')
      .set('Authorization', `Bearer ${userToken}`);

    expect(response.status).toBe(200);
    expect(response.body.subscription).toBeDefined();
  });

  test('admin should update country pricing', async () => {
    const response = await request(app)
      .post('/api/simple-subscription/admin/country-pricing')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        plan_code: 'TestPlan',
        country_code: 'US',
        price: 12.99,
        currency: 'USD',
        response_limit: 15
      });

    expect(response.status).toBe(200);
  });
});
```

#### Payment Gateway Tests
```javascript
// backend/tests/payment-gateways.test.js
const request = require('supertest');
const app = require('../app');
const db = require('../services/database');

describe('Payment Gateway API', () => {
  let adminToken;

  beforeAll(async () => {
    // Create admin user
    const adminResponse = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'admin@test.com',
        password: 'password123',
        first_name: 'Admin',
        last_name: 'User',
        role: 'country_admin',
        country_code: 'US'
      });
    adminToken = adminResponse.body.token;
  });

  test('should get available payment gateways', async () => {
    const response = await request(app)
      .get('/api/admin/payment-gateways/available')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
  });

  test('should configure payment gateway', async () => {
    const response = await request(app)
      .post('/api/admin/payment-gateways/configure')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        country_code: 'US',
        payment_gateway_id: 1,
        configuration: {
          api_key: 'test_api_key',
          secret_key: 'test_secret_key'
        },
        is_primary: true
      });

    expect(response.status).toBe(200);
  });

  test('should get country payment gateways', async () => {
    const response = await request(app)
      .get('/api/admin/payment-gateways/gateways/US')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body)).toBe(true);
  });

  test('should update gateway status', async () => {
    // First configure a gateway
    await request(app)
      .post('/api/admin/payment-gateways/configure')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        country_code: 'US',
        payment_gateway_id: 1,
        configuration: {
          api_key: 'test_api_key',
          secret_key: 'test_secret_key'
        }
      });

    const response = await request(app)
      .put('/api/admin/payment-gateways/1/status')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        is_active: false
      });

    expect(response.status).toBe(200);
  });
});
```

### 2. Integration Tests

#### Database Integration
```javascript
// backend/tests/database.integration.test.js
const db = require('../services/database');

describe('Database Integration', () => {
  test('should connect to database', async () => {
    const result = await db.query('SELECT 1 as test');
    expect(result.rows[0].test).toBe(1);
  });

  test('should handle subscription lifecycle', async () => {
    // Insert test user
    const userResult = await db.query(`
      INSERT INTO users (id, email, first_name, last_name)
      VALUES (gen_random_uuid(), 'test@example.com', 'Test', 'User')
      RETURNING id
    `);
    const userId = userResult.rows[0].id;

    // Create subscription
    await db.query(`
      INSERT INTO user_simple_subscriptions (user_id, plan_code, country_code, status)
      VALUES ($1, 'TestPlan', 'US', 'active')
    `, [userId]);

    // Check subscription exists
    const subResult = await db.query(`
      SELECT * FROM user_simple_subscriptions WHERE user_id = $1
    `, [userId]);
    expect(subResult.rows).toHaveLength(1);

    // Update usage
    await db.query(`
      INSERT INTO usage_monthly (user_id, year_month, response_count)
      VALUES ($1, '202312', 5)
      ON CONFLICT (user_id, year_month) 
      DO UPDATE SET response_count = usage_monthly.response_count + 1
    `, [userId]);

    // Verify usage
    const usageResult = await db.query(`
      SELECT response_count FROM usage_monthly 
      WHERE user_id = $1 AND year_month = '202312'
    `, [userId]);
    expect(usageResult.rows[0].response_count).toBe(5);

    // Cleanup
    await db.query('DELETE FROM usage_monthly WHERE user_id = $1', [userId]);
    await db.query('DELETE FROM user_simple_subscriptions WHERE user_id = $1', [userId]);
    await db.query('DELETE FROM users WHERE id = $1', [userId]);
  });
});
```

### 3. API Endpoint Testing

#### Manual API Tests (Postman/Insomnia)

Create test collections for:

**Authentication Collection:**
```json
{
  "info": {
    "name": "Subscription System - Auth",
    "description": "Authentication endpoints testing"
  },
  "item": [
    {
      "name": "Register User",
      "request": {
        "method": "POST",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"email\": \"test@example.com\",\n  \"password\": \"password123\",\n  \"first_name\": \"Test\",\n  \"last_name\": \"User\"\n}"
        },
        "url": {
          "raw": "{{baseUrl}}/api/auth/register",
          "host": ["{{baseUrl}}"],
          "path": ["api", "auth", "register"]
        }
      }
    },
    {
      "name": "Login User",
      "request": {
        "method": "POST",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"email\": \"test@example.com\",\n  \"password\": \"password123\"\n}"
        },
        "url": {
          "raw": "{{baseUrl}}/api/auth/login",
          "host": ["{{baseUrl}}"],
          "path": ["api", "auth", "login"]
        }
      }
    }
  ]
}
```

**Subscription Collection:**
```json
{
  "name": "Get Subscription Plans",
  "request": {
    "method": "GET",
    "header": [
      {"key": "Authorization", "value": "Bearer {{userToken}}"}
    ],
    "url": {
      "raw": "{{baseUrl}}/api/simple-subscription/plans?country=US",
      "host": ["{{baseUrl}}"],
      "path": ["api", "simple-subscription", "plans"],
      "query": [{"key": "country", "value": "US"}]
    }
  },
  "test": "pm.test('Should return plans', function () {\n    pm.response.to.have.status(200);\n    pm.expect(pm.response.json().plans).to.be.an('array');\n});"
}
```

---

## Frontend Testing (React Admin)

### 1. Component Unit Tests

```javascript
// admin-react/src/components/__tests__/PaymentGatewayManager.test.js
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import PaymentGatewayManager from '../PaymentGatewayManager';
import { AuthProvider } from '../../contexts/AuthContext';

// Mock API service
jest.mock('../../services/paymentGatewayService', () => ({
  getAvailableGateways: jest.fn(() => Promise.resolve([
    {
      id: 1,
      name: 'Stripe',
      code: 'stripe',
      configuration_fields: {
        api_key: { type: 'text', label: 'API Key', required: true }
      }
    }
  ])),
  getCountryGateways: jest.fn(() => Promise.resolve([])),
  configureGateway: jest.fn(() => Promise.resolve({ success: true }))
}));

const renderWithAuth = (component) => {
  return render(
    <AuthProvider>
      {component}
    </AuthProvider>
  );
};

describe('PaymentGatewayManager', () => {
  test('renders payment gateway list', async () => {
    renderWithAuth(<PaymentGatewayManager />);
    
    await waitFor(() => {
      expect(screen.getByText('Payment Gateway Management')).toBeInTheDocument();
    });
  });

  test('opens configuration dialog', async () => {
    renderWithAuth(<PaymentGatewayManager />);
    
    await waitFor(() => {
      const configureButton = screen.getByText('Configure');
      fireEvent.click(configureButton);
    });

    expect(screen.getByText('Configure Stripe')).toBeInTheDocument();
  });

  test('submits gateway configuration', async () => {
    const mockConfigure = require('../../services/paymentGatewayService').configureGateway;
    
    renderWithAuth(<PaymentGatewayManager />);
    
    await waitFor(() => {
      const configureButton = screen.getByText('Configure');
      fireEvent.click(configureButton);
    });

    const apiKeyInput = screen.getByLabelText('API Key');
    fireEvent.change(apiKeyInput, { target: { value: 'test_api_key' } });

    const saveButton = screen.getByText('Save Configuration');
    fireEvent.click(saveButton);

    await waitFor(() => {
      expect(mockConfigure).toHaveBeenCalledWith({
        country_code: expect.any(String),
        payment_gateway_id: 1,
        configuration: { api_key: 'test_api_key' }
      });
    });
  });
});
```

### 2. Integration Tests

```javascript
// admin-react/src/__tests__/App.integration.test.js
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import App from '../App';

// Mock API calls
jest.mock('../services/authService');
jest.mock('../services/subscriptionService');

describe('App Integration', () => {
  test('complete admin workflow', async () => {
    render(<App />);

    // Login
    const emailInput = screen.getByLabelText('Email');
    const passwordInput = screen.getByLabelText('Password');
    const loginButton = screen.getByText('Login');

    fireEvent.change(emailInput, { target: { value: 'admin@test.com' } });
    fireEvent.change(passwordInput, { target: { value: 'password' } });
    fireEvent.click(loginButton);

    // Navigate to subscription management
    await waitFor(() => {
      const subscriptionNav = screen.getByText('Subscriptions');
      fireEvent.click(subscriptionNav);
    });

    // Update pricing
    await waitFor(() => {
      const editButton = screen.getByText('Edit Pricing');
      fireEvent.click(editButton);
    });

    const priceInput = screen.getByLabelText('Price');
    fireEvent.change(priceInput, { target: { value: '15.99' } });

    const saveButton = screen.getByText('Save');
    fireEvent.click(saveButton);

    await waitFor(() => {
      expect(screen.getByText('Pricing updated successfully')).toBeInTheDocument();
    });
  });
});
```

---

## Flutter Mobile Testing

### 1. Unit Tests

```dart
// request/test/services/subscription_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:request/src/services/simple_subscription_service.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  group('SimpleSubscriptionService', () => {
    late SimpleSubscriptionService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = SimpleSubscriptionService();
      service.client = mockClient; // Inject mock client
    });

    test('should get subscription plans for country', () async {
      // Arrange
      const country = 'US';
      const responseBody = '''
      {
        "plans": [
          {
            "code": "Pro",
            "name": "Pro Plan",
            "price": 9.99,
            "currency": "USD"
          }
        ]
      }
      ''';

      when(mockClient.get(
        Uri.parse('${service.baseUrl}/simple-subscription/plans?country=$country'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      final result = await service.getSubscriptionPlans(country);

      // Assert
      expect(result['plans'], isA<List>());
      expect(result['plans'].length, 1);
      expect(result['plans'][0]['code'], 'Pro');
    });

    test('should handle subscription error', () async {
      // Arrange
      when(mockClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response('Server Error', 500));

      // Act & Assert
      expect(
        () => service.getSubscriptionPlans('US'),
        throwsA(isA<Exception>()),
      );
    });

    test('should subscribe to plan', () async {
      // Arrange
      const responseBody = '''
      {
        "subscription": {
          "id": "sub_123",
          "status": "active",
          "plan_code": "Pro"
        }
      }
      ''';

      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      final result = await service.subscribeToPlan(
        'Pro',
        'US',
        'stripe',
        'test_token',
      );

      // Assert
      expect(result['subscription']['status'], 'active');
      expect(result['subscription']['plan_code'], 'Pro');
    });
  });
}
```

### 2. Widget Tests

```dart
// request/test/widgets/subscription_plans_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:request/src/pages/subscription_plans_page.dart';
import 'package:request/src/services/simple_subscription_service.dart';

class MockSubscriptionService extends Mock implements SimpleSubscriptionService {}

void main() {
  group('SubscriptionPlansPage', () {
    late MockSubscriptionService mockService;

    setUp(() {
      mockService = MockSubscriptionService();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: Provider<SimpleSubscriptionService>.value(
          value: mockService,
          child: SubscriptionPlansPage(),
        ),
      );
    }

    testWidgets('should display subscription plans', (WidgetTester tester) async {
      // Arrange
      when(mockService.getSubscriptionPlans('US'))
          .thenAnswer((_) async => {
        'plans': [
          {
            'code': 'Free',
            'name': 'Free Plan',
            'price': 0.0,
            'currency': 'USD',
            'response_limit': 3,
          },
          {
            'code': 'Pro',
            'name': 'Pro Plan',
            'price': 9.99,
            'currency': 'USD',
            'response_limit': -1,
          }
        ]
      });

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Free Plan'), findsOneWidget);
      expect(find.text('Pro Plan'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget);
      expect(find.text('\$9.99'), findsOneWidget);
    });

    testWidgets('should handle subscription selection', (WidgetTester tester) async {
      // Arrange
      when(mockService.getSubscriptionPlans('US'))
          .thenAnswer((_) async => {
        'plans': [
          {
            'code': 'Pro',
            'name': 'Pro Plan',
            'price': 9.99,
            'currency': 'USD',
            'response_limit': -1,
          }
        ]
      });

      when(mockService.subscribeToPlan('Pro', 'US', 'stripe', any))
          .thenAnswer((_) async => {
        'subscription': {
          'status': 'active',
          'plan_code': 'Pro'
        }
      });

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final subscribeButton = find.text('Subscribe');
      await tester.tap(subscribeButton);
      await tester.pumpAndSettle();

      // Assert
      verify(mockService.subscribeToPlan('Pro', 'US', 'stripe', any)).called(1);
    });
  });
}
```

### 3. Integration Tests

```dart
// request/integration_test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:request/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('complete subscription flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Navigate to subscriptions
      await tester.tap(find.text('Subscriptions'));
      await tester.pumpAndSettle();

      // Verify plans load
      expect(find.text('Free Plan'), findsOneWidget);
      expect(find.text('Pro Plan'), findsOneWidget);

      // Select Pro plan
      await tester.tap(find.text('Subscribe').last);
      await tester.pumpAndSettle();

      // Complete payment flow (mock)
      await tester.tap(find.text('Confirm Payment'));
      await tester.pumpAndSettle();

      // Verify subscription success
      expect(find.text('Subscription Active'), findsOneWidget);
    });
  });
}
```

---

## Load Testing

### 1. API Load Testing with Artillery

Install Artillery:
```bash
npm install -g artillery
```

Create load test configuration:
```yaml
# artillery-config.yml
config:
  target: 'http://localhost:3001'
  phases:
    - duration: 60
      arrivalRate: 10
    - duration: 120
      arrivalRate: 20
    - duration: 60
      arrivalRate: 50
  defaults:
    headers:
      Content-Type: 'application/json'

scenarios:
  - name: "Authentication Flow"
    weight: 30
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "user{{ $randomInt(1, 1000) }}@test.com"
            password: "password123"
          capture:
            - json: "$.token"
              as: "authToken"
      - get:
          url: "/api/simple-subscription/plans?country=US"
          headers:
            Authorization: "Bearer {{ authToken }}"

  - name: "Subscription Plans"
    weight: 50
    flow:
      - get:
          url: "/api/simple-subscription/plans?country={{ $randomItem(['US', 'CA', 'GB', 'AU']) }}"

  - name: "Payment Gateway Config"
    weight: 20
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "admin@test.com"
            password: "password123"
          capture:
            - json: "$.token"
              as: "adminToken"
      - get:
          url: "/api/admin/payment-gateways/available"
          headers:
            Authorization: "Bearer {{ adminToken }}"
```

Run load test:
```bash
artillery run artillery-config.yml
```

### 2. Database Load Testing

```sql
-- Database performance test queries
-- Test subscription plan queries under load
EXPLAIN ANALYZE 
SELECT p.*, cp.price, cp.currency, cp.response_limit
FROM simple_subscription_plans p
LEFT JOIN simple_subscription_country_pricing cp ON p.code = cp.plan_code
WHERE cp.country_code = 'US' AND cp.is_active = true AND p.is_active = true;

-- Test user subscription lookups
EXPLAIN ANALYZE
SELECT us.*, p.name as plan_name, cp.price, cp.currency
FROM user_simple_subscriptions us
JOIN simple_subscription_plans p ON us.plan_code = p.code
JOIN simple_subscription_country_pricing cp ON p.code = cp.plan_code 
WHERE us.user_id = 'test-user-id' AND cp.country_code = us.country_code;

-- Test usage tracking performance
EXPLAIN ANALYZE
SELECT response_count FROM usage_monthly 
WHERE user_id = 'test-user-id' AND year_month = '202312';
```

### 3. Concurrent User Testing

```javascript
// backend/tests/load.test.js
const request = require('supertest');
const app = require('../app');

describe('Load Testing', () => {
  test('should handle concurrent subscription requests', async () => {
    const promises = [];
    
    // Create 50 concurrent requests
    for (let i = 0; i < 50; i++) {
      promises.push(
        request(app)
          .get('/api/simple-subscription/plans?country=US')
          .expect(200)
      );
    }

    // Wait for all requests to complete
    const results = await Promise.all(promises);
    
    // All should succeed
    expect(results).toHaveLength(50);
    results.forEach(result => {
      expect(result.status).toBe(200);
    });
  });

  test('should handle concurrent payment gateway configurations', async () => {
    const promises = [];
    
    for (let i = 0; i < 20; i++) {
      promises.push(
        request(app)
          .get('/api/admin/payment-gateways/available')
          .set('Authorization', 'Bearer admin-token')
          .expect(200)
      );
    }

    const results = await Promise.all(promises);
    expect(results).toHaveLength(20);
  });
});
```

---

## Security Testing

### 1. Authentication Testing

```javascript
// backend/tests/security.test.js
const request = require('supertest');
const app = require('../app');

describe('Security Tests', () => {
  test('should reject requests without authentication', async () => {
    const response = await request(app)
      .get('/api/simple-subscription/status');

    expect(response.status).toBe(401);
  });

  test('should reject invalid JWT tokens', async () => {
    const response = await request(app)
      .get('/api/simple-subscription/status')
      .set('Authorization', 'Bearer invalid-token');

    expect(response.status).toBe(401);
  });

  test('should prevent SQL injection', async () => {
    const maliciousPayload = "'; DROP TABLE users; --";
    
    const response = await request(app)
      .get(`/api/simple-subscription/plans?country=${maliciousPayload}`);

    // Should not crash and should sanitize input
    expect(response.status).toBe(400);
  });

  test('should encrypt payment gateway credentials', async () => {
    const testCredentials = {
      api_key: 'sensitive_api_key',
      secret_key: 'very_secret_key'
    };

    const response = await request(app)
      .post('/api/admin/payment-gateways/configure')
      .set('Authorization', 'Bearer admin-token')
      .send({
        country_code: 'US',
        payment_gateway_id: 1,
        configuration: testCredentials
      });

    expect(response.status).toBe(200);

    // Verify credentials are encrypted in database
    const db = require('../services/database');
    const result = await db.query(
      'SELECT configuration FROM country_payment_gateways WHERE country_code = $1',
      ['US']
    );

    // Configuration should be encrypted (not plain text)
    expect(result.rows[0].configuration).not.toEqual(testCredentials);
  });
});
```

### 2. Input Validation Testing

```javascript
// Test various input validation scenarios
describe('Input Validation', () => {
  test('should validate email format', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'invalid-email',
        password: 'password123',
        first_name: 'Test',
        last_name: 'User'
      });

    expect(response.status).toBe(400);
    expect(response.body.message).toContain('email');
  });

  test('should validate subscription plan codes', async () => {
    const response = await request(app)
      .post('/api/simple-subscription/subscribe')
      .set('Authorization', 'Bearer valid-token')
      .send({
        plan_code: 'InvalidPlan',
        country_code: 'US',
        payment_method: 'stripe'
      });

    expect(response.status).toBe(400);
  });

  test('should validate country codes', async () => {
    const response = await request(app)
      .get('/api/simple-subscription/plans?country=INVALID');

    expect(response.status).toBe(400);
  });
});
```

---

## Performance Testing

### 1. Database Query Optimization

```sql
-- Create performance test data
INSERT INTO simple_subscription_plans (code, name, default_price, default_currency, default_response_limit)
SELECT 
  'Plan' || i,
  'Test Plan ' || i,
  random() * 100,
  'USD',
  floor(random() * 50)
FROM generate_series(1, 1000) i;

-- Test query performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.*, cp.price, cp.currency 
FROM simple_subscription_plans p
LEFT JOIN simple_subscription_country_pricing cp ON p.code = cp.plan_code
WHERE cp.country_code = 'US' AND p.is_active = true;

-- Create indexes for optimization
CREATE INDEX CONCURRENTLY idx_country_pricing_country_code 
ON simple_subscription_country_pricing(country_code);

CREATE INDEX CONCURRENTLY idx_country_pricing_plan_code 
ON simple_subscription_country_pricing(plan_code);

CREATE INDEX CONCURRENTLY idx_user_subscriptions_user_id 
ON user_simple_subscriptions(user_id);
```

### 2. API Response Time Testing

```javascript
// backend/tests/performance.test.js
const request = require('supertest');
const app = require('../app');

describe('Performance Tests', () => {
  test('subscription plans should respond within 200ms', async () => {
    const start = Date.now();
    
    const response = await request(app)
      .get('/api/simple-subscription/plans?country=US');
    
    const duration = Date.now() - start;
    
    expect(response.status).toBe(200);
    expect(duration).toBeLessThan(200);
  });

  test('payment gateway list should respond within 100ms', async () => {
    const start = Date.now();
    
    const response = await request(app)
      .get('/api/admin/payment-gateways/available')
      .set('Authorization', 'Bearer admin-token');
    
    const duration = Date.now() - start;
    
    expect(response.status).toBe(200);
    expect(duration).toBeLessThan(100);
  });
});
```

---

## Test Automation

### 1. CI/CD Pipeline Testing

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: request_marketplace_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '18'
        
    - name: Install dependencies
      run: |
        cd backend
        npm install
        
    - name: Run tests
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/request_marketplace_test
        JWT_SECRET: test-secret
        GATEWAY_ENCRYPTION_KEY: test-encryption-key-32-characters
      run: |
        cd backend
        npm test

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '18'
        
    - name: Install dependencies
      run: |
        cd admin-react
        npm install
        
    - name: Run tests
      run: |
        cd admin-react
        npm test -- --coverage --watchAll=false

  flutter-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v1
    - uses: actions/setup-java@v1
      with:
        java-version: '12.x'
    - uses: subosito/flutter-action@v1
      with:
        flutter-version: '3.0.0'
    - name: Get dependencies
      run: |
        cd request
        flutter pub get
    - name: Run tests
      run: |
        cd request
        flutter test
```

### 2. Test Data Management

```javascript
// backend/tests/helpers/testData.js
const db = require('../../services/database');

class TestDataHelper {
  static async createTestUser(userData = {}) {
    const defaultUser = {
      email: 'test@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User'
    };

    const user = { ...defaultUser, ...userData };
    
    const result = await db.query(`
      INSERT INTO users (id, email, password_hash, first_name, last_name, role, country_code)
      VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [
      user.email,
      user.password, // In real app, this would be hashed
      user.first_name,
      user.last_name,
      user.role || 'user',
      user.country_code || 'US'
    ]);

    return result.rows[0];
  }

  static async createTestSubscription(userId, planCode = 'TestPlan') {
    const result = await db.query(`
      INSERT INTO user_simple_subscriptions (user_id, plan_code, country_code, status)
      VALUES ($1, $2, 'US', 'active')
      RETURNING *
    `, [userId, planCode]);

    return result.rows[0];
  }

  static async createTestPlan(planData = {}) {
    const defaultPlan = {
      code: 'TestPlan',
      name: 'Test Plan',
      default_price: 9.99,
      default_currency: 'USD',
      default_response_limit: 10
    };

    const plan = { ...defaultPlan, ...planData };

    await db.query(`
      INSERT INTO simple_subscription_plans (code, name, default_price, default_currency, default_response_limit)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (code) DO NOTHING
    `, [plan.code, plan.name, plan.default_price, plan.default_currency, plan.default_response_limit]);

    return plan;
  }

  static async cleanup() {
    await db.query('DELETE FROM user_simple_subscriptions WHERE user_id IN (SELECT id FROM users WHERE email LIKE $1)', ['%@test.com']);
    await db.query('DELETE FROM users WHERE email LIKE $1', ['%@test.com']);
    await db.query('DELETE FROM simple_subscription_plans WHERE code LIKE $1', ['Test%']);
  }
}

module.exports = TestDataHelper;
```

---

## Test Running Commands

### Backend Tests
```bash
cd backend

# Run all tests
npm test

# Run specific test file
npm test auth.test.js

# Run tests with coverage
npm test -- --coverage

# Run tests in watch mode
npm test -- --watch
```

### Frontend Tests
```bash
cd admin-react

# Run all tests
npm test

# Run tests with coverage
npm test -- --coverage --watchAll=false

# Run specific test
npm test PaymentGatewayManager.test.js
```

### Flutter Tests
```bash
cd request

# Run all tests
flutter test

# Run specific test file
flutter test test/services/subscription_service_test.dart

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter drive --target=integration_test/app_test.dart
```

### Load Testing
```bash
# Install Artillery globally
npm install -g artillery

# Run load test
artillery run artillery-config.yml

# Quick load test
artillery quick --duration 60 --rate 10 http://localhost:3001/api/simple-subscription/plans?country=US
```

---

This comprehensive testing guide ensures your subscription and payment gateway system is thoroughly tested across all components, from unit tests to load testing. Regular execution of these tests will help maintain system reliability and catch issues early in development.
