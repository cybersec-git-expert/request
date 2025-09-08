import '../services/country_service.dart';

class CurrencyHelper {
  static CurrencyHelper? _instance;
  static CurrencyHelper get instance => _instance ??= CurrencyHelper._();
  
  CurrencyHelper._();
  
  /// Get the current user's currency code
  String getCurrency() {
    final currency = CountryService.instance.currency;
    return currency ?? 'LKR'; // Default to LKR for Sri Lanka
  }
  
  /// Get the current user's currency symbol
  String getCurrencySymbol() {
    return CountryService.instance.getCurrencySymbol();
  }
  
  /// Get the current user's currency prefix for text fields
  String getCurrencyPrefix() {
    final symbol = getCurrencySymbol();
    return symbol == 'LKR' ? 'LKR ' : '$symbol ';
  }
  
  /// Format a price with the user's currency
  String formatPrice(double amount) {
    return CountryService.instance.formatPrice(amount);
  }
  
  /// Get label text for price fields
  String getPriceLabel([String? context]) {
    final currency = getCurrency();
    if (context != null) {
      return '$context ($currency)';
    }
    return 'Price ($currency)';
  }
  
  /// Get label text for budget fields  
  String getBudgetLabel([String? context]) {
    final currency = getCurrency();
    if (context != null) {
      return '$context ($currency)';
    }
    return 'Budget ($currency)';
  }
}
