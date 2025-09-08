import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import '../../services/country_filtered_data_service.dart';
import '../../services/user_registration_service.dart';
import '../../services/country_service.dart';
import '../../services/module_management_service.dart';
import '../../services/enhanced_user_service.dart';
import '../../models/request_model.dart' as models;
import '../../screens/unified_request_response/unified_request_view_screen.dart';
import '../../screens/requests/ride/view_ride_request_screen.dart';
import '../../theme/glass_theme.dart';

class BrowseRequestsScreen extends StatefulWidget {
  const BrowseRequestsScreen({super.key});

  @override
  State<BrowseRequestsScreen> createState() => _BrowseRequestsScreenState();
}

class _BrowseRequestsScreenState extends State<BrowseRequestsScreen> {
  final List<models.RequestModel> _requests = [];
  bool _initialLoading = true;
  bool _fetchingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  bool _needsCountrySelection = false;

  // Allowed from user registrations (driver/delivery, etc.)
  List<String> _allowedRequestTypes = ['item', 'service', 'rent'];

  // Country-enabled modules mapped to request type keys (item, service, rent, delivery, ride, price)
  final Set<String> _countryEnabledTypes = {
    'item',
    'service',
    'rent',
    'delivery',
    'ride',
    'price'
  };
  bool _isLoggedIn = true;
  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Filters selected by the user from the bottom sheet
  final Set<String> _selectedTypes =
      {}; // backend keys: item, service, rent, delivery, ride
  final Set<String> _selectedCategories =
      {}; // dynamic strings collected from data
  final Set<String> _selectedSubcategories =
      {}; // dynamic strings collected from data

  // Extra filters & sorting
  String _sortBy = 'relevance'; // relevance | recent | price_high | price_low
  double? _minPrice;
  double? _maxPrice;
  bool _deliveryOnly = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  // Determine display label prioritizing module over main type
  String _displayTypeFor(models.RequestModel r) {
    final meta = r.typeSpecificData;
    // 1) Prefer explicit module saved in metadata by create/edit flows
    final rawModule = meta['module']?.toString().trim();
    if (rawModule != null && rawModule.isNotEmpty) {
      final m = rawModule.toLowerCase();
      switch (m) {
        case 'item':
        case 'items':
          // If module is item(s), infer from text to catch rentals like "van hire".
          final inferred =
              _getRequestTypeFromCategory(r.type.name, r.title, r.description);
          return inferred != 'Items' ? inferred : 'Item';
        case 'rent':
        case 'rental':
        case 'rentals':
          return 'Rent';
        case 'delivery':
          return 'Delivery';
        case 'ride':
          return 'Ride';
        case 'price':
        case 'pricing':
          return 'Price';
        case 'Education':
          return 'Education';
        case 'Hiring':
          return 'Job';
        case 'Construction':
          return 'Construction';
        case 'Events':
          return 'Events';
        case 'Tours':
          return 'Tours';
        case 'tours':
          return 'Tours';
        case 'events':
          return 'Events';
        case 'construction':
          return 'Construction';
        case 'education':
          return 'Education';
        case 'hiring':
        case 'jobs':
          return 'Job';
        case 'other':
        case 'others':
        case 'misc':
        case 'general':
        case 'unknown':
        case 'n/a':
        case 'na':
        case 'product':
        case 'products':
        case 'goods':
          // Treat generic/unknown modules as ambiguous; prefer inference.
          final inferred =
              _getRequestTypeFromCategory(r.type.name, r.title, r.description);
          return inferred != 'Items' ? inferred : 'Item';
        default:
          // Unknown specific module -> try inference first; fallback to title-cased module.
          final inferred =
              _getRequestTypeFromCategory(r.type.name, r.title, r.description);
          if (inferred != 'Items') return inferred;
          return m.isNotEmpty ? m[0].toUpperCase() + m.substring(1) : 'Item';
      }
    }

    // 2) Fall back to request type -> best-effort module label
    final t = r.type.name.toLowerCase();
    switch (t) {
      case 'item':
        // Items are the default bucket, but re-infer from title/description to
        // catch cases like "van hire" which should be Rentals.
        final inferred =
            _getRequestTypeFromCategory(r.type.name, r.title, r.description);
        return inferred != 'Items' ? inferred : 'Item';
      case 'service':
        // If content suggests otherwise (e.g., rental keywords), override.
        final inferredService =
            _getRequestTypeFromCategory(r.type.name, r.title, r.description);
        return inferredService != 'Service' ? inferredService : 'Service';
      case 'rental':
      case 'rent':
        return 'Rent';
      case 'delivery':
        return 'Delivery';
      case 'ride':
        return 'Ride';
      case 'price':
        return 'Price';
      default:
        return _getRequestTypeFromCategory(r.type.name, r.title, r.description);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _requests.clear();
    });
    // Ensure country is set or restored; if missing, prompt selection
    if (CountryService.instance.countryCode == null) {
      await CountryService.instance.loadPersistedCountry();
    }
    if (CountryService.instance.countryCode == null) {
      setState(() {
        _needsCountrySelection = true;
        _initialLoading = false;
      });
      return;
    }
    // Determine auth state
    try {
      final user = await EnhancedUserService().getCurrentUserModel();
      _isLoggedIn = user != null;
    } catch (_) {
      _isLoggedIn = false;
    }
    // Load allowed request types based on user registrations (driver/delivery)
    try {
      final allowed =
          await UserRegistrationService.instance.getAllowedRequestTypes();
      _allowedRequestTypes = allowed;
    } catch (_) {}

