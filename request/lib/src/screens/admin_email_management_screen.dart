import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class AdminEmailManagementPage extends StatefulWidget {
  const AdminEmailManagementPage({Key? key}) : super(key: key);

  @override
  State<AdminEmailManagementPage> createState() =>
      _AdminEmailManagementPageState();
}

class _AdminEmailManagementPageState extends State<AdminEmailManagementPage> {
  List<Map<String, dynamic>> _userEmails = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _loadEmailData();
  }

  Future<void> _loadEmailData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load user emails from user_email_addresses table
      final emailsResponse = await ApiClient.instance
          .get('/api/admin/email-management/user-emails');

      if (emailsResponse.isSuccess) {
        setState(() {
          _userEmails = List<Map<String, dynamic>>.from(
              emailsResponse.data['emails'] ?? []);
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load email data';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleEmailVerification(
      String emailId, bool currentStatus) async {
    try {
      final response = await ApiClient.instance.post(
        '/api/admin/email-management/toggle-verification',
        data: {
          'emailId': emailId,
          'verified': !currentStatus,
        },
      );

      if (response.isSuccess) {
        _loadEmailData(); // Reload data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verification status updated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredEmails {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return _userEmails;
    }

    return _userEmails.where((email) {
      final emailAddress =
          email['email_address']?.toString().toLowerCase() ?? '';
      final userName = email['user_name']?.toString().toLowerCase() ?? '';
      final purpose = email['purpose']?.toString().toLowerCase() ?? '';
      final searchLower = _searchQuery!.toLowerCase();

      return emailAddress.contains(searchLower) ||
          userName.contains(searchLower) ||
          purpose.contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmailData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by email, user name, or purpose...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Statistics cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Emails',
                    _userEmails.length.toString(),
                    Icons.email,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Verified',
                    _userEmails
                        .where((e) => e['is_verified'] == true)
                        .length
                        .toString(),
                    Icons.verified,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Pending',
                    _userEmails
                        .where((e) => e['is_verified'] != true)
                        .length
                        .toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),

          // Email list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEmails.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.email_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No emails found',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredEmails.length,
                        itemBuilder: (context, index) {
                          final email = _filteredEmails[index];
                          return _buildEmailCard(email);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailCard(Map<String, dynamic> email) {
    final bool isVerified = email['is_verified'] == true;
    final String emailAddress = email['email_address'] ?? '';
    final String userName = email['user_name'] ?? 'Unknown User';
    final String purpose = email['purpose'] ?? '';
    final String verificationMethod = email['verification_method'] ?? '';
    final String? verifiedAt = email['verified_at'];
    final String userId = email['user_id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emailAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User: $userName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    border: Border.all(
                      color: isVerified ? Colors.green : Colors.orange,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVerified ? Icons.verified : Icons.pending,
                        size: 16,
                        color: isVerified ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? 'Verified' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: isVerified ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (purpose.isNotEmpty) ...[
                  _buildInfoChip('Purpose', purpose, Icons.label),
                  const SizedBox(width: 8),
                ],
                if (verificationMethod.isNotEmpty) ...[
                  _buildInfoChip(
                      'Method', verificationMethod, Icons.how_to_reg),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            if (verifiedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Verified: ${DateTime.parse(verifiedAt).toLocal().toString().split('.')[0]}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'User ID: $userId',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _toggleEmailVerification(
                    email['id']?.toString() ?? '',
                    isVerified,
                  ),
                  icon: Icon(
                    isVerified ? Icons.cancel : Icons.verified_user,
                    size: 16,
                  ),
                  label: Text(isVerified ? 'Unverify' : 'Verify'),
                  style: TextButton.styleFrom(
                    foregroundColor: isVerified ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
