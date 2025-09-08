import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// REST API Authentication Service
/// Replaces Firebase Auth with JWT-based authentication
class RestAuthService {
  static final ApiClient _apiClient = ApiClient.instance;
  static RestAuthService? _instance;
  static RestAuthService get instance =>
      _instance ??= RestAuthService._internal();

  RestAuthService._internal();
  // Cache last normalized phone used for OTP to ensure verify uses same value
  String? _lastOtpPhoneE164;

  /// Current user data
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// Check if user is currently authenticated
  Future<bool> isAuthenticated() async {
    if (_currentUser != null) return true;

    final isAuth = await _apiClient.isAuthenticated();
    if (isAuth) {
      // Try to get user profile to verify token
      final profileResult = await getUserProfile();
      return profileResult.success;
    }

    return false;
  }

  /// Register new user
  Future<AuthResult> register({
    required String email,
    required String password,
    String? displayName,
    String? phone,
    Map<String, dynamic>? extra,
  }) async {
    try {
      if (kDebugMode) {
        print(
            '🔐 [register] email param runtimeType=${email.runtimeType} value="$email" displayName="$displayName" phone="$phone"');
      }
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'email': email.toLowerCase().trim(),
          'password': password,
          if (displayName != null) 'display_name': displayName,
          if (phone != null) 'phone': phone,
          if (extra != null) ...extra,
        },
      );

      if (kDebugMode) {
        print(
            '🔐 [register] raw api response success=${response.isSuccess} dataType=${response.data.runtimeType} data=${response.data} error=${response.error}');
      }

      if (response.isSuccess && response.data != null) {
        final raw = response.data!;
        Map<String, dynamic>? container;
        // Accept either flat {token,user} or nested {data:{token,user}}
        if (raw['token'] != null || raw['user'] != null) {
          container = raw;
        } else if (raw['data'] is Map<String, dynamic>) {
          container = raw['data'] as Map<String, dynamic>;
        }
        if (kDebugMode) {
          print('🔐 [register] container keys=${container?.keys}');
        }
        if (container != null) {
          final token = container['token'] as String?;
          final refreshToken = container['refreshToken'] as String?;
          final userData = container['user'] as Map<String, dynamic>?;
          if (kDebugMode) {
            print(
                '🔐 [register] tokenType=${token.runtimeType} refreshType=${refreshToken.runtimeType} userDataType=${userData.runtimeType}');
            print('🔐 [register] userData=$userData');
          }
          if (token != null && userData != null) {
            await _apiClient.saveToken(token);
            if (refreshToken != null) {
              await _apiClient.saveRefreshToken(refreshToken);
            }
            _currentUser = UserModel.fromJson(userData);
            return AuthResult(
              success: true,
              user: _currentUser,
              token: token,
              message: response.message ?? 'Registration successful',
            );
          }
        }
      }

