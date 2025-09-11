import 'package:flutter/material.dart';
import '../services/simple_subscription_service.dart';
import '../screens/simple_subscription_screen.dart';

class ResponseEligibilityChecker extends StatelessWidget {
  final Widget child;
  final VoidCallback? onEligible;
  final String? requestId;

  const ResponseEligibilityChecker({
    super.key,
    required this.child,
    this.onEligible,
    this.requestId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResponseEligibility>(
      future: SimpleSubscriptionService.instance.canRespond(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final eligibility = snapshot.data;
        if (eligibility == null || !eligibility.canRespond) {
          return _buildLimitReachedCard(context, eligibility);
        }

        // User can respond - show the original child widget
        return child;
      },
    );
  }

  Widget _buildLimitReachedCard(
      BuildContext context, ResponseEligibility? eligibility) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Colors.orange[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Response Limit Reached',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              eligibility?.message ??
                  'You have reached your monthly response limit. Upgrade to premium for unlimited responses.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (eligibility?.responsesUsed != null &&
                eligibility?.responsesLimit != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: eligibility!.responsesLimit! > 0
                    ? eligibility.responsesUsed! / eligibility.responsesLimit!
                    : 1.0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
              ),
              const SizedBox(height: 8),
              Text(
                '${eligibility.responsesUsed}/${eligibility.responsesLimit} responses used this month',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const SimpleSubscriptionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Upgrade'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A wrapper widget that checks eligibility before allowing response submission
class EligibilityWrappedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final String? requestId;

  const EligibilityWrappedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.requestId,
  });

  @override
  State<EligibilityWrappedButton> createState() =>
      _EligibilityWrappedButtonState();
}

class _EligibilityWrappedButtonState extends State<EligibilityWrappedButton> {
  bool _isChecking = false;

  Future<void> _checkEligibilityAndProceed() async {
    setState(() => _isChecking = true);

    try {
      final eligibility = await SimpleSubscriptionService.instance.canRespond();

      if (!mounted) return;

      if (eligibility.canRespond) {
        // User can respond - proceed with original action
        widget.onPressed();
      } else {
        // Show upgrade dialog
        _showUpgradeDialog(eligibility);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking eligibility: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _showUpgradeDialog(ResponseEligibility eligibility) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Response Limit Reached'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(eligibility.message ??
                'You have reached your monthly response limit.'),
            if (eligibility.responsesUsed != null &&
                eligibility.responsesLimit != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: eligibility.responsesLimit! > 0
                    ? eligibility.responsesUsed! / eligibility.responsesLimit!
                    : 1.0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
              ),
              const SizedBox(height: 8),
              Text(
                '${eligibility.responsesUsed}/${eligibility.responsesLimit} responses used this month',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SimpleSubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isChecking ? null : _checkEligibilityAndProceed,
      child: _isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : widget.child,
    );
  }
}
