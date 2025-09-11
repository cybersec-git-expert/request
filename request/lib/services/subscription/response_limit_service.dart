import 'package:shared_preferences/shared_preferences.dart';

/// Simple subscription service to track response limits and subscription status
/// Implements the 3 responses per month limit for free users
class ResponseLimitService {
  static const String _responseCountKey = 'monthly_response_count';
  static const String _lastResetKey = 'last_monthly_reset';
  static const String _hasUnlimitedPlanKey = 'has_unlimited_plan';
  static const int _freeMonthlyLimit = 3;

  /// Check if user can send a response
  static Future<bool> canSendResponse() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user has unlimited plan
    final hasUnlimited = prefs.getBool(_hasUnlimitedPlanKey) ?? false;
    if (hasUnlimited) return true;

    // Check monthly reset
    await _checkAndResetMonthlyCount();

    // Get current response count
    final responseCount = prefs.getInt(_responseCountKey) ?? 0;

    return responseCount < _freeMonthlyLimit;
  }

  /// Get remaining responses for the month
  static Future<int> getRemainingResponses() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user has unlimited plan
    final hasUnlimited = prefs.getBool(_hasUnlimitedPlanKey) ?? false;
    if (hasUnlimited) return -1; // -1 indicates unlimited

    // Check monthly reset
    await _checkAndResetMonthlyCount();

    // Get current response count
    final responseCount = prefs.getInt(_responseCountKey) ?? 0;

    return (_freeMonthlyLimit - responseCount).clamp(0, _freeMonthlyLimit);
  }

  /// Increment response count (call this when user sends a response)
  static Future<void> incrementResponseCount() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user has unlimited plan
    final hasUnlimited = prefs.getBool(_hasUnlimitedPlanKey) ?? false;
    if (hasUnlimited) return; // Don't count for unlimited users

    // Check monthly reset
    await _checkAndResetMonthlyCount();

    // Increment count
    final currentCount = prefs.getInt(_responseCountKey) ?? 0;
    await prefs.setInt(_responseCountKey, currentCount + 1);
  }

  /// Check if it's a new month and reset count if needed
  static Future<void> _checkAndResetMonthlyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonth = now.year * 12 + now.month;

    final lastReset = prefs.getInt(_lastResetKey) ?? 0;

    if (currentMonth > lastReset) {
      // New month, reset count
      await prefs.setInt(_responseCountKey, 0);
      await prefs.setInt(_lastResetKey, currentMonth);
    }
  }

  /// Upgrade user to unlimited plan
  static Future<void> upgradeToUnlimited() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasUnlimitedPlanKey, true);
  }

  /// Check if user has unlimited plan
  static Future<bool> hasUnlimitedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasUnlimitedPlanKey) ?? false;
  }

  /// Downgrade user to free plan (for testing or subscription cancellation)
  static Future<void> downgradeToFree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasUnlimitedPlanKey, false);
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

  /// Reset all subscription data (for testing)
  static Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_responseCountKey);
    await prefs.remove(_lastResetKey);
    await prefs.remove(_hasUnlimitedPlanKey);
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