    // Load country-enabled modules and map to request types
    try {
      final enabledModules =
          await ModuleManagementService.instance.getEnabledModules();
      _countryEnabledTypes..clear();
      for (final m in enabledModules) {
        final cfg = ModuleManagementService.moduleConfigurations[m];
        if (cfg != null) {
          _countryEnabledTypes
              .addAll(cfg.requestTypes.map((e) => e.toLowerCase()));
        }
      }
    } catch (_) {
      // ignore errors; fall back to defaults
    }

    await _fetchPage(reset: true);
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (_fetchingMore || (!_hasMore && !reset)) return;
    setState(() => _fetchingMore = true);
    try {
      // If exactly one type is selected, pass it to backend; else fetch all and filter client-side
      String? selectedBackendType =
          _selectedTypes.length == 1 ? _selectedTypes.first : null;

      final response = await CountryFilteredDataService.instance.getRequests(
        page: _page,
        limit: 20,
        // Do not pass UI label as categoryId; use request_type for server filtering
        requestType: selectedBackendType,
      );
      if (response != null) {
        if (reset) _requests.clear();

        // Use the stream to get properly converted RequestModel objects, with same type filter
        await for (final modelRequests in CountryFilteredDataService.instance
            .getCountryRequestsStream(limit: 20, type: selectedBackendType)) {
          _requests.addAll(modelRequests);
          break; // Only take the first emission since we're not subscribing
        }

        _hasMore = _page < response.pagination.totalPages;
        _page += 1;
      }
    } catch (e) {
      _error = 'Failed to load requests';
    } finally {
      setState(() {
        _initialLoading = false;
        _fetchingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_fetchingMore &&
        _hasMore) {
      _fetchPage();
    }
  }

  List<models.RequestModel> get _filteredRequests {
    // First, enforce role-based gating (driver/delivery)
    final roleGated = _requests.where((r) {
      final mapped = _mapRequestModelToTypeKey(r);
      return _allowedRequestTypes.contains(mapped);
    }).toList();

    // Next, enforce country-enabled module gating
    Iterable<models.RequestModel> current = roleGated.where((r) {
      final key = _mapRequestModelToTypeKey(r);
      return _countryEnabledTypes.contains(key);
    });

    // Public visibility: if not logged in, show only Price requests
    if (!_isLoggedIn) {
      current = current.where((r) => _mapRequestModelToTypeKey(r) == 'price');
    }

    // Type filters
    if (_selectedTypes.isNotEmpty) {
      current = current
          .where((r) => _selectedTypes.contains(_mapRequestModelToTypeKey(r)));
    }

    // Category filters
    if (_selectedCategories.isNotEmpty) {
      current = current.where((r) {
        final cat = _categoryOf(r)?.toLowerCase();
        return cat != null && _selectedCategories.contains(cat);
      });
    }

    // Subcategory filters
    if (_selectedSubcategories.isNotEmpty) {
      current = current.where((r) {
        final sub = _subcategoryOf(r)?.toLowerCase();
        return sub != null && _selectedSubcategories.contains(sub);
      });
    }

    // Delivery-only filter
    if (_deliveryOnly) {
      current =
          current.where((r) => _mapRequestModelToTypeKey(r) == 'delivery');
    }

    // Search query across multiple fields
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      current = current.where((r) => _matchesSearch(r, q));
    }

    // Price range
    if (_minPrice != null || _maxPrice != null) {
      final min = _minPrice ?? double.negativeInfinity;
      final max = _maxPrice ?? double.infinity;
      current = current.where((r) {
        final b = r.budget;
        if (b == null) return false;
        return b >= min && b <= max;
      });
    }

    // Sorting
    final list = current.toList();
    switch (_sortBy) {
      case 'recent':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'price_high':
        list.sort((a, b) => (b.budget ?? double.negativeInfinity)
            .compareTo(a.budget ?? double.negativeInfinity));
        break;
      case 'price_low':
        list.sort((a, b) => (a.budget ?? double.infinity)
            .compareTo(b.budget ?? double.infinity));
        break;
      case 'relevance':
      default:
        // Keep server order
        break;
    }

    return list;
  }

