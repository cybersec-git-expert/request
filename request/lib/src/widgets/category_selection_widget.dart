import 'package:flutter/material.dart';
import '../services/rest_category_service.dart';

class CategorySelectionWidget extends StatefulWidget {
  /// Request type per new scheme: 'product' or 'service'.
  /// You may also pass a module as the type for convenience (e.g., 'tours').
  final String type;

  /// Optional module filter: one of item, rent, delivery, ride, tours, events, construction, education, hiring, other
  final String? module;
  final String? selectedCategoryId;
  final String? selectedSubCategoryId;
  final Function(String? categoryId, String? subCategoryId) onSelectionChanged;
  final bool isRequired;

  const CategorySelectionWidget({
    super.key,
    required this.type,
    this.module,
    this.selectedCategoryId,
    this.selectedSubCategoryId,
    required this.onSelectionChanged,
    this.isRequired = true,
  });

  @override
  State<CategorySelectionWidget> createState() =>
      _CategorySelectionWidgetState();
}

class CategoryOption {
  final String id;
  final String displayName;
  final String categoryId;
  final String? subCategoryId;
  final bool isCategory;

  CategoryOption({
    required this.id,
    required this.displayName,
    required this.categoryId,
    this.subCategoryId,
    required this.isCategory,
  });
}

class _CategorySelectionWidgetState extends State<CategorySelectionWidget> {
  final RestCategoryService _categoryService = RestCategoryService.instance;
  List<CategoryOption> _categoryOptions = [];
  bool _isLoading = true;
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Normalize filters per new backend scheme
      String t = widget.type.toLowerCase();
      String? m = widget.module?.toLowerCase();

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
          'hiring',
          'other'
        };
        return s != null && mods.contains(s);
      }

      // If 'type' was actually a module convenience, infer proper type.
      if (isModule(t) && (m == null || m.isEmpty)) {
        m = t;
        t = (m == 'item' || m == 'rent') ? 'product' : 'service';
      }

      // Fetch filtered categories directly from backend
      final categories = await _categoryService.getCategoriesWithCache(
        type: t,
        module: m,
      );

      List<CategoryOption> options = [];

      for (var category in categories) {
        // Add the main category
        options.add(CategoryOption(
          id: 'cat_${category.id}',
          displayName: category.name,
          categoryId: category.id,
          isCategory: true,
        ));
      }

      setState(() {
        _categoryOptions = options;
        _isLoading = false;

        // Set initial selection
        if (widget.selectedCategoryId != null) {
          if (widget.selectedSubCategoryId != null) {
            _selectedValue =
                'sub_${widget.selectedCategoryId}_${widget.selectedSubCategoryId}';
          } else {
            _selectedValue = 'cat_${widget.selectedCategoryId}';
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  void _onSelectionChanged(String? value) {
    setState(() {
      _selectedValue = value;
    });

    if (value == null) {
      widget.onSelectionChanged(null, null);
      return;
    }

    final selectedOption =
        _categoryOptions.firstWhere((opt) => opt.id == value);
    widget.onSelectionChanged(
      selectedOption.categoryId,
      selectedOption.subCategoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading categories...'),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedValue,
      decoration: InputDecoration(
        labelText: _getCategoryTitle(),
        hintText: 'Select a category or subcategory',
        prefixIcon: Icon(
          _getCategoryIcon(),
          color: Colors.blue.shade600,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
      ),
      items: _categoryOptions.map((option) {
        return DropdownMenuItem<String>(
          value: option.id,
          child: Row(
            children: [
              // Icon for category vs subcategory
              Icon(
                option.isCategory
                    ? Icons.folder
                    : Icons.subdirectory_arrow_right,
                size: 16,
                color: option.isCategory
                    ? Colors.blue.shade600
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        option.isCategory ? FontWeight.w500 : FontWeight.normal,
                    color: option.isCategory
                        ? Colors.black87
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: _onSelectionChanged,
      validator: widget.isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a category';
              }
              return null;
            }
          : null,
      isExpanded: true,
      menuMaxHeight: 300,
    );
  }

  IconData _getCategoryIcon() {
    final t = widget.type.toLowerCase();
    final m = widget.module?.toLowerCase();
    if (m == 'delivery' || t == 'delivery') return Icons.local_shipping;
    if (m == 'ride' || t == 'ride') return Icons.directions_car;
    if (m == 'tours') return Icons.card_travel;
    if (m == 'events') return Icons.event;
    if (m == 'construction') return Icons.engineering;
    if (m == 'education') return Icons.school;
    if (m == 'hiring') return Icons.work_outline;
    if (m == 'other') return Icons.dashboard_customize;
    if (t == 'product' || m == 'item' || m == 'rent') return Icons.shopping_bag;
    if (t == 'service') return Icons.build;
    return Icons.category;
  }

  String _getCategoryTitle() {
    final t = widget.type.toLowerCase();
    final m = widget.module?.toLowerCase();
    if (m == 'delivery' || t == 'delivery') return 'Delivery Category';
    if (m == 'ride' || t == 'ride') return 'Ride Category';
    if (m == 'tours') return 'Tours Category';
    if (m == 'events') return 'Events Category';
    if (m == 'construction') return 'Construction Category';
    if (m == 'education') return 'Education Category';
    if (m == 'hiring') return 'Hiring Category';
    if (m == 'other') return 'Other Category';
    if (t == 'product' || m == 'item' || m == 'rent') return 'Item Category';
    if (t == 'service') return 'Service Category';
    return 'Category';
  }
}
