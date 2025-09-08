# Email Verification API Documentation

## Base URL
```
Production: https://api.requestmarketplace.com
Development: http://localhost:3001
```

## Authentication
All endpoints require JWT authentication via Bearer token in the Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

---

## Email Verification Endpoints

### 1. Send Email OTP

**Endpoint**: `POST /api/email-verification/send-otp`

**Description**: Sends a verification OTP to the specified email address.

**Request Body**:
```json
{
  "email": "user@example.com",
  "purpose": "business"
}
```

**Parameters**:
- `email` (string, required): Email address to verify
- `purpose` (string, optional): Purpose of verification. Default: "verification"

**Response Success** (200):
```json
{
  "success": true,
  "message": "Verification code sent to your email",
  "otpId": "uuid-string",
  "expiresIn": 600
}
```

**Response Already Verified** (200):
```json
{
  "success": true,
  "message": "Email is already verified",
  "alreadyVerified": true
}
```

**Response Error** (400/500):
```json
{
  "success": false,
  "message": "Invalid email format",
  "error": "Detailed error message"
}
```

---

### 2. Verify Email OTP

**Endpoint**: `POST /api/email-verification/verify-otp`

**Description**: Verifies the OTP code sent to the email address.

**Request Body**:
```json
{
  "email": "user@example.com",
  "otp": "123456",
  "otpId": "uuid-string",
  "purpose": "business"
}
```

**Parameters**:
- `email` (string, required): Email address being verified
- `otp` (string, required): 6-digit OTP code
- `otpId` (string, required): OTP ID from send-otp response
- `purpose` (string, optional): Purpose of verification

**Response Success** (200):
```json
{
  "success": true,
  "message": "Email verified successfully",
  "emailVerified": true,
  "verificationSource": "otp"
}
```

**Response Error** (400):
```json
{
  "success": false,
  "message": "Invalid OTP"
}
```

---

### 3. Check Email Verification Status

**Endpoint**: `GET /api/email-verification/status/:email`

**Description**: Checks the current verification status of an email address.

**Parameters**:
- `email` (string, required): URL-encoded email address

**Response Verified** (200):
```json
{
  "success": true,
  "verified": true,
  "verifiedAt": "2025-08-21T10:30:00.000Z",
  "purpose": "business",
  "verificationMethod": "registration"
}
```

**Response Not Verified** (200):
```json
{
  "success": true,
  "verified": false,
  "message": "Email not found or not verified"
}
```

---

### 4. List User's Verified Emails

**Endpoint**: `GET /api/email-verification/list`

**Description**: Lists all verified emails for the authenticated user.

**Response** (200):
```json
{
  "success": true,
  "emails": [
    {
      "email": "user@example.com",
      "verified": true,
      "verifiedAt": "2025-08-21T10:30:00.000Z",
      "purpose": "registration",
      "verificationMethod": "registration",
      "isPrimary": true
    },
    {
      "email": "business@example.com",
      "verified": true,
      "verifiedAt": "2025-08-21T11:00:00.000Z",
      "purpose": "business",
      "verificationMethod": "otp",
      "isPrimary": false
    }
  ],
  "total": 2
}
```

---

## Admin Email Management Endpoints

*Note: These endpoints require admin privileges*

### 1. Get User Emails (Admin)

**Endpoint**: `GET /api/admin/email-management/user-emails`

**Description**: Retrieves all user emails for admin management.

**Query Parameters**:
- `page` (number, optional): Page number. Default: 1
- `limit` (number, optional): Items per page. Default: 50
- `search` (string, optional): Search query for email/user

**Response** (200):
```json
{
  "success": true,
  "emails": [
    {
      "id": 1,
      "user_id": "uuid",
      "email_address": "user@example.com",
      "is_verified": true,
      "verified_at": "2025-08-21T10:30:00.000Z",
      "purpose": "business",
      "verification_method": "otp",
      "user_name": "John Doe",
      "created_at": "2025-08-21T10:00:00.000Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 150,
    "totalPages": 3
  }
}
```

---

### 2. Get Email Statistics (Admin)

**Endpoint**: `GET /api/admin/email-management/stats`

**Description**: Retrieves email verification statistics.

**Response** (200):
```json
{
  "success": true,
  "stats": {
    "total_emails": 1250,
    "verified_emails": 1100,
    "pending_emails": 150,
    "registration_verified": 800,
    "otp_verified": 300,
    "business_emails": 600,
    "driver_emails": 500
  },
  "recentVerifications": [
    {
      "email_address": "user@example.com",
      "verified_at": "2025-08-21T10:30:00.000Z",
      "verification_method": "otp",
      "display_name": "John Doe"
    }
  ]
}
```

