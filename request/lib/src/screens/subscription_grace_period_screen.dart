import 'package:flutter/material.dart';
import '../screens/simple_subscription_screen.dart';

class SubscriptionGracePeriodScreen extends StatefulWidget {
  final int graceDaysRemaining;
  final DateTime expiryDate;

  const SubscriptionGracePeriodScreen({
    super.key,
    required this.graceDaysRemaining,
    required this.expiryDate,
  });

  @override
  State<SubscriptionGracePeriodScreen> createState() =>
      _SubscriptionGracePeriodScreenState();
}

class _SubscriptionGracePeriodScreenState
    extends State<SubscriptionGracePeriodScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  Text(
                    'Grace Period',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the row
                ],
              ),

              const SizedBox(height: 40),

              // Main Content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Grace Period Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _getGraceColor().withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_bottom,
                        size: 60,
                        color: _getGraceColor(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      _getTitle(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Grace period countdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _getGraceColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: _getGraceColor().withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.graceDaysRemaining > 0
                            ? '${widget.graceDaysRemaining} days remaining'
                            : 'Final day',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _getGraceColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _getDescription(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color:
                              theme.colorScheme.onBackground.withOpacity(0.7),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Features reminder
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'What you\'ll lose without Pro:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._buildFeatureList(theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Column(
                children: [
                  // Renew Now Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _renewNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getGraceColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Renew Pro Subscription',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Continue with Basic Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isLoading ? null : _continueWithBasic,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            theme.colorScheme.onBackground.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        widget.graceDaysRemaining > 0
                            ? 'Continue with Basic Plan'
                            : 'Switch to Basic Plan',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    if (widget.graceDaysRemaining <= 0) {
      return 'Grace Period Ending';
    } else {
      return 'Your Pro Subscription Expired';
    }
  }

  String _getDescription() {
    if (widget.graceDaysRemaining <= 0) {
      return 'This is your final day of grace period access. Renew now to keep your Pro features, or you\'ll be switched to the Basic plan tomorrow.';
    } else {
      return 'Don\'t worry! You still have ${widget.graceDaysRemaining} days of grace period to renew your subscription and keep all your Pro features.';
    }
  }

  Color _getGraceColor() {
    if (widget.graceDaysRemaining <= 0) {
      return Colors.red;
    } else if (widget.graceDaysRemaining <= 2) {
      return Colors.orange;
    } else {
      return Colors.amber;
    }
  }

  List<Widget> _buildFeatureList(ThemeData theme) {
    final features = [
      'Unlimited requests per day',
      'Priority support response',
      'Advanced analytics & insights',
      'Premium business features',
    ];

    return features
        .map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  Future<void> _renewNow() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Navigate to subscription screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SimpleSubscriptionScreen(),
        ),
      );

      // After returning from subscription screen, pop this grace period screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening subscription screen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _continueWithBasic() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch to Basic Plan?'),
        content: Text(
          widget.graceDaysRemaining > 0
              ? 'You still have ${widget.graceDaysRemaining} days to renew. Are you sure you want to switch to Basic plan now?'
              : 'Are you sure you want to switch to the Basic plan? You can always upgrade later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close grace period screen
            },
            child: const Text('Switch to Basic'),
          ),
        ],
      ),
    );
  }

  /// Static method to show grace period screen
  static Future<void> show(
    BuildContext context, {
    required int graceDaysRemaining,
    required DateTime expiryDate,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubscriptionGracePeriodScreen(
          graceDaysRemaining: graceDaysRemaining,
          expiryDate: expiryDate,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}
