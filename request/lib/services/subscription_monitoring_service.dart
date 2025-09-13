import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../src/services/simple_subscription_service.dart';
import '../services/subscription/response_limit_service.dart';
import '../src/services/api_client.dart';
import '../src/widgets/subscription_renewal_dialog.dart';
import '../src/screens/subscription_grace_period_screen.dart';

/// Comprehensive subscription monitoring service with security and real-time sync
class SubscriptionMonitoringService {
  static SubscriptionMonitoringService? _instance;
  static SubscriptionMonitoringService get instance =>
      _instance ??= SubscriptionMonitoringService._();

  SubscriptionMonitoringService._();

  Timer? _statusCheckTimer;
  Timer? _expirationWarningTimer;
  StreamController<SubscriptionStatusUpdate>? _statusStreamController;
  DateTime? _lastStatusCheck;
  String? _cachedPlanCode;
  int _failedCheckCount = 0;

  static const int _statusCheckIntervalMinutes = 15; // Check every 15 minutes
  static const int _maxFailedChecks = 3;
  static const String _lastCheckKey = 'last_subscription_check';
  static const String _cachedStatusKey = 'cached_subscription_status';

  /// Get status update stream
  Stream<SubscriptionStatusUpdate> get statusUpdates {
    _statusStreamController ??=
        StreamController<SubscriptionStatusUpdate>.broadcast();
    return _statusStreamController!.stream;
  }

  /// Initialize the subscription monitoring service
  Future<void> initialize() async {
    print('🔍 Initializing subscription monitoring service...');

    try {
      // Load cached status
      await _loadCachedStatus();

      // Perform immediate status check
      await _performStatusCheck();

      // Start periodic monitoring
      _startPeriodicMonitoring();

      // Start expiration warning checks
      _startExpirationWarningMonitoring();

      print('✅ Subscription monitoring service initialized');
    } catch (error) {
      print('❌ Error initializing subscription monitoring: $error');
    }
  }

  /// Stop monitoring service
  void dispose() {
    _statusCheckTimer?.cancel();
    _expirationWarningTimer?.cancel();
    _statusStreamController?.close();
    _statusStreamController = null;
  }

  /// Force immediate status check and sync
  Future<bool> forceStatusSync() async {
    print('🔄 Forcing subscription status sync...');
    return await _performStatusCheck();
  }

  /// Check if subscription is active (with security validation)
  Future<bool> isSubscriptionActive() async {
    try {
      final status =
          await SimpleSubscriptionService.instance.getSubscriptionStatus();

      if (status == null) {
        await _handleInactiveSubscription();
        return false;
      }

      // Validate expiration date on frontend for security
      if (status.planCode.toLowerCase() != 'free') {
        final isValid = await _validateSubscriptionSecurity(status);
        if (!isValid) {
          await _handleSuspiciousActivity();
          return false;
        }
      }

      final isActive = status.planCode.toLowerCase() == 'pro' ||
          (status.responsesLimit == null);

      // Update local cache
      await ResponseLimitService.setUnlimitedPlan(isActive);

      return isActive;
    } catch (error) {
      print('❌ Error checking subscription status: $error');
      _failedCheckCount++;

      if (_failedCheckCount >= _maxFailedChecks) {
        await _handleRepeatedFailures();
      }

      return false;
    }
  }

  /// Start periodic status monitoring
  void _startPeriodicMonitoring() {
    _statusCheckTimer = Timer.periodic(
      Duration(minutes: _statusCheckIntervalMinutes),
      (_) => _performStatusCheck(),
    );
    print(
        '📅 Started periodic subscription monitoring (every $_statusCheckIntervalMinutes minutes)');
  }

  /// Start expiration warning monitoring
  void _startExpirationWarningMonitoring() {
    _expirationWarningTimer = Timer.periodic(
      const Duration(hours: 6), // Check for expiration warnings every 6 hours
      (_) => _checkExpirationWarnings(),
    );
    print('⚠️ Started expiration warning monitoring (every 6 hours)');
  }

