import 'package:flutter/material.dart';
import '../models/enhanced_benefit_plan.dart';
import '../services/enhanced_business_benefits_service.dart';

class BenefitPlanCard extends StatelessWidget {
  final EnhancedBenefitPlan plan;
  final bool isCurrentPlan;
  final bool isRecommended;
  final VoidCallback? onSubscribe;
  final VoidCallback? onViewDetails;

  const BenefitPlanCard({
    Key? key,
    required this.plan,
    this.isCurrentPlan = false,
    this.isRecommended = false,
    this.onSubscribe,
    this.onViewDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isRecommended ? 8 : 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isRecommended
              ? Border.all(color: theme.primaryColor, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with plan name and type
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getPlanTypeColor(plan.planType).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.planName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isCurrentPlan)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CURRENT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(_getPlanTypeLabel(plan.planType)),
                    backgroundColor: _getPlanTypeColor(plan.planType),
                    labelStyle: const TextStyle(color: Colors.white),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),

            // Plan content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      plan.planDescription,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    // Pricing display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        plan.priceDisplay,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Features
                    Expanded(
                      child: _buildFeatures(context),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!isCurrentPlan && onSubscribe != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onSubscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isRecommended ? theme.primaryColor : null,
                        ),
                        child: Text(
                          isRecommended ? 'Choose Recommended' : 'Subscribe',
                        ),
                      ),
                    ),
                  if (onViewDetails != null)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onViewDetails,
                        child: const Text('View Details'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatures(BuildContext context) {
    final theme = Theme.of(context);
    final features = <Widget>[];

    // Response-based features
    if (plan.planType == 'response_based' || plan.planType == 'hybrid') {
      if (plan.hasUnlimitedResponses) {
        features.add(_buildFeatureItem(
          context,
          Icons.all_inclusive,
          'Unlimited responses',
          Colors.green,
        ));
      } else {
        final limit = plan.responseLimit;
        if (limit != null) {
          features.add(_buildFeatureItem(
            context,
            Icons.chat_bubble_outline,
            '$limit responses per month',
            Colors.blue,
          ));
        }
      }

      if (plan.allowsContactRevealing) {
        features.add(_buildFeatureItem(
          context,
          Icons.contact_phone,
          'Contact details revealed',
          Colors.green,
        ));
      }

      if (plan.allowsMessagingRequesters) {
        features.add(_buildFeatureItem(
          context,
          Icons.message,
          'Can message requesters',
          Colors.blue,
        ));
      }
    }

    // Pricing-based features
    if (plan.planType == 'pricing_based' || plan.planType == 'hybrid') {
      final pricingModel = plan.pricingModel;
      if (pricingModel != null) {
        switch (pricingModel) {
          case 'per_click':
            features.add(_buildFeatureItem(
              context,
              Icons.mouse,
              'Pay per click pricing',
              Colors.orange,
            ));
            break;
          case 'monthly':
            features.add(_buildFeatureItem(
              context,
              Icons.calendar_month,
              'Monthly subscription',
              Colors.purple,
            ));
            break;
          case 'bundle':
            features.add(_buildFeatureItem(
              context,
              Icons.inventory,
              'Bundle package',
              Colors.green,
            ));
            break;
        }
      }
    }

    // General features
    final featuresConfig = plan.config['features'];
    if (featuresConfig is Map<String, dynamic>) {
      featuresConfig.forEach((key, value) {
        if (value == true) {
          final featureName = key.replaceAll('_', ' ').toLowerCase();
          features.add(_buildFeatureItem(
            context,
            _getFeatureIcon(key),
            featureName
                .split(' ')
                .map((word) => word.isNotEmpty
                    ? word[0].toUpperCase() + word.substring(1)
                    : word)
                .join(' '),
            Colors.green,
          ));
        }
      });
    }

    // Allowed response types
    if (plan.allowedResponseTypes.isNotEmpty) {
      features.add(_buildFeatureItem(
        context,
        Icons.business,
        'Can respond to ${plan.allowedResponseTypes.length} business types',
        Colors.blue,
      ));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => features[index],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Color _getPlanTypeColor(String planType) {
    switch (planType) {
      case 'response_based':
        return Colors.blue;
      case 'pricing_based':
        return Colors.orange;
      case 'hybrid':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPlanTypeLabel(String planType) {
    switch (planType) {
      case 'response_based':
        return 'Response Based';
      case 'pricing_based':
        return 'Pricing Based';
      case 'hybrid':
        return 'Hybrid Plan';
      default:
        return planType.toUpperCase();
    }
  }

  IconData _getFeatureIcon(String featureName) {
    switch (featureName.toLowerCase()) {
      case 'basic_profile':
        return Icons.person;
      case 'analytics':
        return Icons.analytics;
      case 'priority_support':
        return Icons.support_agent;
      case 'advanced_search':
        return Icons.search;
      case 'custom_branding':
        return Icons.branding_watermark;
      case 'api_access':
        return Icons.api;
      default:
        return Icons.check_circle;
    }
  }
}

/// Widget for displaying a list of benefit plans
class BenefitPlansList extends StatefulWidget {
  final String countryId;
  final String businessTypeId;
  final String? currentPlanId;
  final Function(EnhancedBenefitPlan)? onPlanSelected;
  final bool showRecommendations;

  const BenefitPlansList({
    Key? key,
    required this.countryId,
    required this.businessTypeId,
    this.currentPlanId,
    this.onPlanSelected,
    this.showRecommendations = true,
  }) : super(key: key);

  @override
  State<BenefitPlansList> createState() => _BenefitPlansListState();
}

class _BenefitPlansListState extends State<BenefitPlansList> {
  final EnhancedBusinessBenefitsService _benefitsService =
      EnhancedBusinessBenefitsService();

  List<EnhancedBenefitPlan> _plans = [];
  List<EnhancedBenefitPlan> _recommendations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plans = await _benefitsService.getBenefitPlans(
        countryId: widget.countryId,
        businessTypeId: widget.businessTypeId,
      );

      List<EnhancedBenefitPlan> recommendations = [];
      if (widget.showRecommendations) {
        try {
          recommendations = await _benefitsService.getPlanRecommendations(
            countryId: widget.countryId,
            businessTypeId: widget.businessTypeId,
          );
        } catch (e) {
          // Recommendations are optional, continue without them
          print('Failed to load recommendations: $e');
        }
      }

      setState(() {
        _plans = plans;
        _recommendations = recommendations;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load benefit plans',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlans,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No benefit plans available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later for available plans',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlans,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          final plan = _plans[index];
          final isCurrentPlan = plan.id == widget.currentPlanId;
          final isRecommended = _recommendations.any((r) => r.id == plan.id);

          return BenefitPlanCard(
            plan: plan,
            isCurrentPlan: isCurrentPlan,
            isRecommended: isRecommended,
            onSubscribe: isCurrentPlan
                ? null
                : () {
                    widget.onPlanSelected?.call(plan);
                  },
            onViewDetails: () {
              _showPlanDetails(context, plan);
            },
          );
        },
      ),
    );
  }

  void _showPlanDetails(BuildContext context, EnhancedBenefitPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plan.planName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(plan.planDescription),
              const SizedBox(height: 16),
              Text(
                'Plan Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Type: ${plan.planType}'),
              Text('Code: ${plan.planCode}'),
              Text('Pricing: ${plan.priceDisplay}'),
              if (plan.config.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Configuration',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(plan.config.toString()),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
