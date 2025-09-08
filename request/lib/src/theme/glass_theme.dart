import 'package:flutter/material.dart';

class GlassTheme {
  // Theme mode setting
  static bool _isDarkMode = false;

  // Single source of truth for the app background color (used by HomeScreen)
  // Keep this in sync with `backgroundGradient`.
  static const Color backgroundColor = Color(0xFFF5F5F5);

  static bool get isDarkMode => _isDarkMode;

  static void toggleTheme() {
    _isDarkMode = !_isDarkMode;
  }

  static void setTheme(bool isDark) {
    _isDarkMode = isDark;
  }

  // Light theme colors
  static const _lightColors = _GlassColors(
    // Background gradients
    primaryGradient: [
      Color(0xFFF8FAFC), // Very light gray-blue
      Color(0xFFE2E8F0), // Light gray-blue
      Color(0xFFCBD5E1), // Medium light gray
      Color(0xFFF1F5F9), // Very light blue-gray
    ],

    // Glass effect colors
    glassBackground: [
      Color(0xD9FFFFFF), // 85% white
      Color(0xBFFFFFFF), // 75% white
    ],
    glassBackgroundSubtle: [
      Color(0xB3FFFFFF), // 70% white
      Color(0x80FFFFFF), // 50% white
    ],
    glassBackgroundDisabled: [
      Color(0x99FFFFFF), // 60% white
      Color(0x80FFFFFF), // 50% white
    ],
    glassBorder: Color(0x99FFFFFF), // 60% white
    glassBorderSubtle: Color(0x66FFFFFF), // 40% white

    // Shadow colors
    shadowPrimary: Color(0x08000000), // 3% black
    shadowSecondary: Color(0x0D000000), // 5% black
    shadowLight: Color(0xCCFFFFFF), // 80% white (for top shadows)

    // Accent colors
    primaryBlue: Color(0xFF4B5563), // Charcoal gray (replacing purple)
    primaryAmber: Color(0xFFF59E0B), // Amber
    primaryEmerald: Color(0xFF10B981), // Emerald
    primaryPurple: Color(0xFF8B5CF6), // Purple
    primaryTeal: Color(0xFF06B6D4), // Cyan
    primaryRose: Color(0xFFF43F5E), // Rose

    // Text colors
    textPrimary: Color(0xFF0F172A), // Very dark slate
    textSecondary: Color(0xFF64748B), // Medium slate
    textTertiary: Color(0xFF94A3B8), // Light slate
    textAccent: Color(0xFF6366F1), // Indigo

    // Status colors
    successColor: Color(0xFF10B981), // Emerald
    warningColor: Color(0xFFF59E0B), // Amber
    errorColor: Color(0xFFF87171), // Red
    infoColor: Color(0xFF3B82F6), // Blue
  );

  // Dark theme colors
  static const _darkColors = _GlassColors(
    // Background gradients - Only 2 shades like the screenshot
    primaryGradient: [
      Color(0xFF2C2C2C), // Charcoal top
      Color(0xFF1A1A1A), // Darker bottom
    ],

    // Glass effect colors - More grayish cards
    glassBackground: [
      Color(0x26FFFFFF), // 15% white (more visible/grayish)
      Color(0x1AFFFFFF), // 10% white
    ],
    glassBackgroundSubtle: [
      Color(0x1AFFFFFF), // 10% white
      Color(0x0DFFFFFF), // 5% white
    ],
    glassBackgroundDisabled: [
      Color(0x0DFFFFFF), // 5% white
      Color(0x08FFFFFF), // 3% white
    ],
    glassBorder: Color(0x1AFFFFFF), // 10% white (subtle border)
    glassBorderSubtle: Color(0x0DFFFFFF), // 5% white

    // Shadow colors - Darker shadows
    shadowPrimary: Color(0x33000000), // 20% black (stronger shadow)
    shadowSecondary: Color(0x40000000), // 25% black (stronger shadow)
    shadowLight: Color(0x0DFFFFFF), // 5% white (very subtle top shadows)

    // Accent colors (same as light but might be adjusted)
    primaryBlue: Color(0xFF6B7280), // Charcoal gray for dark mode
    primaryAmber: Color(0xFFF59E0B),
    primaryEmerald: Color(0xFF10B981),
    primaryPurple: Color(0xFF8B5CF6),
    primaryTeal: Color(0xFF06B6D4),
    primaryRose: Color(0xFFF43F5E),

    // Text colors
    textPrimary: Color(0xFFF8FAFC), // Very light
    textSecondary: Color(0xFFCBD5E1), // Medium light
    textTertiary: Color(0xFF94A3B8), // Medium
    textAccent: Color(0xFF818CF8), // Lighter indigo

    // Status colors
    successColor: Color(0xFF34D399), // Lighter emerald
    warningColor: Color(0xFFFBBF24), // Lighter amber
    errorColor: Color(0xFFFCA5A5), // Lighter red
    infoColor: Color(0xFF60A5FA), // Lighter blue
  );

