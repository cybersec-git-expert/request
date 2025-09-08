import 'package:flutter/material.dart';
import '../services/content_service.dart';
import 'content_page_screen.dart';
import 'notification_screen.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  final ContentService _contentService = ContentService.instance;
  List<ContentPage> _policyPages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPolicyPages();
  }

  Future<void> _loadPolicyPages() async {
    try {
      final pages = await _contentService.getPages();
      setState(() {
        _policyPages = pages.where((page) {
          final cat = page.category?.toLowerCase() ?? '';
          final title = page.title.toLowerCase();
          return cat.contains('policy') ||
              cat.contains('legal') ||
              title.contains('privacy') ||
              title.contains('terms');
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Settings & Privacy'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Account Settings Section
        _buildSection(
          title: 'Account Settings',
          children: [
            _buildSettingsTile(
              icon: Icons.person,
              title: 'Profile Information',
              subtitle: 'Update your personal details',
              onTap: () => _showComingSoon('Profile Information'),
            ),
            _buildSettingsTile(
              icon: Icons.security,
              title: 'Password & Security',
              subtitle: 'Change password and security settings',
              onTap: () => _showComingSoon('Password & Security'),
            ),
            _buildSettingsTile(
              icon: Icons.verified_user,
              title: 'Two-Factor Authentication',
              subtitle: 'Add an extra layer of security',
              onTap: () => _showComingSoon('Two-Factor Authentication'),
            ),
          ],
        ),

        // Notification Settings Section
        _buildSection(
          title: 'Notifications',
          children: [
            _buildSettingsTile(
              icon: Icons.notifications,
              title: 'Push Notifications',
              subtitle: 'Manage your notification preferences',
              onTap: () => _showNotificationSettings(),
            ),
            _buildSettingsTile(
              icon: Icons.email,
              title: 'Email Notifications',
              subtitle: 'Control email communication',
              onTap: () => _showComingSoon('Email Notifications'),
            ),
            _buildSettingsTile(
              icon: Icons.sms,
              title: 'SMS Notifications',
              subtitle: 'Manage SMS alerts',
              onTap: () => _showComingSoon('SMS Notifications'),
            ),
          ],
        ),

        // Privacy Settings Section
        _buildSection(
          title: 'Privacy',
          children: [
            _buildSettingsTile(
              icon: Icons.visibility,
              title: 'Profile Visibility',
              subtitle: 'Control who can see your profile',
              onTap: () => _showPrivacyDialog('Profile Visibility'),
            ),
            _buildSettingsTile(
              icon: Icons.location_on,
              title: 'Location Sharing',
              subtitle: 'Manage location privacy settings',
              onTap: () => _showPrivacyDialog('Location Sharing'),
            ),
            _buildSettingsTile(
              icon: Icons.message,
              title: 'Message Privacy',
              subtitle: 'Control who can message you',
              onTap: () => _showPrivacyDialog('Message Privacy'),
            ),
          ],
        ),

        // Data Management Section
        _buildSection(
          title: 'Data Management',
          children: [
            _buildSettingsTile(
              icon: Icons.download,
              title: 'Download Your Data',
              subtitle: 'Get a copy of your information',
              onTap: () => _showDataDialog('Download Data'),
            ),
            _buildSettingsTile(
              icon: Icons.clear_all,
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              onTap: () => _showStorageDialog(),
            ),
            _buildSettingsTile(
              icon: Icons.delete_forever,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              onTap: () => _showDeleteAccountDialog(),
            ),
          ],
        ),

        // Legal & Policies Section
        if (_policyPages.isNotEmpty)
          _buildSection(
            title: 'Legal & Policies',
            children: _policyPages
                .map((page) => _buildSettingsTile(
                      icon: Icons.article,
                      title: page.title,
                      subtitle: 'Last updated: ${_formatDate(page.updatedAt)}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContentPageScreen(
                            slug: page.slug,
                            title: page.title,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

        // App Settings Section
        _buildSection(
          title: 'App Settings',
          children: [
            _buildSettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'English (US)',
              onTap: () => _showLanguageDialog(),
            ),
            _buildSettingsTile(
              icon: Icons.dark_mode,
              title: 'Theme',
              subtitle: 'Choose your preferred theme',
              onTap: () => _showThemeDialog(),
            ),
            _buildSettingsTile(
              icon: Icons.info,
              title: 'About',
              subtitle: 'App version and information',
              onTap: () => _showAboutDialog(),
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blue[600],
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  void _showPrivacyDialog(String setting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(setting),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Public'),
              leading: Radio<String>(
                value: 'public',
                groupValue: 'private',
                onChanged: (value) {},
              ),
            ),
            ListTile(
              title: const Text('Friends Only'),
              leading: Radio<String>(
                value: 'friends',
                groupValue: 'private',
                onChanged: (value) {},
              ),
            ),
            ListTile(
              title: const Text('Private'),
              leading: Radio<String>(
                value: 'private',
                groupValue: 'private',
                onChanged: (value) {},
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDataDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: Text(
          action == 'Download Data'
              ? 'We\'ll prepare your data and send you a download link via email.'
              : 'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(action == 'Download Data' ? 'Request' : 'Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon('Account Deletion');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showStorageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage'),
        content: const Text('Clear app cache and temporary files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English (US)'),
              leading: Radio<String>(
                value: 'en',
                groupValue: 'en',
                onChanged: (value) {},
              ),
            ),
            ListTile(
              title: const Text('Sinhala'),
              leading: Radio<String>(
                value: 'si',
                groupValue: 'en',
                onChanged: (value) {},
              ),
            ),
            ListTile(
              title: const Text('Tamil'),
              leading: Radio<String>(
                value: 'ta',
                groupValue: 'en',
                onChanged: (value) {},
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('System Default'),
              leading: Radio<String>(
                value: 'system',
                groupValue: 'system',
                onChanged: (value) {},
              ),
            ),
            ListTile(
              title: const Text('Light'),
              leading: Radio<String>(
                value: 'light',
                groupValue: 'system',
                onChanged: (value) {},
              ),
            ),
            ListTile(
              title: const Text('Dark'),
              leading: Radio<String>(
                value: 'dark',
                groupValue: 'system',
                onChanged: (value) {},
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationScreen(),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Request',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.apps, size: 48),
      children: [
        const Text(
            'A comprehensive marketplace and request platform for Sri Lanka.'),
        const SizedBox(height: 16),
        const Text('© 2025 Request Platform. All rights reserved.'),
      ],
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature - Coming Soon')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
