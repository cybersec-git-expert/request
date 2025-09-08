/// Shim AuthService wrapping the new RestAuthService for legacy screens.
import 'rest_auth_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  RestAuthService get _rest => RestAuthService.instance;

  get currentUser => _rest.currentUser; // Exposes REST user (has id, email)

  Future<bool> isAuthenticated() => _rest.isAuthenticated();
  Future<void> signOut() => _rest.logout();

  /// Send OTP for password reset
  Future<OTPResult> sendOtp({
    required String emailOrPhone,
    required bool isEmail,
  }) =>
      _rest.sendOTP(
        emailOrPhone: emailOrPhone,
        isEmail: isEmail,
        countryCode:
            '+94', // Default country code, you can make this configurable
      );

  /// Verify OTP without consuming it (for password reset flow)
  Future<AuthResult> verifyOtp({
    required String emailOrPhone,
    required String otp,
    required bool isEmail,
  }) async {
    // For verification, we can use the verifyOTP method with empty otpToken
    // This is just to check if OTP is valid without consuming it
    return _rest.verifyOTP(
      emailOrPhone: emailOrPhone,
      otp: otp,
      otpToken: '', // Empty token for standalone verification
    );
  }

  /// Change password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _rest.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  /// Reset password with OTP
  Future<AuthResult> resetPassword({
    required String emailOrPhone,
    required String otp,
    required String newPassword,
    required bool isEmail,
  }) =>
      _rest.resetPassword(
        emailOrPhone: emailOrPhone,
        otp: otp,
        newPassword: newPassword,
        isEmail: isEmail,
      );
}
