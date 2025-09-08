import 'package:flutter/material.dart';
import 'content_page_screen.dart';

/// Thin wrapper that delegates to ContentPageScreen so legal/privacy pages
/// use the unified Glass styling and formatting.
class LegalPageScreen extends StatelessWidget {
  final String pageSlug;
  final String pageTitle;

  const LegalPageScreen({
    super.key,
    required this.pageSlug,
    required this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ContentPageScreen(slug: pageSlug, title: pageTitle);
  }
}