      return AuthResult(
        success: false,
        error: response.error ?? 'Registration failed',
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('❌ [register] exception=$e');
        print(st);
      }
      return AuthResult(
        success: false,
        error: 'Registration failed: ${e.toString()}',
      );
    }
  }

  /// Login with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'email': email.toLowerCase().trim(),
          'password': password,
        },
      );

      if (response.isSuccess && response.data != null) {
        final raw = response.data!;
        Map<String, dynamic>? container;
        if (raw['token'] != null || raw['user'] != null) {
          container = raw;
        } else if (raw['data'] is Map<String, dynamic>) {
          container = raw['data'] as Map<String, dynamic>;
        }
        if (container != null) {
          final token = container['token'] as String?;
          final refreshToken = container['refreshToken'] as String?;
          final userData = container['user'] as Map<String, dynamic>?;
          if (token != null && userData != null) {
            await _apiClient.saveToken(token);
            if (refreshToken != null) {
              await _apiClient.saveRefreshToken(refreshToken);
            }
            _currentUser = UserModel.fromJson(userData);
            return AuthResult(
              success: true,
              user: _currentUser,
              token: token,
              message: response.message ?? 'Login successful',
            );
          }
        }
      }

      return AuthResult(
        success: false,
        error: response.error ?? 'Login failed',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      return AuthResult(
        success: false,
        error: 'Login failed: ${e.toString()}',
      );
    }
  }

  /// Check if user exists by email or phone
  Future<bool> checkUserExists(String emailOrPhone) async {
    try {
      if (kDebugMode) {
        print('🔍 Checking if user exists: $emailOrPhone');
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/flutter/auth/check-user-exists',
        data: {
          'emailOrPhone': emailOrPhone.toLowerCase().trim(),
        },
      );

      if (kDebugMode) {
        print('📱 checkUserExists response: ${response.data}');
      }

      if (response.isSuccess && response.data != null) {
        final exists = response.data!['exists'] as bool? ?? false;
        if (kDebugMode) {
          print('👤 User exists: $exists');
          print('🎯 checkUserExists returning: $exists');
        }
        return exists;
      }

      if (kDebugMode) {
        print('❌ checkUserExists: response not successful or data is null');
        print('📊 Response success: ${response.isSuccess}');
        print('📊 Response data: ${response.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Check user exists error: $e');
      }
      return false;
    }
  }

  /// Send OTP for registration/verification
  Future<OTPResult> sendOTP({
    required String emailOrPhone,
    required bool isEmail,
    required String countryCode,
  }) async {
    try {
      ApiResponse<Map<String, dynamic>> response;

      if (isEmail) {
        // Use legacy email endpoint for now
        response = await _apiClient.post<Map<String, dynamic>>(
          '/api/auth/send-email-otp',
          data: {'email': emailOrPhone.toLowerCase().trim()},
        );
      } else {
        // Normalize to E.164 if possible (e.g., 072xxxxxxx + '+94' => +9472xxxxxxx)
        String phone = emailOrPhone.trim();
        if (!phone.startsWith('+') && countryCode.startsWith('+')) {
          final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
          final cc = countryCode.replaceAll(RegExp(r'[^0-9+]'), '');
          if (digits.isNotEmpty) phone = '$cc$digits';
        }
        // Remember for verify step
        _lastOtpPhoneE164 = phone;
        // Use new SMS OTP endpoint for phone numbers
        response = await _apiClient.post<Map<String, dynamic>>(
          '/api/sms/send-otp',
          data: {
            'phoneNumber': phone,
            'countryCode': countryCode,
          },
        );
      }

      // Fallback to legacy combined endpoint if SMS endpoint fails
      if (!response.success && !isEmail) {
        final legacy = await _apiClient.post<Map<String, dynamic>>(
          '/api/auth/send-otp',
          data: {
            'emailOrPhone': emailOrPhone.toLowerCase().trim(),
            'isEmail': isEmail,
            'countryCode': countryCode,
          },
        );
        response = legacy;
      }

      if (kDebugMode) {
        print(
            '🔍 sendOTP response: success=${response.success}, data=${response.data}');
      }

      // Handle the backend response structure directly
      if (response.success ||
          (response.data != null && response.data!['success'] == true)) {
        final responseData = response.data ?? <String, dynamic>{};
        // For /api/sms/send-otp the payload is { success, data: { otpId, ... } }
        final data = (responseData['data'] is Map<String, dynamic>)
            ? responseData['data'] as Map<String, dynamic>
            : responseData;
        // Prefer explicit otpToken, else map otpId -> otpToken for compatibility
        final otpToken = (responseData['otpToken'] as String?) ??
            (data['otpToken'] as String?) ??
            (data['otpId'] as String?);
        final message = (data['message'] as String?) ??
            (responseData['message'] as String?) ??
            response.message;

        if (kDebugMode) {
          print('🔍 Extracted otpToken: $otpToken');
          if (otpToken == null) {
            print(
                '⚠️ otpToken is null even though success=true. Raw response data: ${response.data}');
          }
        }

        final channel = responseData['channel'] as String?;
        Map<String, dynamic>? emailMeta;
        if (responseData['email'] is Map<String, dynamic>) {
          emailMeta = responseData['email'] as Map<String, dynamic>;
        }

        return OTPResult(
          success: true,
          otpToken: otpToken,
          message: message ?? 'OTP sent successfully',
          channel: channel,
          messageId:
              emailMeta != null ? emailMeta['messageId'] as String? : null,
          fallback: emailMeta != null
              ? (emailMeta['fallback'] as bool? ?? false)
              : false,
          deliveryError:
              emailMeta != null ? emailMeta['error'] as String? : null,
        );
      }

      return OTPResult(
        success: false,
        error: response.error ?? 'Failed to send OTP',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Send OTP error: $e');
      }
      return OTPResult(
        success: false,
        error: 'Failed to send OTP: ${e.toString()}',
      );
    }
  }

  /// Verify OTP code
  Future<AuthResult> verifyOTP({
    required String emailOrPhone,
    required String otp,
    required String otpToken,
  }) async {
    try {
      final isEmail = emailOrPhone.contains('@');
      // Prefer modern endpoints. For phone, use /api/sms/verify-otp (otpId maps to otpToken).
      ApiResponse<Map<String, dynamic>> response;
      if (!isEmail) {
        // Normalize phone
        String phone = emailOrPhone.trim();
        // Prefer the exact phone used when sending the OTP (most reliable)
        if (_lastOtpPhoneE164 != null) {
          phone = _lastOtpPhoneE164!;
        } else if (!phone.startsWith('+')) {
          // Fallback best-effort: add '+'
          phone = '+${phone.replaceAll(RegExp(r'[^0-9]'), '')}';
        }
        // Try SMS verify endpoint first
        response = await _apiClient.post<Map<String, dynamic>>(
          '/api/sms/verify-otp',
          data: {
            'phoneNumber': phone,
            'otp': otp,
            if (otpToken.isNotEmpty) 'otpId': otpToken,
          },
        );
        if (response.isSuccess) {
          return AuthResult(
            success: true,
            message: response.message ?? 'OTP verified successfully',
          );
        }
        // Fallback 1: dedicated auth phone verify
        response = await _apiClient.post<Map<String, dynamic>>(
          '/api/auth/verify-phone-otp',
          data: {
            'phone': phone,
            'otp': otp,
          },
        );
        if (response.isSuccess && response.data != null) {
          final raw = response.data!;
          final container = (raw['data'] is Map<String, dynamic>)
              ? raw['data'] as Map<String, dynamic>
              : raw;
          final userMap = container['user'] as Map<String, dynamic>?;
          final token = container['token'] as String?;
          final refreshToken = container['refreshToken'] as String?;
          if (token != null) await _apiClient.saveToken(token);
          if (refreshToken != null)
            await _apiClient.saveRefreshToken(refreshToken);
          if (userMap != null) _currentUser = UserModel.fromJson(userMap);
          return AuthResult(
            success: true,
            user: _currentUser,
            token: token,
            message: response.message ?? 'OTP verified successfully',
          );
        }
        // Fallback 2: legacy combined verify using otpToken
        if (otpToken.isNotEmpty) {
          response = await _apiClient.post<Map<String, dynamic>>(
            '/api/auth/verify-otp',
            data: {
              'emailOrPhone': emailOrPhone.toLowerCase().trim(),
              'otp': otp,
              'otpToken': otpToken,
            },
          );
          if (response.isSuccess) {
            return AuthResult(
              success: true,
              message: response.message ?? 'OTP verified successfully',
            );
          }
        }
        return AuthResult(
            success: false, error: response.error ?? 'Invalid OTP');
      }

      // Email OTP path
      final endpoint = '/api/auth/verify-email-otp';
      response = await _apiClient.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'email': emailOrPhone.toLowerCase().trim(),
          'otp': otp,
        },
      );
      if (response.isSuccess && response.data != null) {
        final raw = response.data!;
        final container = (raw['data'] is Map<String, dynamic>)
            ? raw['data'] as Map<String, dynamic>
            : raw;
        final userMap = container['user'] as Map<String, dynamic>?;
        final token = container['token'] as String?;
        final refreshToken = container['refreshToken'] as String?;
        if (token != null) await _apiClient.saveToken(token);
        if (refreshToken != null)
          await _apiClient.saveRefreshToken(refreshToken);
        if (userMap != null) {
          _currentUser = UserModel.fromJson(userMap);
        }
        return AuthResult(
          success: true,
          user: _currentUser,
          token: token,
          message: response.message ?? 'OTP verified successfully',
        );
      }
      return AuthResult(success: false, error: response.error ?? 'Invalid OTP');
    } catch (e) {
      if (kDebugMode) {
        print('Verify OTP error: $e');
      }
      return AuthResult(
        success: false,
        error: 'Failed to verify OTP: ${e.toString()}',
      );
    }
  }

  /// Get current user profile
  Future<AuthResult> getUserProfile() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/auth/profile',
      );

      if (response.isSuccess && response.data != null) {
        // Accept either flat user or wrapped { success, data: { user fields } }
        final raw = response.data!;
        Map<String, dynamic>? userMap;
        if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
          userMap = raw['data'] as Map<String, dynamic>;
        } else if (raw.containsKey('user') &&
            raw['user'] is Map<String, dynamic>) {
          userMap = raw['user'] as Map<String, dynamic>;
        } else {
          userMap = raw; // fallback
        }
        _currentUser = UserModel.fromJson(userMap);

        return AuthResult(
          success: true,
          user: _currentUser,
        );
      }

      return AuthResult(
        success: false,
        error: response.error ?? 'Failed to get user profile',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Get profile error: $e');
      }
      return AuthResult(
        success: false,
        error: 'Failed to get profile: ${e.toString()}',
      );
    }
  }

  /// Login verified user (for users who completed OTP but don't have tokens)
  Future<AuthResult> loginVerifiedUser(String emailOrPhone) async {
    try {
      if (kDebugMode) {
        print('🔑 [loginVerifiedUser] Attempting login for: $emailOrPhone');
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/flutter/auth/login-verified',
        data: {
          'emailOrPhone': emailOrPhone.toLowerCase().trim(),
        },
      );

      if (kDebugMode) {
        print('🔑 [loginVerifiedUser] Response: ${response.isSuccess}');
        print('🔑 [loginVerifiedUser] Data: ${response.data}');
      }

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final userData = data['data'] as Map<String, dynamic>?;

        if (userData != null) {
          final userMap = userData['user'] as Map<String, dynamic>?;
          final token = userData['token'] as String?;
          final refreshToken = userData['refreshToken'] as String?;

          if (token != null) await _apiClient.saveToken(token);
          if (refreshToken != null)
            await _apiClient.saveRefreshToken(refreshToken);

          if (userMap != null) {
            _currentUser = UserModel.fromJson(userMap);
          }

          if (kDebugMode) {
            print(
                '🔑 [loginVerifiedUser] Login successful, user: ${_currentUser?.email}');
          }

          return AuthResult(
            success: true,
            user: _currentUser,
            token: token,
            message: 'Login successful',
          );
        }
      }

      return AuthResult(
        success: false,
        error: response.error ?? 'Failed to login',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [loginVerifiedUser] Exception: $e');
      }
      return AuthResult(
        success: false,
        error: 'Failed to login: ${e.toString()}',
      );
    }
  }

  /// Register new user with complete profile information
  Future<AuthResult> registerNewUser({
    required String emailOrPhone,
    required String firstName,
    required String lastName,
    required String displayName,
    required String password,
    required bool isEmail,
    String? countryCode,
  }) async {
    try {
      if (kDebugMode) {
        print('👤 [registerNewUser] Starting registration for: $emailOrPhone');
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/flutter/auth/register-complete',
        data: {
          'emailOrPhone': emailOrPhone.toLowerCase().trim(),
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'displayName': displayName.trim(),
          'password': password,
          'isEmail': isEmail,
          if (countryCode != null) 'countryCode': countryCode,
        },
      );

      if (kDebugMode) {
        print('👤 [registerNewUser] Response: ${response.isSuccess}');
        print('👤 [registerNewUser] Data: ${response.data}');
      }

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final userData = data['data'] as Map<String, dynamic>?;

        if (userData != null) {
          final userMap = userData['user'] as Map<String, dynamic>?;
          final token = userData['token'] as String?;
          final refreshToken = userData['refreshToken'] as String?;

          if (token != null) await _apiClient.saveToken(token);
          if (refreshToken != null)
            await _apiClient.saveRefreshToken(refreshToken);

          if (userMap != null) {
            _currentUser = UserModel.fromJson(userMap);
          }

          if (kDebugMode) {
            print(
                '👤 [registerNewUser] Registration successful, user: ${_currentUser?.email}');
          }

          return AuthResult(
            success: true,
            user: _currentUser,
            token: token,
            message: 'Registration successful',
          );
        }
      }

      return AuthResult(
        success: false,
        error: response.error ?? 'Failed to register',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [registerNewUser] Exception: $e');
      }
      return AuthResult(
        success: false,
        error: 'Failed to register: ${e.toString()}',
      );
    }
  }

  /// Complete user profile (update profile info and set password)
  Future<AuthResult> completeProfile({
    String? firstName,
    String? lastName,
    String? displayName,
    String? password,
    Map<String, dynamic>? extra,
  }) async {
    try {
      if (kDebugMode) {
        print('🔐 [completeProfile] Starting profile completion...');
        print('🔐 [completeProfile] Parameters received:');
        print('🔐   firstName: "$firstName"');
        print('🔐   lastName: "$lastName"');
        print('🔐   displayName: "$displayName"');
        print(
            '🔐   password: ${password != null ? "[${password.length} chars]" : "null"}');
        print('🔐   extra: $extra');
      }

      // Check if user is authenticated
      final isAuth = await _apiClient.isAuthenticated();
      if (kDebugMode) {
        print('🔐 [completeProfile] User authenticated: $isAuth');
      }

      if (!isAuth) {
        throw Exception('User not authenticated');
      }

      final data = <String, dynamic>{};

      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (displayName != null) data['display_name'] = displayName;
      if (password != null) data['password'] = password;
      if (extra != null) data.addAll(extra);

      if (kDebugMode) {
        print('🔐 [completeProfile] Request data prepared: $data');
        print(
            '🔐 [completeProfile] Making PUT request to /api/auth/profile...');
      }

      final response = await _apiClient.put<Map<String, dynamic>>(
        '/api/auth/profile',
        data: data,
      );

      if (kDebugMode) {
        print('🔐 [completeProfile] API Response received:');
        print('🔐   success: ${response.isSuccess}');
        print('🔐   statusCode: ${response.statusCode}');
        print('🔐   message: ${response.message}');
        print('🔐   error: ${response.error}');
        print('🔐   data type: ${response.data.runtimeType}');
        print('🔐   data: ${response.data}');
      }

      if (response.isSuccess && response.data != null) {
        if (kDebugMode) {
          print('🔐 [completeProfile] Parsing user from response data...');
          print(
              '🔐 [completeProfile] Response data keys: ${response.data!.keys}');
        }

        // Handle different response formats
        Map<String, dynamic> userData;
        if (response.data!.containsKey('user')) {
          userData = response.data!['user'] as Map<String, dynamic>;
          if (kDebugMode) {
            print('🔐 [completeProfile] Found user in response.data["user"]');
          }
        } else if (response.data!.containsKey('data')) {
          userData = response.data!['data'] as Map<String, dynamic>;
          if (kDebugMode) {
            print('🔐 [completeProfile] Found user in response.data["data"]');
          }
        } else {
          userData = response.data!;
          if (kDebugMode) {
            print(
                '🔐 [completeProfile] Using response.data directly as user data');
          }
        }

        if (kDebugMode) {
          print('🔐 [completeProfile] userData to parse: $userData');
        }

        _currentUser = UserModel.fromJson(userData);

        if (kDebugMode) {
          print('🔐 [completeProfile] UserModel created successfully:');
          print('🔐   id: ${_currentUser!.id}');
          print('🔐   email: ${_currentUser!.email}');
          print('🔐   firstName: ${_currentUser!.firstName}');
          print('🔐   lastName: ${_currentUser!.lastName}');
          print('🔐   displayName: ${_currentUser!.displayName}');
        }

        return AuthResult(
          success: true,
          user: _currentUser,
          message: response.message ?? 'Profile completed successfully',
        );
      }

      if (kDebugMode) {
        print('🔐 [completeProfile] Request failed - returning error result');
      }

      return AuthResult(
        success: false,
        error: response.error ?? 'Failed to complete profile',
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [completeProfile] Exception caught: $e');
        print('❌ [completeProfile] Stack trace: $stackTrace');
      }
      return AuthResult(
        success: false,
        error: 'Failed to complete profile: ${e.toString()}',
      );
    }
  }

  /// Change user password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (kDebugMode) {
        print('🔐 [changePassword] Attempting to change password');
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      if (response.success && response.data != null) {
        if (kDebugMode) {
          print('✅ [changePassword] Password changed successfully');
        }
        return AuthResult(
          success: true,
          message: response.data!['message'] ?? 'Password changed successfully',
        );
      } else {
        if (kDebugMode) {
          print('❌ [changePassword] Failed: ${response.error}');
        }
        return AuthResult(
          success: false,
          error: response.error ?? 'Failed to change password',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [changePassword] Exception caught: $e');
        print('❌ [changePassword] Stack trace: $stackTrace');
      }
      return AuthResult(
        success: false,
        error: 'Failed to change password: ${e.toString()}',
      );
    }
  }

  /// Reset password using OTP verification
  Future<AuthResult> resetPassword({
    required String emailOrPhone,
    required String otp,
    required String newPassword,
    required bool isEmail,
  }) async {
    try {
      if (kDebugMode) {
        print(
            '🔐 [resetPassword] Attempting to reset password for $emailOrPhone');
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/auth/reset-password',
        data: {
          'emailOrPhone': emailOrPhone,
          'otp': otp,
          'newPassword': newPassword,
          'isEmail': isEmail,
        },
      );

      if (response.success && response.data != null) {
        if (kDebugMode) {
          print('✅ [resetPassword] Password reset successfully');
        }
        return AuthResult(
          success: true,
          message: response.data!['message'] ?? 'Password reset successfully',
        );
      } else {
        if (kDebugMode) {
          print('❌ [resetPassword] Failed: ${response.error}');
        }
        return AuthResult(
          success: false,
          error: response.error ?? 'Failed to reset password',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [resetPassword] Exception caught: $e');
        print('❌ [resetPassword] Stack trace: $stackTrace');
      }
      return AuthResult(
        success: false,
        error: 'Failed to reset password: ${e.toString()}',
      );
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _apiClient.clearToken();
    _currentUser = null;
  }

  /// Initialize auth state - check if user is already logged in
  Future<bool> initializeAuth() async {
    try {
      final isAuth = await _apiClient.isAuthenticated();
      if (isAuth) {
        final profileResult = await getUserProfile();
        return profileResult.success;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Initialize auth error: $e');
      }
      return false;
    }
  }
}

/// User model for REST API
class UserModel {
  final String id;
  final String email;
  final String? phone;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final bool emailVerified;
  final bool phoneVerified;
  final bool isActive;
  final String role;
  final String countryCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.phone,
    this.displayName,
    this.firstName,
    this.lastName,
    required this.emailVerified,
    required this.phoneVerified,
    required this.isActive,
    required this.role,
    required this.countryCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      displayName: json['display_name']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      emailVerified: json['email_verified'] as bool? ?? false,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      role: json['role']?.toString() ?? 'user',
      countryCode: json['country_code']?.toString() ?? 'LK',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
      'is_active': isActive,
      'role': role,
      'country_code': countryCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get name => displayName ?? email.split('@')[0];
  String get fullName {
    if (firstName != null || lastName != null) {
      return [firstName, lastName]
          .where((p) => p != null && p.isNotEmpty)
          .cast<String>()
          .join(' ');
    }
    return displayName ?? email.split('@')[0];
  }

  // Legacy compatibility getters (Firebase-style fields)
  // Many legacy screens still reference user.uid / user.phoneNumber
  // during the incremental migration away from Firebase.
  String get uid => id; // Firebase user UID equivalent
  String? get phoneNumber => phone; // Firebase phoneNumber equivalent

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name)';
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? token;
  final String? message;
  final String? error;

  AuthResult({
    required this.success,
    this.user,
    this.token,
    this.message,
    this.error,
  });

  bool get isSuccess => success;
  bool get isError => !success;

  @override
  String toString() {
    return 'AuthResult(success: $success, user: ${user?.email}, error: $error)';
  }
}

/// OTP result wrapper
class OTPResult {
  final bool success;
  final String? otpToken;
  final String? message;
  final String? error;
  final String? channel; // 'email' or 'sms'
  final String? messageId; // SES message id
  final bool fallback; // dev fallback mode
  final String? deliveryError; // provider error if any

  OTPResult({
    required this.success,
    this.otpToken,
    this.message,
    this.error,
    this.channel,
    this.messageId,
    this.fallback = false,
    this.deliveryError,
  });

  bool get isSuccess => success;
  bool get isError => !success;

  @override
  String toString() {
    return 'OTPResult(success: $success, otpToken: $otpToken, channel: $channel, messageId: $messageId, fallback: $fallback, error: $error, deliveryError: $deliveryError)';
  }
}
