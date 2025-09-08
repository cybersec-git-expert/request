class Category {
  final String id;
  final String name;
  final String type; // 'item', 'service', 'delivery', etc.
  final List<SubCategory> subCategories;
  final String? iconUrl;
  final int order;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.subCategories = const [],
    this.iconUrl,
    this.order = 0,
    this.isActive = true,
  });

  // Convert from REST API response
  factory Category.fromJson(Map<String, dynamic> data) {
    return Category(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      subCategories: (data['subCategories'] as List<dynamic>? ?? [])
          .map((sub) => SubCategory.fromMap(sub as Map<String, dynamic>))
          .toList(),
      iconUrl: data['iconUrl'],
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'subCategories': subCategories.map((sub) => sub.toMap()).toList(),
      'iconUrl': iconUrl,
      'order': order,
      'isActive': isActive,
    };
  }
}

class SubCategory {
  final String id;
  final String name;
  final String? iconUrl;
  final int order;
  final bool isActive;

  SubCategory({
    required this.id,
    required this.name,
    this.iconUrl,
    this.order = 0,
    this.isActive = true,
  });

  factory SubCategory.fromMap(Map<String, dynamic> data) {
    return SubCategory(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      iconUrl: data['iconUrl'],
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconUrl': iconUrl,
      'order': order,
      'isActive': isActive,
    };
  }
}
