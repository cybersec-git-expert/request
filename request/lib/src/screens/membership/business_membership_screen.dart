import 'package:flutter/material.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/api_client.dart';
import '../../models/enhanced_user_model.dart';

class BusinessMembershipScreen extends StatefulWidget {
  const BusinessMembershipScreen({super.key});

  @override
  State<BusinessMembershipScreen> createState() =>
      _BusinessMembershipScreenState();
}

class _BusinessMembershipScreenState extends State<BusinessMembershipScreen> {
  bool _isLoading = true;
  bool _isRegistered = false;
  String _verificationStatus = 'not_registered';
  Map<String, bool> _completionStatus = {
    'registration': false,
    'contact': false,
    'documents': false,
    'profile': false,
  };
  final EnhancedUserService _userService = EnhancedUserService();

  @override
  void initState() {
    super.initState();
    _checkBusinessStatus();
  }

  Future<void> _checkBusinessStatus() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) return;

      // Always check business verification status first, regardless of role
      try {
        final resp = await ApiClient.instance
            .get('/api/business-verifications/user/${user.uid}');
        if (resp.isSuccess && resp.data != null) {
          final responseWrapper = resp.data as Map<String, dynamic>;
          final data = responseWrapper['data'] as Map<String, dynamic>?;
          if (data != null) {
            final status =
                (data['status'] ?? 'pending').toString().trim().toLowerCase();
            setState(() {
              _isRegistered = true;
              _verificationStatus = status;
              _updateCompletionStatus(data);
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        print('Business verification check error: $e');
      }

      // Fallback: Check if user has business role
      bool hasBusinessRole = user.roles.contains(UserRole.business);
      setState(() {
        _isRegistered = hasBusinessRole;
        _verificationStatus = hasBusinessRole ? 'pending' : 'not_registered';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateCompletionStatus(Map<String, dynamic> data) {
    // This is a simplified status check - adjust based on your API response
    _completionStatus = {
      'registration': true, // If we have data, registration is complete
      'contact': data['contact_verified'] == true,
      'documents': data['documents_verified'] == true,
      'profile': data['profile_complete'] == true,
    };
  }

  String get _statusText {
    switch (_verificationStatus) {
      case 'approved':
        return 'Verified';
      case 'pending':
        return 'Pending Verification';
      case 'rejected':
        return 'Verification Rejected';
      default:
        return 'Not Registered';
    }
  }

  Color get _statusColor {
    switch (_verificationStatus) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Business Membership'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isRegistered)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _checkBusinessStatus,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Role Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.business_center,
                                color: Colors.orange[600],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Business Owner',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _statusText,
                                      style: TextStyle(
                                        color: _statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Manage your business and reach customers',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'As a business owner, you can post service requests and reach customers.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isRegistered
                                ? () {
                                    // Go to business verification screen
                                    Navigator.pushNamed(
                                        context, '/business-verification');
                                  }
                                : () {
                                    // Go to business registration
                                    Navigator.pushNamed(
                                        context, '/business-registration');
                                  },
                            icon: Icon(
                                _isRegistered ? Icons.verified : Icons.add),
                            label: Text(_isRegistered
                                ? 'View Status'
                                : 'Register as Business Owner'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Verification Steps (only show if registered)
                  if (_isRegistered) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verification Progress',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildVerificationStep(
                            'Business Registration',
                            'Basic business information',
                            _completionStatus['registration']!,
                          ),
                          _buildVerificationStep(
                            'Contact Verification',
                            'Phone and email verification',
                            _completionStatus['contact']!,
                          ),
                          _buildVerificationStep(
                            'Business Documents',
                            'Upload required documents',
                            _completionStatus['documents']!,
                          ),
                          _buildVerificationStep(
                            'Business Profile',
                            'Complete your business profile',
                            _completionStatus['profile']!,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Benefits Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Business Benefits',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildBenefitItem(
                          icon: Icons.post_add,
                          title: 'Post Service Requests',
                          description:
                              'Share your service needs with providers',
                        ),
                        const SizedBox(height: 12),
                        _buildBenefitItem(
                          icon: Icons.people,
                          title: 'Reach Customers',
                          description: 'Connect with potential customers',
                        ),
                        const SizedBox(height: 12),
                        _buildBenefitItem(
                          icon: Icons.verified_user,
                          title: 'Verified Badge',
                          description: 'Build trust with verification badge',
                        ),
                      ],
                    ),
                  ),

                  // Subscription Management
                  const SizedBox(height: 24),
                  if (_verificationStatus == 'approved')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.verified,
                            color: Colors.green[600],
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Business Verified!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/business-pricing');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Manage Subscription'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildVerificationStep(
      String title, String description, bool isComplete) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isComplete ? Colors.green : Colors.grey[300],
            ),
            child: Icon(
              isComplete ? Icons.check : Icons.circle_outlined,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isComplete ? Colors.green[800] : Colors.grey[800],
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: Colors.orange[600],
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
