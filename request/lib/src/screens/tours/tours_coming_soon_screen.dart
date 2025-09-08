import 'package:flutter/material.dart';
import '../../widgets/coming_soon_widget.dart';

class ToursComingSoonScreen extends StatelessWidget {
  const ToursComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ComingSoonWidget(
      title: 'Tours & Travel',
      description:
          'Discover amazing tours and travel packages! We\'re working hard to bring you the best travel experiences in your region.',
      icon: Icons.flight,
      showBackButton: true,
    );
  }
}
