class ContentPageModel {
  final String id;
  final String slug;
  final String title;
  final String category;
  final String type;
  final String content;
  final List<String> countries;
  final String? country;
  final List<String> keywords;
  final String? metaDescription;
  final bool requiresApproval;
  final String status;
  final bool isTemplate;
  final int? displayOrder;
  final Map<String, dynamic> metadata;
  final String? targetCountry;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  ContentPageModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.category,
    required this.type,
    required this.content,
    required this.countries,
    this.country,
    required this.keywords,
    this.metaDescription,
    required this.requiresApproval,
    required this.status,
    required this.isTemplate,
    this.displayOrder,
    required this.metadata,
    this.targetCountry,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory ContentPageModel.fromJson(Map<String, dynamic> json) {
    return ContentPageModel(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'info',
      type: json['type'] ?? 'centralized',
      content: json['content'] ?? '',
      countries: List<String>.from(json['countries'] ?? ['global']),
      country: json['country'],
      keywords: List<String>.from(json['keywords'] ?? []),
      metaDescription: json['metaDescription'],
      requiresApproval: json['requiresApproval'] ?? true,
      status: json['status'] ?? 'draft',
      isTemplate: json['isTemplate'] ?? false,
      displayOrder: json['displayOrder'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      targetCountry: json['targetCountry'],
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      createdBy: json['createdBy'],
      updatedBy: json['updatedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'category': category,
      'type': type,
      'content': content,
      'countries': countries,
      'country': country,
      'keywords': keywords,
      'metaDescription': metaDescription,
      'requiresApproval': requiresApproval,
      'status': status,
      'isTemplate': isTemplate,
      'displayOrder': displayOrder,
      'metadata': metadata,
      'targetCountry': targetCountry,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}
