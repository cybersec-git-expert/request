import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Subscriptions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.card_membership,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Subscription Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Access subscription plans and manage your membership through the membership section.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/membership');
                },
                child: const Text('Go to Membership'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
