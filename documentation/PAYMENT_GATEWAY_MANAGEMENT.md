# Payment Gateway Management System

## Overview

The Payment Gateway Management System allows country administrators to configure and manage payment methods for their specific regions. This system supports multiple payment providers and provides secure credential storage with role-based access control.

## Supported Payment Gateways

### 1. Stripe
- **Countries Supported**: US, CA, GB, AU, SG, IN, LK
- **Configuration Fields**:
  - Publishable Key (Public)
  - Secret Key (Encrypted)
  - Webhook Secret (Encrypted, Optional)

### 2. PayPal
- **Countries Supported**: US, CA, GB, AU, IN, LK
- **Configuration Fields**:
  - Client ID (Public)
  - Client Secret (Encrypted)
  - Environment (sandbox/live)

### 3. Razorpay
- **Countries Supported**: IN
- **Configuration Fields**:
  - Key ID (Public)
  - Key Secret (Encrypted)
  - Webhook Secret (Encrypted, Optional)

### 4. PayHere
- **Countries Supported**: LK
- **Configuration Fields**:
  - Merchant ID (Public)
  - Merchant Secret (Encrypted)
  - Environment (sandbox/live)

### 5. Bank Transfer
- **Countries Supported**: All
- **Configuration Fields**:
  - Bank Name
  - Account Number
  - Account Holder Name
  - Branch/Routing Code (Optional)

## Database Schema

### payment_gateways
```sql
CREATE TABLE payment_gateways (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    supported_countries TEXT[],
    requires_api_key BOOLEAN DEFAULT true,
    requires_secret_key BOOLEAN DEFAULT true,
    requires_webhook_url BOOLEAN DEFAULT false,
    configuration_fields JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### country_payment_gateways
```sql
CREATE TABLE country_payment_gateways (
    id SERIAL PRIMARY KEY,
    country_code CHAR(2) NOT NULL,
    payment_gateway_id INTEGER NOT NULL REFERENCES payment_gateways(id),
    configuration JSONB NOT NULL, -- Encrypted configuration data
    is_active BOOLEAN DEFAULT true,
    is_primary BOOLEAN DEFAULT false, -- One primary gateway per country
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(country_code, payment_gateway_id)
);
```

### payment_gateway_fees
```sql
CREATE TABLE payment_gateway_fees (
    id SERIAL PRIMARY KEY,
    country_payment_gateway_id INTEGER NOT NULL REFERENCES country_payment_gateways(id),
    transaction_type VARCHAR(50) NOT NULL, -- 'subscription', 'one_time', 'refund'
    fee_type VARCHAR(20) NOT NULL, -- 'percentage', 'fixed', 'combined'
    percentage_fee DECIMAL(5,2) DEFAULT 0, -- e.g., 2.90 for 2.9%
    fixed_fee DECIMAL(10,2) DEFAULT 0, -- e.g., 0.30 for $0.30
    currency CHAR(3) NOT NULL,
    minimum_amount DECIMAL(10,2) DEFAULT 0,
    maximum_amount DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints

### Get Available Gateways
```http
GET /api/admin/payment-gateways/gateways/{countryCode}
Authorization: Bearer {token}
```

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
      "configuration_fields": {...},
      "country_gateway_id": 123,
      "configured": true,
      "is_primary": false,
      "configured_at": "2025-09-12T10:30:00.000Z"
    }
  ]
}
```

### Configure Gateway
```http
POST /api/admin/payment-gateways/gateways/{countryCode}/configure
Authorization: Bearer {token}
Content-Type: application/json

{
  "gatewayId": 1,
  "configuration": {
    "api_key": "pk_test_...",
    "secret_key": "sk_test_...",
    "webhook_secret": "whsec_..."
  },
  "isPrimary": true
}
```

### Get Gateway Configuration
```http
GET /api/admin/payment-gateways/gateways/{countryCode}/{gatewayId}/config
Authorization: Bearer {token}
```

### Toggle Gateway Status
```http
PATCH /api/admin/payment-gateways/gateways/{countryCode}/{gatewayId}/toggle
Authorization: Bearer {token}
Content-Type: application/json

