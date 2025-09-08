import '../services/rest_category_service.dart';

class CategoryData {
  static final RestCategoryService _categoryService =
      RestCategoryService.instance;

  // Cache for categories to avoid repeated Firestore calls
  static Map<String, Map<String, List<String>>> _cachedCategories = {};
  static DateTime? _lastFetchTime;
  static const Duration _cacheValidityDuration = Duration(minutes: 10);

  /// Get categories from Firestore with caching (simplified structure)
  static Future<Map<String, List<String>>> getCategoriesForType(
      String type) async {
    // Check cache validity
    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidityDuration &&
        _cachedCategories.containsKey(type)) {
      print('📦 CategoryData: Using cached categories for type $type');
      return _cachedCategories[type]!;
    }

    try {
      print('🔄 CategoryData: Fetching fresh categories for type $type');

      // First, let's debug what's in the database
      // Fetch fresh categories and attempt to infer hierarchy (name pattern)
      final categories = await _categoryService.getCategoriesWithCache();
      final hierarchy = <String, List<String>>{};
      for (final c in categories) {
        final parts = c.name
            .split(RegExp(r'[:>-]'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.length >= 2) {
          final main = parts.first;
          final sub = parts.sublist(1).join(' ');
          hierarchy.putIfAbsent(main, () => []);
          if (!hierarchy[main]!.contains(sub)) hierarchy[main]!.add(sub);
        } else {
          hierarchy.putIfAbsent(c.name, () => []);
        }
      }

      print(
          '📈 CategoryData: Received hierarchy with ${hierarchy.length} categories');
      hierarchy.forEach((category, subcategories) {
        print('   📂 $category: ${subcategories.length} subcategories');
      });

      // Update cache
      _cachedCategories[type] = hierarchy;
      _lastFetchTime = DateTime.now();

      return hierarchy;
    } catch (e) {
      print('❌ CategoryData Error fetching categories for type $type: $e');
      print('   Stack trace: ${StackTrace.current}');
      // Return empty map (no hardcoded fallback per latest requirement)
      return <String, List<String>>{};
    }
  }

  /// Clear cache to force refresh from Firestore
  static void clearCache() {
    _cachedCategories.clear();
    _lastFetchTime = null;
  }

  // Hardcoded fallback categories removed per requirement.
}
