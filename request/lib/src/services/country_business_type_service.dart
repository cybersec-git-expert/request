import 'dart:convert';
import 'package:http/http.dart' as http;

class CountryBusinessType {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int displayOrder;

  CountryBusinessType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.displayOrder,
  });

  factory CountryBusinessType.fromJson(Map<String, dynamic> json) {
    return CountryBusinessType(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      displayOrder: json['display_order'] is int
          ? json['display_order']
          : int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
    );
  }
}

class CountryBusinessTypeService {
  static const String baseUrl =
      'https://api.alphabet.lk/api/country-business-types';

  static Future<List<CountryBusinessType>> fetchBusinessTypes(
      String countryCode) async {
    final response = await http.get(Uri.parse('$baseUrl/$countryCode'));
    if (response.statusCode == 200) {
      final List<dynamic> data =
          json.decode(response.body)['businessTypes'] ?? [];
      return data.map((e) => CountryBusinessType.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load business types');
    }
  }
}
