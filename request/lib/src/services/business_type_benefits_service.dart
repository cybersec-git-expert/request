class BusinessTypeBenefitsService {
  // Disabled. Keep signature compatibility and return harmless defaults.

  static Future<Map<String, dynamic>?> getBusinessTypeBenefits(
      int countryId) async {
    return {'success': true, 'businessTypeBenefits': {}};
  }

  static Future<bool> updateBusinessTypeBenefits({
    required int countryId,
    required int businessTypeId,
    required String planType,
    int? responsesPerMonth,
    bool? contactRevealed,
    bool? canMessageRequester,
    bool? respondButtonEnabled,
    bool? instantNotifications,
    bool? priorityInSearch,
  }) async {
    return false; // disabled
  }
}
