class ModuleFieldLocalizer {
  // Minimal i18n-ready mapping; defaults to English
  static const Map<String, Map<String, String>> _labels = {
    'en': {
      'peopleCount': 'People Count',
      'durationDays': 'Duration (days)',
      'needsGuide': 'Needs Guide',
      'pickupRequired': 'Pickup Required',
      'guestsCount': 'Guests Count',
      'areaSizeSqft': 'Area Size (sqft)',
      'level': 'Level',
      'sessionsPerWeek': 'Sessions/Week',
      'positionType': 'Position Type',
      'experienceYears': 'Experience (years)',
    },
    // Add more locales here when needed, e.g., 'si', 'ta'
  };

  static String getLabel(String key, {String locale = 'en'}) {
    final map = _labels[locale] ?? _labels['en']!;
    final direct = map[key];
    if (direct != null) return direct;
    // Fallback: make a title-cased label from the key
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
