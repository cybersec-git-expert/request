import 'entitlement_service.dart';

class EntitlementsService {
  /// Get user's current entitlements via unified API
  static Future<Map<String, dynamic>?> getUserEntitlements() async {
    try {
      return await EntitlementService.instance.getMyEntitlements();
    } catch (e) {
      // Swallow errors and return null to allow callers to degrade gracefully
      return null;
    }
  }

  /// Check if user can see contact details
  static Future<bool> canSeeContactDetails() async {
    final ent = await getUserEntitlements();
    return ent?['canSeeContactDetails'] == true;
  }

  /// Check if user can send messages
  static Future<bool> canSendMessages() async {
    final ent = await getUserEntitlements();
    return ent?['canSendMessages'] == true;
  }

  /// Check if user can respond to requests
  static Future<bool> canRespond() async {
    final ent = await getUserEntitlements();
    return ent?['canRespond'] == true;
  }

  /// Get entitlements summary for UI display
  static Future<EntitlementsSummary> getEntitlementsSummary() async {
    final entitlements = await getUserEntitlements();

    if (entitlements == null) {
      return EntitlementsSummary(
        canSeeContactDetails: false,
        canSendMessages: false,
        canRespond: false,
        responseCount: 0,
        remainingResponses: '0',
        subscriptionType: 'free',
        planName: 'Free Plan',
      );
    }

    // Support both shapes:
    // - Legacy: { canSeeContactDetails, canSendMessages, canRespond, responseCount, remainingResponses, subscriptionType, planName }
    // - New: { isSubscribed, audience, responseCountThisMonth, canViewContact, canMessage, subscription }
    final bool canViewContact = entitlements['canSeeContactDetails'] == true ||
        entitlements['canViewContact'] == true;
    final bool canMessage = entitlements['canSendMessages'] == true ||
        entitlements['canMessage'] == true;
    // Respond entitlement follows messaging/contacts gating in backend
    final bool canRespond =
        entitlements['canRespond'] == true || canMessage == true;

    final int responseCount = (entitlements['responseCount'] as int?) ??
        (entitlements['responseCountThisMonth'] as int?) ??
        0;

    final bool isSubscribed = entitlements['isSubscribed'] == true ||
        (entitlements['subscription'] != null);

    // Derive remaining responses: if subscribed OR business audience (free unlimited), mark unlimited
    final String audience = entitlements['audience']?.toString() ?? '';
    String remaining = entitlements['remainingResponses']?.toString() ?? '';
    if (remaining.isEmpty) {
      if (isSubscribed || audience == 'business') {
        remaining = 'unlimited';
      } else {
        final int freeLimit = 3; // default free limit for normal audience
        final int left = freeLimit - responseCount;
        remaining = left > 0 ? left.toString() : '0';
      }
    }

    final String subscriptionType =
        entitlements['subscriptionType']?.toString() ??
            (isSubscribed
                ? (entitlements['subscription']?['plan_type']?.toString() ??
                    'subscribed')
                : 'free');

    final String planName = entitlements['planName']?.toString() ??
        (isSubscribed
            ? (entitlements['subscription']?['name']?.toString() ??
                'Subscribed')
            : 'Free Plan');

    return EntitlementsSummary(
      canSeeContactDetails: canViewContact,
      canSendMessages: canMessage,
      canRespond: canRespond,
      responseCount: responseCount,
      remainingResponses: remaining,
      subscriptionType: subscriptionType,
      planName: planName,
    );
  }
}

class EntitlementsSummary {
  final bool canSeeContactDetails;
  final bool canSendMessages;
  final bool canRespond;
  final int responseCount;
  final String remainingResponses;
  final String subscriptionType;
  final String planName;

  EntitlementsSummary({
    required this.canSeeContactDetails,
    required this.canSendMessages,
    required this.canRespond,
    required this.responseCount,
    required this.remainingResponses,
    required this.subscriptionType,
    required this.planName,
  });

  bool get isSubscribed => subscriptionType != 'free';
  bool get hasUnlimitedResponses => remainingResponses == 'unlimited';

  String get statusText {
    if (isSubscribed) {
      return 'Subscribed: $planName';
    } else {
      return 'Free Plan: $remainingResponses responses remaining';
    }
  }
}
