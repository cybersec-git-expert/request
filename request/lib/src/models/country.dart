class Country {
  final String code;
  final String name;
  final String phoneCode; // e.g. "+94"
  final String? flagEmoji; // Computed from code if not provided
  final String? flagUrl; // Server-provided flag URL (optional)
  final bool isEnabled; // true = selectable now
  final String comingSoonMessage; // Shown when disabled

  const Country({
    required this.code,
    required this.name,
    required this.phoneCode,
    this.flagEmoji,
    this.flagUrl,
    this.isEnabled = true,
    this.comingSoonMessage = '',
  });

  /// Fallback flag string for UI (emoji preferred, else placeholder globe)
  String get flag => flagEmoji ?? _countryCodeToEmoji(code) ?? '🌐';

  /// JSON factory mapping backend /api/countries/public response.
  factory Country.fromJson(Map<String, dynamic> json) {
    final String code = _readCountryCode(json);
    final _FlagParts flag = _readFlag(json, code: code);
    return Country(
      code: code,
      name: (json['name'] ?? json['countryName'] ?? '').toString(),
      phoneCode: _readPhoneCode(json),
      flagEmoji: flag.emoji,
      flagUrl: flag.url,
      isEnabled: _computeEnabled(json),
      comingSoonMessage:
          (json['comingSoonMessage'] ?? json['disabledReason'] ?? '') as String,
    );
  }

  static bool _computeEnabled(Map<String, dynamic> json) {
    // Direct booleans
    final dynamic isEnabled = json['isEnabled'] ?? json['enabled'];
    if (isEnabled is bool) return isEnabled;

    final dynamic isActive =
        json['isActive'] ?? json['active'] ?? json['status'];
    if (isActive is bool) return isActive;
    if (isActive is num) return isActive != 0;
    if (isActive is String) {
      final s = isActive.toLowerCase();
      if (s == 'active' || s == 'enabled' || s == 'true' || s == '1')
        return true;
      if (s == 'inactive' || s == 'disabled' || s == 'false' || s == '0')
        return false;
    }

    // If marked comingSoon, consider disabled
    if (json.containsKey('comingSoon')) return json['comingSoon'] != true;

    // Default to enabled if unknown
    return true;
  }

  static String _readPhoneCode(Map<String, dynamic> json) {
    final dynamic raw = json['phoneCode'] ??
        json['phone_prefix'] ??
        json['phonePrefix'] ??
        json['callingCode'] ??
        json['calling_code'] ??
        json['dialCode'] ??
        json['dial_code'];

    String value = (raw ?? '').toString().trim();
    if (value.isEmpty) return value;

    // Normalize to "+<digits>"
    // Remove all non-digit and non-plus first, then ensure single leading '+'
    // If starts with '00', convert to '+'
    value = value.replaceAll(RegExp(r"\s"), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (!value.startsWith('+')) {
      // If it's all digits now, prefix '+'
      final digitsOnly = value.replaceAll(RegExp(r"[^0-9]"), '');
      if (digitsOnly.isNotEmpty && digitsOnly == value) {
        value = '+$value';
      }
    }
    return value;
  }

  static String _readCountryCode(Map<String, dynamic> json) {
    final dynamic raw = json['code'] ??
        json['countryCode'] ??
        json['iso2'] ??
        json['alpha2'] ??
        json['cca2'] ??
        json['country_code'];
    return (raw ?? '').toString().toUpperCase();
  }

  static _FlagParts _readFlag(Map<String, dynamic> json,
      {required String code}) {
    final dynamic explicitEmoji = json['flagEmoji'];
    final dynamic explicitUrl = json['flagUrl'];
    if (explicitEmoji is String && explicitEmoji.trim().isNotEmpty) {
      return _FlagParts(emoji: explicitEmoji.trim());
    }
    if (explicitUrl is String && explicitUrl.trim().isNotEmpty) {
      return _FlagParts(url: explicitUrl.trim());
    }
    // Some payloads may include a generic 'flag' which could be an emoji or a URL
    final dynamic generic = json['flag'];
    if (generic is String && generic.trim().isNotEmpty) {
      final val = generic.trim();
      final isUrl = val.startsWith('http://') ||
          val.startsWith('https://') ||
          val.endsWith('.png') ||
          val.endsWith('.svg') ||
          val.contains('/');
      if (isUrl) return _FlagParts(url: val);
      return _FlagParts(emoji: val);
    }
    // Fallback: compute emoji from code in getter if needed
    return _FlagParts();
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'phoneCode': phoneCode,
        'flagEmoji': flagEmoji,
        'flagUrl': flagUrl,
        'isEnabled': isEnabled,
        'comingSoonMessage': comingSoonMessage,
      };

  Country copyWith({
    String? code,
    String? name,
    String? phoneCode,
    String? flagEmoji,
    String? flagUrl,
    bool? isEnabled,
    String? comingSoonMessage,
  }) =>
      Country(
        code: code ?? this.code,
        name: name ?? this.name,
        phoneCode: phoneCode ?? this.phoneCode,
        flagEmoji: flagEmoji ?? this.flagEmoji,
        flagUrl: flagUrl ?? this.flagUrl,
        isEnabled: isEnabled ?? this.isEnabled,
        comingSoonMessage: comingSoonMessage ?? this.comingSoonMessage,
      );

  static String? _countryCodeToEmoji(String code) {
    if (code.length != 2) return null;
    final int base = 0x1F1E6; // Regional Indicator Symbol Letter A
    final String upper = code.toUpperCase();
    final int first = upper.codeUnitAt(0) - 0x41 + base;
    final int second = upper.codeUnitAt(1) - 0x41 + base;
    if (first < base || second < base) return null;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  @override
  String toString() => '${flag} $name ($phoneCode)';
}

class _FlagParts {
  final String? emoji;
  final String? url;
  const _FlagParts({this.emoji, this.url});
}
