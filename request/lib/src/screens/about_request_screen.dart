import 'package:flutter/material.dart';
import '../services/content_service.dart';
import 'content_page_screen.dart';

class AboutRequestScreen extends StatefulWidget {
  const AboutRequestScreen({super.key});

  @override
  State<AboutRequestScreen> createState() => _AboutRequestScreenState();
}

class _AboutRequestScreenState extends State<AboutRequestScreen> {
  final ContentService _contentService = ContentService.instance;
  List<ContentPage> _aboutPages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAboutPages();
  }

  Future<void> _loadAboutPages() async {
    try {
      final pages = await _contentService.getPages();
      setState(() {
        _aboutPages = pages.where((page) => 
          page.title.toLowerCase().contains('about') ||
          page.title.toLowerCase().contains('company') ||
          page.title.toLowerCase().contains('mission')
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button and title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'About Request',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // App Logo and Info
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // App Logo - using the provided gradient logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF4FC3F7), // Light blue
                            Color(0xFF66BB6A), // Green
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Request Marketplace',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Key Features
              _buildSection(
                title: 'Key Features',
                children: [
                  _buildFeatureTile(
                    icon: Icons.search,
                    title: 'Smart Request Matching',
                    description: 'Find exactly what you need with our intelligent matching system',
                  ),
                  _buildFeatureTile(
                    icon: Icons.security,
                    title: 'Secure Transactions',
                    description: 'All transactions are protected with advanced security measures',
                  ),
                  _buildFeatureTile(
                    icon: Icons.location_on,
                    title: 'Location-Based Services',
                    description: 'Connect with nearby users and services in your area',
                  ),
                  _buildFeatureTile(
                    icon: Icons.star,
                    title: 'Rating & Reviews',
                    description: 'Make informed decisions with our comprehensive review system',
                  ),
                ],
              ),
              
              // About Pages from Admin (if any)
              if (_aboutPages.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Learn More',
                  children: _aboutPages.map((page) => _buildInfoTile(
                    icon: Icons.info_outline,
                    title: page.title,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContentPageScreen(
                          slug: page.slug,
                          title: page.title,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Contact Information
              _buildSection(
                title: 'Get In Touch',
                children: [
                  _buildInfoTile(
                    icon: Icons.email,
                    title: 'Email Support',
                    subtitle: 'support@requestmarketplace.com',
                    onTap: () => _launchEmail('support@requestmarketplace.com'),
                  ),
                  _buildInfoTile(
                    icon: Icons.phone,
                    title: 'Phone Support',
                    subtitle: '+1 (555) 123-4567',
                    onTap: () => _launchPhone('+1 (555) 123-4567'),
                  ),
                  _buildInfoTile(
                    icon: Icons.language,
                    title: 'Website',
                    subtitle: 'www.requestmarketplace.com',
                    onTap: () => _launchWebsite('https://www.requestmarketplace.com'),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Legal Information
              _buildSection(
                title: 'Legal',
                children: [
                  _buildInfoTile(
                    icon: Icons.gavel,
                    title: 'Open Source Licenses',
                    subtitle: 'View third-party licenses',
                    onTap: () => _showLicensePage(),
                  ),
                  _buildInfoTile(
                    icon: Icons.info,
                    title: 'App Information',
                    subtitle: 'Build info and technical details',
                    onTap: () {},
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Social Media
              _buildSection(
                title: 'Follow Us',
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        icon: Icons.facebook,
                        label: 'Facebook',
                        color: Colors.blue,
                      ),
                      _buildSocialButton(
                        icon: Icons.alternate_email,
                        label: 'Twitter',
                        color: Colors.lightBlue,
                      ),
                      _buildSocialButton(
                        icon: Icons.camera_alt,
                        label: 'Instagram',
                        color: Colors.purple,
                      ),
                      _buildSocialButton(
                        icon: Icons.work,
                        label: 'LinkedIn',
                        color: Colors.indigo,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.grey[600], size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _launchEmail(String email) {
    // TODO: Implement email launch
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening email to $email')),
    );
  }

  void _launchPhone(String phone) {
    // TODO: Implement phone call
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $phone')),
    );
  }

  void _launchWebsite(String url) {
    // TODO: Implement website launch
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $url')),
    );
  }

  void _showLicensePage() {
    showLicensePage(
      context: context,
      applicationName: 'Request Marketplace',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Request Marketplace',
    );
  }
}
