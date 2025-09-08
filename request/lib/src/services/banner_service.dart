import 'dart:convert';
import '../models/banner_item.dart';
import 'rest_support_services.dart' show CountryService;
import 'api_client.dart';
import 'image_url_service.dart';

class BannerService {
  BannerService._();
  static final instance = BannerService._();

  Future<List<BannerItem>> getCountryBanners({int limit = 6}) async {
    // Ensure we have a country code
    if (CountryService.instance.countryCode == null) {
      await CountryService.instance.loadPersistedCountry();
    }
    final code = CountryService.instance.countryCode ?? 'US';

    final resp = await ApiClient.instance
        .get<dynamic>('/api/countries/$code/banners', queryParameters: {
      'limit': '$limit',
      'active': 'true',
    });

    final data = resp.data;
    List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['items'] is List) {
      list = data['items'] as List;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List;
    } else {
      list = const [];
    }

    final bannerFutures = list.map((e) async {
      final raw = BannerItem.fromJson(_toMap(e));
      final processedImageUrl =
          await ImageUrlService.instance.processImageUrl(raw.imageUrl);

      return BannerItem(
        id: raw.id,
        imageUrl: processedImageUrl,
        title: raw.title,
        subtitle: raw.subtitle,
        linkUrl: raw.linkUrl,
        priority: raw.priority,
      );
    });

    // Wait for all signed URL requests to complete
    return await Future.wait(bannerFutures);
  }

  Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is String) {
      try {
        return jsonDecode(v) as Map<String, dynamic>;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}
