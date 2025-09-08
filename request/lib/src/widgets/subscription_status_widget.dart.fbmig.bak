import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';

class SubscriptionStatusWidget extends StatefulWidget {
  final bool showFullDetails;
  final VoidCallback? onUpgradePressed;

  const SubscriptionStatusWidget({
    Key? key,
    this.showFullDetails = false,
    this.onUpgradePressed,
  }) : super(key: key);

  @override
  State<SubscriptionStatusWidget> createState() => _SubscriptionStatusWidgetState();
}

class _SubscriptionStatusWidgetState extends State<SubscriptionStatusWidget> {
  Map<String, dynamic>? subscriptionStatus;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final status = await SubscriptionService.getSubscriptionStatus(user.uid);
      setState(() {
        subscriptionStatus = status;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (subscriptionStatus == null || !subscriptionStatus!['hasSubscription']) {
      return _buildNoSubscriptionCard();
    }

    final hasActiveAccess = subscriptionStatus!['hasActiveAccess'] ?? false;
    final isTrialActive = subscriptionStatus!['isTrialActive'] ?? false;

    if (widget.showFullDetails) {
      return _buildDetailedStatusCard();
    }

    // Show warning for expired subscriptions or limited access
    if (!hasActiveAccess) {
      return _buildUpgradePromptCard();
    }

    if (isTrialActive) {
      return _buildTrialStatusCard();
    }

    return _buildActiveSubscriptionCard();
  }

  Widget _buildNoSubscriptionCard() {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Start your 3-month free trial!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () => _navigateToSubscription(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialStatusCard() {
    final remainingDays = subscriptionStatus!['remainingTrialDays'] ?? 0;
    
    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.schedule, color: Colors.green[700], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Free Trial Active',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$remainingDays days remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (remainingDays <= 7) // Show upgrade button when trial is about to expire
              ElevatedButton(
                onPressed: () => _navigateToSubscription(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upgrade'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionCard() {
    final remainingDays = subscriptionStatus!['remainingSubscriptionDays'] ?? 0;
    
    return Card(
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Premium Active',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (remainingDays > 0)
                    Text(
                      '$remainingDays days remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _navigateToSubscription(),
              icon: const Icon(Icons.settings),
              tooltip: 'Manage Subscription',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradePromptCard() {
    final type = subscriptionStatus!['type'] ?? 'rider';
    
    return Card(
      color: Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_outlined, color: Colors.orange[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Limited Access',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        type == 'rider' 
                            ? 'Only 3 rides/month • No notifications'
                            : 'Pay per click • Limited features',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.onUpgradePressed ?? () => _navigateToSubscription(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Upgrade'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatusCard() {
    final status = subscriptionStatus!;
    final hasActiveAccess = status['hasActiveAccess'] ?? false;
    final isTrialActive = status['isTrialActive'] ?? false;
    final type = status['type'] ?? 'rider';
    final usageStats = status['usageStats'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subscription Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToSubscription(),
                  child: const Text('View Details'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasActiveAccess ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasActiveAccess ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasActiveAccess ? Icons.check_circle : Icons.warning_outlined,
                    size: 16,
                    color: hasActiveAccess ? Colors.green[700] : Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTrialActive ? 'Free Trial' : hasActiveAccess ? 'Premium' : 'Limited Access',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasActiveAccess ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Usage stats
            if (type == 'rider') ...[
              _buildStatRow('Rides this month:', '${usageStats['ridesResponded'] ?? 0}'),
              if (!hasActiveAccess)
                _buildStatRow('Remaining free rides:', '${3 - (usageStats['ridesResponded'] ?? 0)}'),
            ] else ...[
              _buildStatRow('Clicks received:', '${usageStats['clicksReceived'] ?? 0}'),
              _buildStatRow('Total spent:', '${status['currency'] ?? 'Rs'}${usageStats['totalSpent']?.toStringAsFixed(2) ?? '0.00'}'),
            ],
            
            if (!hasActiveAccess) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onUpgradePressed ?? () => _navigateToSubscription(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Upgrade Now'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _navigateToSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionScreen(),
      ),
    );
  }
}

/// Subscription check mixin for screens that need to verify subscription status
mixin SubscriptionCheckMixin<T extends StatefulWidget> on State<T> {
  /// Check if user can perform an action based on their subscription
  Future<bool> checkSubscriptionAccess(String action, {bool showDialog = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final canPerform = await SubscriptionService.canPerformAction(user.uid, action);
      
      if (!canPerform && showDialog && mounted) {
        _showSubscriptionRequiredDialog(action);
      }
      
      return canPerform;
    } catch (e) {
      return false;
    }
  }

  /// Record user action for subscription tracking
  Future<void> recordSubscriptionAction(String action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (action == 'respond_to_ride') {
        await SubscriptionService.recordRiderAction(user.uid, action);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _showSubscriptionRequiredDialog(String action) {
    String title = 'Subscription Required';
    String message = 'You need an active subscription to perform this action.';
    
    switch (action) {
      case 'respond_to_ride':
        title = 'Ride Response Limit Reached';
        message = 'You have reached your limit of 3 ride responses for this month. Upgrade to premium for unlimited responses.';
        break;
      case 'receive_notifications':
        title = 'Premium Feature';
        message = 'Real-time ride notifications are available for premium subscribers only.';
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Upgrade Now'),
            ),
          ],
        );
      },
    );
  }
}
