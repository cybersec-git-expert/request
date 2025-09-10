import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription_models.dart';
import '../../services/enhanced_user_service.dart';
import '../../services/api_client.dart';
import '../../models/enhanced_user_model.dart';

class MembershipScreen extends StatefulWidget {
  final bool promptOnboarding;

  const MembershipScreen({
    super.key,
    this.promptOnboarding = false,
  });

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  bool _loading = true;
  String? _error;
  MembershipInit? _data;
  String? _selectedRole;
  bool _updatingRole = false;
  final EnhancedUserService _userService = EnhancedUserService();

  static const Set<String> _allowedRoles = {
    'general',
    'product_seller',
    'driver',
  };

  List<RoleOption> _filteredRoles(List<RoleOption> roles) {
    return roles.where((r) => _allowedRoles.contains(r.type)).toList();
  }

  // Display order for cards
  static const List<String> _roleOrder = [
    'general',
    'product_seller',
    'driver',
  ];

  IconData _roleIcon(String type) {
    switch (type) {
      case 'driver':
        return Icons.local_taxi;
      case 'product_seller':
        return Icons.storefront;
      case 'general':
      default:
        return Icons.business_center;
    }
  }

  String _roleTitle(String type, String fallback) {
    switch (type) {
      case 'general':
        return 'General Business';
      case 'product_seller':
        return 'Product Seller';
      case 'driver':
        return 'Driver';
      default:
        return fallback;
    }
  }

  List<Widget> _buildRoleCardsList() {
    if (_data == null) return const [];
    final roles = _filteredRoles(_data!.roles).toList()
      ..sort((a, b) =>
          _roleOrder.indexOf(a.type).compareTo(_roleOrder.indexOf(b.type)));
    return roles
        .map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _RoleCard(
                title: _roleTitle(r.type, r.name),
                description: r.description ?? '',
                icon: _roleIcon(r.type),
                selected: _selectedRole == r.type,
                onTap: () => _onSelectRole(r.type),
              ),
            ))
        .toList(growable: false);
  }

  String _defaultRole(List<RoleOption> roles) {
    final list = _filteredRoles(roles);
    // Prefer General Business, then Product Seller, then Driver
    final byType = {for (var r in list) r.type: r};
    if (byType.containsKey('general')) return 'general';
    if (byType.containsKey('product_seller')) return 'product_seller';
    if (byType.containsKey('driver')) return 'driver';
    return list.isNotEmpty ? list.first.type : 'general';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = SubscriptionService.instance;
      try {
        final init = await svc.membershipInit();
        setState(() {
          _data = init;
          _selectedRole =
              init.roles.isNotEmpty ? _defaultRole(init.roles) : null;
        });
      } catch (_) {
        final List<SubscriptionPlan> plans = await svc.availablePlansPublic();
        setState(() {
          _data = MembershipInit(
            country: 'LK',
            roles: const [],
            plans: plans,
            sellerPlanCodes: const [],
          );
          _selectedRole = null;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSelectRole(String type) async {
    if (_updatingRole) return;
    setState(() => _updatingRole = true);
    final svc = SubscriptionService.instance;
    try {
      final ok = await svc.updateRegistrationType(type);
      if (!ok) throw Exception('Failed to update role');
      if (!mounted) return;
      setState(() => _selectedRole = type);
      try {
        final init = await svc.membershipInit();
        if (!mounted) return;
        setState(() => _data = init);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to save your role.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingRole = false);
    }
  }

  /// Check business verification status for current user
  Future<String> _checkBusinessVerificationStatus() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) return 'no_auth';

      // Check if user has business role
      if (!user.roles.contains(UserRole.business)) {
        return 'no_business_role';
      }

      // Check business verification status
      final resp = await ApiClient.instance
          .get('/api/business-verifications/user/${user.uid}');
      if (resp.isSuccess && resp.data != null) {
        final responseWrapper = resp.data as Map<String, dynamic>;
        final data = responseWrapper['data'] as Map<String, dynamic>?;
        if (data != null) {
          final status =
              (data['status'] ?? 'pending').toString().trim().toLowerCase();
          return status; // 'approved', 'pending', 'rejected'
        }
      }
      return 'no_verification';
    } catch (e) {
      print('Error checking business verification: $e');
      return 'error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authed = _data != null && _data!.roles.isNotEmpty;
    return GlassTheme.backgroundContainer(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Membership'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppTheme.textPrimary,
          actions: [
            if (widget.promptOnboarding)
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (r) => false),
                child: const Text('Skip'),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorBox(error: _error!, onRetry: _load)
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_data != null && _data!.roles.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blueAccent),
                              ),
                              child: const Text(
                                "You're viewing public plans. Sign in to choose a role and see personalized options.",
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.orange,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.orange,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Get registered to continue',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: GlassTheme.colors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Complete your registration to unlock responding, contact details, and messaging features.',
                            style: TextStyle(
                              fontSize: 16,
                              color: GlassTheme.colors.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (authed) ...[
                            const Text('Choose your role',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ..._buildRoleCardsList(),
                            if (_updatingRole)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                          ],
                          // Plans are chosen after registration approval, so hidden here.
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: () async {
              if (!authed) {
                Navigator.pushNamed(context, '/login').then((_) => _load());
                return;
              }
              if (_selectedRole == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please choose a role to continue.')),
                );
                return;
              }

              final role = _selectedRole!;
              if (role == 'driver') {
                Navigator.pushNamed(context, '/driver-registration',
                    arguments: {'selectedRole': role});
              } else {
                // For business and product_seller, check verification status first
                final verificationStatus =
                    await _checkBusinessVerificationStatus();

                switch (verificationStatus) {
                  case 'approved':
                    // User is verified business, go to subscription plans
                    Navigator.pushNamed(context, '/membership', arguments: {
                      'requiredSubscriptionType': 'business',
                    });
                    break;
                  case 'pending':
                    // User has pending verification, go to role management
                    Navigator.pushNamed(context, '/role-management');
                    break;
                  case 'rejected':
                    // User was rejected, show message and go to role management
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Your business verification was rejected. Please check your role management for details.')),
                    );
                    Navigator.pushNamed(context, '/role-management');
                    break;
                  case 'no_business_role':
                  case 'no_verification':
                  case 'error':
                  default:
                    // New user or no existing business role, go to business registration
                    Navigator.pushNamed(context, '/business-registration',
                        arguments: {'selectedRole': role});
                    break;
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A6B7A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Text(
              authed ? 'Continue' : 'Sign in to Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

// Plans list is omitted on this screen; plans are chosen after registration approval.

class _ErrorBox extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text('Failed to load membership',
              style: TextStyle(
                  color: GlassTheme.colors.textPrimary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: TextStyle(color: GlassTheme.colors.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          )
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? Colors.blue.withOpacity(0.06)
        : Colors.white.withOpacity(0.9);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.blue, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle,
                              color: Colors.blueAccent, size: 20),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.35,
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
}
