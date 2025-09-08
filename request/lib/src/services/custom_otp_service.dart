import 'dart:math';

class CustomOTPService {
  static final Map<String, OTPSession> _activeSessions = {};
  
  static CustomOTPService? _instance;
  static CustomOTPService get instance => _instance ??= CustomOTPService._();
  CustomOTPService._();

  /// Send custom OTP (for non-Firebase auth purposes)
  Future<String> sendCustomOTP({
    required String identifier, // email or phone
    required String purpose,    // 'email_registration', 'password_reset', etc.
  }) async {
    // Generate 6-digit OTP
    final otp = _generateOTP();
    
    // Create session
    final sessionId = _generateSessionId();
    final session = OTPSession(
      otp: otp,
      identifier: identifier,
      purpose: purpose,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    
    _activeSessions[sessionId] = session;
    
    // Send OTP based on identifier type
    if (identifier.contains('@')) {
      await _sendEmailOTP(identifier, otp, purpose);
    } else {
      await _sendSMSOTP(identifier, otp, purpose);
    }
    
    return sessionId;
  }

  /// Verify custom OTP
  Future<bool> verifyCustomOTP({
    required String sessionId,
    required String otp,
  }) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      return false;
    }
    
    // Check expiration
    if (DateTime.now().isAfter(session.expiresAt)) {
      _activeSessions.remove(sessionId);
      return false;
    }
    
    // Check OTP
    if (session.otp == otp) {
      _activeSessions.remove(sessionId);
      return true;
    }
    
    return false;
  }

  /// Get session info (for UI purposes)
  OTPSession? getSession(String sessionId) {
    return _activeSessions[sessionId];
  }

  /// Clean up expired sessions
  void cleanupExpiredSessions() {
    final now = DateTime.now();
    _activeSessions.removeWhere((key, session) => now.isAfter(session.expiresAt));
  }

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _generateSessionId() {
    final random = Random();
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           random.nextInt(10000).toString();
  }

  Future<void> _sendEmailOTP(String email, String otp, String purpose) async {
    // Implement email sending
    print('📧 Email OTP sent to $email: $otp (Purpose: $purpose)');
    // TODO: Integrate with email service (SendGrid, AWS SES, etc.)
  }
  
  Future<void> _sendSMSOTP(String phone, String otp, String purpose) async {
    // Implement SMS sending
    print('💬 SMS OTP sent to $phone: $otp (Purpose: $purpose)');
    // TODO: Integrate with SMS service (Twilio, AWS SNS, etc.)
  }
}

class OTPSession {
  final String otp;
  final String identifier;
  final String purpose;
  final DateTime createdAt;
  final DateTime expiresAt;
  
  OTPSession({
    required this.otp,
    required this.identifier,
    required this.purpose,
    required this.createdAt,
    required this.expiresAt,
  });
}
