import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/glass_theme.dart';
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
      body: _navigationItems[_currentIndex].screen,
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Opaque to match Home background
            color: GlassTheme.backgroundColor,
            border: const Border(
              top: BorderSide(
                color: Color.fromARGB(64, 148, 147, 147), // subtle divider
                width: 0.2,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            height: 64,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              _persistIndex(index);
            },
            indicatorColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: _navigationItems.map((item) {
              final isMessages = item.label.toLowerCase() == 'messages';
              final hasBadge = isMessages && _unreadMessages > 0;
              return NavigationDestination(
                icon: _buildIcon(item.icon, hasBadge ? _unreadMessages : null),
                selectedIcon: _buildIcon(
                    item.activeIcon, hasBadge ? _unreadMessages : null),
                label: item.label,
              );
            }).toList(),
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

  Widget _buildIcon(IconData icon, [int? badge]) {
    final iconWidget = Icon(icon, size: 26);
    if (badge == null || badge <= 0) return iconWidget;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
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
