class BannerItem {
  final String id;
  final String imageUrl; // full URL to banner image
  final String? title;
  final String? subtitle;
  final String? linkUrl; // optional deep link / http link
  final int? priority; // for ordering

  const BannerItem({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.linkUrl,
    this.priority,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    // Support multiple backend field names gracefully
    final id = (json['id'] ?? json['_id'] ?? json['uuid'] ?? '').toString();
    final image =
        (json['imageUrl'] ?? json['image'] ?? json['url'] ?? '').toString();
    return BannerItem(
      id: id.isEmpty ? image : id,
      imageUrl: image,
      title: (json['title'] ?? json['name'] ?? '') as String?,
      subtitle: (json['subtitle'] ?? json['description'] ?? '') as String?,
      linkUrl: (json['linkUrl'] ?? json['link'] ?? json['target']) as String?,
      priority: (json['priority'] is int) ? json['priority'] as int : null,
    );
  }
}