  bool _matchesSearch(models.RequestModel r, String q) {
    // Collect searchable tokens from various fields
    final parts = <String?>[
      r.title,
      r.description,
      _displayTypeFor(
          r), // inferred module/type label e.g., Item, Service, Rent
      _categoryOf(r),
      _subcategoryOf(r),
      r.location?.city,
    ];

    // Include typeSpecificData values (flattened)
    if (r.typeSpecificData.isNotEmpty) {
      for (final entry in r.typeSpecificData.entries) {
        // key and value as strings
        parts.add(entry.key);
        final v = entry.value;
        if (v is String) {
          parts.add(v);
        } else if (v is num || v is bool) {
          parts.add(v.toString());
        } else if (v is List) {
          parts.add(v.join(' '));
        } else if (v is Map) {
          parts.add(v.values.join(' '));
        }
      }
    }

    // Basic contains matching
    for (final p in parts) {
      final s = p?.toString().toLowerCase();
      if (s != null && s.contains(q)) return true;
    }
    return false;
  }

  // Map RequestModel to a backend type key used by allowed types list
  String _mapRequestModelToTypeKey(models.RequestModel r) {
    switch (r.type.name.toLowerCase()) {
      case 'item':
        return 'item';
      case 'service':
        return 'service';
      case 'rental':
      case 'rent':
        return 'rent';
      case 'delivery':
        return 'delivery';
      case 'ride':
        return 'ride';
      case 'price':
        return 'price';
      default:
        return r.type.name.toLowerCase();
    }
  }

