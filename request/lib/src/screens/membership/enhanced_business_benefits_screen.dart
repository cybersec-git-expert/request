import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';
import '../../services/enhanced_business_benefits_service.dart';
import '../../models/enhanced_business_benefits.dart';
import '../../widgets/enhanced_benefit_plan_card.dart';

class EnhancedBusinessBenefitsScreen extends StatefulWidget {
  const EnhancedBusinessBenefitsScreen({super.key});

  @override
  State<EnhancedBusinessBenefitsScreen> createState() =>
      _EnhancedBusinessBenefitsScreenState();
}

class _EnhancedBusinessBenefitsScreenState
    extends State<EnhancedBusinessBenefitsScreen> {
  List<EnhancedBenefitPlan> _plans = [];
  bool _isLoading = true;
  String? _error;
  String _countryCode = 'LK'; // Default to Sri Lanka

  // Business type mapping - we'll load available plans directly
  final Map<int, String> _businessTypes = {
    1: 'Restaurant',
    2: 'Retail',
    3: 'Service Provider',
    4: 'Delivery',
    5: 'Grocery',
    6: 'Pharmacy',
    7: 'Other',
  };

  int _selectedBusinessTypeId = 1;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response =
          await EnhancedBusinessBenefitsService.getBusinessTypePlans(
              _countryCode, _selectedBusinessTypeId);

      if (response['success'] == true && response['data'] != null) {
        final businessTypeBenefits =
            BusinessTypeBenefits.fromJson(response['data']);
        setState(() {
          _plans = businessTypeBenefits.plans;
          _isLoading = false;
        });
      } else {
        setState(() {
          _plans = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Enhanced Business Benefits'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppTheme.textPrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPlans,
            ),
          ],
        ),
        body: Column(
          children: [
            // Business Type Selector
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.glassBorder,
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedBusinessTypeId,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: GlassTheme.colors.textSecondary,
                  ),
                  style: TextStyle(
                    color: GlassTheme.colors.textPrimary,
                    fontSize: 16,
                  ),
                  dropdownColor: Colors.white,
                  items: _businessTypes.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null &&
                        newValue != _selectedBusinessTypeId) {
                      setState(() {
                        _selectedBusinessTypeId = newValue;
                      });
                      _loadPlans();
                    }
                  },
                ),
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
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
              color: GlassTheme.colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading benefits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: GlassTheme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: GlassTheme.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPlans,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 64,
              color: GlassTheme.colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No benefit plans available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: GlassTheme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new business benefit plans.',
              style: TextStyle(
                color: GlassTheme.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EnhancedBenefitPlanCard(
            plan: plan,
            onTap: () => _showPlanDetails(plan),
          ),
        );
      },
    );
  }

  void _showPlanDetails(EnhancedBenefitPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GlassTheme.colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.planName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: GlassTheme.colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: GlassTheme.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan Code
                    Text(
                      'Plan Code: ${plan.planCode}',
                      style: TextStyle(
                        fontSize: 16,
                        color: GlassTheme.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pricing
                    Text(
                      'Pricing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: GlassTheme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPricingDetails(plan),
                    const SizedBox(height: 24),

                    // Features
                    if (plan.features.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Features',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: GlassTheme.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...plan.features.entries.map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      entry.value == true
                                          ? Icons.check_circle
                                          : Icons.info_outline,
                                      color: entry.value == true
                                          ? Colors.green
                                          : Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${entry.key}: ${entry.value}',
                                        style: TextStyle(
                                          color:
                                              GlassTheme.colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Bottom action
            Container(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _contactSupport(plan);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A6B7A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingDetails(EnhancedBenefitPlan plan) {
    // Show pricing based on the pricing model and actual pricing data
    final pricing = plan.pricing;
    final currency = pricing['currency'] ?? 'LKR';

    switch (plan.pricingModel) {
      case 'monthly_subscription':
        final monthlyFee = pricing['monthly_fee'];
        final setupFee = pricing['setup_fee'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (monthlyFee != null)
              Text(
                '$currency ${monthlyFee}/month',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: GlassTheme.colors.textPrimary,
                ),
              ),
            if (setupFee != null)
              Text(
                'Setup fee: $currency $setupFee',
                style: TextStyle(
                  color: GlassTheme.colors.textSecondary,
                ),
              ),
          ],
        );
      case 'pay_per_click':
        final costPerClick = pricing['cost_per_click'];
        final minimumBudget = pricing['minimum_budget'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (costPerClick != null)
              Text(
                '$currency $costPerClick per click',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: GlassTheme.colors.textPrimary,
                ),
              ),
            if (minimumBudget != null)
              Text(
                'Minimum budget: $currency $minimumBudget',
                style: TextStyle(
                  color: GlassTheme.colors.textSecondary,
                ),
              ),
          ],
        );
      case 'bundle':
        final bundlePrice = pricing['bundle_price'];
        final clicksIncluded = pricing['clicks_included'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bundlePrice != null)
              Text(
                '$currency $bundlePrice',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: GlassTheme.colors.textPrimary,
                ),
              ),
            if (clicksIncluded != null)
              Text(
                'Includes $clicksIncluded clicks',
                style: TextStyle(
                  color: GlassTheme.colors.textSecondary,
                ),
              ),
          ],
        );
      case 'response_based':
        final costPerResponse = pricing['cost_per_response'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (costPerResponse != null)
              Text(
                '$currency $costPerResponse per response',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: GlassTheme.colors.textPrimary,
                ),
              ),
          ],
        );
      default:
        return Text(
          'Contact for pricing',
          style: TextStyle(
            fontSize: 16,
            color: GlassTheme.colors.textSecondary,
          ),
        );
    }
  }

  void _contactSupport(EnhancedBenefitPlan plan) {
    // Navigate to help/support screen or show contact options
    Navigator.pushNamed(context, '/help-support');
  }
}
