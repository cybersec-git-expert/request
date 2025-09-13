import 'package:flutter/material.dart';

class SubscriptionRenewalDialog extends StatelessWidget {
  final int daysRemaining;
  final VoidCallback onRenew;
  final VoidCallback onDismiss;
  final bool isLastWarning;

  const SubscriptionRenewalDialog({
    super.key,
    required this.daysRemaining,
    required this.onRenew,
    required this.onDismiss,
    this.isLastWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getWarningColor().withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getWarningIcon(),
                size: 40,
                color: _getWarningColor(),
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              _getTitle(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              _getMessage(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                // Dismiss Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isLastWarning ? 'I understand' : 'Remind me later',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Renew Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRenew,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getWarningColor(),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Renew Now',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    if (daysRemaining <= 0) {
      return 'Subscription Expired';
    } else if (daysRemaining == 1) {
      return 'Last Day!';
    } else {
      return 'Subscription Ending Soon';
    }
  }

  String _getMessage() {
    if (daysRemaining <= 0) {
      return 'Your Pro subscription has expired. Renew now to continue enjoying unlimited requests and premium features.';
    } else if (daysRemaining == 1) {
      return 'Your Pro subscription expires tomorrow. Renew now to avoid any interruption to your service.';
    } else {
      return 'Your Pro subscription expires in $daysRemaining days. Renew now to continue enjoying unlimited requests and premium features.';
    }
  }

  IconData _getWarningIcon() {
    if (daysRemaining <= 0) {
      return Icons.error_outline;
    } else if (daysRemaining <= 1) {
      return Icons.warning_amber;
    } else {
      return Icons.schedule;
    }
  }

  Color _getWarningColor() {
    if (daysRemaining <= 0) {
      return Colors.red;
    } else if (daysRemaining <= 1) {
      return Colors.orange;
    } else {
      return Colors.amber;
    }
  }

  /// Show renewal dialog with appropriate styling based on days remaining
  static Future<bool?> show(
    BuildContext context, {
    required int daysRemaining,
    required VoidCallback onRenew,
    bool isLastWarning = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !isLastWarning, // Force interaction on last warning
      builder: (context) => SubscriptionRenewalDialog(
        daysRemaining: daysRemaining,
        onRenew: onRenew,
        onDismiss: () => Navigator.of(context).pop(false),
        isLastWarning: isLastWarning,
      ),
    );
  }
}

/// Helper widget for subscription warnings in other screens
class SubscriptionWarningBanner extends StatelessWidget {
  final int daysRemaining;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const SubscriptionWarningBanner({
    super.key,
    required this.daysRemaining,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getWarningColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getWarningColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getWarningIcon(),
            color: _getWarningColor(),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getTitle(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _getWarningColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getMessage(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: _getWarningColor(),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            child: const Text(
              'Renew',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTitle() {
    if (daysRemaining <= 0) {
      return 'Subscription Expired';
    } else if (daysRemaining == 1) {
      return 'Expires Tomorrow';
    } else {
      return 'Expires in $daysRemaining days';
    }
  }

  String _getMessage() {
    if (daysRemaining <= 0) {
      return 'Renew to restore unlimited access';
    } else {
      return 'Renew now to avoid service interruption';
    }
  }

  IconData _getWarningIcon() {
    if (daysRemaining <= 0) {
      return Icons.error_outline;
    } else if (daysRemaining <= 1) {
      return Icons.warning_amber;
    } else {
      return Icons.schedule;
    }
  }

  Color _getWarningColor() {
    if (daysRemaining <= 0) {
      return Colors.red;
    } else if (daysRemaining <= 1) {
      return Colors.orange;
    } else {
      return Colors.amber;
    }
  }
}
