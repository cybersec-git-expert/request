import 'package:shared_preferences/shared_preferences.dart';
import '../entitlements_service.dart';
import '../../src/services/simple_subscription_service.dart';

/// Simple subscription service to track response limits and subscription status
/// Syncs with backend usage_monthly table for accurate counting
class ResponseLimitService {
  static const String _hasUnlimitedPlanKey = 'has_unlimited_plan';
  static const int _freeMonthlyLimit = 3;

  /// Check if user can send a response
  static Future<bool> canSendResponse() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user has unlimited plan
    final hasUnlimited = prefs.getBool(_hasUnlimitedPlanKey) ?? false;
    if (hasUnlimited) {
      print('DEBUG: canSendResponse = true (unlimited plan)');
      return true;
    }

    // Get current response count from backend
    final responseCount = await _getBackendResponseCount();
    final canSend = responseCount < _freeMonthlyLimit;

    print(
        'DEBUG: canSendResponse = $canSend (responseCount: $responseCount, limit: $_freeMonthlyLimit)');
    return canSend;
  }

  /// Get remaining responses for the month
  static Future<int> getRemainingResponses() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user has unlimited plan
    final hasUnlimited = prefs.getBool(_hasUnlimitedPlanKey) ?? false;
    if (hasUnlimited) {
      print('DEBUG: getRemainingResponses = -1 (unlimited)');
      return -1; // -1 indicates unlimited
    }

    // Get current response count from backend
    final responseCount = await _getBackendResponseCount();
    final remaining =
        (_freeMonthlyLimit - responseCount).clamp(0, _freeMonthlyLimit);

    print(
        'DEBUG: getRemainingResponses = $remaining (responseCount: $responseCount)');
    return remaining;
  }

  /// Get current response count for the month from backend
  static Future<int> getCurrentResponseCount() async {
    final count = await _getBackendResponseCount();
    print('DEBUG: getCurrentResponseCount = $count');
    return count;
  }

  /// Get backend response count from entitlements service
  static Future<int> _getBackendResponseCount() async {
    try {
      print('DEBUG: Getting response count from EntitlementsService...');

      final entitlementsService = EntitlementsService();
      final entitlements = await entitlementsService.getUserEntitlements();

      if (entitlements != null) {
        final responseCount = entitlements.responseCount;
        print(
            'DEBUG: EntitlementsService returned response count: $responseCount');
        return responseCount;
      }

      // No fallback: treat as limit reached
      print(
          'DEBUG: EntitlementsService returned null, treating as at limit (${_freeMonthlyLimit})');
      return _freeMonthlyLimit;
    } catch (e) {
      // On error, assume at limit to be safe
      print(
          'DEBUG: Error getting response count from EntitlementsService: $e (treating as at limit)');
      return _freeMonthlyLimit;
    }
  }

  /// Increment response count (called after successful response creation)
  static Future<void> incrementResponseCount() async {
    // No longer needed - backend automatically increments via usage_monthly table
    // But we keep this method for compatibility and to trigger UI refresh
    print('DEBUG: incrementResponseCount - delegated to backend');
  }

  /// Set unlimited plan status
  static Future<void> setUnlimitedPlan(bool hasUnlimited) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasUnlimitedPlanKey, hasUnlimited);
    print('DEBUG: setUnlimitedPlan = $hasUnlimited');
  }

  /// Check if user has unlimited plan
  static Future<bool> hasUnlimitedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUnlimited = prefs.getBool(_hasUnlimitedPlanKey) ?? false;
    print('DEBUG: hasUnlimitedPlan = $hasUnlimited');
    return hasUnlimited;
  }

  /// Get current plan status for display
  static Future<String> getPlanStatus() async {
    final hasUnlimited = await hasUnlimitedPlan();
    if (hasUnlimited) {
      return 'Pro Plan - Unlimited responses';
    } else {
      final remaining = await getRemainingResponses();
      return 'Free Plan - $remaining responses remaining this month';
    }
  }

  /// Testing methods for debugging
  static Future<void> resetResponseCount() async {
    print('DEBUG: resetResponseCount - not supported with backend sync');
  }

  static Future<void> setResponseCount(int count) async {
    print('DEBUG: setResponseCount - not supported with backend sync');
  }

  static Future<void> setToLimit() async {
    print('DEBUG: setToLimit - not supported with backend sync');
  }

  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasUnlimitedPlanKey);
    print('DEBUG: clearAllData - cleared local data only');
  }

  /// Get user's subscription status info
  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    final hasUnlimited = await hasUnlimitedPlan();
    final remaining = await getRemainingResponses();

    return SubscriptionStatus(
      hasUnlimitedPlan: hasUnlimited,
      remainingResponses: remaining,
      planType: hasUnlimited ? 'pro' : 'free',
    );
  }

  /// Sync subscription status with backend on app startup
  static Future<void> syncWithBackend() async {
    try {
      print(
          'DEBUG: syncWithBackend - checking subscription status with backend');

      // Get current subscription status from backend
      final subscriptionService = SimpleSubscriptionService.instance;
      final status = await subscriptionService.getSubscriptionStatus();

      if (status != null) {
        final isPro = status.planCode.toLowerCase() == 'pro';
        print(
            'DEBUG: syncWithBackend - got status: planCode=${status.planCode}, isPro=$isPro');

        // Update local cache based on backend status
        await setUnlimitedPlan(isPro);
        print('DEBUG: syncWithBackend - updated local cache: unlimited=$isPro');
      } else {
        print(
            'DEBUG: syncWithBackend - no subscription status found, defaulting to basic');
        await setUnlimitedPlan(false);
      }

      print('DEBUG: syncWithBackend completed successfully');
    } catch (e) {
      print('ERROR: syncWithBackend failed: $e');
      // On error, don't change the current cache state
    }
  }

  /// Force refresh subscription status (for testing and immediate sync)
  static Future<void> forceRefreshSubscriptionStatus() async {
    try {
      print('DEBUG: forceRefreshSubscriptionStatus - forcing backend sync');
      await syncWithBackend();
      print('DEBUG: forceRefreshSubscriptionStatus completed');
    } catch (e) {
      print('ERROR: forceRefreshSubscriptionStatus failed: $e');
    }
  }

  /// Clear cache and force re-sync (useful for debugging)
  static Future<void> clearCacheAndSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hasUnlimitedPlanKey);
      print('DEBUG: clearCacheAndSync - cleared cache, now syncing');
      await syncWithBackend();
      print('DEBUG: clearCacheAndSync completed');
    } catch (e) {
      print('ERROR: clearCacheAndSync failed: $e');
    }
  }
}

/// Data class for subscription status
class SubscriptionStatus {
  final bool hasUnlimitedPlan;
  final int remainingResponses; // -1 for unlimited
  final String planType;

  SubscriptionStatus({
    required this.hasUnlimitedPlan,
    required this.remainingResponses,
    required this.planType,
  });

  bool get canSendResponse => hasUnlimitedPlan || remainingResponses > 0;

  String get statusText {
    if (hasUnlimitedPlan) {
      return 'Pro Plan - Unlimited Responses';
    } else {
      return 'Free Plan - $remainingResponses responses remaining this month';
    }
  }
}
