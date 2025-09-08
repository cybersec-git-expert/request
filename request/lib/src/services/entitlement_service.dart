import 'api_client.dart';

class EntitlementService {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>?> getMyEntitlements() async {
    final res = await _api.get<Map<String, dynamic>>('/api/me/entitlements');
    if (res.isSuccess && res.data != null) {
      return res.data!['data'] as Map<String, dynamic>?;
    }
    return null;
  }
}
