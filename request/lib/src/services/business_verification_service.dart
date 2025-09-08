import 'api_client.dart';

class BusinessVerification {
  final String id;
  final String userId;
  final String businessName;
  final String businessEmail;
  final String businessPhone;
  final String businessAddress;
  final String businessCategory;
  final String businessDescription;
  final bool isVerified;
  final String countryCode;
  final String? businessLogoUrl;

  BusinessVerification({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.businessEmail,
    required this.businessPhone,
    required this.businessAddress,
    required this.businessCategory,
    required this.businessDescription,
    required this.isVerified,
    required this.countryCode,
    this.businessLogoUrl,
  });

  factory BusinessVerification.fromJson(Map<String, dynamic> json) {
    return BusinessVerification(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      businessName:
          (json['business_name'] ?? json['businessName'] ?? '').toString(),
      businessEmail:
          (json['business_email'] ?? json['businessEmail'] ?? '').toString(),
      businessPhone:
          (json['business_phone'] ?? json['businessPhone'] ?? '').toString(),
      businessAddress:
          (json['business_address'] ?? json['businessAddress'] ?? '')
              .toString(),
      businessCategory:
          (json['business_category'] ?? json['businessCategory'] ?? 'general')
              .toString(),
      businessDescription:
          (json['business_description'] ?? json['businessDescription'] ?? '')
              .toString(),
      isVerified: (json['is_verified'] ?? json['isVerified'] ?? false) == true,
      countryCode: (json['country'] ?? json['countryCode'] ?? '').toString(),
      businessLogoUrl:
          (json['business_logo_url'] ?? json['businessLogoUrl'])?.toString(),
    );
  }
}

class BusinessVerificationService {
  static final _api = ApiClient.instance;

  static Future<BusinessVerification?> getForUser(String userId) async {
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/business-verifications/user/$userId',
    );
    if (!resp.isSuccess || resp.data == null) return null;
    final map = resp.data!['data'] as Map<String, dynamic>?;
    if (map == null) return null;
    return BusinessVerification.fromJson(map);
  }
}
