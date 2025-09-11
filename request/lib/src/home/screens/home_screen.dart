import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/rest_auth_service.dart';
import '../../screens/unified_request_response/unified_request_create_screen.dart';
import '../../models/enhanced_user_model.dart' show RequestType;
import '../../services/rest_support_services.dart'
    show CountryService, ModuleService, CountryModules; // Module gating
import '../../services/pricing_service.dart';
import '../../models/master_product.dart';
import '../../screens/pricing/price_comparison_screen.dart';
import '../../widgets/coming_soon_widget.dart';
import '../../services/rest_notification_service.dart';
import '../../screens/notification_screen.dart';
import '../../screens/account/user_profile_screen.dart';
import '../../theme/glass_theme.dart';
import '../../theme/app_theme.dart';
import '../../services/banner_service.dart';
import '../../models/banner_item.dart' as model;
import '../../widgets/smart_network_image.dart';
import '../../services/enhanced_user_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CountryModules? _modules;
  bool _loadingModules = false;
  int _unreadNotifications = 0;

  // Favorites (persisted locally)
  static const String _prefsFavoritesKey = 'home_favorites_v1';
  Set<String> _favorites = <String>{};

  // UI: banners & popular products
  final PageController _bannerController =
      PageController(viewportFraction: 1.0);
  int _currentBanner = 0;
  final List<_BannerItem> _defaultBanners = const [
    _BannerItem(
      title: 'Find what you need',
      subtitle: 'Post a request and let others help',
      color: Color(0xFF6366F1), // Indigo
      icon: Icons.search,
    ),
    _BannerItem(
      title: 'Compare prices',
      subtitle: 'See best offers from verified sellers',
      color: Color(0xFFF59E0B), // Amber
      icon: Icons.trending_up,
    ),
    _BannerItem(
      title: 'Quick delivery',
      subtitle: 'Send or receive anything fast',
      color: Color(0xFF10B981), // Emerald
      icon: Icons.local_shipping,
    ),
  ];
  // Remote banners + loading state
  List<model.BannerItem> _remoteBanners = const [];
  bool _loadingBanners = false;

  // Pricing + popular products
  final PricingService _pricing = PricingService();
  List<MasterProduct> _popularProducts = const [];
  bool _loadingPopular = false;

  @override
  void initState() {
    super.initState();
    _loadModules();
    _loadUnreadCounts();
    _loadPopularProducts();
    _loadBanners();
    _loadFavorites();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadBanners() async {
    if (_loadingBanners) return;
    setState(() => _loadingBanners = true);
    try {
      final cs = CountryService.instance;
      if (cs.countryCode == null) {
        await cs.loadPersistedCountry();
      }
      final items = await BannerService.instance.getCountryBanners(limit: 6);
      if (!mounted) return;
      setState(() => _remoteBanners = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _remoteBanners = const []);
    } finally {
      if (mounted) setState(() => _loadingBanners = false);
    }
  }

  Future<void> _loadModules({bool forceRefresh = false}) async {
    if (_loadingModules) return;
    setState(() => _loadingModules = true);
    try {
      final cs = CountryService.instance;
      if (cs.countryCode == null) {
        await cs.loadPersistedCountry();
      }
      final code = CountryService.instance.countryCode ?? 'US';
      final mods = await ModuleService.getCountryModules(code,
          forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() => _modules = mods);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingModules = false);
    }
  }

  Future<void> _loadPopularProducts() async {
    if (_loadingPopular) return;
    setState(() => _loadingPopular = true);
    try {
      final products = await _pricing.searchProducts(query: '', limit: 16);
      if (!mounted) return;
      setState(() => _popularProducts = products);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _loadingPopular = false);
    }
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final counts = await RestNotificationService.instance.unreadCounts();
      if (!mounted) return;
      setState(() => _unreadNotifications = counts.total);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotifications = 0);
    }
  }

  // Favorites persistence
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsFavoritesKey) ?? const [];
      if (!mounted) return;
      setState(() => _favorites = list.toSet());
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsFavoritesKey, _favorites.toList());
    } catch (_) {
      // ignore
    }
  }

  bool _isFavorite(String type) => _favorites.contains(type);

  void _toggleFavorite(String type) {
    setState(() {
      if (_favorites.contains(type)) {
        _favorites.remove(type);
      } else {
        _favorites.add(type);
      }
    });
    _saveFavorites();
  }

  List<_RequestType> get _requestTypes => [
        // Grouped home: show two top-level choices to reduce cognitive load
        _RequestType(
          type: 'products',
          title: 'Products',
          subtitle: 'Buy items or rent equipment',
          icon: Icons.shopping_bag,
          color: const Color(0xFFFF6B35),
        ),
        _RequestType(
          type: 'services',
          title: 'Services',
          subtitle: 'Delivery, rides, and more',
          icon: Icons.build,
          color: const Color(0xFF00BCD4),
        ),
      ];

  // Leaf options for Products
  List<_RequestType> get _productOptions => [
        _RequestType(
          type: 'item',
          title: 'Item',
          subtitle: 'Request for products or items',
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xFFFF6B35),
        ),
        _RequestType(
          type: 'rental',
          title: 'Rental',
          subtitle: 'Rent vehicles, equipment, or items',
          icon: Icons.vpn_key,
          color: const Color(0xFF2196F3),
        ),
      ];

  // Leaf options for Services (grouped by verticals)
  List<_RequestType> get _serviceOptions => [
        // Transport
        _RequestType(
          type: 'delivery',
          title: 'Delivery',
          subtitle: 'Send or receive anything fast',
          icon: Icons.local_shipping,
          color: const Color(0xFF4CAF50),
        ),
        _RequestType(
          type: 'ride',
          title: 'Ride',
          subtitle: 'Request for transportation',
          icon: Icons.directions_car,
          color: const Color(0xFF3B82F6),
        ),
        // Experiences
        _RequestType(
          type: 'tours',
          title: 'Tours',
          subtitle: 'Trips and travel packages',
          icon: Icons.flight,
          color: const Color(0xFF9C27B0),
        ),
        _RequestType(
          type: 'events',
          title: 'Events',
          subtitle: 'Weddings, parties, corporate',
          icon: Icons.celebration,
          color: const Color(0xFFFFC107),
        ),
        // Skilled trades
        _RequestType(
          type: 'construction',
          title: 'Construction',
          subtitle: 'Builders and renovations',
          icon: Icons.construction,
          color: const Color(0xFF8D6E63),
        ),
        // Learning
        _RequestType(
          type: 'education',
          title: 'Education',
          subtitle: 'Tutoring and training',
          icon: Icons.school,
          color: const Color(0xFF6366F1),
        ),
        // Job
        _RequestType(
          type: 'hiring',
          title: 'Job',
          subtitle: 'Find jobs or candidates',
          icon: Icons.work,
          color: const Color(0xFF0EA5E9),
        ),
        // Other
        _RequestType(
          type: 'other',
          title: 'Other',
          subtitle: 'Not listed above',
          icon: Icons.more_horiz,
          color: const Color(0xFF64748B),
        ),
      ];

  List<_RequestType> get _allLeafOptions => [
        ..._productOptions,
        ..._serviceOptions,
      ];

  _RequestType? _findOptionByType(String type) {
    try {
      return _allLeafOptions.firstWhere((o) => o.type == type);
    } catch (_) {
      return null;
    }
  }

  String _greetingName() {
    final user = RestAuthService.instance.currentUser;
    if (user == null) return '';
    if (user.firstName != null && user.firstName!.trim().isNotEmpty) {
      final first = user.firstName!.trim();
      if (first.isNotEmpty) return _capitalize(first);
    }
    final emailLocal = user.email.split('@').first;
    if (emailLocal.isEmpty) return '';
    final token = emailLocal.split(RegExp(r'[._-]+')).firstWhere(
          (p) => p.isNotEmpty,
          orElse: () => emailLocal,
        );
    return _capitalize(token);
  }

  String _capitalize(String s) => s.isEmpty
      ? s
      : s.length == 1
          ? s.toUpperCase()
          : s[0].toUpperCase() + s.substring(1);

  Widget _buildModernGreeting() {
    final userName = _greetingName();
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;

    if (hour >= 5 && hour < 12) {
      greeting = 'Good morning';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
      greetingIcon = Icons.wb_sunny;
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good evening';
      greetingIcon = Icons.brightness_3;
    } else {
      greeting = 'Good night';
      greetingIcon = Icons.brightness_2;
    }

    return Row(
      children: [
        // Simple greeting text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    greetingIcon,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                userName.isNotEmpty ? userName : 'User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // Quick create bottom sheet removed from Home.

  bool _moduleEnabled(String type) {
    // Group headers are always enabled (they open a chooser)
    if (type == 'products' || type == 'services') return true;
    // All leaf modules (including tours/events/etc) must respect country toggles
    final key = switch (type) {
      'rental' => 'rent',
      _ => type,
    };
    final mods = _modules;
    if (mods == null) return true;
    return mods.isModuleEnabled(key);
  }

  void _handleTap(_RequestType it) {
    // If a grouped tile is tapped, show the subcategory selector
    if (it.type == 'products' || it.type == 'services') {
      _showCategorySheet(it.type);
      return;
    }
    if (!_moduleEnabled(it.type)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ComingSoonWidget(
            title: it.title,
            description:
                'This feature is not available in your country yet. We\'re working to bring ${it.title.toLowerCase()} to your region soon!',
            icon: it.icon,
          ),
        ),
      );
      return;
    }
    _selectRequestType(it.type);
  }

  void _showCategorySheet(String group) {
    final isProducts = group == 'products';

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtle drag handle for modern look
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        isProducts ? 'Products' : 'Services',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!isProducts) ...[
                    // Lightweight headings for service verticals
                    _SectionHeader(title: 'Transport'),
                    _OptionList(
                      options: _serviceOptions
                          .where(
                              (o) => o.type == 'delivery' || o.type == 'ride')
                          .toList(),
                      moduleEnabled: _moduleEnabled,
                      isFavorite: _isFavorite,
                      onToggleFavorite: (t) {
                        _toggleFavorite(t);
                        setModalState(() {});
                      },
                      onTap: (opt) {
                        Navigator.of(ctx).pop();
                        _handleTap(opt);
                      },
                    ),
                    const SizedBox(height: 6),
                    _SectionHeader(title: 'Experiences'),
                    _OptionList(
                      options: _serviceOptions
                          .where((o) => o.type == 'tours' || o.type == 'events')
                          .toList(),
                      moduleEnabled: _moduleEnabled,
                      isFavorite: _isFavorite,
                      onToggleFavorite: (t) {
                        _toggleFavorite(t);
                        setModalState(() {});
                      },
                      onTap: (opt) {
                        Navigator.of(ctx).pop();
                        _handleTap(opt);
                      },
                    ),
                    const SizedBox(height: 6),
                    _SectionHeader(title: 'Skilled Trades'),
                    _OptionList(
                      options: _serviceOptions
                          .where((o) => o.type == 'construction')
                          .toList(),
                      moduleEnabled: _moduleEnabled,
                      isFavorite: _isFavorite,
                      onToggleFavorite: (t) {
                        _toggleFavorite(t);
                        setModalState(() {});
                      },
                      onTap: (opt) {
                        Navigator.of(ctx).pop();
                        _handleTap(opt);
                      },
                    ),
                    const SizedBox(height: 6),
                    _SectionHeader(title: 'Learning'),
                    _OptionList(
                      options: _serviceOptions
                          .where((o) => o.type == 'education')
                          .toList(),
                      moduleEnabled: _moduleEnabled,
                      isFavorite: _isFavorite,
                      onToggleFavorite: (t) {
                        _toggleFavorite(t);
                        setModalState(() {});
                      },
                      onTap: (opt) {
                        Navigator.of(ctx).pop();
                        _handleTap(opt);
                      },
                    ),
                    const SizedBox(height: 6),
                    _SectionHeader(title: 'Job'),
                    _OptionList(
                      options: _serviceOptions
                          .where((o) => o.type == 'hiring')
                          .toList(),
                      moduleEnabled: _moduleEnabled,
                      isFavorite: _isFavorite,
                      onToggleFavorite: (t) {
                        _toggleFavorite(t);
                        setModalState(() {});
                      },
                      onTap: (opt) {
                        Navigator.of(ctx).pop();
                        _handleTap(opt);
                      },
                    ),
                    const SizedBox(height: 6),
                    _SectionHeader(title: 'Other'),
                    _OptionList(
                      options: _serviceOptions
                          .where((o) => o.type == 'other')
                          .toList(),
                      moduleEnabled: _moduleEnabled,
                      isFavorite: _isFavorite,
                      onToggleFavorite: (t) {
                        _toggleFavorite(t);
                        setModalState(() {});
                      },
                      onTap: (opt) {
                        Navigator.of(ctx).pop();
                        _handleTap(opt);
                      },
                    ),
                  ] else ...[
                    _SectionHeader(title: 'Choose type'),
                    _OptionList(
                      options: _productOptions,
                      moduleEnabled: _moduleEnabled,
                      isFavorite: _isFavorite,
                      onToggleFavorite: (t) {
                        _toggleFavorite(t);
                        setModalState(() {});
                      },
                      onTap: (opt) {
                        Navigator.of(ctx).pop();
                        _handleTap(opt);
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectRequestType(String type) {
    switch (type) {
      case 'item':
        _openUnified(RequestType.item);
        break;
      case 'service':
        _openUnified(RequestType.service);
        break;
      case 'rental':
        _openUnified(RequestType.rental);
        break;
      case 'delivery':
        _openUnified(RequestType.delivery);
        break;
      case 'ride':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UnifiedRequestCreateScreen(initialModule: 'ride')),
        );
        break;
      case 'tours':
      case 'events':
      case 'construction':
      case 'education':
      case 'hiring':
        // Route other service types to generic Service flow with module context
        _openUnified(RequestType.service, module: type);
        break;
      case 'other':
        _openUnified(RequestType.service, module: 'other');
        break;
    }
  }

  void _openUnified(RequestType type, {String? module}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnifiedRequestCreateScreen(
          initialType: type,
          initialModule: module,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Android
          statusBarBrightness: Brightness.light, // iOS
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: _buildModernGreeting(),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: Icon(
                  Icons.notifications_none,
                  color: AppTheme.textPrimary,
                  size: 24,
                ),
                onPressed: () async {
                  try {
                    await Navigator.pushNamed(context, '/notifications');
                  } catch (_) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationScreen(),
                      ),
                    );
                  }
                  await _loadUnreadCounts();
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              splashRadius: 22,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserProfileScreen(),
                  ),
                );
                // Refresh any state that may have changed (including potential avatar)
                await _loadUnreadCounts();
                if (mounted) setState(() {});
              },
              icon: _AppBarAvatar(),
            ),
          ),
        ],
      ),
      body: GlassTheme.backgroundContainer(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadModules(forceRefresh: true);
              await _loadPopularProducts();
              await _loadBanners(); // also refresh banners
            },
            child: Column(
              children: [
                const SizedBox(height: 8), // tighter top padding
                // Banners carousel - full width with custom padding to match grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 128,
                    child: _loadingBanners
                        ? const Center(child: CircularProgressIndicator())
                        : PageView.builder(
                            controller: _bannerController,
                            padEnds: false,
                            itemCount: _remoteBanners.isNotEmpty
                                ? _remoteBanners.length
                                : _defaultBanners.length,
                            onPageChanged: (i) =>
                                setState(() => _currentBanner = i),
                            itemBuilder: (ctx, i) {
                              if (_remoteBanners.isNotEmpty) {
                                return _NetworkBannerCard(
                                  item: _remoteBanners[i],
                                );
                              }
                              return _BannerCard(
                                item: _defaultBanners[i],
                              );
                            },
                          ),
                  ),
                ),

                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _remoteBanners.isNotEmpty
                        ? _remoteBanners.length
                        : _defaultBanners.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: _currentBanner == i ? 14 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _currentBanner == i
                            ? AppTheme.textPrimary
                            : AppTheme.textTertiary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                // Rest of content in scrollable area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    children: [
                      const SizedBox(height: 4),

                      // Quick actions
                      Text('Quick Actions',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  )),
                      const SizedBox(height: 10),
                      _QuickActionsGrid(
                        items: _requestTypes,
                        moduleEnabled: _moduleEnabled,
                        onTap: _handleTap,
                      ),

                      // Favorites section
                      if (_favorites.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Favorites',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    )),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() => _favorites.clear());
                                _saveFavorites();
                              },
                              child: const Text('Clear'),
                            )
                          ],
                        ),
                        _FavoritesWrap(
                          favorites: _favorites
                              .map((t) => _findOptionByType(t))
                              .whereType<_RequestType>()
                              .toList(),
                          onTap: (t) {
                            // reuse existing flow
                            _handleTap(t);
                          },
                          onRemove: (t) => _toggleFavorite(t.type),
                        ),
                      ],

                      // Always show advertisement below Favorites (or directly after Quick Actions when none)
                      const SizedBox(height: 16),
                      _AdCard(
                        title: 'QuickMart — Local Deals',
                        category: 'Shopping',
                        sizeLabel: '22 MB',
                        rating: 4.6,
                        installsLabel: '1M+',
                        icon: Icons.shopping_bag,
                        onTap: () {
                          // Placeholder tap handler for ad card
                        },
                        onInstall: () {
                          // Placeholder install action
                        },
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('Best Sellers',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  )),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PriceComparisonScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'See All',
                              style: TextStyle(
                                color: GlassTheme.colors.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 210,
                        child: _loadingPopular
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (ctx, i) => _ProductCard(
                                  product: _popularProducts[i],
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PriceComparisonScreen(),
                                      ),
                                    );
                                  },
                                ),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemCount: _popularProducts.length,
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBarAvatar extends StatefulWidget {
  @override
  State<_AppBarAvatar> createState() => _AppBarAvatarState();
}

