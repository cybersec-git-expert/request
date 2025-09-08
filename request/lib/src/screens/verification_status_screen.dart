import 'package:flutter/material.dart';
import '../services/rest_auth_service.dart'
    hide UserModel; // for auth current user
import '../models/enhanced_user_model.dart';
import '../services/enhanced_user_service.dart';
import '../services/contact_verification_service.dart';
// REMOVED_FB_IMPORT: import 'package:firebase_auth/firebase_auth.dart';

class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({Key? key}) : super(key: key);

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  final EnhancedUserService _userService = EnhancedUserService();
  final ContactVerificationService _contactService =
      ContactVerificationService.instance;
  UserModel? _userModel;
  bool _isLoading = true;

  // Phone verification state
  bool _isPhoneVerified = false;
  bool _isVerifyingPhone = false;
  bool _isPhoneOtpSent = false;
  String? _phoneVerificationId;
  final TextEditingController _phoneOtpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _phoneOtpController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = RestAuthService.instance.currentUser;
      if (user != null) {
        final userModel = await _userService.getUserById(user.uid);
        setState(() {
          _userModel = userModel;
          _isLoading = false;
        });

        // Check if phone number exists in user model, if not try to get from role submissions
        await _loadPhoneFromSubmissions();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }

  Future<void> _loadPhoneFromSubmissions() async {
    // If user model already has phone number, use it
    if (_userModel?.phoneNumber != null &&
        _userModel!.phoneNumber!.isNotEmpty) {
      return;
    }

    // Otherwise, try to get phone number from role verification data
    try {
      for (UserRole role in _userModel!.roles) {
        final roleData = _userModel!.roleData[role];
        if (roleData?.data != null) {
          final data = roleData!.data;

          // Check if phone number exists in role data
          if (data['phoneNumber'] != null &&
              data['phoneNumber'].toString().isNotEmpty) {
            setState(() {
              // Update the user model to include phone number for UI display
              // Note: This doesn't persist to database, just for UI
              _userModel = UserModel(
                id: _userModel!.id,
                email: _userModel!.email,
                name: _userModel!.name,
                roles: _userModel!.roles,
                activeRole: _userModel!.activeRole,
                roleData: _userModel!.roleData,
                createdAt: _userModel!.createdAt,
                updatedAt: _userModel!.updatedAt,
                firstName: _userModel!.firstName,
                lastName: _userModel!.lastName,
                phoneNumber:
                    data['phoneNumber'].toString(), // Add phone from role data
                isEmailVerified: _userModel!.isEmailVerified,
                isPhoneVerified: _userModel!.isPhoneVerified,
                profileComplete: _userModel!.profileComplete,
                countryCode: _userModel!.countryCode,
                countryName: _userModel!.countryName,
              );
            });
            break; // Found phone number, stop looking
          }
        }
      }
    } catch (e) {
      print('Error loading phone from role data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verification Status'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _userModel == null
              ? const Center(child: Text('User data not found'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Colors.black, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userModel!.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _userModel!.email,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Active Role: ${_getRoleDisplayName(_userModel!.activeRole)}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Phone Verification Section
          _buildPhoneVerificationCard(),

          const SizedBox(height: 32),

          const Text(
            'Your Roles',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 16),

          // Roles List
          ..._userModel!.roles.map((role) => _buildRoleCard(role)).toList(),

          if (_userModel!.roles.length < UserRole.values.length) ...[
            const SizedBox(height: 32),
            const Text(
              'Add New Role',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            ...UserRole.values
                .where((role) => !_userModel!.hasRole(role))
                .map((role) => _buildAddRoleCard(role))
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleCard(UserRole role) {
    final roleData = _userModel!.roleData[role];
    final isActive = _userModel!.activeRole == role;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isActive ? Colors.black : Colors.grey,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(roleData?.verificationStatus),
                ),
                child: Icon(
                  _getRoleIcon(role),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getRoleDisplayName(role),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.black : Colors.black87,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(roleData?.verificationStatus),
                      ),
                      child: Text(
                        _getStatusText(roleData?.verificationStatus),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isActive)
                TextButton(
                  onPressed: () => _switchRole(role),
                  child: const Text(
                    'Switch',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
            ],
          ),
          if (roleData?.verificationNotes != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.grey,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.black,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      roleData!.verificationNotes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneVerificationCard() {
    // Check if user has phone number from their submissions
    bool hasPhoneNumber =
        _userModel?.phoneNumber != null && _userModel!.phoneNumber!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone,
                color: _isPhoneVerified ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Phone Verification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasPhoneNumber) ...[
            const Text(
              'No phone number found in your submissions.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete your driver or business registration to add a phone number.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ] else if (!_isPhoneVerified && !_isPhoneOtpSent) ...[
            Text(
              'Phone: ${_userModel!.phoneNumber}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Status: Pending Verification',
              style: TextStyle(color: Colors.orange),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isVerifyingPhone ? null : _startPhoneVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isVerifyingPhone
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Send Verification Code'),
            ),
          ] else if (_isPhoneOtpSent && !_isPhoneVerified) ...[
            Text(
              'Phone: ${_userModel!.phoneNumber}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verification code sent! Enter the 6-digit code below:',
              style: TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneOtpController,
              decoration: const InputDecoration(
                labelText: 'Enter OTP Code',
                hintText: '123456',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sms),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _verifyPhoneOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Verify'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: _startPhoneVerification,
                  child: const Text('Resend Code'),
                ),
              ],
            ),
          ] else if (_isPhoneVerified) ...[
            Text(
              'Phone: ${_userModel!.phoneNumber}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Verified',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startPhoneVerification() async {
    if (_userModel?.phoneNumber == null || _userModel!.phoneNumber!.isEmpty) {
      _showSnackBar('No phone number found', isError: true);
      return;
    }

    setState(() {
      _isVerifyingPhone = true;
      _phoneVerificationId = null;
      _isPhoneOtpSent = false;
    });

    try {
      final result = await _contactService.startBusinessPhoneVerification(
        phoneNumber: _userModel!.phoneNumber!,
        onCodeSent: (verificationId) {
          if (mounted) {
            setState(() {
              _phoneVerificationId = verificationId;
              _isVerifyingPhone = false;
              _isPhoneOtpSent = true;
            });

            String message;
            if (verificationId.startsWith('dev_verification_')) {
              message = '🚀 DEVELOPMENT MODE: Use OTP code 123456 to verify';
            } else {
              message = 'Verification code sent to ${_userModel!.phoneNumber}!';
            }
            _showSnackBar(message, isError: false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isVerifyingPhone = false);
            _showSnackBar(error, isError: true);
          }
        },
      );

      if (!result.success && mounted) {
        setState(() => _isVerifyingPhone = false);
        _showSnackBar(result.error ?? 'Failed to send verification code',
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifyingPhone = false);
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _verifyPhoneOTP() async {
    if (_phoneVerificationId == null ||
        _phoneOtpController.text.trim().isEmpty) {
      _showSnackBar('Please enter the verification code', isError: true);
      return;
    }

    try {
      final result = await _contactService.verifyBusinessPhoneOTP(
        verificationId: _phoneVerificationId!,
        otp: _phoneOtpController.text.trim(),
      );

      if (result.success) {
        setState(() {
          _isPhoneVerified = true;
          _isPhoneOtpSent = false;
          _phoneVerificationId = null;
        });
        _phoneOtpController.clear();
        _showSnackBar('Phone verified successfully!', isError: false);
      } else {
        _showSnackBar(result.error ?? 'Verification failed', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error verifying code: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  Widget _buildAddRoleCard(UserRole role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.grey,
          ),
          child: Icon(
            _getRoleIcon(role),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          _getRoleDisplayName(role),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: const Text(
          'Tap to add this role',
          style: TextStyle(color: Colors.grey),
        ),
        trailing: const Icon(
          Icons.add,
          color: Colors.black,
        ),
        onTap: () => _navigateToRoleSetup(role),
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.general:
        return 'General User';
      case UserRole.driver:
        return 'Driver';
      case UserRole.delivery:
        return 'Delivery Partner';
      case UserRole.business:
        return 'Business Owner';
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.general:
        return Icons.person;
      case UserRole.driver:
        return Icons.directions_car;
      case UserRole.delivery:
        return Icons.delivery_dining;
      case UserRole.business:
        return Icons.business;
    }
  }

  Color _getStatusColor(VerificationStatus? status) {
    switch (status) {
      case VerificationStatus.pending:
        return Colors.orange;
      case VerificationStatus.approved:
        return Colors.green;
      case VerificationStatus.rejected:
        return Colors.red;
      case VerificationStatus.notRequired:
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(VerificationStatus? status) {
    switch (status) {
      case VerificationStatus.pending:
        return 'Pending Review';
      case VerificationStatus.approved:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
      case VerificationStatus.notRequired:
      default:
        return 'Active';
    }
  }

  Future<void> _switchRole(UserRole role) async {
    try {
      await _userService.switchActiveRole(_userModel!.id, role.name);
      await _loadUserData(); // Refresh data

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${_getRoleDisplayName(role)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToRoleSetup(UserRole role) {
    String route;
    switch (role) {
      case UserRole.general:
        route = '/main-dashboard';
        break;
      case UserRole.driver:
        route = '/new-driver-verification';
        break;
      case UserRole.delivery:
        route = '/delivery-verification';
        break;
      case UserRole.business:
        route = '/new-business-verification';
        break;
    }

    Navigator.pushNamed(context, route);
  }
}
