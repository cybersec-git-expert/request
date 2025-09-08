/// Contact verification service integrating with backend REST endpoints.
/// NOTE: Original stub returned fixed values causing UI to always show
///       phone verification as pending. This implementation calls the
///       real business verification phone endpoints.
import 'api_client.dart';
import 'enhanced_user_service.dart';

enum LinkedCredentialsStatus { none, partial, complete }

class ContactVerificationService {
  ContactVerificationService._();
  static final ContactVerificationService instance =
      ContactVerificationService._();

  // Cache last phone + otp id so verify call doesn't need phone again
  String? _lastPhoneNumber;

  /// Normalize phone number to a consistent format for comparison
  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digits = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // If starts with 94 (Sri Lanka code), ensure it has + prefix
    if (digits.startsWith('94') && digits.length >= 11) {
      return '+$digits';
    }

    // If it's a local number (9 digits), add Sri Lanka code
    if (digits.length == 9) {
      return '+94$digits';
    }

    // If it's 10 digits starting with 0, replace 0 with country code
    if (digits.length == 10 && digits.startsWith('0')) {
      return '+94${digits.substring(1)}';
    }

    // Return with + prefix if not already there
    return digits.startsWith('94') ? '+$digits' : '+94$digits';
  }

  /// Check if two phone numbers are equivalent (normalized comparison)
  bool _arePhoneNumbersEqual(String? phone1, String? phone2) {
    if (phone1 == null || phone2 == null) return false;

    try {
      final normalized1 = _normalizePhoneNumber(phone1);
      final normalized2 = _normalizePhoneNumber(phone2);
      return normalized1 == normalized2;
    } catch (e) {
      // Fallback to exact string comparison
      return phone1 == phone2;
    }
  }

  // Generic (legacy) helpers retained for compatibility
  Future<bool> sendPhoneOtp(String phone) async => true;
  Future<bool> verifyPhoneOtp(String phone, String code) async => true;
  Future<bool> sendEmailOtp(String email) async => true;
  Future<bool> verifyEmailOtp(String email, String code) async => true;

  /// Start phone verification for business (send OTP)
  Future<Map<String, dynamic>> startBusinessPhoneVerification({
    required String phoneNumber,
    void Function(String verificationId)? onCodeSent,
    void Function(String error)? onError,
  }) async {
    try {
      _lastPhoneNumber = phoneNumber;
      final resp = await ApiClient.instance.post(
        '/api/business-verifications/verify-phone/send-otp',
        data: {
          'phoneNumber': phoneNumber,
        },
      );

      final dataWrapper = resp.data;
      if (resp.isSuccess && dataWrapper is Map<String, dynamic>) {
        // Backend returns flat payload { success, otpId, phoneNumber, ... }
        final otpId = dataWrapper['otpId'] as String? ?? dataWrapper['otp_id'];
        if (otpId != null) {
          onCodeSent?.call(otpId);
        }
        return dataWrapper;
      }
      final error = (dataWrapper is Map && dataWrapper['message'] != null)
          ? dataWrapper['message'].toString()
          : 'Failed to send OTP';
      onError?.call(error);
      return {'success': false, 'error': error};
    } catch (e) {
      final msg = 'Send OTP failed: $e';
      onError?.call(msg);
      return {'success': false, 'error': msg};
    }
  }

  /// Verify phone OTP
  Future<Map<String, dynamic>> verifyBusinessPhoneOTP({
    required String verificationId, // maps to otpId
    required String otp,
  }) async {
    try {
      final phone = _lastPhoneNumber;
      if (phone == null) {
        return {
          'success': false,
          'error': 'No phone number cached for verification'
        };
      }
      final resp = await ApiClient.instance.post(
        '/api/business-verifications/verify-phone/verify-otp',
        data: {
          'phoneNumber': phone,
          'otp': otp,
          'otpId': verificationId,
        },
      );
      final dataWrapper = resp.data;
      if (resp.isSuccess && dataWrapper is Map<String, dynamic>) {
        // Normalize common flags
        return {
          ...dataWrapper,
          'success': dataWrapper['success'] == true,
          'verified': dataWrapper['verified'] == true,
          'phoneVerified': dataWrapper['userPhoneVerified'] == true ||
              (dataWrapper['businessVerification'] is Map &&
                  (dataWrapper['businessVerification']['phone_verified'] ==
                      true)),
        };
      }
      return {
        'success': false,
        'error': (dataWrapper is Map && dataWrapper['message'] != null)
            ? dataWrapper['message'].toString()
            : 'Verification failed'
      };
    } catch (e) {
      return {'success': false, 'error': 'Verify OTP failed: $e'};
    }
  }

  /// Trigger email verification (placeholder - integrate when backend ready)
  Future<Map<String, dynamic>> sendBusinessEmailVerification(
          {required String email}) async =>
      {'success': true, 'message': 'Email flow not yet implemented'};

  // ========== Driver Verification Methods ==========

  /// Start driver phone verification (Send OTP)
  Future<Map<String, dynamic>> startDriverPhoneVerification({
    required String phoneNumber,
  }) async {
    try {
      _lastPhoneNumber = phoneNumber;
      final resp = await ApiClient.instance.post(
        '/api/driver-verifications/verify-phone/send-otp',
        data: {'phoneNumber': phoneNumber},
      );
      final dataWrapper = resp.data;
      if (resp.isSuccess && dataWrapper is Map<String, dynamic>) {
        return {
          ...dataWrapper,
          'success': dataWrapper['success'] == true,
          'verificationId':
              dataWrapper['otpId'] ?? dataWrapper['verificationId'],
        };
      }
      return {
        'success': false,
        'error': (dataWrapper is Map && dataWrapper['message'] != null)
            ? dataWrapper['message'].toString()
            : 'Failed to start verification'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Start driver phone verification failed: $e'
      };
    }
  }

  /// Verify driver phone OTP
  Future<Map<String, dynamic>> verifyDriverPhoneOTP({
    required String verificationId, // maps to otpId
    required String otp,
  }) async {
    try {
      final phone = _lastPhoneNumber;
      if (phone == null) {
        return {
          'success': false,
          'error': 'No phone number cached for verification'
        };
      }
      final resp = await ApiClient.instance.post(
        '/api/driver-verifications/verify-phone/verify-otp',
        data: {
          'phoneNumber': phone,
          'otp': otp,
          'otpId': verificationId,
        },
      );
      final dataWrapper = resp.data;
      if (resp.isSuccess && dataWrapper is Map<String, dynamic>) {
        return {
          ...dataWrapper,
          'success': dataWrapper['success'] == true,
          'verified': dataWrapper['verified'] == true,
          'phoneVerified': dataWrapper['userPhoneVerified'] == true,
        };
      }
      return {
        'success': false,
        'error': (dataWrapper is Map && dataWrapper['message'] != null)
            ? dataWrapper['message'].toString()
            : 'Verification failed'
      };
    } catch (e) {
      return {'success': false, 'error': 'Verify driver OTP failed: $e'};
    }
  }

  /// Compute overall linked credential status from backend record.
  Future<LinkedCredentialsStatus> getLinkedCredentialsStatus() async {
    try {
      final user = await EnhancedUserService.instance.getCurrentUser();
      if (user == null) return LinkedCredentialsStatus.none;
      final resp = await ApiClient.instance
          .get('/api/business-verifications/user/${user.id}');
      if (!resp.isSuccess || resp.data == null) {
        return LinkedCredentialsStatus.none;
      }
      final wrapper = resp.data as Map<String, dynamic>;
      final data = wrapper['data'] as Map<String, dynamic>?;
      if (data == null) return LinkedCredentialsStatus.none;
      final phoneVerified = data['phone_verified'] == true;
      final emailVerified = data['email_verified'] == true;
      if (phoneVerified && emailVerified)
        return LinkedCredentialsStatus.complete;
      if (phoneVerified || emailVerified)
        return LinkedCredentialsStatus.partial;
      return LinkedCredentialsStatus.none;
    } catch (_) {
      // Fallback – treat unknown as partial to avoid blocking UX
      return LinkedCredentialsStatus.partial;
    }
  }

  /// Check unified verification status across ALL verification types (business, driver, user)
  Future<Map<String, dynamic>> checkUnifiedVerificationStatus({
    String? phoneNumber,
    String? email,
  }) async {
    try {
      final user = await EnhancedUserService.instance.getCurrentUserModel();
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'phoneVerified': false,
          'emailVerified': false,
        };
      }

      bool phoneVerified = false;
      bool emailVerified = false;

      // First check the main users table verification status
      if (phoneNumber != null &&
          _arePhoneNumbersEqual(user.phoneNumber, phoneNumber)) {
        phoneVerified = user.isPhoneVerified;
        print('📱 Phone verified from users table: $phoneVerified');
      }

      if (email != null && user.email == email) {
        emailVerified = user.isEmailVerified;
        print('📧 Email verified from users table: $emailVerified');
      }

      // Check business verification status (only if not already verified)
      if (!phoneVerified || !emailVerified) {
        try {
          final businessResp = await ApiClient.instance
              .get('/api/business-verifications/user/${user.id}');
          if (businessResp.isSuccess && businessResp.data != null) {
            final wrapper = businessResp.data as Map<String, dynamic>;
            final businessData = wrapper['data'] as Map<String, dynamic>?;
            if (businessData != null) {
              // Check if phone matches and is verified
              if (phoneNumber != null && !phoneVerified) {
                final businessPhone = businessData['businessPhone'] as String?;
                if (_arePhoneNumbersEqual(businessPhone, phoneNumber) &&
                    (businessData['phoneVerified'] == true ||
                        businessData['phone_verified'] == true)) {
                  phoneVerified = true;
                  print(
                      '📱 Phone verified from business verification: $phoneVerified');
                }
              }
              // Check if email matches and is verified
              if (email != null && !emailVerified) {
                final businessEmail = businessData['businessEmail'] as String?;
                if (businessEmail == email &&
                    (businessData['emailVerified'] == true ||
                        businessData['email_verified'] == true)) {
                  emailVerified = true;
                  print(
                      '📧 Email verified from business verification: $emailVerified');
                }
              }
            }
          }
        } catch (e) {
          print('Error checking business verification: $e');
        }
      }

      // Check driver verification status (only if not already verified)
      if (!phoneVerified || !emailVerified) {
        try {
          final driverResp = await ApiClient.instance
              .get('/api/driver-verifications/user/${user.id}');
          if (driverResp.isSuccess && driverResp.data != null) {
            final wrapper = driverResp.data as Map<String, dynamic>;
            final driverData = wrapper['data'] as Map<String, dynamic>?;
            if (driverData != null) {
              // Check if phone matches and is verified
              if (phoneNumber != null && !phoneVerified) {
                final driverPhone = driverData['phoneNumber'] as String?;
                if (_arePhoneNumbersEqual(driverPhone, phoneNumber) &&
                    driverData['phoneVerified'] == true) {
                  phoneVerified = true;
                  print(
                      '📱 Phone verified from driver verification: $phoneVerified');
                }
              }
              // Check if email matches and is verified
              if (email != null && !emailVerified) {
                final driverEmail = driverData['email'] as String?;
                if (driverEmail == email &&
                    driverData['emailVerified'] == true) {
                  emailVerified = true;
                  print(
                      '📧 Email verified from driver verification: $emailVerified');
                }
              }
            }
          }
        } catch (e) {
          print('Error checking driver verification: $e');
        }
      }

      print('🔍 Final unified verification status:');
      print('  Phone ($phoneNumber): $phoneVerified');
      print('  Email ($email): $emailVerified');

      return {
        'success': true,
        'phoneVerified': phoneVerified,
        'emailVerified': emailVerified,
        'message': 'Unified verification status checked successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Check unified verification failed: $e',
        'phoneVerified': false,
        'emailVerified': false,
      };
    }
  }

  /// Check verification status for a specific phone/email (unified endpoint)
  Future<Map<String, dynamic>> checkVerificationStatus({
    String? phoneNumber,
    String? email,
    String? userId,
    String endpoint = '/api/business-verifications/check-verification-status',
  }) async {
    try {
      final user = userId != null
          ? null
          : await EnhancedUserService.instance.getCurrentUser();
      final actualUserId = userId ?? user?.id;

      if (actualUserId == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'phoneVerified': false,
          'emailVerified': false,
        };
      }

      final resp = await ApiClient.instance.post(
        endpoint,
        data: {
          'phoneNumber': phoneNumber,
          'email': email,
          if (endpoint.contains('driver')) 'userId': actualUserId,
        },
      );

      if (resp.isSuccess && resp.data is Map<String, dynamic>) {
        return resp.data as Map<String, dynamic>;
      }

      return {
        'success': false,
        'error': 'Failed to check verification status',
        'phoneVerified': false,
        'emailVerified': false,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Check verification failed: $e',
        'phoneVerified': false,
        'emailVerified': false,
      };
    }
  }
}

extension LinkedCredentialsStatusX on LinkedCredentialsStatus {
  bool get businessPhoneVerified =>
      this == LinkedCredentialsStatus.complete; // refined in UI using record
  bool get businessEmailVerified =>
      this == LinkedCredentialsStatus.complete; // refined in UI using record
  bool get isAllVerified => this == LinkedCredentialsStatus.complete;
}

extension VerificationResultMapX on Map<String, dynamic> {
  bool get success => this['success'] == true;
  String? get error => this['error'] as String? ?? this['message'] as String?;
  bool get isCredentialConflict => this['isCredentialConflict'] == true;
}
