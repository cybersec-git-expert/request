import 'package:flutter/material.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/api_client.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = true;
  Map<String, String> _verificationStatuses = {
    'driver': 'not_registered',
    'business': 'not_registered',
  };
  final EnhancedUserService _userService = EnhancedUserService();

  @override
  void initState() {
    super.initState();
    _checkExistingVerifications();
  }

  Future<void> _checkExistingVerifications() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) return;

      Map<String, String> statuses = {
        'driver': 'not_registered',
        'business': 'not_registered',
      };

      // Check driver verification
      try {
        final driverResp = await ApiClient.instance
            .get('/api/driver-verifications/user/${user.uid}');
        if (driverResp.isSuccess && driverResp.data != null) {
          final driverWrapper = driverResp.data as Map<String, dynamic>;
          final driverData = driverWrapper['data'] as Map<String, dynamic>?;
          if (driverData != null) {
            statuses['driver'] = (driverData['status'] ?? 'pending')
                .toString()
                .trim()
                .toLowerCase();
          }
        }
      } catch (e) {
        print('Driver verification check error: $e');
      }

      // Check business verification
      try {
        final businessResp = await ApiClient.instance
            .get('/api/business-verifications/user/${user.uid}');
        if (businessResp.isSuccess && businessResp.data != null) {
          final businessWrapper = businessResp.data as Map<String, dynamic>;
          final businessData = businessWrapper['data'] as Map<String, dynamic>?;
          if (businessData != null) {
            statuses['business'] = (businessData['status'] ?? 'pending')
                .toString()
                .trim()
                .toLowerCase();
          }
        }
      } catch (e) {
        print('Business verification check error: $e');
      }

      setState(() {
        _verificationStatuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Choose Your Role'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Select Your Role',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to use the app to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Driver Option
                  _buildRoleCard(
                    context: context,
                    title: 'Driver',
                    subtitle: 'Drive and earn money with flexible hours',
                    description:
                        'Accept ride requests, delivery jobs, and earn money with flexible working hours.',
                    icon: Icons.local_taxi,
                    color: Colors.blue,
                    status: _verificationStatuses['driver']!,
                    onTap: () {
                      Navigator.pushNamed(context, '/driver-membership');
                    },
                  ),

                  const SizedBox(height: 16),

                  // Business Owner Option
                  _buildRoleCard(
                    context: context,
                    title: 'Business Owner',
                    subtitle: 'Manage your business and reach customers',
                    description:
                        'Post service requests, manage your business profile, and connect with customers.',
                    icon: Icons.business_center,
                    color: Colors.orange,
                    status: _verificationStatuses['business']!,
                    onTap: () {
                      Navigator.pushNamed(context, '/business-membership');
                    },
                  ),

                  const SizedBox(height: 24),

                  // Info Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Need Help?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can register for multiple roles later. Start with the one that\'s most important to you right now.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required MaterialColor color,
    required String status,
    required VoidCallback onTap,
  }) {
    String statusText = '';
    Color statusColor = Colors.grey;

    switch (status) {
      case 'approved':
        statusText = 'Verified';
        statusColor = Colors.green;
        break;
      case 'pending':
        statusText = 'Pending';
        statusColor = Colors.orange;
        break;
      case 'rejected':
        statusText = 'Rejected';
        statusColor = Colors.red;
        break;
      default:
        statusText = '';
        statusColor = Colors.grey;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          border: Border.all(
            color: status != 'not_registered' ? color[100]! : Colors.grey[200]!,
            width: status != 'not_registered' ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          if (statusText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
