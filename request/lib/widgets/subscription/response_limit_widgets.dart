import 'package:flutter/material.dart';
import '../../services/subscription/response_limit_service.dart';
import '../../pages/subscription/simple_subscription_page.dart';

/// Widget to check response eligibility and show upgrade prompt if needed
class ResponseLimitChecker extends StatelessWidget {
  final Widget child;
  final VoidCallback? onResponseAllowed;

  const ResponseLimitChecker({
    super.key,
    required this.child,
    this.onResponseAllowed,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ResponseLimitService.canSendResponse(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final canRespond = snapshot.data ?? false;

        if (canRespond) {
          return GestureDetector(
            onTap: () {
              // Increment count when response is sent
              ResponseLimitService.incrementResponseCount();
              onResponseAllowed?.call();
            },
            child: child,
          );
        } else {
          return _buildUpgradePrompt(context);
        }
      },
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    return GestureDetector(
      onTap: () => _showUpgradeDialog(context),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.orange.shade50,
        ),
        child: Stack(
          children: [
            // Original child (grayed out)
            Opacity(
              opacity: 0.3,
              child: child,
            ),
            // Upgrade overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Upgrade to Respond',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap to upgrade to Pro',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Response Limit Reached'),
          content: const Text(
            'You\'ve used all 3 free responses for this month.\n\n'
            'Upgrade to Pro plan for unlimited responses and premium features!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SimpleSubscriptionPage(),
                  ),
                );
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        );
      },
    );
  }
}

/// Widget to display current response limit status
class ResponseLimitDisplay extends StatelessWidget {
  const ResponseLimitDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionStatus>(
      future: ResponseLimitService.getSubscriptionStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data;
        if (status == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: status.hasUnlimitedPlan
                ? Colors.green.shade50
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: status.hasUnlimitedPlan ? Colors.green : Colors.blue,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status.hasUnlimitedPlan ? Icons.verified : Icons.info_outline,
                size: 16,
                color: status.hasUnlimitedPlan ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                status.statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: status.hasUnlimitedPlan
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                ),
              ),
              if (!status.hasUnlimitedPlan &&
                  status.remainingResponses == 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SimpleSubscriptionPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Simple banner to show response limits
class ResponseLimitBanner extends StatelessWidget {
  const ResponseLimitBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionStatus>(
      future: ResponseLimitService.getSubscriptionStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data;
        if (status == null || status.hasUnlimitedPlan) {
          return const SizedBox.shrink();
        }

        // Only show banner if user has limited responses
        if (status.remainingResponses <= 1) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: status.remainingResponses == 0
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    status.remainingResponses == 0 ? Colors.red : Colors.orange,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  status.remainingResponses == 0 ? Icons.warning : Icons.info,
                  color: status.remainingResponses == 0
                      ? Colors.red
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.remainingResponses == 0
                        ? 'You\'ve used all your free responses for this month!'
                        : 'Only ${status.remainingResponses} response${status.remainingResponses == 1 ? '' : 's'} remaining this month.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SimpleSubscriptionPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text(
                    'Upgrade',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
