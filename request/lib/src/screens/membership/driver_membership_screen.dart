import 'package:flutter/material.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/api_client.dart';
import '../../models/enhanced_user_model.dart';

class DriverMembershipScreen extends StatefulWidget {
  const DriverMembershipScreen({super.key});

  @override
  State<DriverMembershipScreen> createState() => _DriverMembershipScreenState();
}

class _DriverMembershipScreenState extends State<DriverMembershipScreen> {
  bool _isLoading = true;
  bool _isRegistered = false;
  String _verificationStatus = 'not_registered';
  final EnhancedUserService _userService = EnhancedUserService();

  @override
  void initState() {
    super.initState();
    _checkDriverStatus();
  }

  Future<void> _checkDriverStatus() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) return;

      // Check if user has driver role
      bool hasDriverRole = user.roles.contains(UserRole.driver);

      if (hasDriverRole) {
        // Check driver verification status
        final resp = await ApiClient.instance
            .get('/api/driver-verifications/user/${user.uid}');
        if (resp.isSuccess && resp.data != null) {
          final responseWrapper = resp.data as Map<String, dynamic>;
          final data = responseWrapper['data'] as Map<String, dynamic>?;
          if (data != null) {
            final status =
                (data['status'] ?? 'pending').toString().trim().toLowerCase();
            setState(() {
              _isRegistered = true;
              _verificationStatus = status;
              _isLoading = false;
            });
            return;
          }
        }
      }

      setState(() {
        _isRegistered = hasDriverRole;
        _verificationStatus = hasDriverRole ? 'pending' : 'not_registered';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
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
        title: const Text('Driver Membership'),
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
                  // Driver Role Card
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
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_taxi,
                                color: Colors.blue[600],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Driver',
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
                          'Drive and earn money with flexible hours',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'As a driver, you can accept ride requests, delivery jobs, and earn money with flexible hours.',
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
                                    // Go to driver verification screen
                                    Navigator.pushNamed(
                                        context, '/driver-verification');
                                  }
                                : () {
                                    // Go to driver registration
                                    Navigator.pushNamed(
                                        context, '/driver-registration');
                                  },
                            icon: Icon(
                                _isRegistered ? Icons.verified : Icons.add),
                            label: Text(_isRegistered
                                ? 'View Status'
                                : 'Register as Driver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
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
                              'Driver Benefits',
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
                          icon: Icons.access_time,
                          title: 'Flexible Schedule',
                          description:
                              'Work when you want, as much as you want',
                        ),
                        const SizedBox(height: 12),
                        _buildBenefitItem(
                          icon: Icons.attach_money,
                          title: 'Earn Money',
                          description: 'Accept ride requests and delivery jobs',
                        ),
                        const SizedBox(height: 12),
                        _buildBenefitItem(
                          icon: Icons.support_agent,
                          title: '24/7 Support',
                          description: 'Get help whenever you need it',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: Colors.blue[600],
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
