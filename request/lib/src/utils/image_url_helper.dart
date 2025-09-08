import 'dart:io';
import 'package:flutter/foundation.dart';

/// Helper class for constructing proper image URLs
class ImageUrlHelper {
  // Get the base URL for the API
  static String get _baseUrl {
    if (kIsWeb) {
      return 'https://api.alphabet.lk'; // Production Web
    } else if (Platform.isAndroid) {
      return 'https://api.alphabet.lk'; // Production Android
    } else if (Platform.isIOS) {
      return 'https://api.alphabet.lk'; // Production iOS
    } else {
      return 'https://api.alphabet.lk'; // Production Desktop/other
    }
  }

  /// Public getter for base URL (for debugging/testing)
  static String get baseUrl => _baseUrl;

  /// Convert a relative or incomplete image URL to a full URL
  static String getFullImageUrl(String imageUrl) {
    // Handle null or empty strings
    if (imageUrl.isEmpty) {
      return getPlaceholderImageUrl();
    }

    // Handle local file paths (Android cache files)
    if (imageUrl.startsWith('file://')) {
      // This is a local file path, should not be converted to server URL
      // Return a placeholder instead since local files can't be served by backend
      if (kDebugMode) {
        print('⚠️ Local file path detected: $imageUrl');
        print(
            '⚠️ Local files cannot be served by backend. Consider uploading to server first.');
      }
      return getPlaceholderImageUrl();
    }

    // Handle example/placeholder URLs that should be replaced
    if (imageUrl.contains('example.com') || imageUrl.contains('placeholder')) {
      if (kDebugMode) {
        print('⚠️ Placeholder/example URL detected: $imageUrl');
      }
      return getPlaceholderImageUrl();
    }

    // If already a full URL, return as-is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // If starts with /uploads, append to base URL
    if (imageUrl.startsWith('/uploads')) {
      return '$_baseUrl$imageUrl';
    }

    // If starts with uploads (no leading slash), append with slash
    if (imageUrl.startsWith('uploads')) {
      return '$_baseUrl/$imageUrl';
    }

    // If just a filename, assume it's in uploads/images
    if (!imageUrl.contains('/')) {
      return '$_baseUrl/uploads/images/$imageUrl';
    }

    // Default: append to base URL with leading slash
    return '$_baseUrl/$imageUrl';
  }

  /// Test if an image URL is accessible
  static bool isValidImageUrl(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Get a placeholder image URL for testing
  static String getPlaceholderImageUrl() {
    return '$_baseUrl/uploads/images/placeholder.jpg';
  }

  /// Check if URL is a local file path
  static bool isLocalFilePath(String url) {
    return url.startsWith('file://') ||
        url.startsWith('/data/') ||
        url.startsWith('/storage/') ||
        url.contains('/cache/');
  }

  /// Check if URL is a placeholder/example URL that should be replaced
  static bool isPlaceholderUrl(String url) {
    return url.contains('example.com') ||
        url.contains('placeholder.com') ||
        url.contains('via.placeholder') ||
        url.isEmpty;
  }

  /// Clean and validate image URL list
  static List<String> cleanImageUrls(List<String>? urls) {
    if (urls == null || urls.isEmpty) return [];

    return urls
        .where((url) => url.isNotEmpty)
        .map((url) => getFullImageUrl(url))
        .where((url) => isValidImageUrl(url))
        .toList();
  }

  /// Debug: Print image URL info
  static void debugImageUrl(String imageUrl) {
    if (kDebugMode) {
      print('🖼️ Original URL: $imageUrl');
      print('🖼️ Is Local File: ${isLocalFilePath(imageUrl)}');
      print('🖼️ Is Placeholder: ${isPlaceholderUrl(imageUrl)}');
      print('🖼️ Full URL: ${getFullImageUrl(imageUrl)}');
      print('🖼️ Valid: ${isValidImageUrl(getFullImageUrl(imageUrl))}');
      print('🖼️ Base URL: $_baseUrl');
    }
  }
}
