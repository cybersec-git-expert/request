import 'package:flutter/material.dart';

/// Simple subscription page to replace complex multi-tier subscription screen
/// Fixes "Something went wrong" error by providing a clean two-tier model
class SimpleSubscriptionPage extends StatelessWidget {
  const SimpleSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const SizedBox(height: 20),
            const Text(
              'Simple. Clear. Affordable.',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the plan that works best for your business',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Free Plan Card
            _buildPlanCard(
              context: context,
              title: 'Free Plan',
              price: '₹0',
              period: '/month',
              features: [
                '3 responses per month',
                'Respond to any request',
                'Basic profile',
                'Standard support',
              ],
              buttonText: 'Current Plan',
              isActive: true,
              onPressed: null, // Current plan, no action needed
            ),

            const SizedBox(height: 20),

            // Pro Plan Card
            _buildPlanCard(
              context: context,
              title: 'Pro Plan',
              price: '₹299',
              period: '/month',
              features: [
                'Unlimited responses',
                'Verification badge*',
                'Product pricing access*',
                'Priority support',
                'Advanced analytics',
              ],
              buttonText: 'Upgrade Now',
              isActive: false,
              onPressed: () => _handleUpgrade(context),
              isRecommended: true,
            ),

            const SizedBox(height: 20),

            // Info text
            const Text(
              '*Verification badge and product pricing require business verification',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Benefits section
            _buildBenefitsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required String buttonText,
    required bool isActive,
    required VoidCallback? onPressed,
    bool isRecommended = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isRecommended ? Colors.blue : Colors.grey.shade300,
          width: isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isActive ? Colors.blue.shade50 : Colors.white,
      ),
      child: Column(
        children: [
          // Recommended badge
          if (isRecommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: const Text(
                'RECOMMENDED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      period,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Features
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 20),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive
                          ? Colors.grey
                          : (isRecommended
                              ? Colors.blue
                              : Colors.grey.shade600),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Why Choose Pro?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildBenefitItem(
          icon: Icons.all_inclusive,
          title: 'Unlimited Responses',
          description:
              'Respond to as many requests as you want, no monthly limits',
        ),
        _buildBenefitItem(
          icon: Icons.verified,
          title: 'Trust Badge',
          description:
              'Get verified badge to build customer trust and credibility',
        ),
        _buildBenefitItem(
          icon: Icons.price_check,
          title: 'Product Pricing',
          description:
              'Set and display your product/service prices to customers',
        ),
        _buildBenefitItem(
          icon: Icons.support_agent,
          title: 'Priority Support',
          description: 'Get faster response times and dedicated support',
        ),
      ],
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleUpgrade(BuildContext context) {
    // Show upgrade dialog or navigate to payment
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upgrade to Pro'),
          content: const Text(
            'Ready to unlock unlimited responses and premium features?\n\n'
            'Pro plan includes:\n'
            '• Unlimited responses\n'
            '• Verification badge (after business verification)\n'
            '• Product pricing access\n'
            '• Priority support\n\n'
            'Only ₹299/month',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processUpgrade(context);
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        );
      },
    );
  }

  void _processUpgrade(BuildContext context) {
    // TODO: Integrate with payment gateway
    // For now, show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Payment integration coming soon! Your upgrade request has been noted.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