  /// Perform comprehensive status check
  Future<bool> _performStatusCheck() async {
    try {
      print('🔍 Performing subscription status check...');

      final status =
          await SimpleSubscriptionService.instance.getSubscriptionStatus();
      _lastStatusCheck = DateTime.now();
      _failedCheckCount = 0;

      if (status == null) {
        await _handleStatusChange(null, 'No active subscription');
        return false;
      }

      // Check for status changes
      final hasChanged = await _detectStatusChanges(status);

      if (hasChanged) {
        await _handleStatusChange(status, 'Subscription status changed');
      }

      // Update cached status
      await _cacheStatus(status);

      // Security validation for paid plans
      if (status.planCode.toLowerCase() != 'free') {
        final isValid = await _validateSubscriptionSecurity(status);
        if (!isValid) {
          await _handleSuspiciousActivity();
          return false;
        }
      }

      // Update local subscription cache
      final isUnlimited = status.planCode.toLowerCase() == 'pro' ||
          (status.responsesLimit == null);
      await ResponseLimitService.setUnlimitedPlan(isUnlimited);

      print('✅ Subscription status check completed - Plan: ${status.planCode}');
      return true;
    } catch (error) {
      print('❌ Failed to perform status check: $error');
      _failedCheckCount++;
      return false;
    }
  }

  /// Detect if subscription status has changed
  Future<bool> _detectStatusChanges(SimpleSubscriptionStatus newStatus) async {
    if (_cachedPlanCode == null) {
      _cachedPlanCode = newStatus.planCode;
      return true; // First time, consider it a change
    }

    final planChanged = _cachedPlanCode != newStatus.planCode;

    // TODO: Add expiry date comparison when available in status

    return planChanged;
  }

  /// Handle subscription status change
  Future<void> _handleStatusChange(
      SimpleSubscriptionStatus? newStatus, String reason) async {
    print('📢 Subscription status change detected: $reason');

    if (newStatus == null) {
      // Subscription became inactive
      await ResponseLimitService.setUnlimitedPlan(false);
      _cachedPlanCode = 'Free';
    } else {
      // Subscription changed
      final isUnlimited = newStatus.planCode.toLowerCase() == 'pro' ||
          (newStatus.responsesLimit == null);
      await ResponseLimitService.setUnlimitedPlan(isUnlimited);
      _cachedPlanCode = newStatus.planCode;
    }

    // Emit status update event
    _statusStreamController?.add(SubscriptionStatusUpdate(
      newStatus: newStatus,
      reason: reason,
      timestamp: DateTime.now(),
    ));
  }

  /// Validate subscription security (anti-manipulation)
  Future<bool> _validateSubscriptionSecurity(
      SimpleSubscriptionStatus status) async {
    try {
      // Check 1: Validate with backend timestamp
      final backendResponse = await ApiClient.instance
          .get<Map<String, dynamic>>(
              '/api/simple-subscription/validate-status');

      if (!backendResponse.isSuccess) {
        print('⚠️ Backend validation failed');
        return false;
      }

      // Check 2: Cross-validate plan code
      final serverPlanCode = backendResponse.data?['data']?['plan_code'];
      if (serverPlanCode != status.planCode) {
        print('🚨 Plan code mismatch - potential manipulation detected');
        return false;
      }

      // Check 3: Validate against device time manipulation
      final serverTimestamp =
          backendResponse.data?['data']?['server_timestamp'];
      if (serverTimestamp != null) {
        final serverTime = DateTime.parse(serverTimestamp);
        final timeDiff = DateTime.now().difference(serverTime).abs().inMinutes;

        if (timeDiff > 10) {
          // Allow 10 minutes tolerance
          print('🚨 Suspicious time difference detected: ${timeDiff} minutes');
          return false;
        }
      }

      return true;
    } catch (error) {
      print('❌ Security validation error: $error');
      return false;
    }
  }

  /// Handle suspicious activity (potential manipulation)
  Future<void> _handleSuspiciousActivity() async {
    print('🚨 Suspicious activity detected - securing subscription');

    // Force downgrade to free plan
    await ResponseLimitService.setUnlimitedPlan(false);

    // Clear cached data
    await _clearCachedStatus();

    // Emit security alert
    _statusStreamController?.add(SubscriptionStatusUpdate(
      newStatus: null,
      reason: 'Security validation failed',
      timestamp: DateTime.now(),
      isSecurityAlert: true,
    ));
  }

  /// Handle repeated check failures
  Future<void> _handleRepeatedFailures() async {
    print('⚠️ Multiple subscription check failures - applying fallback');

    // Use cached status if available and recent
    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString(_lastCheckKey);

    if (lastCheckStr != null) {
      final lastCheck = DateTime.parse(lastCheckStr);
      final hoursSinceLastCheck = DateTime.now().difference(lastCheck).inHours;

      if (hoursSinceLastCheck > 24) {
        // If we haven't had a successful check in 24 hours, force free plan
        await ResponseLimitService.setUnlimitedPlan(false);
        print('🚨 Forced downgrade due to extended validation failure');
      }
    }
  }

  /// Handle inactive subscription
  Future<void> _handleInactiveSubscription() async {
    await ResponseLimitService.setUnlimitedPlan(false);
    _cachedPlanCode = 'Free';
  }

