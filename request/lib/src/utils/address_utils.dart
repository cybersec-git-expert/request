class AddressUtils {
  /// Clean address by removing location codes (Plus Codes) that start with alphanumeric patterns
  /// Examples: "8JF7+2MG, Kondadeniya Rd, ..." -> "Kondadeniya Rd, ..."
  static String cleanAddress(String address) {
    if (address.isEmpty) return address;
    
    // Remove Plus Code patterns (e.g., "8JF7+2MG", "ABCD+123")
    // Plus codes are typically alphanumeric codes followed by a comma
    final plusCodeRegex = RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,3},?\s*');
    String cleanedAddress = address.replaceFirst(plusCodeRegex, '').trim();
    
    // Also handle longer Plus Codes like "8JF7+2MG Kondadeniya" without comma
    final plusCodeRegex2 = RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,3}\s+');
    cleanedAddress = cleanedAddress.replaceFirst(plusCodeRegex2, '').trim();
    
    // Remove any leading commas that might be left
    cleanedAddress = cleanedAddress.replaceFirst(RegExp(r'^,\s*'), '').trim();
    
    return cleanedAddress.isEmpty ? address : cleanedAddress;
  }
  
  /// Get a short version of the address (first part before comma)
  static String getShortAddress(String address) {
    final cleaned = cleanAddress(address);
    final parts = cleaned.split(',');
    return parts.isNotEmpty ? parts[0].trim() : cleaned;
  }
}