  // Removed unused _relativeTime helper (no longer displayed in cards)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassTheme.backgroundContainer(
        child: _needsCountrySelection
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flag_outlined,
                          size: 72, color: Colors.blueGrey),
                      const SizedBox(height: 16),
                      const Text(
                        'Select your country',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose your country to browse requests near you.',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/welcome'),
                        child: const Text('Select Country'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  _Header(
                      onRefresh: _loadInitial,
                      onOpenFilter: _openFilterSheet,
                      hasActiveFilters: _selectedTypes.isNotEmpty ||
                          _selectedCategories.isNotEmpty ||
                          _selectedSubcategories.isNotEmpty ||
                          _deliveryOnly ||
                          _minPrice != null ||
                          _maxPrice != null ||
                          _sortBy != 'relevance' ||
                          _searchQuery.trim().isNotEmpty,
                      searchController: _searchController,
                      onSearchChanged: _onSearchChanged,
                      onClearSearch: _clearSearch),
                  _buildResultCount(),
                  Expanded(
                    child: _initialLoading
                        ? _buildLoadingSkeleton()
                        : _error != null
                            ? _buildErrorState()
                            : _filteredRequests.isEmpty
                                ? _buildEmptyState()
                                : RefreshIndicator(
                                    onRefresh: _loadInitial,
                                    child: GridView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.75,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                      itemCount: _filteredRequests.length +
                                          (_fetchingMore ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index == _filteredRequests.length) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 16),
                                            child: Center(
                                                child:
                                                    CircularProgressIndicator()),
                                          );
                                        }
                                        final request =
                                            _filteredRequests[index];
                                        return _buildRequestCard(request);
                                      },
                                    ),
                                  ),
                  ),
                ],
              ),
      ),
    );
  }

  // Compute available filter values from current data
  Set<String> _availableCategories() {
    final set = <String>{};
    for (final r in _requests) {
      final cat = _categoryOf(r);
      if (cat != null && cat.trim().isNotEmpty) set.add(cat.toLowerCase());
    }
    return set;
  }

  Set<String> _availableSubcategories() {
    final set = <String>{};
    for (final r in _requests) {
      final sub = _subcategoryOf(r);
      if (sub != null && sub.trim().isNotEmpty) set.add(sub.toLowerCase());
    }
    return set;
  }

  String? _categoryOf(models.RequestModel r) {
    switch (r.type.name) {
      case 'item':
        return r.itemData?.category ?? r.itemData?.categoryId;
      case 'service':
        return r.serviceData?.serviceType;
      case 'rental':
      case 'rent':
        return r.rentalData?.itemCategory;
      case 'delivery':
        return r.deliveryData?.package.category;
      default:
        return null;
    }
  }

  String? _subcategoryOf(models.RequestModel r) {
    if (r.type.name == 'item') {
      return r.itemData?.subcategory ?? r.itemData?.subcategoryId;
    }
    return null;
  }

  Future<void> _openFilterSheet() async {
    final typesAvailable = <String>[
      'item',
      'service',
      'rent',
      'delivery',
      'ride',
      'price'
    ]
        .where((t) => _allowedRequestTypes.contains(t))
        .where((t) => _countryEnabledTypes.contains(t))
        .toList();
    final availableCategories = _availableCategories().toList()..sort();
    final availableSubcategories = _availableSubcategories().toList()..sort();

    // Local copies to edit within the sheet
    final tmpTypes = Set<String>.from(_selectedTypes);
    final tmpCats = Set<String>.from(_selectedCategories);
    final tmpSubs = Set<String>.from(_selectedSubcategories);
    String tmpSort = _sortBy;
    double? tmpMin = _minPrice;
    double? tmpMax = _maxPrice;
    bool tmpDeliveryOnly = _deliveryOnly;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: GlassTheme.glassContainer
                            .copyWith(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24)))
                            .copyWith(),
                        child: Column(
                          children: [
                            // Grabber
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: GlassTheme.colors.textTertiary
                                      .withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Header with Reset
                            SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Center(
                                      child: Text('Filters',
                                          style: GlassTheme.titleSmall),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setSheetState(() {
                                        tmpTypes.clear();
                                        tmpCats.clear();
                                        tmpSubs.clear();
                                        tmpSort = 'relevance';
                                        tmpMin = null;
                                        tmpMax = null;
                                        tmpDeliveryOnly = false;
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          GlassTheme.colors.textAccent,
                                    ),
                                    child: const Text('Reset'),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  _sectionTitle('Sort by'),
                                  GlassTheme.glassCard(
                                    subtle: true,
                                    child: Column(
                                      children: [
                                        RadioListTile<String>(
                                          value: 'relevance',
                                          groupValue: tmpSort,
                                          onChanged: (v) =>
                                              setSheetState(() => tmpSort = v!),
                                          activeColor:
                                              GlassTheme.colors.primaryBlue,
                                          title: Text('Relevance',
                                              style: GlassTheme.bodyMedium
                                                  .copyWith(
                                                      color: GlassTheme
                                                          .colors.textPrimary)),
                                          dense: true,
                                        ),
                                        RadioListTile<String>(
                                          value: 'recent',
                                          groupValue: tmpSort,
                                          onChanged: (v) =>
                                              setSheetState(() => tmpSort = v!),
                                          activeColor:
                                              GlassTheme.colors.primaryBlue,
                                          title: Text('Most recent',
                                              style: GlassTheme.bodyMedium
                                                  .copyWith(
                                                      color: GlassTheme
                                                          .colors.textPrimary)),
                                          dense: true,
                                        ),
                                        RadioListTile<String>(
                                          value: 'price_high',
                                          groupValue: tmpSort,
                                          onChanged: (v) =>
                                              setSheetState(() => tmpSort = v!),
                                          activeColor:
                                              GlassTheme.colors.primaryBlue,
                                          title: Text('Highest priced',
                                              style: GlassTheme.bodyMedium
                                                  .copyWith(
                                                      color: GlassTheme
                                                          .colors.textPrimary)),
                                          dense: true,
                                        ),
                                        RadioListTile<String>(
                                          value: 'price_low',
                                          groupValue: tmpSort,
                                          onChanged: (v) =>
                                              setSheetState(() => tmpSort = v!),
                                          activeColor:
                                              GlassTheme.colors.primaryBlue,
                                          title: Text('Lowest priced',
                                              style: GlassTheme.bodyMedium
                                                  .copyWith(
                                                      color: GlassTheme
                                                          .colors.textPrimary)),
                                          dense: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _buildAccordion(
                                    title: 'Categories',
                                    subtitle: tmpCats.isEmpty
                                        ? 'All categories'
                                        : tmpCats.map(_capitalize).join(', '),
                                    child: availableCategories.isEmpty
                                        ? _emptyHint(
                                            'No categories available yet')
                                        : Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children:
                                                availableCategories.map((c) {
                                              final sel = tmpCats.contains(c);
                                              return FilterChip(
                                                label: Text(_capitalize(c)),
                                                selected: sel,
                                                onSelected: (_) =>
                                                    setSheetState(() {
                                                  if (sel) {
                                                    tmpCats.remove(c);
                                                  } else {
                                                    tmpCats.add(c);
                                                  }
                                                }),
                                                backgroundColor:
                                                    Colors.transparent,
                                                selectedColor: GlassTheme
                                                    .colors.primaryBlue
                                                    .withOpacity(0.1),
                                                checkmarkColor: GlassTheme
                                                    .colors.primaryBlue,
                                                labelStyle: TextStyle(
                                                  color: sel
                                                      ? GlassTheme
                                                          .colors.primaryBlue
                                                      : GlassTheme
                                                          .colors.textSecondary,
                                                  fontWeight: sel
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  side: BorderSide.none,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Subcategories
                                  _buildAccordion(
                                    title: 'Subcategories',
                                    subtitle: tmpSubs.isEmpty
                                        ? 'All subcategories'
                                        : tmpSubs.map(_capitalize).join(', '),
                                    child: availableSubcategories.isEmpty
                                        ? _emptyHint(
                                            'No subcategories available yet')
                                        : Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children:
                                                availableSubcategories.map((s) {
                                              final sel = tmpSubs.contains(s);
                                              return FilterChip(
                                                label: Text(_capitalize(s)),
                                                selected: sel,
                                                onSelected: (_) =>
                                                    setSheetState(() {
                                                  if (sel) {
                                                    tmpSubs.remove(s);
                                                  } else {
                                                    tmpSubs.add(s);
                                                  }
                                                }),
                                                backgroundColor:
                                                    Colors.transparent,
                                                selectedColor: GlassTheme
                                                    .colors.primaryBlue
                                                    .withOpacity(0.1),
                                                checkmarkColor: GlassTheme
                                                    .colors.primaryBlue,
                                                labelStyle: TextStyle(
                                                  color: sel
                                                      ? GlassTheme
                                                          .colors.primaryBlue
                                                      : GlassTheme
                                                          .colors.textSecondary,
                                                  fontWeight: sel
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  side: BorderSide.none,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                  const SizedBox(height: 12),

                                  _buildAccordion(
                                    title: 'Item type',
                                    subtitle: tmpTypes.isEmpty
                                        ? 'All items'
                                        : tmpTypes
                                            .map(_displayNameForTypeKey)
                                            .join(', '),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: typesAvailable.map((t) {
                                        final sel = tmpTypes.contains(t);
                                        return FilterChip(
                                          label:
                                              Text(_displayNameForTypeKey(t)),
                                          selected: sel,
                                          onSelected: (_) => setSheetState(() {
                                            if (sel) {
                                              tmpTypes.remove(t);
                                            } else {
                                              tmpTypes.add(t);
                                            }
                                          }),
                                          backgroundColor: Colors.transparent,
                                          selectedColor: GlassTheme
                                              .colors.primaryBlue
                                              .withOpacity(0.1),
                                          checkmarkColor:
                                              GlassTheme.colors.primaryBlue,
                                          labelStyle: TextStyle(
                                            color: sel
                                                ? GlassTheme.colors.primaryBlue
                                                : GlassTheme
                                                    .colors.textSecondary,
                                            fontWeight: sel
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            side: BorderSide.none,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _buildAccordion(
                                    title: 'Price',
                                    subtitle: (tmpMin == null && tmpMax == null)
                                        ? 'Any price'
                                        : '${tmpMin?.toStringAsFixed(0) ?? '0'} - ${tmpMax?.toStringAsFixed(0) ?? '∞'}',
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Min',
                                              labelStyle: GlassTheme.bodySmall,
                                              filled: true,
                                              fillColor: Colors.transparent,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                    color: GlassTheme.colors
                                                        .glassBorderSubtle,
                                                    width: 1),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                    color: GlassTheme
                                                        .colors.primaryBlue,
                                                    width: 1.5),
                                              ),
                                            ),
                                            onChanged: (v) => setSheetState(() {
                                              tmpMin = double.tryParse(v);
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Max',
                                              labelStyle: GlassTheme.bodySmall,
                                              filled: true,
                                              fillColor: Colors.transparent,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                    color: GlassTheme.colors
                                                        .glassBorderSubtle,
                                                    width: 1),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                    color: GlassTheme
                                                        .colors.primaryBlue,
                                                    width: 1.5),
                                              ),
                                            ),
                                            onChanged: (v) => setSheetState(() {
                                              tmpMax = double.tryParse(v);
                                            }),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _buildAccordion(
                                    title: 'Delivery',
                                    subtitle: tmpDeliveryOnly
                                        ? 'Delivery only'
                                        : 'Any',
                                    child: SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('Show delivery requests only',
                                          style: GlassTheme.bodyMedium.copyWith(
                                              color: GlassTheme
                                                  .colors.textPrimary)),
                                      value: tmpDeliveryOnly,
                                      activeColor:
                                          GlassTheme.colors.primaryBlue,
                                      onChanged: (v) => setSheetState(
                                          () => tmpDeliveryOnly = v),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _buildAccordion(
                                    title: 'Delivers to',
                                    subtitle: (CountryService
                                            .instance.countryName.isNotEmpty
                                        ? CountryService.instance.countryName
                                        : 'Your country'),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                          CountryService.instance.countryName
                                                  .isNotEmpty
                                              ? CountryService
                                                  .instance.countryName
                                              : 'Current country',
                                          style: GlassTheme.bodyMedium.copyWith(
                                              color: GlassTheme
                                                  .colors.textPrimary)),
                                      subtitle: Text(
                                          'Country is based on your selection',
                                          style: GlassTheme.bodySmall),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                            SafeArea(
                              top: false,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedTypes
                                          ..clear()
                                          ..addAll(tmpTypes);
                                        _selectedCategories
                                          ..clear()
                                          ..addAll(tmpCats);
                                        _selectedSubcategories
                                          ..clear()
                                          ..addAll(tmpSubs);
                                        _sortBy = tmpSort;
                                        _minPrice = tmpMin;
                                        _maxPrice = tmpMax;
                                        _deliveryOnly = tmpDeliveryOnly;
                                        _page = 1;
                                        _hasMore = true;
                                      });
                                      Navigator.pop(context);
                                      _loadInitial();
                                    },
                                    style: GlassTheme.primaryButton,
                                    child: const Text('Show results'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                );
              },
            );
          },
        );
      },
    );
  }

  String _displayNameForTypeKey(String key) {
    switch (key) {
      case 'item':
        return 'Items';
      case 'service':
        return 'Service';
      case 'rent':
        return 'Rent';
      case 'delivery':
        return 'Delivery';
      case 'ride':
        return 'Ride';
      default:
        return key;
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GlassTheme.titleSmall,
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GlassTheme.bodySmall,
      ),
    );
  }

  String _capitalize(String v) {
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Widget _buildAccordion({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return GlassTheme.glassCard(
      subtle: true,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(title, style: GlassTheme.titleSmall),
          subtitle: subtitle != null
              ? Text(subtitle, style: GlassTheme.bodySmall)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildResultCount() {
    final count = _filteredRequests.length;
    // Handle pluralization gracefully
    final requestsFoundText =
        count == 1 ? '1 request found' : '$count requests found';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Text(
            requestsFoundText,
            style: TextStyle(
              color: _Palette.secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_fetchingMore && !_initialLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 64, color: _Palette.secondaryText),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _Palette.primaryText),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t load requests. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _Palette.secondaryText),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadInitial,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _Palette.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No requests here',
              style: TextStyle(
                fontSize: 18,
                color: _Palette.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different category or check back later for new opportunities.',
              style: TextStyle(
                fontSize: 15,
                color: _Palette.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(models.RequestModel request) {
    final requestType = _displayTypeFor(request);
    final style = _typeStyle(requestType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Flat design - no shadows or borders
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type badge section
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: style.bg.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  requestType,
                  style: TextStyle(
                    color: style.bg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title with better typography
              Text(
                request.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: GlassTheme.colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Description
              Expanded(
                child: Text(
                  request.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: GlassTheme.colors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 16),

              // Bottom section with like and response icons only
              Row(
                children: [
                  // Like count
                  Icon(
                    Icons.favorite_border,
                    size: 16,
                    color: GlassTheme.colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '0', // Placeholder for likes
                    style: TextStyle(
                      color: GlassTheme.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Response count
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: GlassTheme.colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Builder(builder: (context) {
                    int count = 0;
                    final meta = request.typeSpecificData;
                    if (meta.containsKey('response_count')) {
                      final v = meta['response_count'];
                      if (v is int) {
                        count = v;
                      } else {
                        count = int.tryParse(v.toString()) ??
                            request.responses.length;
                      }
                    } else {
                      count = request.responses.length;
                    }
                    return Text(
                      '$count',
                      style: TextStyle(
                        color: GlassTheme.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }),
                ],
              ), // Location with proper spacing
              if (request.location?.city != null) const SizedBox(height: 8),
              if (request.location?.city != null)
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: GlassTheme.colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        request.location!.city!,
                        style: TextStyle(
                          color: GlassTheme.colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to map categories to request types
  String _getRequestTypeFromCategory(
      String? categoryName, String? title, String? description) {
    if (categoryName == null && title == null) return 'Items';

    // Check title and description for keywords first
    String searchText =
        (title ?? '').toLowerCase() + ' ' + (description ?? '').toLowerCase();

    // Normalize punctuation
    searchText = searchText.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // Check for price/quote keywords
    if (searchText.contains('quote') ||
        searchText.contains('price') ||
        searchText.contains('pricing') ||
        searchText.contains('estimate')) {
      return 'Price';
    }

    // Check for delivery keywords
    if (searchText.contains('delivery') ||
        searchText.contains('deliver') ||
        searchText.contains('courier') ||
        searchText.contains('ship') ||
        searchText.contains('shipping') ||
        searchText.contains('parcel') ||
        searchText.contains('package') ||
        searchText.contains('logistics')) {
      return 'Delivery';
    }

    // Check for rental keywords
    if (searchText.contains('rent') ||
        searchText.contains('rental') ||
        searchText.contains('lease') ||
        searchText.contains('leased') ||
        searchText.contains('hire') ||
        searchText.contains('booking') ||
        searchText.contains('book ')) {
      return 'Rent';
    }

    // Check for service keywords
    if (searchText.contains('service') ||
        searchText.contains('repair') ||
        searchText.contains('maintenance') ||
        searchText.contains('fix') ||
        searchText.contains('consultation') ||
        searchText.contains('cleaning') ||
        searchText.contains('cleaner') ||
        searchText.contains('clean ') ||
        searchText.contains('install') ||
        searchText.contains('installation') ||
        searchText.contains('setup') ||
        searchText.contains('electrician') ||
        searchText.contains('plumber') ||
        searchText.contains('plumbing') ||
        searchText.contains('painting') ||
        searchText.contains('paint ') ||
        searchText.contains('support')) {
      return 'Service';
    }

    // Check for ride keywords
    if (searchText.contains('ride') ||
        searchText.contains('transport') ||
        searchText.contains('taxi') ||
        searchText.contains('driver') ||
        searchText.contains('pickup') ||
        searchText.contains('drop') ||
        searchText.contains('travel') ||
        searchText.contains('trip')) {
      return 'Ride';
    }

    // Default to Items for any physical objects or general requests
    return 'Items';
  }

  void _showRequestDetails(models.RequestModel request) {
    // Use specific view screen for ride requests, unified for others
    if (request.type.name == 'ride') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewRideRequestScreen(requestId: request.id),
        ),
      ).then((_) => _loadInitial()); // Refresh list when returning
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UnifiedRequestViewScreen(requestId: request.id),
        ),
      ).then((_) => _loadInitial()); // Refresh list when returning
    }
  }

  // Loading skeleton shimmer-like blocks
  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type badge skeleton
              Container(
                height: 28,
                width: 80,
                decoration: BoxDecoration(
                  color: GlassTheme.colors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              // Title skeleton
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: GlassTheme.colors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              // Description skeleton
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: GlassTheme.colors.textTertiary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: double.infinity * 0.7,
                      decoration: BoxDecoration(
                        color: GlassTheme.colors.textTertiary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Budget skeleton
              Container(
                height: 28,
                width: 100,
                decoration: BoxDecoration(
                  color: GlassTheme.colors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _TypeStyle _typeStyle(String type) {
    switch (type) {
      case 'Delivery':
        return _TypeStyle(Icons.local_shipping, const Color(0xFF4CAF50),
            Colors.white); // green
      case 'Ride':
        return _TypeStyle(Icons.directions_car, const Color(0xFF3B82F6),
            Colors.white); // blue
      case 'Service':
        return _TypeStyle(Icons.build, const Color(0xFF00BCD4), Colors.white);
      case 'Rent':
        return _TypeStyle(
            Icons.vpn_key, const Color(0xFF2196F3), Colors.white); // blue
      case 'Price':
        return _TypeStyle(Icons.attach_money, const Color(0xFF9C27B0),
            Colors.white); // purple
      case 'Education':
        return _TypeStyle(
            Icons.school, const Color(0xFF6366F1), Colors.white); // indigo
      case 'Hiring':
        return _TypeStyle(
            Icons.work_outline, const Color(0xFF0EA5E9), Colors.white); // cyan
      case 'Construction':
        return _TypeStyle(Icons.construction, const Color(0xFF8D6E63),
            Colors.white); // brown (match Home sheet)
      case 'Events':
        return _TypeStyle(
            Icons.event, const Color(0xFFFFC107), Colors.white); // amber
      case 'Tours':
        return _TypeStyle(Icons.travel_explore, const Color(0xFF9C27B0),
            Colors.white); // purple
      case 'Items':
      default:
        return _TypeStyle(
            Icons.shopping_bag, const Color(0xFFFF6B35), Colors.white);
    }
  }
}

// Gradient header with search, Android 16-inspired
class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onOpenFilter;
  final bool hasActiveFilters;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  const _Header({
    required this.onRefresh,
    required this.onOpenFilter,
    this.hasActiveFilters = false,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: GlassTheme.glassContainerSubtle.copyWith(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Discover Requests',
                    style: GlassTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                    color: GlassTheme.colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.tune_rounded),
                        onPressed: onOpenFilter,
                        tooltip: 'Filters',
                        color: _Palette.secondaryText,
                      ),
                      if (hasActiveFilters)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _Palette.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SearchBar(
                searchController: searchController,
                onChanged: onSearchChanged,
                onClear: onClearSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchBar({
    required this.searchController,
    required this.onChanged,
    required this.onClear,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Find requests by skill, item, or service',
          hintStyle: TextStyle(color: _Palette.secondaryText, fontSize: 15),
          prefixIcon:
              Icon(Icons.search_outlined, color: _Palette.secondaryText),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: _Palette.secondaryText),
                  onPressed: onClear,
                  tooltip: 'Clear',
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}

class _TypeStyle {
  final IconData icon;
  final Color bg;
  final Color fg;
  _TypeStyle(this.icon, this.bg, this.fg);
}

// Modern, vibrant, and accessible color palette
class _Palette {
  // Primary & Accents
  static const primaryBlue = Color(0xFF007AFF);

  // Neutrals
  static const primaryText = Color(0xFF1C1C1E);
  static const secondaryText = Color(0xFF6E6E73);
}