---

### 3. Toggle Email Verification (Admin)

**Endpoint**: `POST /api/admin/email-management/toggle-verification`

**Description**: Toggles the verification status of an email address.

**Request Body**:
```json
{
  "emailId": "123",
  "verified": true
}
```

**Response** (200):
```json
{
  "success": true,
  "message": "Email verification enabled successfully",
  "email": {
    "id": 123,
    "email_address": "user@example.com",
    "is_verified": true,
    "verified_at": "2025-08-21T10:30:00.000Z"
  }
}
```

---

### 4. Manual Email Verification (Admin)

**Endpoint**: `POST /api/admin/email-management/manual-verify`

**Description**: Manually verifies an email address for a user.

**Request Body**:
```json
{
  "userId": "user-uuid",
  "email": "user@example.com",
  "purpose": "business"
}
```

**Response** (200):
```json
{
  "success": true,
  "message": "Email manually verified by admin",
  "email": {
    "id": 124,
    "user_id": "user-uuid",
    "email_address": "user@example.com",
    "is_verified": true,
    "verification_method": "admin"
  }
}
```

---

### 5. Get OTP History (Admin)

**Endpoint**: `GET /api/admin/email-management/otp-history`

**Description**: Retrieves OTP verification history.

**Query Parameters**:
- `page` (number, optional): Page number
- `limit` (number, optional): Items per page
- `email` (string, optional): Filter by email address

**Response** (200):
```json
{
  "success": true,
  "otpHistory": [
    {
      "id": 1,
      "email": "user@example.com",
      "otp": "123456",
      "purpose": "business",
      "verified": true,
      "verified_at": "2025-08-21T10:30:00.000Z",
      "attempts": 1,
      "created_at": "2025-08-21T10:25:00.000Z",
      "display_name": "John Doe"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 100,
    "totalPages": 2
  }
}
```

---

## Error Codes

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 400 | Bad Request - Invalid parameters |
| 401 | Unauthorized - Invalid or missing token |
| 403 | Forbidden - Insufficient privileges |
| 404 | Not Found - Resource not found |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Internal Server Error |

---

## Rate Limiting

- **OTP Sending**: Maximum 5 requests per email per hour
- **OTP Verification**: Maximum 3 attempts per OTP
- **General API**: 100 requests per minute per user

---

## Integration Examples

### JavaScript/Node.js
```javascript
const axios = require('axios');

// Send OTP
const sendOTP = async (email, purpose) => {
  try {
    const response = await axios.post('http://localhost:3001/api/email-verification/send-otp', {
      email,
      purpose
    }, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    return response.data;
  } catch (error) {
    console.error('Error sending OTP:', error.response.data);
    throw error;
  }
};

// Verify OTP
const verifyOTP = async (email, otp, otpId) => {
  try {
    const response = await axios.post('http://localhost:3001/api/email-verification/verify-otp', {
      email,
      otp,
      otpId
    }, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    return response.data;
  } catch (error) {
    console.error('Error verifying OTP:', error.response.data);
    throw error;
  }
};
```

### Flutter/Dart
```dart
import 'package:dio/dio.dart';

class EmailVerificationService {
  final Dio _dio;
  final String baseUrl;
  
  EmailVerificationService(this._dio, this.baseUrl);
  
  Future<Map<String, dynamic>> sendOTP(String email, {String purpose = 'verification'}) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/email-verification/send-otp',
        data: {
          'email': email,
          'purpose': purpose,
        },
      );
      
      return response.data;
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }
  
  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String otp,
    required String otpId,
    String purpose = 'verification',
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/email-verification/verify-otp',
        data: {
          'email': email,
          'otp': otp,
          'otpId': otpId,
          'purpose': purpose,
        },
      );
      
      return response.data;
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }
}
```

---

## Testing

### Test Credentials
- **Test Email**: Use any valid email address
- **Test Environment**: `http://localhost:3001`
- **Admin Access**: Requires admin role in JWT token

### Example Test Flow
1. Login to get JWT token
2. Send OTP to test email
3. Check email for OTP code
4. Verify OTP with received code
5. Check verification status

---

**API Version**: 1.0.0
**Last Updated**: August 21, 2025
**Contact**: support@requestmarketplace.com
