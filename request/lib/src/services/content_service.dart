import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'placeholder_services.dart' show CountryService; // for country code

/// ContentService & ContentPage REST-backed implementation.
class ContentPage {
  final String id;
  final String slug;
  final String title;
  final String type; // centralized | country_specific
  final String? category;
  final String? targetCountry;
  final String status; // published | draft
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata; // arbitrary extra data
  final String content; // page body / markdown / html

  ContentPage({
    required this.id,
    required this.slug,
    required this.title,
    required this.type,
    this.category,
    this.targetCountry,
    this.status = 'published',
    this.metadata,
    this.content = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

class ContentService {
  ContentService._();
  static final ContentService instance = ContentService._();

  static String get _baseUrl {
    if (kIsWeb) return 'https://api.alphabet.lk';
    if (Platform.isAndroid) return 'https://api.alphabet.lk';
    return 'https://api.alphabet.lk';
  }

  Map<String, String> _authHeaders(String? token) => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  ContentPage _fromJson(Map<String, dynamic> j) {
    return ContentPage(
      id: (j['id'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      type: (j['type'] ?? 'centralized').toString(),
      category: j['category']?.toString(),
      targetCountry: j['country']?.toString(),
      status: (j['status'] ?? 'published').toString(),
      metadata: (j['metadata'] is Map<String, dynamic>)
          ? (j['metadata'] as Map<String, dynamic>)
          : null,
      content: (j['content'] ?? '').toString(),
      updatedAt:
          DateTime.tryParse(j['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Fetch pages with optional filters; defaults to current country and published.
  Future<List<ContentPage>> getPages({
    String? country,
    String status = 'published',
    String? type,
    String? search,
    String? slug,
  }) async {
    final token = await ApiClient.instance.getToken();
    final cc = country ?? CountryService.instance.getCurrentCountryCode();
    final q = <String, String>{};
    if (cc.isNotEmpty) q['country'] = cc;
    if (status.isNotEmpty) q['status'] = status;
    if (type != null && type.isNotEmpty) q['type'] = type;
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (slug != null && slug.isNotEmpty) q['slug'] = slug;
    final uri =
        Uri.parse('$_baseUrl/api/content-pages').replace(queryParameters: q);
    final resp = await http.get(uri, headers: _authHeaders(token));
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body);
    if (data is List) {
      return data.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Prefer country-specific version; fallback to centralized if available.
  Future<ContentPage?> getPageBySlug(String slug, {String? country}) async {
    final cc = country ?? CountryService.instance.getCurrentCountryCode();
    final pages = await getPages(country: cc, status: 'published', slug: slug);
    if (pages.isEmpty) return null;
    // Prefer exact country match
    final match = pages.firstWhere(
      (p) => (p.targetCountry?.toUpperCase() ?? '') == (cc.toUpperCase()),
      orElse: () => pages.first,
    );
    return match;
  }
}
