import 'api_client.dart';

/// Fetches role-specific membership benefits from the backend Admin table.
/// Falls back to a sensible local default list if the API is unavailable.
class RoleBenefitsService {
  RoleBenefitsService._();
  static final RoleBenefitsService instance = RoleBenefitsService._();
  final ApiClient _api = ApiClient.instance;

  /// Returns a list of short benefit bullet points for the given role.
  /// role: general | driver | delivery | professional | business | product_seller
  Future<List<String>> fetchRoleBenefits(String role) async {
    try {
      final res = await _api.get<Map<String, dynamic>>(
        '/api/membership/role-benefits',
        queryParameters: {'role': role},
      );
      if (res.isSuccess && res.data != null) {
        final data = res.data!['data'];
        if (data is List) {
          return data.map((e) => e.toString()).toList();
        }
        if (data is Map<String, dynamic>) {
          final list = data['benefits'];
          if (list is List) return list.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {
      // ignore and fall back
    }
    return _fallback(role);
  }

  List<String> _fallback(String role) {
    switch (role) {
      case 'driver':
        return [
          '3 free ride responses per month',
          'Upgrade for unlimited responses',
          'See rider contact details',
          'Instant alerts for nearby rides',
        ];
      case 'delivery':
      case 'business':
      case 'professional':
        return [
          '3 free responses per month',
          'Upgrade for unlimited responses',
          'See customer contact details',
          'Priority placement on matching requests',
          'Chat with customers inside the app',
        ];
      case 'product_seller':
        return [
          'List products with prices',
          'Appear in price comparison',
          'Get customer clicks and leads',
          'Pay per click or monthly plan',
        ];
      case 'general':
      default:
        return [
          '3 free responses per month',
          'Upgrade for unlimited responses',
          'See contact details after upgrade',
          'Smart notifications for matching requests',
        ];
    }
  }
}
