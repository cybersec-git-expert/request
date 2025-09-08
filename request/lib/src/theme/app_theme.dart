import 'package:flutter/material.dart';
import 'glass_theme.dart';

/// Temporary shim to keep legacy AppTheme references working while we migrate
/// everything to GlassTheme. Values are aligned to GlassTheme (light mode)
/// so visuals remain consistent. Prefer using GlassTheme directly going forward.
class AppTheme {
  // Core palette (const so they can be used in const widgets)
  static const Color backgroundColor = Colors.transparent;
  static const Color primaryColor =
      Color(0xFF4B5563); // GlassTheme light primaryBlue
  static const Color primaryLight = Color(0xFF6B7280); // Slightly lighter gray
  static const Color textPrimary =
      Color(0xFF0F172A); // GlassTheme light textPrimary
  static const Color textSecondary =
      Color(0xFF64748B); // GlassTheme light textSecondary
  static const Color textTertiary =
      Color(0xFF94A3B8); // GlassTheme light textTertiary
  static const Color errorColor =
      Color(0xFFF87171); // GlassTheme light errorColor

  // Theming
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor, brightness: Brightness.light),
    // Ensure a consistent light background everywhere (no black bleed-through)
    scaffoldBackgroundColor: Colors.white,
    canvasColor: Colors.white,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.black,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      // No elevation/shadow to blend with app background and divider only.
      elevation: 0,
      backgroundColor: Colors.transparent,
      indicatorColor: const Color(0xFF4B9D62).withValues(alpha: 0.18),
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight, brightness: Brightness.dark),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: Colors.transparent,
      indicatorColor: primaryLight.withValues(alpha: 0.22),
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
    ),
  );

  // Common decorations/styles
  static BoxDecoration get fieldDecoration => GlassTheme.glassContainerSubtle;
  static ButtonStyle get primaryButtonStyle => GlassTheme.primaryButton;
  static BoxDecoration get cardDecoration => GlassTheme.glassContainerSubtle;
}
