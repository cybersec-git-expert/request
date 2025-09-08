import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/country.dart';

class CountryService {
  CountryService._();
  static final CountryService instance = CountryService._();

  // Selected country state (null until user chooses or restored from prefs)
  String? countryCode;
  String countryName = '';
  String currency = '';
  String phoneCode = '';

  static const _prefsCountryKey = 'selected_country_code';
  static const _prefsCountryPhoneKey = 'selected_country_phone_code';

  final List<Country> _cache = [];
  DateTime? _lastFetch;
  Duration cacheTtl = const Duration(minutes: 15);

  String getCurrencySymbol() => 'Rs';
  String formatPrice(num amount) => 'Rs ${amount.toStringAsFixed(2)}';

  // Resolved backend base URL (call _resolveBaseUrl once then allow override)
  late String baseUrl = _resolveBaseUrl();

  // Allow runtime override (e.g., from settings screen)
  void overrideBaseUrl(String url) {
    if (kDebugMode) debugPrint('Overriding API base URL -> $url');
    baseUrl = url.replaceFirst(RegExp(r'/+$'), '');
    // Invalidate cache so fresh fetch uses new host
    _cache.clear();
    _lastFetch = null;
  }

  String _resolveBaseUrl() {
    // 1. Compile-time define
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) return defined;
    // 2. Production URLs for all platforms
    return 'https://api.alphabet.lk';
  }

  Future<List<Country>> getAllCountries({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.isNotEmpty && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!) < cacheTtl) {
        return List.unmodifiable(_cache);
      }
    }
    try {
      final uri = Uri.parse('$baseUrl/api/countries/public');
      if (kDebugMode)
        debugPrint('Fetching countries: $uri (resolved base: $baseUrl)');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final dynamic decoded = json.decode(resp.body);
      final List data;
      if (decoded is List) {
        data = decoded;
      } else if (decoded is Map<String, dynamic>) {
        data = (decoded['data'] ??
            decoded['countries'] ??
            decoded['items'] ??
            []) as List;
      } else {
        throw Exception('Unexpected response shape');
      }
      _cache
        ..clear()
        ..addAll(data.map((e) => Country.fromJson(e as Map<String, dynamic>)));
      _lastFetch = DateTime.now();
      return List.unmodifiable(_cache);
    } catch (e) {
      if (_cache.isNotEmpty) {
        if (kDebugMode) debugPrint('Country fetch failed, using cache: $e');
        return List.unmodifiable(_cache);
      }
      if (kDebugMode) {
        debugPrint(
            'Country fetch failed with baseUrl=$baseUrl. If running on Android emulator make sure to use 10.0.2.2 or call overrideBaseUrl("http://10.0.2.2:3001"). Error: $e');
      }
      rethrow;
    }
  }

  Future<void> setCountryFromObject(Country c) async {
    countryCode = c.code;
    countryName = c.name;
    phoneCode = c.phoneCode;
    // currency not in model yet -> fallback logic
    currency = c.code == 'LK' ? 'LKR' : (c.code == 'US' ? 'USD' : 'USD');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCountryKey, countryCode!);
    await prefs.setString(_prefsCountryPhoneKey, phoneCode);
  }

  Future<void> loadPersistedCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsCountryKey);
    final phone = prefs.getString(_prefsCountryPhoneKey);
    if (code != null) {
      countryCode = code;
      phoneCode = phone ?? phoneCode;
    }
  }

  // Backward compatibility helper used by other screens
  String getCurrentCountryCode() => countryCode ?? 'LK';
  String getCurrentPhoneCode() => phoneCode.isNotEmpty ? phoneCode : '+94';
}

class CountryModules {
  final Map<String, bool> modules;
  CountryModules(this.modules);

  bool isModuleEnabled(String moduleId) => modules[moduleId] ?? false;
}

class ModuleService {
  ModuleService._();
  static final Map<String, CountryModules> _cache = {};
  static DateTime? _lastFetch;
  static const _ttl = Duration(minutes: 15);

  static Future<CountryModules> getCountryModules(String countryCode,
      {bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cache.containsKey(countryCode) &&
        _lastFetch != null &&
        now.difference(_lastFetch!) < _ttl) {
      return _cache[countryCode]!;
    }
    try {
      final base = CountryService.instance.baseUrl;
      final uri = Uri.parse('$base/api/country-modules/public/$countryCode');
      if (kDebugMode) print('Fetching modules for $countryCode -> $uri');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body) as Map<String, dynamic>;
        final raw = (decoded['modules'] as Map?)?.cast<String, dynamic>() ?? {};
        final mapped = raw
            .map((k, v) => MapEntry(k.toString(), v is bool ? v : (v == true)));
        final cm = CountryModules(mapped);
        _cache[countryCode] = cm;
        _lastFetch = now;
        if (kDebugMode) print('Modules loaded: $mapped');
        return cm;
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } catch (e) {
      if (kDebugMode)
        print('Module fetch failed ($e); using fallback defaults');
      // Fallback defaults (all true enables legacy behavior)
      final fallback = CountryModules({
        'ride': true,
        'delivery': true,
        'item': true,
        'service': true,
        'rent': true,
        'price': true,
      });
      _cache[countryCode] = fallback;
      return fallback;
    }
  }
}
