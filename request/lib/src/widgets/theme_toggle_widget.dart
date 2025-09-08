import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';

class ThemeToggleWidget extends StatefulWidget {
  final Widget child;

  const ThemeToggleWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<ThemeToggleWidget> createState() => _ThemeToggleWidgetState();
}

class _ThemeToggleWidgetState extends State<ThemeToggleWidget> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 50,
          right: 20,
          child: FloatingActionButton.small(
            onPressed: () {
              setState(() {
                GlassTheme.toggleTheme();
              });
            },
            backgroundColor: GlassTheme.colors.primaryBlue,
            child: Icon(
              GlassTheme.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class ThemeSwitcher extends StatefulWidget {
  const ThemeSwitcher({Key? key}) : super(key: key);

  @override
  State<ThemeSwitcher> createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<ThemeSwitcher> {
  @override
  Widget build(BuildContext context) {
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.palette_outlined,
            color: GlassTheme.colors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Theme',
            style: GlassTheme.labelMedium,
          ),
          const SizedBox(width: 16),
          Switch(
            value: GlassTheme.isDarkMode,
            onChanged: (value) {
              setState(() {
                GlassTheme.setTheme(value);
              });
            },
            activeThumbColor: GlassTheme.colors.primaryBlue,
          ),
          const SizedBox(width: 8),
          Text(
            GlassTheme.isDarkMode ? 'Dark' : 'Light',
            style: GlassTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
