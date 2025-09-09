import 'package:flutter/material.dart';
import '../../services/entitlements_service.dart';
import '../../widgets/subscription_dialog.dart';

/// Mixin to add entitlements checking functionality to any widget
mixin EntitlementsCheckMixin<T extends StatefulWidget> on State<T> {
  final EntitlementsService _entitlementsService = EntitlementsService();
  UserEntitlements? _currentEntitlements;
  bool _isLoadingEntitlements = false;

  /// Get current user entitlements
  UserEntitlements? get currentEntitlements => _currentEntitlements;

  /// Check if entitlements are currently being loaded
  bool get isLoadingEntitlements => _isLoadingEntitlements;

  /// Load user entitlements (override in implementing class if needed)
  Future<void> loadEntitlements({String? userId}) async {
    if (_isLoadingEntitlements) return;

    setState(() {
      _isLoadingEntitlements = true;
    });

    try {
      final entitlements = userId != null
          ? await _entitlementsService.getUserEntitlementsSimple(userId)
          : await _entitlementsService.getUserEntitlements();

      if (mounted) {
        setState(() {
          _currentEntitlements = entitlements;
          _isLoadingEntitlements = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading entitlements: $e');
      if (mounted) {
        setState(() {
          _isLoadingEntitlements = false;
        });
      }
    }
  }

  /// Check if user can respond to requests
  Future<bool> checkCanRespond({String? userId, bool showDialog = true}) async {
    try {
      final canRespond = await _entitlementsService.canRespond(userId);

      if (!canRespond && showDialog && mounted) {
        final remainingResponses =
            await _entitlementsService.getRemainingResponses(userId);
        final shouldSubscribe = await showSubscriptionLimitDialog(
          context,
          remainingResponses: remainingResponses,
          onSubscribe: () => _handleSubscribe(),
        );

        if (shouldSubscribe == true) {
          // Handle subscription flow
          return false;
        }
      }

      return canRespond;
    } catch (e) {
      debugPrint('Error checking respond permission: $e');
      return false;
    }
  }

  /// Check if user can see contact details
  Future<bool> checkCanSeeContactDetails(
      {String? userId, bool showDialog = true}) async {
    try {
      final canSee = await _entitlementsService.canSeeContactDetails(userId);

      if (!canSee && showDialog && mounted) {
        _showContactDetailsLimitDialog();
      }

      return canSee;
    } catch (e) {
      debugPrint('Error checking contact details permission: $e');
      return false;
    }
  }

  /// Check if user can send messages
  Future<bool> checkCanSendMessages(
      {String? userId, bool showDialog = true}) async {
    try {
      final canSend = await _entitlementsService.canSendMessages(userId);

      if (!canSend && showDialog && mounted) {
        _showMessagingLimitDialog();
      }

      return canSend;
    } catch (e) {
      debugPrint('Error checking messaging permission: $e');
      return false;
    }
  }

  /// Get remaining responses count
  Future<int> getRemainingResponses({String? userId}) async {
    return await _entitlementsService.getRemainingResponses(userId);
  }

  /// Check if user has reached response limit
  Future<bool> hasReachedLimit({String? userId}) async {
    return await _entitlementsService.hasReachedResponseLimit(userId);
  }

  /// Show a warning when approaching limit
  Future<bool> checkAndWarnAboutResponseLimit({String? userId}) async {
    try {
      final remainingResponses = await getRemainingResponses(userId: userId);

      // Show warning when user has 1-2 responses left
      if (remainingResponses <= 2 && remainingResponses > 0 && mounted) {
        final shouldContinue = await showSubscriptionLimitDialog(
          context,
          remainingResponses: remainingResponses,
          onSubscribe: () => _handleSubscribe(),
        );

        // If user chose to subscribe, return false to prevent action
        // If user chose to continue, allow the action
        return shouldContinue != true;
      }

      return remainingResponses > 0;
    } catch (e) {
      debugPrint('Error checking response limit: $e');
      return false;
    }
  }

  /// Handle subscription flow (override in implementing class)
  void _handleSubscribe() {
    // Default implementation - navigate to subscription screen
    // Override this method in your implementing class
    if (mounted) {
      Navigator.of(context).pop(true);
      // Navigate to subscription screen
      _navigateToSubscription();
    }
  }

  /// Navigate to subscription screen (override in implementing class)
  void _navigateToSubscription() {
    // Override this in implementing class to navigate to your subscription screen
    debugPrint('Navigate to subscription screen - implement this method');

    // Example:
    // Navigator.pushNamed(context, '/subscription');
  }

  /// Show contact details limit dialog
  void _showContactDetailsLimitDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.contact_phone, color: Colors.orange),
            SizedBox(width: 12),
            Text('Contact Details Locked'),
          ],
        ),
        content: const Text(
          'Subscribe to access contact details and connect directly with service providers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSubscribe();
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  /// Show messaging limit dialog
  void _showMessagingLimitDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.message, color: Colors.orange),
            SizedBox(width: 12),
            Text('Messaging Locked'),
          ],
        ),
        content: const Text(
          'Subscribe to send messages and communicate directly with other users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSubscribe();
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  /// Build widget that shows remaining responses
  Widget buildResponsesRemaining() {
    if (_currentEntitlements == null) return const SizedBox.shrink();

    return ResponsesRemainingWidget(
      remainingResponses: _currentEntitlements!.remainingResponses,
      isVisible: _currentEntitlements!.isFreePlan,
    );
  }

  /// Build loading indicator for entitlements
  Widget buildEntitlementsLoading() {
    if (!_isLoadingEntitlements) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
