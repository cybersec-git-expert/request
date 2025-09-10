import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';

class PublicPlansScreen extends StatefulWidget {
  const PublicPlansScreen({super.key});

  @override
  State<PublicPlansScreen> createState() => _PublicPlansScreenState();
}

class _PublicPlansScreenState extends State<PublicPlansScreen> {
  @override
  Widget build(BuildContext context) {
    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Subscription Plans'),
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
                  'Subscription Plans',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Access subscription plans through the main menu or membership section.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
