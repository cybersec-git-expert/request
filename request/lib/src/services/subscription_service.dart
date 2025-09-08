import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscription_models.dart';
import 'rest_support_services.dart';
import 'api_client.dart';

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  // Use the same token store as RestAuthService (secure storage via ApiClient)
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, String>> _headers() async {
    final token = await _api.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String get _base => CountryService.instance.baseUrl;

  Future<Capabilities> getCapabilities() async {
    final uri = Uri.parse('$_base/api/flutter/subscriptions/capabilities');
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode != 200) {
      throw Exception('Capabilities failed: HTTP ${resp.statusCode}');
    }
    final data = json.decode(resp.body);
    return Capabilities.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Eligibility> getEligibility(String requestType) async {
    final uri = Uri.parse(
        '$_base/api/flutter/subscriptions/eligibility?request_type=$requestType');
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode != 200) {
      throw Exception('Eligibility failed: HTTP ${resp.statusCode}');
    }
    final data = json.decode(resp.body);
    return Eligibility.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<MembershipInit> membershipInit() async {
    final uri = Uri.parse('$_base/api/flutter/subscriptions/membership-init');
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode != 200) {
      throw Exception('Membership init failed: HTTP ${resp.statusCode}');
    }
    final data = json.decode(resp.body);
    return MembershipInit.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<SubscriptionPlan>> availablePlans() async {
    final uri = Uri.parse('$_base/api/flutter/subscriptions/plans/available');
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode != 200) {
      throw Exception('Plans failed: HTTP ${resp.statusCode}');
    }
    final data = json.decode(resp.body);
    if (data is List) {
      final List<SubscriptionPlan> result = data
          .whereType<Map>()
          .map<SubscriptionPlan>(
              (e) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      return result;
    }
    if (data is Map && data['plans'] is List) {
      final List<SubscriptionPlan> result = (data['plans'] as List)
          .whereType<Map>()
          .map<SubscriptionPlan>(
              (e) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      return result;
    }
    return <SubscriptionPlan>[];
  }

  // Public fallback (no auth required)
  Future<List<SubscriptionPlan>> availablePlansPublic() async {
    final uri = Uri.parse('$_base/api/public/subscriptions/plans/available');
    final resp =
        await http.get(uri, headers: {'Content-Type': 'application/json'});
    if (resp.statusCode != 200) {
      throw Exception('Public plans failed: HTTP ${resp.statusCode}');
    }
    final data = json.decode(resp.body);
    final list = (data is List)
        ? data
        : (data is Map && data['plans'] is List ? data['plans'] : []);
    final List<SubscriptionPlan> result = list
        .whereType<Map>()
        .map<SubscriptionPlan>(
            (e) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    return result;
  }
}

// Update registration type (role)
extension SubscriptionMutations on SubscriptionService {
  Future<bool> updateRegistrationType(String registrationType) async {
    final uri =
        Uri.parse('$_base/api/flutter/subscriptions/update-registration-type');
    final resp = await http.post(
      uri,
      headers: await _headers(),
      body: json.encode({'registration_type': registrationType}),
    );
    return resp.statusCode == 200;
  }
}