class _AppBarAvatarState extends State<_AppBarAvatar> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Try enhanced user service for richer profile (photo_url)
      final u = await EnhancedUserService.instance.getCurrentUserModel();
      if (!mounted) return;
      setState(() {
        _photoUrl = u?.profilePictureUrl;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _photoUrl = null);
    }
  }

  @override
  void didUpdateWidget(covariant _AppBarAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when parent rebuilds (e.g., after returning from profile page)
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = RestAuthService.instance.currentUser;
    // Try to use cached enhanced user photo if available
    _photoUrl = _photoUrl ??
        EnhancedUserService.instance.currentUser?.profilePictureUrl;
    final fallbackInitial = (user?.displayName?.isNotEmpty == true
            ? user!.displayName![0]
            : user?.email.isNotEmpty == true
                ? user!.email[0]
                : 'U')
        .toUpperCase();
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 32,
          height: 32,
          child: SmartNetworkImage(
            imageUrl: _photoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (c, e, st) => _buildInitialsAvatar(fallbackInitial),
            placeholder: Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return _buildInitialsAvatar(fallbackInitial);
  }
}

Widget _buildInitialsAvatar(String ch) {
  return CircleAvatar(
    radius: 16,
    backgroundColor: GlassTheme.colors.primaryBlue,
    child: Text(
      ch,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}

class _NetworkBannerCard extends StatelessWidget {
  final model.BannerItem item;
  const _NetworkBannerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final link = item.linkUrl;
        if (link == null || link.isEmpty) return;
        if (link.startsWith('/')) {
          try {
            Navigator.of(context).pushNamed(link);
          } catch (_) {}
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          // Removed shadows for flat design
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF7B7B), Color(0xFFFF5E62)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Full-bleed uploaded image as background
                Positioned.fill(
                  child: SmartNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, st) => const SizedBox.shrink(),
                  ),
                ),
                // Subtle left-to-right overlay for readability
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.20),
                          Colors.black.withOpacity(0.00),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Fallback static banner types for defaults
