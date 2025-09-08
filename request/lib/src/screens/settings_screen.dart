import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/glass_theme.dart';
import '../widgets/password_change_bottom_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GlassTheme.backgroundGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                GlassTheme.isDarkMode ? Brightness.light : Brightness.dark,
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: GlassTheme.colors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Settings', style: GlassTheme.titleLarge),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // App Preferences Section
              _buildSectionHeader('App Preferences'),
              const SizedBox(height: 12),

              // Theme Setting
              _buildThemeSetting(),
              const SizedBox(height: 12),

              // Language Setting (placeholder)
              _buildLanguageSetting(),
              const SizedBox(height: 12),

              // Notifications Setting
              _buildNotificationsSetting(),
              const SizedBox(height: 24),

              // Account Section
              _buildSectionHeader('Account'),
              const SizedBox(height: 12),

              // Change Password
              _buildChangePasswordSetting(),
              const SizedBox(height: 12),

              // Privacy Setting
              _buildPrivacySetting(),
              const SizedBox(height: 12),

              // Data & Storage
              _buildDataStorageSetting(),
              const SizedBox(height: 24),

              // Support Section
              _buildSectionHeader('Support'),
              const SizedBox(height: 12),

              // Help & Support
              _buildHelpSetting(),
              const SizedBox(height: 12),

              // About
              _buildAboutSetting(),
              const SizedBox(height: 32),

              // App Version
              _buildAppVersion(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GlassTheme.titleMedium.copyWith(
          color: GlassTheme.colors.textAccent,
        ),
      ),
    );
  }

  Widget _buildThemeSetting() {
    return GlassTheme.glassCard(
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Theme settings coming soon!',
                style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: GlassTheme.colors.infoColor,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.colors.primaryPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.primaryPurple.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                GlassTheme.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: GlassTheme.colors.primaryPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: GlassTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Light and dark mode settings',
                    style: GlassTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSetting() {
    return GlassTheme.glassCard(
      child: InkWell(
        onTap: () {
          // TODO: Implement language selection
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Language settings coming soon!',
                style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: GlassTheme.colors.infoColor,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.colors.primaryBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.language,
                color: GlassTheme.colors.primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language', style: GlassTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text('English', style: GlassTheme.bodyMedium),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSetting() {
    return GlassTheme.glassCard(
      child: InkWell(
        onTap: () {
          // TODO: Navigate to notifications settings
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Notification settings coming soon!',
                style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: GlassTheme.colors.infoColor,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.colors.primaryAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.primaryAmber.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: GlassTheme.colors.primaryAmber,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifications', style: GlassTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your notification preferences',
                    style: GlassTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySetting() {
    return GlassTheme.glassCard(
      child: InkWell(
        onTap: () {
          // TODO: Navigate to privacy settings
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Privacy & Security settings coming soon!',
                style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: GlassTheme.colors.infoColor,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.colors.primaryEmerald.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.primaryEmerald.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.privacy_tip_outlined,
                color: GlassTheme.colors.primaryEmerald,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privacy & Security', style: GlassTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Control your privacy settings',
                    style: GlassTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordSetting() {
    return GlassTheme.glassCard(
      child: InkWell(
        onTap: () {
          _showChangePasswordDialog();
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.colors.primaryBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.lock_outline,
                color: GlassTheme.colors.primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Change Password', style: GlassTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Update your account password',
                    style: GlassTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataStorageSetting() {
    return GlassTheme.glassCard(
      child: InkWell(
        onTap: () {
          // TODO: Navigate to data storage settings
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Data & Storage settings coming soon!',
                style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: GlassTheme.colors.infoColor,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.colors.primaryTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.primaryTeal.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.storage_outlined,
                color: GlassTheme.colors.primaryTeal,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data & Storage', style: GlassTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Manage app data and storage',
                    style: GlassTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSetting() {
    return GlassTheme.glassCard(
      child: InkWell(
        onTap: () {
          // TODO: Navigate to help & support
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Help & Support coming soon!',
                style: GlassTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: GlassTheme.colors.infoColor,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.colors.primaryRose.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.primaryRose.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.help_outline,
                color: GlassTheme.colors.primaryRose,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Help & Support', style: GlassTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Get help and contact support',
                    style: GlassTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSetting() {
    return GlassTheme.glassCard(
      child: InkWell(
        onTap: () {
          // TODO: Navigate to about page
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: GlassTheme.isDarkMode
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text('About Request App', style: GlassTheme.titleMedium),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version 1.0.0', style: GlassTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    'A modern request and response platform built with Flutter.',
                    style: GlassTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '© 2025 Request App. All rights reserved.',
                    style: GlassTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GlassTheme.accent),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.colors.primaryBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GlassTheme.colors.primaryBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.info_outline,
                color: GlassTheme.colors.primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: GlassTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'App information and version',
                    style: GlassTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return Center(
      child: Text(
        'Request App v1.0.0',
        style: GlassTheme.bodySmall.copyWith(
          color: GlassTheme.colors.textTertiary,
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showPasswordChangeBottomSheet(
      context: context,
      isResetMode: false, // Change password mode
    );
  }
}