  /// Check for upcoming expiration warnings
  Future<void> _checkExpirationWarnings() async {
    try {
      // This would be called from backend, but for now we implement basic logic
      print('⚠️ Checking for expiration warnings...');

      // TODO: Implement expiration warning logic when expiry dates are available
      // For now, we just ensure status is current
      await _performStatusCheck();
    } catch (error) {
      print('❌ Error checking expiration warnings: $error');
    }
  }

  /// Load cached subscription status
  Future<void> _loadCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStatusStr = prefs.getString(_cachedStatusKey);
      final lastCheckStr = prefs.getString(_lastCheckKey);

      if (cachedStatusStr != null) {
        final cachedData = json.decode(cachedStatusStr);
        _cachedPlanCode = cachedData['plan_code'];
      }

      if (lastCheckStr != null) {
        _lastStatusCheck = DateTime.parse(lastCheckStr);
      }
    } catch (error) {
      print('❌ Error loading cached status: $error');
    }
  }

  /// Cache subscription status
  Future<void> _cacheStatus(SimpleSubscriptionStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final statusData = {
        'plan_code': status.planCode,
        'plan_name': status.planName,
        'responses_used': status.responsesUsed,
        'responses_limit': status.responsesLimit,
        'cached_at': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_cachedStatusKey, json.encode(statusData));
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
    } catch (error) {
      print('❌ Error caching status: $error');
    }
  }

  /// Clear cached status
  Future<void> _clearCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedStatusKey);
      await prefs.remove(_lastCheckKey);
    } catch (error) {
      print('❌ Error clearing cached status: $error');
    }
  }

  /// Get time since last successful check
  Duration? getTimeSinceLastCheck() {
    if (_lastStatusCheck == null) return null;
    return DateTime.now().difference(_lastStatusCheck!);
  }

  /// Check if monitoring is healthy
  bool isMonitoringHealthy() {
    final timeSinceLastCheck = getTimeSinceLastCheck();
    if (timeSinceLastCheck == null) return false;

    return timeSinceLastCheck.inHours < 2 &&
        _failedCheckCount < _maxFailedChecks;
  }

  /// Show renewal warning dialog to user
  Future<void> showRenewalWarning(
      BuildContext context, int daysRemaining) async {
    try {
      await SubscriptionRenewalDialog.show(
        context,
        daysRemaining: daysRemaining,
        onRenew: () {
          Navigator.of(context).pop(true);
          // Navigate to subscription screen - handled by calling code
        },
        isLastWarning: daysRemaining <= 1,
      );
    } catch (e) {
      debugPrint('Error showing renewal warning: $e');
    }
  }

  /// Show grace period screen
  Future<void> showGracePeriodScreen(
    BuildContext context,
    int graceDaysRemaining,
    DateTime expiryDate,
  ) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SubscriptionGracePeriodScreen(
            graceDaysRemaining: graceDaysRemaining,
            expiryDate: expiryDate,
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      debugPrint('Error showing grace period screen: $e');
    }
  }

  /// Check if user should see renewal warnings
  bool shouldShowRenewalWarning(DateTime? expiryDate) {
    if (expiryDate == null) return false;

    final now = DateTime.now();
    final daysUntilExpiry = expiryDate.difference(now).inDays;

    // Show warnings at 7, 3, and 1 day(s) before expiry
    return daysUntilExpiry <= 7 && daysUntilExpiry >= 0;
  }

  /// Check if user is in grace period
  bool isInGracePeriod(DateTime? expiryDate, int graceDays) {
    if (expiryDate == null) return false;

    final now = DateTime.now();
    final daysSinceExpiry = now.difference(expiryDate).inDays;

    return daysSinceExpiry > 0 && daysSinceExpiry <= graceDays;
  }
}

/// Subscription status update event
class SubscriptionStatusUpdate {
  final SimpleSubscriptionStatus? newStatus;
  final String reason;
  final DateTime timestamp;
  final bool isSecurityAlert;

  SubscriptionStatusUpdate({
    required this.newStatus,
    required this.reason,
    required this.timestamp,
    this.isSecurityAlert = false,
  });
}

/// Subscription security validator
class SubscriptionSecurityValidator {
  /// Validate subscription integrity
  static Future<bool> validateIntegrity() async {
    // Add additional security checks here
    return true;
  }

  /// Check for device time manipulation
  static Future<bool> checkTimeIntegrity() async {
    // Implement time validation against server
    return true;
  }

  /// Validate plan entitlements
  static Future<bool> validateEntitlements(String planCode) async {
    // Cross-check plan permissions with server
    return true;
  }
}
