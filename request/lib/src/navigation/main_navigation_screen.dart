import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../services/rest_notification_service.dart';
import '../home/screens/home_screen.dart';
import '../home/screens/browse_requests_screen.dart';
import '../screens/modern_menu_screen.dart';
import '../screens/pricing/price_comparison_screen.dart';
import '../screens/chat/chat_conversations_screen.dart';
import '../services/notification_center.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _unreadMessages = 0;
  late final List<_NavigationItem> _navigationItems = [
    _NavigationItem(
      screen: const HomeScreen(),
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    _NavigationItem(
      screen: const BrowseRequestsScreen(),
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: 'Browse',
    ),
    _NavigationItem(
      screen: const PriceComparisonScreen(),
      icon: Icons.trending_up_outlined,
      activeIcon: Icons.trending_up,
      label: 'Prices',
    ),
    _NavigationItem(
      screen: const ChatConversationsScreen(),
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Messages',
    ),
    _NavigationItem(
      screen: const ModernMenuScreen(),
      icon: Icons.menu_outlined,
      activeIcon: Icons.menu,
      label: 'Menu',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUnreadCounts();
    // Subscribe to live updates from NotificationCenter
    NotificationCenter.instance.unreadMessages.addListener(_updateBadge);
  }

  void _updateBadge() {
    if (!mounted) return;
    setState(() {
      _unreadMessages = NotificationCenter.instance.unreadMessages.value;
    });
  }

  Future<void> _persistIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_tab_index', index);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlassTheme.backgroundColor,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: _navigationItems[_currentIndex].screen,
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        offset: _navVisible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _navVisible ? 1 : 0,
          child: GlassBottomNavBar(
            // Uniform mode: one row, no center circle
            items: [
              GlassBottomNavItem(
                icon: _currentIndex == 0
                    ? _navigationItems[0].activeIcon
                    : _navigationItems[0].icon,
                label: _navigationItems[0].label,
                selected: _currentIndex == 0,
                onTap: () {
                  setState(() => _currentIndex = 0);
                  _persistIndex(0);
                },
              ),
              GlassBottomNavItem(
                icon: _currentIndex == 1
                    ? _navigationItems[1].activeIcon
                    : _navigationItems[1].icon,
                label: _navigationItems[1].label,
                selected: _currentIndex == 1,
                onTap: () {
                  setState(() => _currentIndex = 1);
                  _persistIndex(1);
                },
              ),
              GlassBottomNavItem(
                icon: _currentIndex == 2
                    ? _navigationItems[2].activeIcon
                    : _navigationItems[2].icon,
                label: _navigationItems[2].label,
                selected: _currentIndex == 2,
                onTap: () {
                  setState(() => _currentIndex = 2);
                  _persistIndex(2);
                },
              ),
              GlassBottomNavItem(
                icon: _currentIndex == 3
                    ? _navigationItems[3].activeIcon
                    : _navigationItems[3].icon,
                label: _navigationItems[3].label,
                selected: _currentIndex == 3,
                badgeCount: _unreadMessages,
                onTap: () {
                  setState(() => _currentIndex = 3);
                  _persistIndex(3);
                },
              ),
              GlassBottomNavItem(
                icon: _currentIndex == 4
                    ? _navigationItems[4].activeIcon
                    : _navigationItems[4].icon,
                label: _navigationItems[4].label,
                selected: _currentIndex == 4,
                onTap: () {
                  setState(() => _currentIndex = 4);
                  _persistIndex(4);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    NotificationCenter.instance.unreadMessages.removeListener(_updateBadge);
    super.dispose();
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final counts = await RestNotificationService.instance.unreadCounts();
      if (!mounted) return;
      setState(() => _unreadMessages = counts.messages);
    } catch (_) {
      // Ignore errors and keep badge hidden
    }
  }

  // Note: badge support can be added into GlassBottomNavBar if needed.

  bool _navVisible = true;
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final dy = notification.scrollDelta;
      if (dy != null) {
        if (dy > 2 && _navVisible) {
          setState(() => _navVisible = false);
        } else if (dy < -2 && !_navVisible) {
          setState(() => _navVisible = true);
        }
      }
    }
    return false;
  }
}

class _NavigationItem {
  final Widget screen;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavigationItem({
    required this.screen,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
