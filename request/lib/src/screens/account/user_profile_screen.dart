import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/rest_auth_service.dart' hide UserModel;
import '../../services/contact_verification_service.dart';
import '../../services/s3_image_upload_service.dart';
import '../../services/api_client.dart';
import '../../models/enhanced_user_model.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final EnhancedUserService _userService = EnhancedUserService();
  final ContactVerificationService _contactService =
      ContactVerificationService.instance;
  UserModel? _currentUser;
  bool _isLoading = true;
  String _primaryContact = 'email'; // 'email' or 'phone'

  // Unified verification status
  bool _unifiedPhoneVerified = false;
  bool _unifiedEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _userService.getCurrentUserModel();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
        // Load unified verification status
        await _loadUnifiedVerificationStatus();
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUnifiedVerificationStatus() async {
    if (_currentUser == null) return;

    try {
      // Check unified verification status across ALL verification types (business, driver, user)
      final phoneStatus = await _contactService.checkUnifiedVerificationStatus(
        phoneNumber: _currentUser!.phoneNumber,
      );

      final emailStatus = await _contactService.checkUnifiedVerificationStatus(
        email: _currentUser!.email,
      );

      if (mounted) {
        setState(() {
          _unifiedPhoneVerified = phoneStatus['phoneVerified'] == true;
          _unifiedEmailVerified = emailStatus['emailVerified'] == true;
        });

        print('DEBUG: Unified verification status loaded:');
        print('  Phone (${_currentUser!.phoneNumber}): $_unifiedPhoneVerified');
        print('  Email (${_currentUser!.email}): $_unifiedEmailVerified');
      }
    } catch (e) {
      print('Error loading unified verification status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Your profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? const Center(child: Text('Unable to load profile'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Your information'),
                        const SizedBox(height: 16),
                        _buildProfilePictureItem(),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          icon: Icons.person_outline,
                          title: 'Full Name',
                          value: _currentUser!.name.isNotEmpty
                              ? _currentUser!.name
                              : 'Not provided',
                          onTap: () => _showEditNameBottomSheet(),
                        ),
                        const SizedBox(height: 8),
                        _buildContactItem(
                          icon: Icons.phone_outlined,
                          title: 'Mobile',
                          value: _currentUser!.phoneNumber != null
                              ? (_currentUser!.phoneNumber!.startsWith('+94')
                                  ? _currentUser!.phoneNumber!
                                  : '+94 ${_currentUser!.phoneNumber}')
                              : '+94 Not provided',
                          isVerified: _unifiedPhoneVerified,
                          verificationStatus: _unifiedPhoneVerified
                              ? 'Verified'
                              : 'Not verified',
                          isPrimary: _primaryContact == 'phone',
                          contactType: 'phone',
                          onTap: () => _showEditPhoneBottomSheet(),
                          onMakePrimary: () => _makePrimaryContact('phone'),
                        ),
                        const SizedBox(height: 8),
                        _buildContactItem(
                          icon: Icons.email_outlined,
                          title: 'E-mail',
                          value: _currentUser!.email,
                          isVerified: _unifiedEmailVerified,
                          verificationStatus: _unifiedEmailVerified
                              ? 'Verified'
                              : 'Not verified',
                          isPrimary: _primaryContact == 'email',
                          contactType: 'email',
                          onTap: () => _showEditEmailBottomSheet(),
                          onMakePrimary: () => _makePrimaryContact('email'),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          icon: Icons.cake_outlined,
                          title: 'Birthday',
                          value: _currentUser!.dateOfBirth != null
                              ? '${_currentUser!.dateOfBirth!.day}/${_currentUser!.dateOfBirth!.month}/${_currentUser!.dateOfBirth!.year}'
                              : 'Not provided',
                          onTap: () => _showEditBirthdayBottomSheet(),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          icon: Icons.wc_outlined,
                          title: 'Gender',
                          value: _currentUser!.gender ?? 'Not specified',
                          onTap: () => _showEditGenderBottomSheet(),
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Your preferences'),
                        const SizedBox(height: 16),
                        _buildInfoItem(
                          icon: Icons.language_outlined,
                          title: 'Language',
                          value: 'English',
                          onTap: () {
                            // Language is fixed to English for now
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Language is set to English')),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          icon: Icons.emergency_outlined,
                          title: 'Add emergency contact(s)',
                          value: '${_getEmergencyContactsCount()} contacts',
                          onTap: () => _navigateToEmergencyContacts(),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoItem(
                          icon: Icons.settings_outlined,
                          title: 'Additional settings',
                          value: '',
                          onTap: () => _navigateToAdditionalSettings(),
                        ),
                        const SizedBox(height: 40),
                        _buildLogoutButton(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.grey,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildProfilePictureItem() {
    return InkWell(
      onTap: _showProfilePictureOptions,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        child: Row(
          children: [
            Icon(
              Icons.person_outline,
              color: Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasProfilePicture()
                        ? 'Change profile picture'
                        : 'Add profile picture',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  if (!_hasProfilePicture()) const SizedBox(height: 4),
                  if (!_hasProfilePicture())
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _hasProfilePicture()
                ? FutureBuilder<String?>(
                    future:
                        _getProfilePictureUrl(_currentUser!.profilePictureUrl!),
                    builder: (context, snapshot) {
                      return CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            snapshot.hasData && snapshot.data != null
                                ? NetworkImage(snapshot.data!)
                                : null,
                        child: !snapshot.hasData || snapshot.data == null
                            ? Icon(
                                Icons.person,
                                color: Colors.grey[600],
                                size: 24,
                              )
                            : null,
                      );
                    },
                  )
                : CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    child: Icon(
                      Icons.person,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    bool? isVerified,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.grey[600],
              size: 24,
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (isVerified != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVerified ? 'Verified' : 'Not verified',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
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
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
    bool? isVerified,
    String? verificationStatus,
    required bool isPrimary,
    required String contactType,
    required VoidCallback onTap,
    required VoidCallback onMakePrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      if (isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      if (isVerified != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVerified ? 'Verified' : 'Not verified',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isPrimary && isVerified == true) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onMakePrimary,
                      child: Text(
                        'Make Primary',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
      ),
    );
  }

  void _makePrimaryContact(String contactType) {
    if (contactType == 'phone' && !_currentUser!.isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your phone number first')),
      );
      return;
    }

    if (contactType == 'email' && !_currentUser!.isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your email first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Primary Contact'),
        content: Text(
            'Are you sure you want to make ${contactType == 'phone' ? 'phone number' : 'email'} your primary contact method?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _primaryContact = contactType;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${contactType == 'phone' ? 'Phone number' : 'Email'} is now your primary contact')),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _handleLogout,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[300]!),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _hasProfilePicture() {
    return _currentUser?.profilePictureUrl != null &&
        _currentUser!.profilePictureUrl!.isNotEmpty;
  }

  Future<String?> _getProfilePictureUrl(String profilePictureUrl) async {
    // If it's already a full HTTP URL, check if it's an S3 URL that needs signing
    if (profilePictureUrl
        .startsWith('https://requestappbucket.s3.amazonaws.com/')) {
      try {
        // Extract the S3 key from the URL
        final uri = Uri.parse(profilePictureUrl);
        final s3Key = uri.path.substring(1); // Remove leading slash
        return await S3ImageUploadService.getSignedUrlForKey(s3Key);
      } catch (e) {
        print('Error getting signed URL for profile picture: $e');
        return profilePictureUrl; // Fallback to original URL
      }
    }
    // If it's not an S3 URL, return as-is
    return profilePictureUrl;
  }

  int _getEmergencyContactsCount() {
    // TODO: Implement emergency contacts count from user model
    return 2; // Placeholder
  }

  void _navigateToEmergencyContacts() {
    // TODO: Navigate to emergency contacts screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency contacts feature coming soon')),
    );
  }

  void _navigateToAdditionalSettings() {
    // TODO: Navigate to additional settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Additional settings feature coming soon')),
    );
  }

  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_hasProfilePicture())
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture();
                },
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadProfilePicture(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture(XFile imageFile) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Upload image using the S3ImageUploadService
      final S3ImageUploadService uploadService = S3ImageUploadService();
      final uploadedUrl = await uploadService.uploadImageToS3(
        imageFile,
        'profile-pictures',
        userId: _currentUser?.id,
      );

      if (uploadedUrl != null) {
        // Verify authentication before profile update
        final isAuthenticated = await ApiClient.instance.isAuthenticated();
        final token = await ApiClient.instance.getToken();

        if (kDebugMode) {
          print('🔑 Auth check before profile update:');
          print('🔑 Is authenticated: $isAuthenticated');
          print('🔑 Token exists: ${token != null}');
          print('🔑 Token length: ${token?.length ?? 0}');
        }

        if (!isAuthenticated || token == null) {
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication expired. Please login again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Update user profile with new image URL
        final success = await _userService.updateProfile(
          profilePictureUrl: uploadedUrl,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog

          if (success) {
            // Refresh user data to show new image
            await _loadUserData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Profile picture updated successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update profile picture'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Profile Picture'),
          content: const Text(
              'Are you sure you want to remove your profile picture?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Delete from S3 if there's an existing profile picture
        if (_currentUser?.profilePictureUrl != null &&
            _currentUser!.profilePictureUrl!.isNotEmpty &&
            _currentUser!.profilePictureUrl!.contains('amazonaws.com')) {
          final S3ImageUploadService uploadService = S3ImageUploadService();
          await uploadService
              .deleteImageFromS3(_currentUser!.profilePictureUrl!);
        }

        // Update user profile with null image URL
        final success = await _userService.updateProfile(
          profilePictureUrl: null,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog

          if (success) {
            // Refresh user data to show removed image
            await _loadUserData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Profile picture removed successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to remove profile picture'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RestAuthService.instance.logout();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out: $e')),
          );
        }
      }
    }
  }

  void _showEditNameBottomSheet() {
    final TextEditingController firstNameController = TextEditingController();
    final TextEditingController lastNameController = TextEditingController();

    // Split current name if available
    final nameParts = _currentUser!.name.split(' ');
    if (nameParts.isNotEmpty) {
      firstNameController.text = nameParts.first;
      if (nameParts.length > 1) {
        lastNameController.text = nameParts.sublist(1).join(' ');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Name',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _saveName(
                    firstNameController.text, lastNameController.text),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditPhoneBottomSheet() {
    // Check if phone is primary and prevent editing if it's the only verified contact
    if (_primaryContact == 'phone' && (!_currentUser!.isEmailVerified)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Edit Primary Contact'),
          content: const Text(
              'Your phone number is your primary contact method. Please verify your email and set it as primary before changing your phone number.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final TextEditingController phoneController = TextEditingController();
    // Remove +94 prefix if present for editing
    String phoneNumber = _currentUser!.phoneNumber ?? '';
    if (phoneNumber.startsWith('+94 ')) {
      phoneNumber = phoneNumber.substring(4);
    } else if (phoneNumber.startsWith('+94')) {
      phoneNumber = phoneNumber.substring(3);
    }
    phoneController.text = phoneNumber;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Mobile Number',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
                prefixText: '+94 ',
                hintText: '77 123 4567',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _savePhone(phoneController.text),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save & Verify'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditEmailBottomSheet() {
    // Check if email is primary and prevent editing if it's the only verified contact
    if (_primaryContact == 'email' && (!_currentUser!.isPhoneVerified)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Edit Primary Contact'),
          content: const Text(
              'Your email is your primary contact method. Please verify your phone number and set it as primary before changing your email.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final TextEditingController emailController = TextEditingController();
    emailController.text = _currentUser!.email;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Email Address',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _saveEmail(emailController.text),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save & Verify'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _saveName(String firstName, String lastName) async {
    if (firstName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name is required')),
      );
      return;
    }

    try {
      final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();

      // Update user name via API
      final success = await _userService.updateUserProfile(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        displayName: fullName,
      );

      if (success) {
        // Reload user data to get updated information
        await _loadUserData();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully')),
        );
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating name: $e')),
      );
    }
  }

  Future<void> _savePhone(String phoneNumber) async {
    if (phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is required')),
      );
      return;
    }

    try {
      // Format phone number with country code
      String formattedPhone = phoneNumber.trim();
      if (!formattedPhone.startsWith('+94')) {
        formattedPhone = '+94 $formattedPhone';
      }

      // First check if this phone number is already verified across all verification types
      final verificationStatus =
          await _contactService.checkUnifiedVerificationStatus(
        phoneNumber: formattedPhone,
      );

      // Update local state
      setState(() {
        _currentUser = UserModel(
          id: _currentUser!.id,
          name: _currentUser!.name,
          firstName: _currentUser!.firstName,
          lastName: _currentUser!.lastName,
          email: _currentUser!.email,
          phoneNumber: formattedPhone,
          roles: _currentUser!.roles,
          activeRole: _currentUser!.activeRole,
          roleData: _currentUser!.roleData,
          isEmailVerified: _currentUser!.isEmailVerified,
          isPhoneVerified: verificationStatus['phoneVerified'] == true,
          profileComplete: _currentUser!.profileComplete,
          countryCode: _currentUser!.countryCode,
          countryName: _currentUser!.countryName,
          createdAt: _currentUser!.createdAt,
          updatedAt: DateTime.now(),
        );
        _unifiedPhoneVerified = verificationStatus['phoneVerified'] == true;
      });

      Navigator.pop(context);

      if (verificationStatus['phoneVerified'] == true) {
        // Phone is already verified, show success message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Phone Number Updated'),
            content: Text(
                '$formattedPhone is already verified and has been updated successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Also update the user data in the backend
        try {
          await _userService.updateUserProfile(
            phoneNumber: formattedPhone,
          );
          // Reload user data to refresh the UI
          await _loadUserData();
        } catch (e) {
          print('Error updating user profile: $e');
        }
      } else {
        // Phone is not verified, start verification process
        _startPhoneVerification(formattedPhone);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating phone: $e')),
      );
    }
  }

  Future<void> _saveEmail(String email) async {
    if (email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email address is required')),
      );
      return;
    }

    // Basic email validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    try {
      final emailAddress = email.trim();

      // First check if this email is already verified across all verification types
      final verificationStatus =
          await _contactService.checkUnifiedVerificationStatus(
        email: emailAddress,
      );

      // Update local state
      setState(() {
        _currentUser = UserModel(
          id: _currentUser!.id,
          name: _currentUser!.name,
          firstName: _currentUser!.firstName,
          lastName: _currentUser!.lastName,
          email: emailAddress,
          phoneNumber: _currentUser!.phoneNumber,
          roles: _currentUser!.roles,
          activeRole: _currentUser!.activeRole,
          roleData: _currentUser!.roleData,
          isEmailVerified: verificationStatus['emailVerified'] == true,
          isPhoneVerified: _currentUser!.isPhoneVerified,
          profileComplete: _currentUser!.profileComplete,
          countryCode: _currentUser!.countryCode,
          countryName: _currentUser!.countryName,
          createdAt: _currentUser!.createdAt,
          updatedAt: DateTime.now(),
        );
        _unifiedEmailVerified = verificationStatus['emailVerified'] == true;
      });

      Navigator.pop(context);

      if (verificationStatus['emailVerified'] == true) {
        // Email is already verified, show success message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Email Updated'),
            content: Text(
                '$emailAddress is already verified and has been updated successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Also update the user data in the backend
        try {
          await _userService.updateUserProfile(
            firstName: _currentUser!.firstName,
            lastName: _currentUser!.lastName,
          );
        } catch (e) {
          print('Error updating user profile: $e');
        }
      } else {
        // Email is not verified, start verification process
        _startEmailVerification(emailAddress);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating email: $e')),
      );
    }
  }

  void _startPhoneVerification(String phoneNumber) async {
    // First check if phone is already verified through unified system
    try {
      final status = await _contactService.checkUnifiedVerificationStatus(
        phoneNumber: phoneNumber,
      );

      if (status['phoneVerified'] == true) {
        // Phone is already verified in the system
        setState(() {
          _unifiedPhoneVerified = true;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Phone Already Verified'),
            content: Text('$phoneNumber is already verified in your account.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      print('Error checking phone verification status: $e');
    }

    // Phone not verified, start verification process using auth system for personal profile
    try {
      // Use RestAuthService for personal profile phone verification
      final result = await RestAuthService.instance.sendOTP(
        emailOrPhone: phoneNumber,
        isEmail: false,
        countryCode: '+94', // Default country code for Sri Lanka
      );

      if (result.success) {
        _showPhoneOtpDialog(phoneNumber, result.otpToken ?? '');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to send verification code: ${result.error}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending verification code: $e')),
      );
    }
  }

  void _showPhoneOtpDialog(String phoneNumber, String otpToken) {
    final TextEditingController otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Verification Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the verification code sent to $phoneNumber'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Verification Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                _verifyPhoneOtp(otpToken, otpController.text, phoneNumber),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _verifyPhoneOtp(String otpToken, String otp, String phoneNumber) async {
    if (otp.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the verification code')),
      );
      return;
    }

    try {
      // Use RestAuthService for personal profile phone verification
      final result = await RestAuthService.instance.verifyOTP(
        emailOrPhone: phoneNumber,
        otp: otp.trim(),
        otpToken: otpToken,
      );

      Navigator.pop(context); // Close OTP dialog

      if (result.success) {
        // Update unified verification status
        setState(() {
          _unifiedPhoneVerified = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number verified successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Verification failed: ${result.error ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close OTP dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying code: $e')),
      );
    }
  }

  void _startEmailVerification(String email) async {
    // First check if email is already verified through unified system
    try {
      final status = await _contactService.checkUnifiedVerificationStatus(
        email: email,
      );

      if (status['emailVerified'] == true) {
        // Email is already verified in the system
        setState(() {
          _unifiedEmailVerified = true;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Email Already Verified'),
            content: Text('$email is already verified in your account.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      print('Error checking email verification status: $e');
    }

    // Email not verified, start verification process
    try {
      await _contactService.sendBusinessEmailVerification(email: email);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Email Verification'),
          content: Text(
              'A verification link has been sent to $email. Please check your email and click the verification link.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending verification email: $e')),
      );
    }
  }

  void _showEditBirthdayBottomSheet() {
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Birthday',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              child: CalendarDatePicker(
                initialDate: selectedDate,
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
                onDateChanged: (date) {
                  selectedDate = date;
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _saveBirthday(selectedDate),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGenderBottomSheet() {
    final List<String> genders = [
      'Male',
      'Female',
      'Other',
      'Prefer not to say'
    ];
    String selectedGender = 'Not specified';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Gender',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...genders
                .map((gender) => ListTile(
                      title: Text(gender),
                      onTap: () {
                        selectedGender = gender;
                        _saveGender(selectedGender);
                      },
                    ))
                .toList(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _saveBirthday(DateTime birthday) async {
    try {
      if (_currentUser == null) return;

      // Save to backend
      final success = await _userService.updateUserProfile(
        dateOfBirth: birthday,
      );

      if (success) {
        // Reload user data to get updated information
        await _loadUserData();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Birthday saved: ${_formatDateForDisplay(birthday)}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save birthday: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saveGender(String gender) async {
    try {
      if (_currentUser == null) return;

      // Save to backend
      final success = await _userService.updateUserProfile(
        gender: gender,
      );

      if (success) {
        // Reload user data to get updated information
        await _loadUserData();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gender saved: $gender'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save gender: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateForDisplay(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
