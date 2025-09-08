import 'package:flutter/material.dart';
import 'legal_page_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPageScreen(
      pageSlug: 'privacy-policy',
      pageTitle: 'Privacy Policy',
    );
  }
}