class _BannerItem {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
}

class _BannerCard extends StatelessWidget {
  final _BannerItem item;
  const _BannerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Removed shadows for flat design
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.color.withOpacity(0.95),
                item.color.withOpacity(0.75),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    item.icon,
                    size: 96,
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final List<_RequestType> items;
  final bool Function(String) moduleEnabled;
  final void Function(_RequestType) onTap;
  const _QuickActionsGrid({
    required this.items,
    required this.moduleEnabled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        // One unified flat container for all cards
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          // Slightly higher aspect ratio -> shorter cards (more content fits)
          childAspectRatio: 2.6,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
        ),
        itemBuilder: (ctx, i) {
          final it = items[i];
          final disabled = !moduleEnabled(it.type);
          // Show a single concise word (split by space or &)
          final title = it.title
              .split(RegExp(r'\s|&'))
              .first; // e.g., "Tours & Travel" -> "Tours"
          final textColor =
              disabled ? const Color(0xFF9CA3AF) : AppTheme.textPrimary;
          final subColor =
              disabled ? const Color(0xFFB8BFC7) : AppTheme.textSecondary;

          // Determine which corners should be rounded based on position
          BorderRadius cardRadius;
          final isFirstRow = i < 2;
          final isLastRow = i >= items.length - 2;
          final isFirstColumn = i % 2 == 0;
          final isLastColumn = i % 2 == 1;
          final hasSingleRow = items.length <= 2;

          if (hasSingleRow && isFirstColumn) {
            // Single row - round both left corners
            cardRadius = const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            );
          } else if (hasSingleRow && isLastColumn) {
            // Single row - round both right corners
            cardRadius = const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            );
          } else if (isFirstRow && isFirstColumn) {
            // Top-left card - only top-left corner rounded
            cardRadius = const BorderRadius.only(topLeft: Radius.circular(20));
          } else if (isFirstRow && isLastColumn) {
            // Top-right card - only top-right corner rounded
            cardRadius = const BorderRadius.only(topRight: Radius.circular(20));
          } else if (isLastRow && isFirstColumn) {
            // Bottom-left card - only bottom-left corner rounded
            cardRadius =
                const BorderRadius.only(bottomLeft: Radius.circular(20));
          } else if (isLastRow && isLastColumn) {
            // Bottom-right card - only bottom-right corner rounded
            cardRadius =
                const BorderRadius.only(bottomRight: Radius.circular(20));
          } else {
            // Middle cards - no rounded corners
            cardRadius = BorderRadius.zero;
          }

