import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  SubscriptionStatus? _status;
  UpgradeInfo? _upgradeInfo;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() => _isLoading = true);

    try {
      final status =
          await SimpleSubscriptionService.instance.getSubscriptionStatus();
      final upgradeInfo =
          await SimpleSubscriptionService.instance.getUpgradeInfo();

      if (mounted) {
        setState(() {
          _status = status;
          _upgradeInfo = upgradeInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load subscription data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentPlanCard(),
                  const SizedBox(height: 24),
                  _buildUsageCard(),
                  const SizedBox(height: 24),
                  _buildUpgradeCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Current Plan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green[300]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'FREE PLAN',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '3 free responses per month',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard() {
    if (_status == null) return const SizedBox.shrink();

    final usagePercentage = _status!.responsesLimit > 0
        ? _status!.responsesUsed / _status!.responsesLimit
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Monthly Usage',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Usage progress bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Responses Used',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${_status!.responsesUsed} / ${_status!.responsesLimit}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: usagePercentage,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          usagePercentage >= 1.0 ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Remaining responses
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _status!.canRespond ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _status!.canRespond
                      ? Colors.green[300]!
                      : Colors.red[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _status!.canRespond ? Icons.check_circle : Icons.warning,
                    color: _status!.canRespond
                        ? Colors.green[700]
                        : Colors.red[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status!.canRespond
                          ? '${_status!.remainingResponses} responses remaining this month'
                          : 'No responses remaining this month',
                      style: TextStyle(
                        color: _status!.canRespond
                            ? Colors.green[700]
                            : Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Resets on ${_getNextMonthText()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeCard() {
    if (_upgradeInfo == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch, color: Colors.purple, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Premium Plan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_upgradeInfo!.premiumPlan['comingSoon'] == true) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[50]!, Colors.blue[50]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coming Soon!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _upgradeInfo!.message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    // Premium features
                    ...(_upgradeInfo!.premiumPlan['features'] as List? ?? [])
                        .map<Widget>(
                          (feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.check,
                                    color: Colors.green, size: 16),
                                const SizedBox(width: 8),
                                Text(feature.toString()),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
            ] else ...[
              // Premium plan available
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement premium subscription
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Premium subscription coming soon!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  'Upgrade to Premium - ${_upgradeInfo!.premiumPlan['price']}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getNextMonthText() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[nextMonth.month - 1]} 1st';
  }
}
