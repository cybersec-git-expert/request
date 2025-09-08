import 'package:flutter/material.dart';

// Disabled test screen placeholder to keep builds green after removing subscriptions.
class EntitlementsTestScreen extends StatelessWidget {
  const EntitlementsTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entitlements Test')),
      body: const Center(
        child: Text('Entitlements testing is disabled.'),
      ),
    );
  }
}