          return InkWell(
            onTap: disabled ? null : () => onTap(it),
            borderRadius: cardRadius,
            child: Container(
              decoration: BoxDecoration(
                color: disabled ? Colors.grey.shade50 : Colors.white,
                borderRadius: cardRadius,
                // Only outer corners rounded, inner dividers visible
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Colored icon container (like Play Store style)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: disabled
                          ? Colors.grey.shade200
                          : it.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      it.icon,
                      color: disabled ? Colors.grey.shade400 : it.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Texts (title + subtitle)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          it.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class _OptionList extends StatelessWidget {
  final List<_RequestType> options;
  final bool Function(String) moduleEnabled;
  final void Function(_RequestType) onTap;
  final bool Function(String)? isFavorite;
  final void Function(String)? onToggleFavorite;
  const _OptionList({
    required this.options,
    required this.moduleEnabled,
    required this.onTap,
    this.isFavorite,
    this.onToggleFavorite,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < options.length; i++)
          _OptionTile(
            option: options[i],
            disabled: !moduleEnabled(options[i].type),
            onTap: () => onTap(options[i]),
            isLast: i == options.length - 1,
            isFavorite: isFavorite,
            onToggleFavorite: onToggleFavorite,
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _RequestType option;
  final bool disabled;
  final VoidCallback onTap;
  final bool isLast;
  final bool Function(String)? isFavorite;
  final void Function(String)? onToggleFavorite;
  const _OptionTile({
    required this.option,
    required this.disabled,
    required this.onTap,
    required this.isLast,
    this.isFavorite,
    this.onToggleFavorite,
  });
  @override
  Widget build(BuildContext context) {
    final titleColor =
        disabled ? const Color(0xFF9CA3AF) : AppTheme.textPrimary;
    final subColor =
        disabled ? const Color(0xFFB8BFC7) : AppTheme.textSecondary;
    return InkWell(
      onTap: () {
        if (disabled) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ComingSoonWidget(
                title: option.title,
                description:
                    'This feature is not available in your country yet. We\'re working to bring ${option.title.toLowerCase()} to your region soon!',
                icon: option.icon,
              ),
            ),
          );
        } else {
          onTap();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(option.icon,
                color: disabled ? Colors.grey.shade400 : option.color,
                size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            if (onToggleFavorite != null)
              IconButton(
                tooltip: 'Favorite',
                icon: Icon(
                  (isFavorite?.call(option.type) ?? false)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: (isFavorite?.call(option.type) ?? false)
                      ? Colors.redAccent
                      : subColor,
                ),
                onPressed: () => onToggleFavorite?.call(option.type),
              ),
            // Removed trailing chevron for a cleaner list
          ],
        ),
      ),
    );
  }
}

// Favorites chips shown under Quick Actions
class _FavoritesWrap extends StatelessWidget {
  final List<_RequestType> favorites;
  final void Function(_RequestType) onTap;
  final void Function(_RequestType) onRemove;
  const _FavoritesWrap({
    required this.favorites,
    required this.onTap,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in favorites)
          InkWell(
            onTap: () => onTap(f),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f.icon, color: f.color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    f.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => onRemove(f),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.close, size: 16),
                    ),
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Simple sponsored advertisement card shown below Favorites
class _AdCard extends StatelessWidget {
  final String title;
  final String category;
  final String sizeLabel; // e.g., "22 MB"
  final double rating; // 0.0 - 5.0
  final String installsLabel; // e.g., "1M+"
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onInstall;
  const _AdCard({
    required this.title,
    required this.category,
    required this.sizeLabel,
    required this.rating,
    required this.installsLabel,
    required this.icon,
    this.onTap,
    this.onInstall,
  });
  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimary;
    final textSecondary = AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon placeholder
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: GlassTheme.colors.primaryBlue, size: 30),
            ),
            const SizedBox(width: 12),
            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Sponsored',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star,
                          size: 14, color: const Color(0xFFFFB300)),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(
                            rating.truncateToDouble() == rating ? 0 : 1),
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Dot(),
                      const SizedBox(width: 8),
                      Text(category,
                          style: TextStyle(color: textSecondary, fontSize: 12)),
                      const SizedBox(width: 8),
                      _Dot(),
                      const SizedBox(width: 8),
                      Text(sizeLabel,
                          style: TextStyle(color: textSecondary, fontSize: 12)),
                      const SizedBox(width: 8),
                      _Dot(),
                      const SizedBox(width: 8),
                      Text(installsLabel,
                          style: TextStyle(color: textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // CTA
            TextButton(
              onPressed: onInstall,
              style: TextButton.styleFrom(
                backgroundColor: GlassTheme.colors.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Install',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: AppTheme.textTertiary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final MasterProduct product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            // Removed shadows and borders for flat design
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    // Removed shadows for flat design
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: product.images.isNotEmpty
                        ? SmartNetworkImage(
                            imageUrl: product.images.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (c, e, st) {
                              print(
                                  'DEBUG: Image error for ${product.name}: $e');
                              return _buildModernPlaceholder();
                            },
                          )
                        : _buildModernPlaceholder(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.brandName ?? product.brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              // "Today's Lowest Price" label
              Text(
                "Today's Lowest Price",
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              // Price display with charcoal background container
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: GlassTheme.colors.primaryBlue, // Charcoal color
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatPriceRange(context, product),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernPlaceholder({bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Modern geometric pattern background
          Positioned.fill(
            child: CustomPaint(
              painter: _GeometricPatternPainter(),
            ),
          ),
          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 32,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                if (!isLoading) ...[
                  const SizedBox(height: 8),
                  Text(
                    'No Image',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPriceRange(BuildContext context, MasterProduct p) {
    final cs = CountryService.instance;
    final min = p.minPrice ?? p.avgPrice ?? 0;
    final max = p.maxPrice ?? p.avgPrice ?? 0;
    if (min == 0 && max == 0) return '—';
    if (min == max) return cs.formatPrice(min);
    return '${cs.formatPrice(min)} - ${cs.formatPrice(max)}';
  }
}

class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw subtle geometric pattern
    final step = size.width / 6;
    for (int i = 0; i < 7; i++) {
      for (int j = 0; j < 7; j++) {
        final x = i * step;
        final y = j * step;

        // Draw small circles
        canvas.drawCircle(
          Offset(x, y),
          2,
          paint
            ..style = PaintingStyle.fill
            ..color = Colors.grey.shade200.withOpacity(0.2),
        );

        // Draw connecting lines
        if (i < 6) {
          canvas.drawLine(
            Offset(x + 2, y),
            Offset(x + step - 2, y),
            paint
              ..style = PaintingStyle.stroke
              ..color = Colors.grey.shade200.withOpacity(0.1),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Removed _RequestTypeTile (legacy bottom sheet entry).

class _RequestType {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _RequestType({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
