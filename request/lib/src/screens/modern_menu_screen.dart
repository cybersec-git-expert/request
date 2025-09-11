import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/enhanced_user_service.dart';
import '../services/rest_notification_service.dart';
import '../theme/glass_theme.dart';
// Removed direct RestAuthService usage in this screen
import 'my_activities_screen.dart';
import 'help_support_screen.dart';
import 'notification_screen.dart';
import 'account/user_profile_screen.dart';
import 'about_us_simple_screen.dart';
import 'pricing/business_product_dashboard.dart';
import 'settings_screen.dart';
import '../widgets/smart_network_image.dart';
// Removed subscription service

class ModernMenuScreen extends StatefulWidget {
  const ModernMenuScreen({super.key});

  @override
  State<ModernMenuScreen> createState() => _ModernMenuScreenState();
}

class _ModernMenuScreenState extends State<ModernMenuScreen> {
  final AuthService _authService = AuthService.instance;
  final EnhancedUserService _userService = EnhancedUserService();

  // Removed content pages and privacy policy section
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  String? _profileImageUrl;
  // Product seller flag no longer used for menu routing; dashboard self-gates
  int _unreadTotal = 0;
  int _unreadMessages = 0;
  String? _membershipLabel; // e.g., static member label

  // Lightweight in-memory cache to avoid refetching every time tab opens
  static DateTime? _lastCountsFetchAt;
  static int _lastUnreadTotal = 0;
  static int _lastUnreadMessages = 0;

  @override
  void initState() {
    super.initState();
    // Seed UI immediately from locally cached auth user to avoid spinner
    final authUser = _authService.currentUser;
    if (authUser != null) {
      final json = authUser.toJson();
      // Ensure we have a 'name' key for UI header fallback
      json['name'] = authUser.fullName;
      _currentUser = json;
    }
    // Also seed avatar from any cached enhanced user profile if present
    final cachedEnhanced = EnhancedUserService.instance.currentUser;
    if (cachedEnhanced != null) {
      _profileImageUrl = cachedEnhanced.profilePictureUrl ?? _profileImageUrl;
    }
    _isLoading = false; // render UI instantly; fill details in background
    // Kick off background refresh
    scheduleMicrotask(_refreshMenuData);
  }

