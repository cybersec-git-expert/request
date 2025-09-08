/// EnhancedAuthService provides a Firebase-like API surface backed by RestAuthService.
import 'rest_auth_service.dart' hide UserModel; // hide auth UserModel
import '../models/enhanced_user_model.dart' as enhanced;

class EnhancedAuthService {
  EnhancedAuthService._();
  static EnhancedAuthService? _instance;
  static EnhancedAuthService get instance =>
      _instance ??= EnhancedAuthService._();

  final RestAuthService _rest = RestAuthService.instance;

  enhanced.UserModel? _cachedUser;

  enhanced.UserModel? get currentUser => _cachedUser;

  Future<enhanced.UserModel?> refreshUser() async {
    final ok = await _rest.isAuthenticated();
    if (!ok) return null;
    await _rest.getUserProfile();
    final authUser = _rest.currentUser;
    if (authUser == null) return null;
    _cachedUser = enhanced.UserModel(
      id: authUser.id,
      name: authUser.fullName,
      email: authUser.email,
      phoneNumber: authUser.phoneNumber,
      roles: const [enhanced.UserRole.general],
      activeRole: enhanced.UserRole.general,
      roleData: const {},
      isEmailVerified: authUser.emailVerified,
      isPhoneVerified: authUser.phoneVerified,
      profileComplete: true,
      countryCode: authUser.countryCode,
      countryName: null,
      createdAt: authUser.createdAt,
      updatedAt: authUser.updatedAt,
    );
    return _cachedUser;
  }

  Future<bool> login(String email, String password) async {
    final result = await _rest.login(email: email, password: password);
    if (result.success) {
      await refreshUser();
    }
    return result.success;
  }

  Future<bool> register(String email, String password,
      {String? displayName, String? phone}) async {
    final result = await _rest.register(
        email: email,
        password: password,
        displayName: displayName,
        phone: phone);
    if (result.success) {
      await refreshUser();
    }
    return result.success;
  }

  Future<void> signOut() async {
    await _rest.logout();
    _cachedUser = null;
  }
}
