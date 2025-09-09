import 'package:flutter/material.dart';

/// Dialog shown when user hits their response limit and needs to subscribe
class SubscriptionLimitDialog extends StatelessWidget {
  final int remainingResponses;
  final VoidCallback? onSubscribe;
  final VoidCallback? onCancel;

  const SubscriptionLimitDialog({
    Key? key,
    required this.remainingResponses,
    this.onSubscribe,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasReachedLimit = remainingResponses <= 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            hasReachedLimit ? Icons.block : Icons.warning,
            color: hasReachedLimit ? Colors.red : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasReachedLimit
                  ? 'Response Limit Reached'
                  : 'Response Limit Warning',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasReachedLimit) ...[
            Text(
              'You have used all your free responses.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Subscribe to continue responding to requests and unlock unlimited access.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Text(
              'You have $remainingResponses free response${remainingResponses == 1 ? '' : 's'} remaining.',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'After using all free responses, you\'ll need to subscribe to continue.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Premium Benefits',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBenefitItem(
                  context,
                  Icons.all_inclusive,
                  'Unlimited responses',
                ),
                _buildBenefitItem(
                  context,
                  Icons.contact_phone,
                  'Access to contact details',
                ),
                _buildBenefitItem(
                  context,
                  Icons.message,
                  'Direct messaging',
                ),
                _buildBenefitItem(
                  context,
                  Icons.notifications,
                  'Priority notifications',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: Text(
            hasReachedLimit ? 'Maybe Later' : 'Continue',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onSubscribe ?? () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Subscribe Now'),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show subscription limit dialog
Future<bool?> showSubscriptionLimitDialog(
  BuildContext context, {
  required int remainingResponses,
  VoidCallback? onSubscribe,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SubscriptionLimitDialog(
      remainingResponses: remainingResponses,
      onSubscribe: onSubscribe,
    ),
  );
}

/// Widget to show remaining responses counter
class ResponsesRemainingWidget extends StatelessWidget {
  final int remainingResponses;
  final bool isVisible;

  const ResponsesRemainingWidget({
    Key? key,
    required this.remainingResponses,
    this.isVisible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final Color color = remainingResponses <= 1
        ? Colors.red
        : remainingResponses <= 3
            ? Colors.orange
            : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '$remainingResponses response${remainingResponses == 1 ? '' : 's'} left',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