  Future<void> _refreshMenuData() async {
    try {
      // Start all async work in parallel with short timeouts
      final futures = <Future<void>>[];

      // Fresh user profile (non-blocking; falls back to existing values)
      final user = _authService.currentUser;
      if (user != null) {
        futures.add(_userService
            .getCurrentUserModel()
            .timeout(const Duration(seconds: 3))
            .then((fresh) {
          if (fresh != null && mounted) {
            setState(() {
              _currentUser = fresh.toMap();
              _profileImageUrl = fresh.profilePictureUrl ?? _profileImageUrl;
            });
          }
        }).catchError((_) {}));
      }

      // Driver registration (cached in service for 5 minutes)
      // Removed driver functionality

      // Membership label (static)
      if (mounted && _membershipLabel == null) _membershipLabel = 'Member';

      // Unread counts with a tiny TTL to reduce chattiness
      final now = DateTime.now();
      final withinTtl = _lastCountsFetchAt != null &&
          now.difference(_lastCountsFetchAt!) < const Duration(seconds: 30);
      if (withinTtl) {
        if (mounted) {
          setState(() {
            _unreadTotal = _lastUnreadTotal;
            _unreadMessages = _lastUnreadMessages;
          });
        }
      } else {
        futures.add(RestNotificationService.instance
            .unreadCounts()
            .timeout(const Duration(seconds: 3))
            .then((counts) {
          _lastCountsFetchAt = DateTime.now();
          _lastUnreadTotal = counts.total;
          _lastUnreadMessages = counts.messages;
          if (mounted) {
            setState(() {
              _unreadTotal = counts.total;
              _unreadMessages = counts.messages;
            });
          }
        }).catchError((_) {
          if (mounted) {
            setState(() {
              _unreadTotal = _lastUnreadTotal;
              _unreadMessages = _lastUnreadMessages;
            });
          }
        }));
      }

      // Wait for all background tasks, but don't block UI
      await Future.wait(futures);
    } catch (e) {
      print('Error loading menu data: $e');
      // Keep whatever we have on screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: GlassTheme.backgroundGradient,
        child: _isLoading ? _buildLoadingState() : _buildMenuContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor:
            AlwaysStoppedAnimation<Color>(GlassTheme.colors.primaryBlue),
      ),
    );
  }

  Widget _buildMenuContent() {
    return CustomScrollView(
      slivers: [
        // Modern header with centered profile
        SliverToBoxAdapter(
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Centered Profile Section
                _buildCenteredProfileSection(),

                const SizedBox(height: 15),
              ],
            ),
          ),
        ),

        // Menu content
        SliverList(
          delegate: SliverChildListDelegate([
            // Modern grid sections
            _buildMenuGrid(),
            const SizedBox(height: 20),

            // Account actions section
            _buildAccountActionsSection(),
            const SizedBox(height: 20),

            // Logout separated
            _buildLogoutSection(),
            const SizedBox(height: 120),
          ]),
        ),
      ],
    );
  } // Note: User profile header is rendered via _buildCenteredProfileSection()

  Widget _buildCenteredProfileSection() {
    return Column(
      children: [
        // Logo/App Title
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menu',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: GlassTheme.colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.search,
                    color: GlassTheme.colors.textSecondary, size: 28),
                onPressed: () => Navigator.pushNamed(context, '/search'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Centered Profile Picture
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserProfileScreen(),
              ),
            );
            if (mounted) {
              // Refresh user details & avatar after returning
              await _refreshMenuData();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: GlassTheme.isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : const Color(0xFFE2E8F0),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: GlassTheme.isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFF64748B).withOpacity(0.1),
                  blurRadius: GlassTheme.isDarkMode ? 10 : 20,
                  offset: GlassTheme.isDarkMode
                      ? const Offset(0, 5)
                      : const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              width: 100,
              height: 100,
              child: ClipOval(
                child:
                    (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                        ? SmartNetworkImage(
                            imageUrl: _profileImageUrl!,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                            errorBuilder: (c, e, st) => _avatarFallback(),
                            placeholder: _avatarShimmer(),
                          )
                        : _avatarFallback(),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Centered Name
        Text(
          _currentUser?['name'] ?? _currentUser?['displayName'] ?? 'User',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: GlassTheme.colors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Membership status or subtitle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: GlassTheme.colors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user,
                color: GlassTheme.colors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _membershipLabel ?? 'Member',
                style: TextStyle(
                  fontSize: 14,
                  color: GlassTheme.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid() {
    final accountItems = [
      _MenuItem(
        title: 'Products',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFF59E0B), // Amber
        route: 'products', // handled specially
      ),
      _MenuItem(
        title: 'Messages',
        icon: Icons.message_outlined,
        color: const Color(0xFF10B981), // Emerald
        route: '/messages',
        badgeCount: _unreadMessages,
      ),
      _MenuItem(
        title: 'Membership',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFF8B5CF6), // Violet
        route: '/role-selection',
      ),
      _MenuItem(
        title: 'My Activities',
        icon: Icons.history,
        color: const Color(0xFF06B6D4), // Cyan
        route: '/activities',
      ),
      _MenuItem(
        title: 'Notifications',
        icon: Icons.notifications_outlined,
        color: const Color(0xFFEF4444), // Red
        route: '/notifications',
        badgeCount: _unreadTotal,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.0,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: accountItems.length,
            itemBuilder: (context, index) {
              final item = accountItems[index];
              return InkWell(
                onTap: () async {
                  if (item.route != null) {
                    if (item.route == '/activities') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const MyActivitiesScreen()),
                      );
                    } else if (item.route == '/notifications') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const NotificationScreen()),
                      );
                    } else if (item.route == 'products') {
                      // Always route to the business product dashboard; it self-gates for non-approved users
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const BusinessProductDashboard()),
                      );
                    } else {
                      await Navigator.pushNamed(context, item.route!);
                    }
                    // Refresh badges after returning
                    if (mounted) _refreshMenuData();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: GlassTheme.glassContainer,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: GlassTheme.colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((item.badgeCount ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${item.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Removed Information Pages section

  Widget _buildAccountActionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: GlassTheme.glassContainer,
      child: Column(
        children: [
          // Membership tile removed
          _buildActionTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'App preferences and theme',
            color: const Color(0xFF6366F1), // Indigo
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              // Refresh the screen when returning from settings
              if (mounted) {
                setState(() {});
              }
            },
          ),
          _buildActionTile(
            icon: Icons.help_outline,
            title: 'Help and Support',
            subtitle: 'Get help when you need it',
            color: const Color(0xFF06B6D4), // Cyan
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const HelpSupportScreen()),
            ),
          ),
          _buildActionTile(
            icon: Icons.payment_outlined,
            title: 'Payment',
            subtitle: 'Accepted payment methods',
            color: const Color(0xFF10B981), // Emerald
            onTap: () =>
                Navigator.pushNamed(context, '/settings/payment-methods'),
          ),
          _buildActionTile(
            icon: Icons.info_outline,
            title: 'About Us',
            subtitle: 'About Request',
            color: const Color(0xFF6B7280), // Gray
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AboutUsSimpleScreen()),
            ),
          ),
          // Legal links removed from modern menu per request. Accessible from Settings if needed.
        ],
      ),
    );
  }

  Widget _buildLogoutSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: GlassTheme.glassContainer,
      child: _buildActionTile(
        icon: Icons.logout,
        title: 'Log Out',
        subtitle: 'Sign out of your account',
        color: const Color(0xFFEF4444), // Red
        onTap: () async {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: GlassTheme.isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : Colors.white,
              title: Text(
                'Log Out',
                style: TextStyle(color: GlassTheme.colors.textPrimary),
              ),
              content: Text(
                'Are you sure you want to log out?',
                style: TextStyle(color: GlassTheme.colors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: GlassTheme.colors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (shouldLogout == true) {
            await _authService.signOut();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          }
        },
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: GlassTheme.colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: GlassTheme.colors.textSecondary.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _avatarFallback() {
  return Container(
    color: GlassTheme.isDarkMode
        ? const Color(0xFF404040)
        : const Color(0xFFF1F5F9),
    child: Icon(
      Icons.person,
      color: GlassTheme.isDarkMode ? Colors.white70 : const Color(0xFF64748B),
      size: 50,
    ),
  );
}

Widget _avatarShimmer() {
  return Container(
    color: GlassTheme.isDarkMode
        ? const Color(0xFF404040)
        : const Color(0xFFF1F5F9),
    child: const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final String? route;
  final int? badgeCount;
  _MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    this.route,
    this.badgeCount,
  });
}
