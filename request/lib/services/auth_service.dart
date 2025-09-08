import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get stored authentication token
  Future<String?> getToken() async {
    await _initPrefs();
    return _prefs?.getString(_tokenKey);
  }

  /// Store authentication token
  Future<void> setToken(String token) async {
    await _initPrefs();
    await _prefs?.setString(_tokenKey, token);
  }

  /// Get stored user ID
  Future<String?> getUserId() async {
    await _initPrefs();
    return _prefs?.getString(_userIdKey);
  }

  /// Store user ID
  Future<void> setUserId(String userId) async {
    await _initPrefs();
    await _prefs?.setString(_userIdKey, userId);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear all authentication data
  Future<void> logout() async {
    await _initPrefs();
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_userIdKey);
  }

  /// Get authorization headers for API requests
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
