import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/content_service.dart';
import 'content_page_screen.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_page.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ContentService _contentService = ContentService.instance;
  List<ContentPage> _helpPages = [];
  bool _isLoading = true;

  // Contact form controllers
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final GlobalKey<FormState> _contactFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHelpPages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadHelpPages() async {
    try {
      final pages = await _contentService.getPages();
      setState(() {
        _helpPages = pages.where((page) {
          final cat = page.category?.toLowerCase() ?? '';
          final title = page.title.toLowerCase();
          return cat.contains('help') ||
              cat.contains('support') ||
              title.contains('help') ||
              title.contains('faq') ||
              title.contains('guide');
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Help & Support',
      bottom: TabBar(
        controller: _tabController,
        labelColor: GlassTheme.colors.textPrimary,
        unselectedLabelColor: GlassTheme.colors.textSecondary,
        indicatorColor: GlassTheme.colors.textAccent,
        tabs: const [
          Tab(text: 'FAQ'),
          Tab(text: 'Guides'),
          Tab(text: 'Contact'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFAQTab(),
          _buildGuidesTab(),
          _buildContactTab(),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic Help Pages
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_helpPages.isNotEmpty) ...[
            Text('Help Articles', style: GlassTheme.titleSmall),
            const SizedBox(height: 15),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _helpPages.length,
              itemBuilder: (context, index) {
                final page = _helpPages[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: GlassTheme.glassContainer,
                  child: ListTile(
                    leading:
                        Icon(Icons.article, color: GlassTheme.colors.infoColor),
                    title: Text(page.title, style: GlassTheme.bodyLarge),
                    subtitle:
                        Text(page.category ?? '', style: GlassTheme.bodySmall),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16, color: GlassTheme.colors.textTertiary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContentPageScreen(
                            slug: page.slug,
                            title: page.title,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // Static FAQ Items
          Text('Frequently Asked Questions', style: GlassTheme.titleSmall),
          const SizedBox(height: 15),

          _buildFAQItem(
            'How do I create a request?',
            'Go to the Browse screen, select a category, and tap "Create Request". Fill in the details and submit.',
          ),

          _buildFAQItem(
            'How do I respond to a request?',
            'Find the request you want to respond to and tap "Respond". Provide your offer details and contact information.',
          ),

          _buildFAQItem(
            'How does pricing work?',
            'You can compare prices from different businesses and contact them directly for the best deals.',
          ),

          _buildFAQItem(
            'Is my information secure?',
            'Yes, we take privacy seriously. Your personal information is encrypted and protected.',
          ),

          _buildFAQItem(
            'How do I verify my business?',
            'Go to Account > Role Management and submit your business verification documents.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuidesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Guides', style: GlassTheme.titleSmall),
          const SizedBox(height: 15),
          _buildGuideItem(
            Icons.person_add,
            'Getting Started',
            'Learn how to set up your account and start using the app',
          ),
          _buildGuideItem(
            Icons.search,
            'Creating Requests',
            'Step-by-step guide on how to create and manage requests',
          ),
          _buildGuideItem(
            Icons.business,
            'Business Features',
            'How to use business features and manage your listings',
          ),
          _buildGuideItem(
            Icons.price_check,
            'Price Comparison',
            'How to compare prices and find the best deals',
          ),
          _buildGuideItem(
            Icons.car_rental,
            'Ride Requests',
            'Guide for creating and responding to ride requests',
          ),
          _buildGuideItem(
            Icons.delivery_dining,
            'Delivery Services',
            'How to use delivery and logistics features',
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Support',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),

          _buildContactOption(
            Icons.chat,
            'Live Chat',
            'Get instant help from our support team',
            _startLiveChat,
          ),

          _buildContactOption(
            Icons.email,
            'Email Support',
            'Send us a detailed message',
            _sendEmail,
          ),

          _buildContactOption(
            Icons.phone,
            'Phone Support',
            'Call our support hotline',
            _callSupport,
          ),

          _buildContactOption(
            Icons.bug_report,
            'Report a Bug',
            'Help us improve by reporting issues',
            _reportBug,
          ),

          const SizedBox(height: 30),

          // Contact Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GlassTheme.isDarkMode
                  ? const Color(0xFF2C2C2C).withOpacity(0.8)
                  : Colors.white,
              borderRadius: BorderRadius.circular(15),
              // Removed border to make it borderless
            ),
            child: Form(
              key: _contactFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send us a message',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: GlassTheme.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: GlassTheme.colors.textAccent),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a subject';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: GlassTheme.colors.textAccent),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your message';
                      }
                      if (value.trim().length < 10) {
                        return 'Message should be at least 10 characters long';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlassTheme.colors.textAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0, // Remove shadow
                        shadowColor: Colors.transparent, // Remove shadow
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Send Message',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GlassTheme.glassContainer,
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: GlassTheme.colors.textPrimary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: TextStyle(
                color: GlassTheme.colors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GlassTheme.glassContainer,
      child: InkWell(
        onTap: () => _showGuideDialog(title),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4)
                      .withOpacity(0.2), // Cyan color like modern menu
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF06B6D4),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: GlassTheme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: GlassTheme.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption(
      IconData icon, String title, String description, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GlassTheme.glassContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981)
                      .withOpacity(0.2), // Emerald color like modern menu
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: GlassTheme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: GlassTheme.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuideDialog(String guide) {
    String content = '';

    switch (guide) {
      case 'Getting Started':
        content = '''
1. Download and install the Request app
2. Create your account with email or phone number
3. Verify your account through OTP
4. Complete your profile information
5. Browse categories and start creating requests!

Tip: Add a profile picture to build trust with other users.
        ''';
        break;
      case 'Creating Requests':
        content = '''
1. Go to the Browse screen
2. Select the category that matches your need
3. Tap "Create Request" button
4. Fill in all the required details:
   - Title and description
   - Budget range
   - Location
   - Photos (if applicable)
5. Review and submit your request

Your request will be visible to businesses in your area!
        ''';
        break;
      case 'Business Features':
        content = '''
1. Go to Account > Role Management
2. Switch to Business account
3. Upload verification documents
4. Wait for admin approval
5. Once verified, you can:
   - Respond to customer requests
   - Create business listings
   - Manage your business profile
   - View analytics and insights

Business accounts get priority visibility!
        ''';
        break;
      case 'Price Comparison':
        content = '''
1. Browse through different business responses
2. Compare prices, ratings, and reviews
3. Check business verification status
4. Contact businesses directly through the app
5. Make informed decisions based on:
   - Price ranges
   - Business ratings
   - Location proximity
   - Available services

Always verify business credentials before making payments!
        ''';
        break;
      case 'Ride Requests':
        content = '''
1. Select "Transportation" category
2. Choose "Ride Request" subcategory
3. Enter pickup and drop-off locations
4. Set your budget and preferred time
5. Add any special requirements
6. Submit the request

Drivers will respond with their offers and availability.
        ''';
        break;
      case 'Delivery Services':
        content = '''
1. Select "Delivery" category
2. Choose the type of delivery needed
3. Enter pickup and delivery addresses
4. Specify item details and special instructions
5. Set your budget and timeline
6. Submit the request

Delivery providers will contact you with quotes and availability.
        ''';
        break;
      default:
        content =
            'This guide will be implemented with detailed step-by-step instructions.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guide),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startLiveChat() {
    // For now, redirect to email since live chat is not implemented
    _sendEmail();
  }

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'info@request.lk',
      query: 'subject=Support Request&body=Please describe your issue here...',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not open email client. Please email us at info@request.lk'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open email client. Please email us at info@request.lk'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _callSupport() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '0725742238');

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Could not open phone dialer. Please call 0725742238'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not open phone dialer. Please call 0725742238'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _reportBug() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'info@request.lk',
      query:
          'subject=Bug Report&body=Please describe the bug you encountered:\n\nSteps to reproduce:\n1. \n2. \n3. \n\nExpected behavior:\n\n\nActual behavior:\n\n\nDevice info:\n\n',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not open email client. Please email your bug report to info@request.lk'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open email client. Please email your bug report to info@request.lk'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _sendMessage() async {
    if (_contactFormKey.currentState?.validate() ?? false) {
      final String subject = _subjectController.text.trim();
      final String message = _messageController.text.trim();

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'info@request.lk',
        query: 'subject=$subject&body=$message',
      );

      try {
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);

          // Clear the form after successful send
          _subjectController.clear();
          _messageController.clear();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email client opened. Please send your message.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Could not open email client. Please email us directly at info@request.lk'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not open email client. Please email us directly at info@request.lk'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }
}
