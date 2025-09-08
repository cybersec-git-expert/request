import 'api_client.dart';

class Category {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? module; // service module (tours, events, etc) if present
  final String countryCode;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String?
      requestType; // item, service, delivery, rent, etc (optional backend field)

  Category({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.module,
    required this.countryCode,
    required this.isActive,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    this.requestType,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    // Prefer normalized request_type over raw type
    final dynamicType =
        json['request_type'] ?? json['type'] ?? json['category_type'];
    final Map<String, dynamic>? metadata =
        json['metadata'] is Map<String, dynamic>
            ? json['metadata'] as Map<String, dynamic>
            : null;
    final String? topLevelModule =
        (json['module'] is String) ? (json['module'] as String) : null;
    return Category(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'],
      iconUrl: json['icon_url'],
      module: topLevelModule ??
          (metadata != null ? (metadata['module'] as String?) : null),
      countryCode: json['country_code'] ?? 'LK',
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      requestType: (dynamicType is String && dynamicType.isNotEmpty)
          ? dynamicType.toLowerCase()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'country_code': countryCode,
      'is_active': isActive,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (requestType != null) 'type': requestType,
    };
  }
}

class Subcategory {
  final String id;
  final String name;
  final String? description;
  final String categoryId;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subcategory({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    required this.isActive,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'],
      categoryId: json['category_id'].toString(),
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'is_active': isActive,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class RestCategoryService {
  static RestCategoryService? _instance;
  static RestCategoryService get instance =>
      _instance ??= RestCategoryService._();

  RestCategoryService._();

  final ApiClient _apiClient = ApiClient.instance;
  // Lightweight in-memory cache with TTL per unique query
  final Map<String, _CatCache> _cache = {};
  Duration cacheTtl = const Duration(minutes: 10);

  String _key({
    required String country,
    required bool includeInactive,
    String? type,
    String? module,
  }) =>
      [country, includeInactive, type ?? '-', module ?? '-'].join('|');

  /// Get all categories for a specific country
  Future<List<Category>> getCategories({
    String countryCode = 'LK',
    bool includeInactive = false,
    String? type, // product or service, or a module name for convenience
    String? module, // Optional module filter
    bool forceRefresh = false,
  }) async {
    try {
      // Normalize filters per new scheme:
      // - type is either 'product' or 'service'
      // - module is one of: item, rent, delivery, ride, tours, events, construction, education, hiring, other
      // If user passes a module as 'type', infer correctly.
      String? t = type?.toLowerCase();
      String? m = module?.toLowerCase();

      // Alias mapping for backwards compatibility
      // Accept 'rental' as module 'rent', and 'jobs' as 'job'
      if (t == 'rental') {
        m = 'rent';
        t = 'product';
      } else if (t == 'jobs') {
        m = 'job';
        t = 'service';
      }
      if (m == 'rental') m = 'rent';
      if (m == 'jobs') m = 'job';

      bool isModule(String? s) {
        const mods = {
          'item',
          'rent',
          'delivery',
          'ride',
          'tours',
          'events',
          'construction',
          'education',
          'hiring', // legacy
          'job',
          'other'
        };
        return s != null && mods.contains(s);
      }

      if ((t == null || t.isEmpty) && isModule(m)) {
        // infer type from module when only module provided
        t = (m == 'item' || m == 'rent') ? 'product' : 'service';
      } else if (isModule(t) && (m == null || m.isEmpty)) {
        // type was actually a module convenience
        m = t;
        t = (m == 'item' || m == 'rent') ? 'product' : 'service';
      }

      final queryParams = {
        'country': countryCode,
        'includeInactive': includeInactive.toString(),
      };

      // Add type filter if specified
      if (t != null && t.isNotEmpty) {
        queryParams['type'] = t;
      }
      // Add module filter if specified
      if (m != null && m.isNotEmpty) {
        queryParams['module'] = m;
        // Also pass request_type for servers that filter using request_type instead of module
        queryParams['request_type'] = m;
        queryParams['requestType'] = m; // dual key for compatibility
      }

      // Cache key
      final cacheKey = _key(
        country: countryCode,
        includeInactive: includeInactive,
        type: t,
        module: m,
      );

      // Serve from cache if fresh
      final now = DateTime.now();
      final cached = _cache[cacheKey];
      if (!forceRefresh &&
          cached != null &&
          now.difference(cached.at) < cacheTtl) {
        return cached.items;
      }

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/categories',
        queryParameters: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as List?;
        if (data != null) {
          final items = data.map((json) => Category.fromJson(json)).toList();
          _cache[cacheKey] = _CatCache(items, now);
          return items;
        }
      }

      return [];
    } catch (e) {
      print('Error fetching categories: $e');
      // On error, try stale cache if present regardless of TTL
      final cacheKey = _key(
        country: countryCode,
        includeInactive: includeInactive,
        type: type,
        module: module,
      );
      final cached = _cache[cacheKey];
      if (cached != null) return cached.items;
      return [];
    }
  }

  /// Get category by ID
  Future<Category?> getCategoryById(String categoryId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/categories/$categoryId',
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>?;
        if (data != null) {
          return Category.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error fetching category: $e');
      return null;
    }
  }

  /// Get subcategories for a specific category
  Future<List<Subcategory>> getSubcategories({
    required String categoryId,
    bool includeInactive = false,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/categories/$categoryId/subcategories',
        queryParameters: {'includeInactive': includeInactive.toString()},
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] as List?;
        if (data != null) {
          return data.map((json) => Subcategory.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      print('Error fetching subcategories: $e');
      return [];
    }
  }

  /// Cache for categories to improve performance
  final Map<String, List<Category>> _categoriesCache = {};
  final Map<String, List<Subcategory>> _subcategoriesCache = {};

  /// Get categories with caching
  Future<List<Category>> getCategoriesWithCache({
    String countryCode = 'LK',
    bool includeInactive = false,
    String? type, // Add type parameter
    String? module,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        '${countryCode}_${includeInactive}_${type ?? 'all'}_${module ?? 'all'}';

    if (!forceRefresh && _categoriesCache.containsKey(cacheKey)) {
      return _categoriesCache[cacheKey]!;
    }

    final categories = await getCategories(
      countryCode: countryCode,
      includeInactive: includeInactive,
      type: type,
      module: module,
    );

    _categoriesCache[cacheKey] = categories;
    return categories;
  }

  /// Get subcategories with caching
  Future<List<Subcategory>> getSubcategoriesWithCache({
    required String categoryId,
    bool includeInactive = false,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${categoryId}_$includeInactive';

    if (!forceRefresh && _subcategoriesCache.containsKey(cacheKey)) {
      return _subcategoriesCache[cacheKey]!;
    }

    final subcategories = await getSubcategories(
      categoryId: categoryId,
      includeInactive: includeInactive,
    );

    _subcategoriesCache[cacheKey] = subcategories;
    return subcategories;
  }

  /// Clear cache
  void clearCache() {
    _categoriesCache.clear();
    _subcategoriesCache.clear();
  }

  /// Search categories by name
  Future<List<Category>> searchCategories({
    required String query,
    String countryCode = 'LK',
  }) async {
    final categories = await getCategoriesWithCache(countryCode: countryCode);

    return categories.where((category) {
      return category.name.toLowerCase().contains(query.toLowerCase()) ||
          (category.description?.toLowerCase().contains(query.toLowerCase()) ??
              false);
    }).toList();
  }

  /// Search subcategories by name
  Future<List<Subcategory>> searchSubcategories({
    required String query,
    required String categoryId,
  }) async {
    final subcategories = await getSubcategoriesWithCache(
      categoryId: categoryId,
    );

    return subcategories.where((subcategory) {
      return subcategory.name.toLowerCase().contains(query.toLowerCase()) ||
          (subcategory.description?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
              false);
    }).toList();
  }
}

class _CatCache {
  final List<Category> items;
  final DateTime at;
  _CatCache(this.items, this.at);
}
