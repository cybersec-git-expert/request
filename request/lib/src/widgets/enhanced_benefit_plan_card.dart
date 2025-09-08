import 'package:flutter/material.dart';
import '../models/enhanced_business_benefits.dart';
import '../services/enhanced_business_benefits_service.dart';

class EnhancedBenefitPlanCard extends StatelessWidget {
  final EnhancedBenefitPlan plan;
  final VoidCallback? onTap;
  final bool showFullDetails;

  const EnhancedBenefitPlanCard({
    Key? key,
    required this.plan,
    this.onTap,
    this.showFullDetails = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planName,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getPricingModelColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getPricingModelLabel(),
                            style: TextStyle(
                              color: _getPricingModelColor(),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _getPricingModelIcon(),
                    color: _getPricingModelColor(),
                    size: 32,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Pricing information
              _buildPricingSection(context),

              if (showFullDetails) ...[
                const SizedBox(height: 16),
                _buildFeaturesSection(context),
              ],

              if (!plan.isActive) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Inactive',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    switch (plan.pricingModel) {
      case 'pay_per_click':
        return _buildPayPerClickPricing(context);
      case 'monthly_subscription':
        return _buildMonthlySubscriptionPricing(context);
      case 'bundle':
        return _buildBundlePricing(context);
      case 'response_based':
        return _buildResponseBasedPricing(context);
      default:
        return _buildGenericPricing(context);
    }
  }

  Widget _buildPayPerClickPricing(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pay Per Click Pricing',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.mouse, size: 16, color: Colors.blue[600]),
            const SizedBox(width: 8),
            Text(
                '${plan.currency} ${plan.costPerClick?.toStringAsFixed(2)} per click'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.account_balance_wallet,
                size: 16, color: Colors.green[600]),
            const SizedBox(width: 8),
            Text(
                'Minimum budget: ${plan.currency} ${plan.minimumBudget?.toStringAsFixed(2)}'),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlySubscriptionPricing(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Subscription',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: Colors.purple[600]),
            const SizedBox(width: 8),
            Text(
                '${plan.currency} ${plan.monthlyFee?.toStringAsFixed(2)}/month'),
          ],
        ),
        if (plan.setupFee != null && plan.setupFee! > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.settings, size: 16, color: Colors.orange[600]),
              const SizedBox(width: 8),
              Text(
                  'Setup fee: ${plan.currency} ${plan.setupFee?.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBundlePricing(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bundle Offer',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.inventory, size: 16, color: Colors.green[600]),
            const SizedBox(width: 8),
            Text('${plan.currency} ${plan.bundlePrice?.toStringAsFixed(2)}'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.touch_app, size: 16, color: Colors.blue[600]),
            const SizedBox(width: 8),
            Text('Includes ${plan.clicksIncluded} clicks'),
          ],
        ),
        if (plan.pricing['additional_click_cost'] != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.add, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                  'Extra clicks: ${plan.currency} ${plan.pricing['additional_click_cost']?.toStringAsFixed(2)} each'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildResponseBasedPricing(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Response-Based Pricing',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.reply, size: 16, color: Colors.teal[600]),
            const SizedBox(width: 8),
            Text(
                '${plan.currency} ${plan.costPerResponse?.toStringAsFixed(2)} per response'),
          ],
        ),
        if (plan.pricing['monthly_minimum'] != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: Colors.orange[600]),
              const SizedBox(width: 8),
              Text(
                  'Monthly minimum: ${plan.currency} ${plan.pricing['monthly_minimum']?.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildGenericPricing(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pricing Details',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ...plan.pricing.entries
            .map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${entry.key}: ${entry.value}'),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    if (plan.features.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features Included',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: plan.features.entries
              .where((entry) => entry.value == true)
              .map((entry) => Chip(
                    label: Text(
                      _formatFeatureName(entry.key),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getPricingModelColor().withOpacity(0.1),
                    side: BorderSide(
                      color: _getPricingModelColor().withOpacity(0.3),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  String _formatFeatureName(String featureName) {
    return featureName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getPricingModelColor() {
    switch (plan.pricingModel) {
      case 'pay_per_click':
        return Colors.blue;
      case 'monthly_subscription':
        return Colors.purple;
      case 'bundle':
        return Colors.green;
      case 'response_based':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getPricingModelIcon() {
    switch (plan.pricingModel) {
      case 'pay_per_click':
        return Icons.mouse;
      case 'monthly_subscription':
        return Icons.calendar_month;
      case 'bundle':
        return Icons.inventory;
      case 'response_based':
        return Icons.reply;
      default:
        return Icons.payment;
    }
  }

  String _getPricingModelLabel() {
    switch (plan.pricingModel) {
      case 'pay_per_click':
        return 'Pay Per Click';
      case 'monthly_subscription':
        return 'Monthly Subscription';
      case 'bundle':
        return 'Bundle Offer';
      case 'response_based':
        return 'Response Based';
      default:
        return plan.pricingModel.toUpperCase();
    }
  }
}

class BusinessTypeBenefitsScreen extends StatefulWidget {
  final String countryCode;
  final int? businessTypeId;
  final String? businessTypeName;

  const BusinessTypeBenefitsScreen({
    Key? key,
    required this.countryCode,
    this.businessTypeId,
    this.businessTypeName,
  }) : super(key: key);

  @override
  State<BusinessTypeBenefitsScreen> createState() =>
      _BusinessTypeBenefitsScreenState();
}

class _BusinessTypeBenefitsScreenState
    extends State<BusinessTypeBenefitsScreen> {
  EnhancedBusinessBenefitsResponse? _benefitsResponse;
  BusinessTypeBenefits? _specificBenefits;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBenefits();
  }

  Future<void> _loadBenefits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.businessTypeId != null) {
        // Load specific business type benefits
        final response =
            await EnhancedBusinessBenefitsService.getBusinessTypePlans(
          widget.countryCode,
          widget.businessTypeId!,
        );

        _specificBenefits = BusinessTypeBenefits(
          businessTypeId: response['businessTypeId'] ?? 0,
          businessTypeName: response['businessTypeName'] ?? '',
          plans: (response['plans'] as List<dynamic>? ?? [])
              .map((plan) => EnhancedBenefitPlan.fromJson(plan))
              .toList(),
        );
      } else {
        // Load all business type benefits
        final response =
            await EnhancedBusinessBenefitsService.getBusinessTypeBenefits(
          widget.countryCode,
        );
        _benefitsResponse = EnhancedBusinessBenefitsResponse.fromJson(response);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.businessTypeName ?? 'Business Benefits'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
      floatingActionButton: widget.businessTypeId != null
          ? FloatingActionButton(
              onPressed: () => _showCreatePlanDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading benefits',
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
              onPressed: _loadBenefits,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_specificBenefits != null) {
      return _buildSpecificBusinessTypeBenefits();
    }

    if (_benefitsResponse != null) {
      return _buildAllBusinessTypesBenefits();
    }

    return const Center(
      child: Text('No benefits data available'),
    );
  }

  Widget _buildSpecificBusinessTypeBenefits() {
    final benefits = _specificBenefits!;

    if (benefits.plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No benefit plans available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first benefit plan to get started',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBenefits,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${benefits.businessTypeName} Benefit Plans',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          ...benefits.plans.map((plan) => EnhancedBenefitPlanCard(
                plan: plan,
                showFullDetails: true,
                onTap: () => _showPlanDetails(plan),
              )),
        ],
      ),
    );
  }

  Widget _buildAllBusinessTypesBenefits() {
    final benefits = _benefitsResponse!;

    return RefreshIndicator(
      onRefresh: _loadBenefits,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Business Type Benefits',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          ...benefits.businessTypeBenefits.entries.map((entry) {
            final businessType = entry.value;
            return ExpansionTile(
              title: Text(businessType.businessTypeName),
              subtitle: Text('${businessType.plans.length} plan(s) available'),
              children: businessType.plans
                  .map((plan) => EnhancedBenefitPlanCard(
                        plan: plan,
                        onTap: () => _showPlanDetails(plan),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  void _showPlanDetails(EnhancedBenefitPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plan.planName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              EnhancedBenefitPlanCard(
                plan: plan,
                showFullDetails: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (widget.businessTypeId != null) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEditPlanDialog(plan);
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePlan(plan);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ],
      ),
    );
  }

  void _showCreatePlanDialog() {
    // This would open a form to create a new plan
    // For now, just show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Plan'),
        content: const Text('Plan creation form would go here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditPlanDialog(EnhancedBenefitPlan plan) {
    // This would open a form to edit the plan
    // For now, just show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${plan.planName}'),
        content: const Text('Plan editing form would go here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlan(EnhancedBenefitPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Are you sure you want to delete "${plan.planName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await EnhancedBusinessBenefitsService.deleteBenefitPlan(plan.planId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan deleted successfully')),
        );
        _loadBenefits(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting plan: $e')),
        );
      }
    }
  }
}
