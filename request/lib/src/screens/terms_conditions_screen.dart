import 'package:flutter/material.dart';
import 'legal_page_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPageScreen(
      pageSlug: 'terms-conditions',
      pageTitle: 'Terms & Conditions',
    );
  }
}
