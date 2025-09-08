import 'package:flutter/material.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _api = SubscriptionServiceApi.instance;
  bool _loading = true;
  List<SubscriptionPlan> _plans = [];
  Map<String, dynamic>? _current;
  String _type = 'rider';
  final _promoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plans = await _api.fetchPlans(type: _type, activeOnly: true);
    final current = await _api.getMySubscription();
    setState(() {
      _plans = plans;
      _current = current;
      _loading = false;
    });
  }

  Future<void> _startPlan(SubscriptionPlan plan) async {
    setState(() => _loading = true);
    final promo = _promoController.text.trim();
    final ok = await _api.startSubscription(plan.id,
        promoCode: promo.isEmpty ? null : promo);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            ok ? 'Subscription activated' : 'Failed to start subscription'),
      ));
    }
    await _load();
  }

  Future<void> _cancel({bool immediate = false}) async {
    setState(() => _loading = true);
    final ok = await _api.cancelSubscription(immediate: immediate);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            ok ? 'Subscription canceled' : 'Failed to cancel subscription'),
      ));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Promo code input
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Promo code',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _promoController,
                            decoration: const InputDecoration(
                              hintText: 'Enter promo code (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              'Apply a promo to get a free trial period if eligible.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                  if (_current != null) _buildCurrentCard(),
                  ..._plans.map(_buildPlanCard),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentCard() {
    final p = _current!;
    final planName = p['name'] ?? p['plan']?['name'] ?? 'Current Plan';
    final until = p['current_period_end'];
    return Card(
      color: Colors.green.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(planName.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Renews until: ${until ?? '-'}'),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton(
                  onPressed: () => _cancel(immediate: false),
                  child: const Text('Cancel at period end')),
              const SizedBox(width: 8),
              TextButton(
                  onPressed: () => _cancel(immediate: true),
                  child: const Text('Cancel now')),
            ])
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final priceStr = plan.price == null || plan.price == 0
        ? 'Free'
        : '${plan.currency ?? ''} ${plan.price} / ${plan.durationDays ?? 30}d';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (plan.description != null && plan.description!.isNotEmpty)
              Text(plan.description!),
            const SizedBox(height: 8),
            Text(priceStr, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _startPlan(plan),
                child: const Text('Choose'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
