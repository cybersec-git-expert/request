import 'package:flutter/material.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription_models.dart';
import '../../theme/glass_theme.dart';

class QuickUpgradeSheet extends StatefulWidget {
  final String contextType; // 'driver' | 'business' | 'product_seller'
  const QuickUpgradeSheet({super.key, required this.contextType});

  static Future<void> show(BuildContext context, String contextType) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GlassTheme.colors.glassBackground.first,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: QuickUpgradeSheet(contextType: contextType),
      ),
    );
  }

  @override
  State<QuickUpgradeSheet> createState() => _QuickUpgradeSheetState();
}

class _QuickUpgradeSheetState extends State<QuickUpgradeSheet> {
  final _svc = SubscriptionService.instance;
  bool _loading = true;
  SubscriptionPlan? _recommended;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final plans = await _svc.availablePlans();
      _recommended = (widget.contextType == 'product_seller')
          ? _pickRecommendedProductPlan(plans)
          : _pickRecommendedResponsePlan(plans);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isFree(SubscriptionPlan p) =>
      (p.price == null || (p.price is num && (p.price as num) == 0));
  bool _isUnlimited(SubscriptionPlan p) =>
      p.planType.toLowerCase() == 'unlimited';

  SubscriptionPlan? _pickRecommendedResponsePlan(List<SubscriptionPlan> plans) {
    // Prefer a paid unlimited plan; fallback to cheapest paid
    final paid = plans.where((p) => !_isFree(p)).toList();
    if (paid.isEmpty) return null;
    final unlimited = paid.where(_isUnlimited).toList();
    if (unlimited.isNotEmpty) return unlimited.first;
    paid.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
    return paid.first;
  }

  SubscriptionPlan? _pickRecommendedProductPlan(List<SubscriptionPlan> plans) {
    // Prefer monthly/unlimited over PPC; fallback to cheapest paid
    final paid = plans.where((p) => !_isFree(p)).toList();
    if (paid.isEmpty) return null;
    final monthlyish =
        paid.where((p) => p.planType.toLowerCase() != 'ppc').toList();
    if (monthlyish.isNotEmpty) {
      monthlyish.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
      return monthlyish.first;
    }
    paid.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
    return paid.first;
  }

  Future<void> _subscribe() async {
    // Removed gateway/checkout logic in this flow
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushNamed(context, '/membership', arguments: {
      'promptOnboarding': true,
    });
  }

  // Removed gateway/checkout logic in this flow

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: _loading
          ? const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()))
          : _recommended == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No plans available',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: GlassTheme.colors.textPrimary)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/membership', arguments: {
                          'requiredSubscriptionType': widget.contextType,
                        });
                      },
                      child: const Text('See all plans'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user,
                            color: GlassTheme.colors.primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          widget.contextType == 'driver'
                              ? 'Driver Plan'
                              : widget.contextType == 'business'
                                  ? 'Business Plan'
                                  : 'Product Seller Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: GlassTheme.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _recommended!.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: GlassTheme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_recommended!.currency != null &&
                        _recommended!.price != null)
                      Text(
                        '${_recommended!.currency} ${_recommended!.price}',
                        style:
                            TextStyle(color: GlassTheme.colors.textSecondary),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'Unlimited responses, contact visibility and instant notifications.',
                      style: TextStyle(color: GlassTheme.colors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _subscribe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlassTheme.colors.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('See Plans'),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/membership', arguments: {
                          'requiredSubscriptionType': widget.contextType,
                        });
                      },
                      child: const Text('See all plans'),
                    ),
                  ],
                ),
    );
  }
}
