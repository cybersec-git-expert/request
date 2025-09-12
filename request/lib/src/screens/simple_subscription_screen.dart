import 'package:flutter/material.dart';
import '../services/simple_subscription_service.dart';

class SimpleSubscriptionScreen extends StatefulWidget {
  const SimpleSubscriptionScreen({super.key});

  @override
  State<SimpleSubscriptionScreen> createState() =>
      _SimpleSubscriptionScreenState();
}

class _SimpleSubscriptionScreenState extends State<SimpleSubscriptionScreen> {
  bool _isLoading = true;
  SimpleSubscriptionStatus? _status;
  List<SubscriptionPlan> _plans = [];

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
      final plans =
          await SimpleSubscriptionService.instance.getAvailablePlans();

      if (mounted) {
        setState(() {
          _status = status;
          _plans = plans;
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

  Future<void> _subscribeToPlan(String planCode) async {
    try {
      final result =
          await SimpleSubscriptionService.instance.subscribeToPlan(planCode);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.requiresPayment
                ? 'Redirecting to payment...'
                : 'Subscription updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // If payment is required, handle payment flow
        if (result.requiresPayment && result.paymentId != null) {
          // TODO: Navigate to payment screen with result.paymentId
          print('Payment required. Payment ID: ${result.paymentId}');
        }

        _loadSubscriptionData(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Failed to update subscription'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_status != null) _buildCurrentStatusCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'Available Plans',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._plans.map((plan) => _buildPlanCard(plan)),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentStatusCard() {
    final status = _status!;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.isPremium ? Icons.star : Icons.person,
                  color: status.isPremium ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Plan: ${status.planName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!status.isUnlimited) ...[
              LinearProgressIndicator(
                value:
                    status.responsesLimit != null && status.responsesLimit! > 0
                        ? status.responsesUsed / status.responsesLimit!
                        : 0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  status.canRespond ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    status.canRespond ? Icons.check_circle : Icons.warning,
                    color: status.canRespond ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status.responsesRemaining != null
                        ? '${status.responsesRemaining} responses remaining this month'
                        : 'Unlimited responses',
                    style: TextStyle(
                      color: status.canRespond ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: const [
                  Icon(Icons.all_inclusive, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Unlimited responses',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            if (status.isVerifiedBusiness) ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.verified, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Verified Business',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isCurrentPlan = _status?.planCode == plan.code;

    return Card(
      elevation: isCurrentPlan ? 8 : 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isCurrentPlan ? Colors.blue[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrentPlan) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.priceText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: plan.isFree ? Colors.green : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCurrentPlan)
                  ElevatedButton(
                    onPressed: () => _subscribeToPlan(plan.code),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isFree ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(plan.isFree ? 'Switch' : 'Upgrade'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (plan.description != null) ...[
              Text(
                plan.description!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(
                  plan.isUnlimited ? Icons.all_inclusive : Icons.reply,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  plan.responseText,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Features:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              ...plan.features.map((feature) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