  // Current theme colors
  static _GlassColors get colors => _isDarkMode ? _darkColors : _lightColors;

  // Glass effect decorations
  static BoxDecoration get glassContainer => BoxDecoration(
        color: Colors.white, // Solid white background
        // gradient: LinearGradient(
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        //   colors: colors.glassBackground,
        // ),
        borderRadius: BorderRadius.circular(20),
        // Removed border to make it borderless
        // Removed boxShadow to make it flat
      );

  static BoxDecoration get glassContainerSubtle => BoxDecoration(
        color: Colors.white, // Solid white background
        // gradient: LinearGradient(
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        //   colors: colors.glassBackgroundSubtle,
        // ),
        borderRadius: BorderRadius.circular(16),
        // Removed border to make it borderless
        // Removed boxShadow to make it flat
      );

  static BoxDecoration glassContainerDisabled({bool disabled = false}) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: disabled
              ? colors.glassBackgroundDisabled
              : colors.glassBackground,
        ),
        borderRadius: BorderRadius.circular(18),
        // Removed border to make it borderless
        // Removed boxShadow to make it flat
      );

  // Background gradient
  static BoxDecoration get backgroundGradient => BoxDecoration(
        color: backgroundColor, // Solid light gray background
        // gradient: LinearGradient(
        //   begin: Alignment.topCenter,
        //   end: Alignment.bottomCenter,
        //   colors: colors.primaryGradient,
        // ),
      );

  // Text styles
  static TextStyle get titleLarge => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: colors.textPrimary,
      );

  static TextStyle get titleMedium => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      );

  static TextStyle get titleSmall => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      );

  static TextStyle get bodyLarge => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: colors.textPrimary,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: colors.textSecondary,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: colors.textTertiary,
      );

  static TextStyle get labelLarge => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      );

  static TextStyle get labelMedium => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      );

  static TextStyle get accent => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textAccent,
      );

  // Button styles
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: colors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: colors.shadowSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      );

  static ButtonStyle get secondaryButton => ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        side: BorderSide(color: colors.glassBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      );

  // Common widget builders
  static Container glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    bool subtle = false,
    bool disabled = false,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      decoration: subtle
          ? glassContainerSubtle
          : glassContainerDisabled(disabled: disabled),
      child: child,
    );
  }

  static Container backgroundContainer({
    required Widget child,
  }) {
    return Container(
      decoration: backgroundGradient,
      // Ensure it fills the entire available space
      constraints: const BoxConstraints.expand(),
      child: child,
    );
  }
}

class _GlassColors {
  final List<Color> primaryGradient;
  final List<Color> glassBackground;
  final List<Color> glassBackgroundSubtle;
  final List<Color> glassBackgroundDisabled;
  final Color glassBorder;
  final Color glassBorderSubtle;
  final Color shadowPrimary;
  final Color shadowSecondary;
  final Color shadowLight;
  final Color primaryBlue;
  final Color primaryAmber;
  final Color primaryEmerald;
  final Color primaryPurple;
  final Color primaryTeal;
  final Color primaryRose;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textAccent;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;
  final Color infoColor;

  const _GlassColors({
    required this.primaryGradient,
    required this.glassBackground,
    required this.glassBackgroundSubtle,
    required this.glassBackgroundDisabled,
    required this.glassBorder,
    required this.glassBorderSubtle,
    required this.shadowPrimary,
    required this.shadowSecondary,
    required this.shadowLight,
    required this.primaryBlue,
    required this.primaryAmber,
    required this.primaryEmerald,
    required this.primaryPurple,
    required this.primaryTeal,
    required this.primaryRose,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textAccent,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
    required this.infoColor,
  });
}