{
  "isActive": true
}
```

### Get Primary Gateway for Payment Processing
```http
GET /api/admin/payment-gateways/gateways/{countryCode}/primary
```

### Configure Gateway Fees
```http
POST /api/admin/payment-gateways/gateways/{countryCode}/{gatewayId}/fees
Authorization: Bearer {token}
Content-Type: application/json

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
    }
  ]
}
```

## Security Features

### Credential Encryption
- All sensitive fields (secrets, keys, passwords) are encrypted using AES-256-CBC
- Encryption key should be stored in environment variables
- Decryption only occurs during payment processing

### Role-Based Access Control
- **Super Admin**: Can configure gateways for all countries
- **Country Admin**: Can only configure gateways for their assigned country
- All endpoints require authentication via JWT tokens

### Audit Trail
- All configuration changes are logged with user ID and timestamp
- Gateway status changes are tracked
- Payment processing events are recorded

## Admin Interface Usage

### Accessing Payment Gateway Management
1. Login to the admin panel
2. Navigate to "Payment Gateways" in the sidebar
3. View available gateways for your country

### Configuring a New Gateway
1. Click "Configure" on an unconfigured gateway
2. Fill in the required configuration fields:
   - Public keys/IDs can be entered as plain text
   - Secret keys will be automatically encrypted
   - Select environment (sandbox/live) where applicable
3. Click "Save Configuration"
4. Optionally set as primary gateway

### Managing Existing Gateways
1. Click "Edit" on a configured gateway to update settings
2. Use the toggle switch to activate/deactivate gateways
3. Only one gateway can be set as primary per country

### Setting Up Payment Fees
1. Configure the gateway first
2. Access fee management (if available)
3. Set percentage and/or fixed fees for different transaction types
4. Specify currency and amount limits

## Integration with Subscription System

### Payment Flow
1. User selects a subscription plan
2. System identifies primary payment gateway for user's country
3. Creates payment session with the configured gateway
4. Processes payment using encrypted credentials
5. Updates subscription status upon payment confirmation

### Subscription Lifecycle
1. **Free Plans**: No payment processing required
2. **Paid Plans**: Require active payment gateway configuration
3. **Renewals**: Automatic processing using stored payment methods
4. **Failures**: Downgrade to free plan after grace period

## Environment Variables

```env
# Payment Gateway Encryption
GATEWAY_ENCRYPTION_KEY=your-256-bit-encryption-key

# Database Configuration
DATABASE_URL=postgresql://username:password@host:port/database

# JWT Configuration
JWT_SECRET=your-jwt-secret-key
```

## Error Handling

### Common Error Codes
- `401 Unauthorized`: Invalid or missing authentication token
- `403 Forbidden`: Insufficient permissions for country/gateway
- `404 Not Found`: Gateway or configuration not found
- `409 Conflict`: Gateway already configured
- `500 Internal Server Error`: Database or encryption errors

### Error Response Format
```json
{
  "success": false,
  "error": "Error message description",
  "code": "ERROR_CODE"
}
```

## Best Practices

### Security
1. **Never log sensitive credentials** in plain text
2. **Rotate encryption keys** regularly
3. **Use environment-specific keys** (sandbox for development)
4. **Implement proper HTTPS** in production
5. **Regular security audits** of gateway configurations

### Operations
1. **Test gateway configurations** in sandbox mode first
2. **Monitor payment success rates** per gateway
3. **Set up webhook endpoints** for real-time payment updates
4. **Regular backup** of gateway configurations
5. **Document gateway-specific requirements** for each country

### Performance
1. **Cache primary gateway** configurations
2. **Implement retry logic** for failed payments
3. **Monitor gateway response times**
4. **Load balance** between multiple gateways if needed

## Troubleshooting

### Gateway Configuration Issues
1. **Invalid credentials**: Verify API keys in gateway provider dashboard
2. **Webhook failures**: Check webhook URL accessibility and signature validation
3. **Currency mismatch**: Ensure gateway supports the country's currency
4. **Country restrictions**: Verify gateway availability in target country

### Payment Processing Issues
1. **Check gateway logs** in provider dashboard
2. **Verify webhook configurations** are active
3. **Test with small amounts** first
4. **Monitor error rates** and response times

## Migration Guide

### Adding New Payment Gateways
1. Insert gateway definition in `payment_gateways` table
2. Define configuration fields in JSON format
3. Update supported countries array
4. Test configuration and payment flow

### Updating Existing Gateways
1. Update configuration fields if API changes
2. Migrate existing configurations to new format
3. Test backward compatibility
4. Communicate changes to country admins

## Support

For technical support or questions about payment gateway integration:
- Email: support@requestmarketplace.com
- Documentation: https://docs.requestmarketplace.com
- Admin Help: Available in admin panel under "Help" section
