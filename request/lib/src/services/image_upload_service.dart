import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../utils/image_url_helper.dart';
import 'package:http_parser/http_parser.dart';

class ImageUploadService {
  final ImagePicker _picker = ImagePicker();

  // Get the base URL for the API (same logic as ImageUrlHelper)
  // Optionally override via --dart-define=API_HOST=http://192.168.1.50:3001
  static const String _apiHostOverride = String.fromEnvironment('API_HOST');
  static String get _baseUrl {
    if (_apiHostOverride.isNotEmpty) return _apiHostOverride;
    if (kIsWeb) return 'https://api.alphabet.lk';
    if (Platform.isAndroid) return 'https://api.alphabet.lk';
    if (Platform.isIOS) return 'https://api.alphabet.lk';
    return 'https://api.alphabet.lk';
  }

  Future<List<XFile>?> pickMultipleImages({int maxImages = 5}) async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.length > maxImages) {
        return images.take(maxImages).toList();
      }
      return images;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadImage(XFile file, String uploadPath) async {
    try {
      if (kDebugMode) {
        print('🖼️ [ImageUpload] Starting upload to: $_baseUrl/api/upload');
        print('🖼️ [ImageUpload] File: ${file.path}');
        print('🖼️ [ImageUpload] Upload path: $uploadPath');
      }

      final bytes = await file.readAsBytes();
      final fileName = path.basename(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${timestamp}_$fileName';

      // Create multipart request
      final uri = Uri.parse('$_baseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add file
      // Determine mime type (simple extension-based mapping)
      final ext = path.extension(fileName).toLowerCase();
      MediaType? mediaType;
      switch (ext) {
        case '.jpg':
        case '.jpeg':
          mediaType = MediaType('image', 'jpeg');
          break;
        case '.png':
          mediaType = MediaType('image', 'png');
          break;
        case '.gif':
          mediaType = MediaType('image', 'gif');
          break;
        case '.webp':
          mediaType = MediaType('image', 'webp');
          break;
        case '.bmp':
          mediaType = MediaType('image', 'bmp');
          break;
        case '.heic':
        case '.heif':
          mediaType = MediaType('image', 'heic');
          break;
        default:
          mediaType = MediaType('application', 'octet-stream');
      }

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: uniqueFileName,
        contentType: mediaType,
      ));

      // Add upload path
      request.fields['path'] = uploadPath;

      if (kDebugMode) {
        print('🖼️ [ImageUpload] Sending request to: ${uri.toString()}');
      }

      final response =
          await request.send().timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('🖼️ [ImageUpload] Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        if (kDebugMode) {
          print('🖼️ [ImageUpload] Raw success body: $responseBody');
        }
        try {
          final data = jsonDecode(responseBody);
          dynamic extracted;
          if (data is Map) {
            // Support multiple shapes
            if (data['url'] != null)
              extracted = data['url'];
            else if (data['data'] is Map && data['data']['url'] != null)
              extracted = data['data']['url'];
          }
          if (extracted is String) {
            final cleaned = extracted.trim();
            if (kDebugMode) {
              print(
                  '🖼️ [ImageUpload] Upload successful URL (cleaned): $cleaned');
            }
            if (cleaned.startsWith('http')) {
              return cleaned;
            } else {
              if (kDebugMode) {
                print('⚠️ [ImageUpload] Returned URL not absolute: "$cleaned"');
              }
              // Attempt to convert relative path
              if (cleaned.startsWith('/uploads')) {
                return _baseUrl + cleaned; // ensure absolute
              }
            }
          } else {
            if (kDebugMode) {
              print(
                  '⚠️ [ImageUpload] Could not extract URL from response JSON');
            }
          }
        } catch (parseErr) {
          if (kDebugMode) {
            print('⚠️ [ImageUpload] JSON parse error: $parseErr');
          }
        }
        return null; // fallthrough if not extracted
      } else {
        final responseBody = await response.stream.bytesToString();
        if (kDebugMode) {
          print(
              '🖼️ [ImageUpload] Upload failed with status: ${response.statusCode}');
          print('🖼️ [ImageUpload] Response body: $responseBody');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('🖼️ [ImageUpload] Error uploading image: $e');
        try {
          // Quick connectivity probe
          final probe = await http.get(Uri.parse('$_baseUrl/api/ping'));
          print(
              '🖼️ [ImageUpload] Ping status: ${probe.statusCode} body: ${probe.body}');
        } catch (probeError) {
          print('🖼️ [ImageUpload] Ping failed: $probeError');
        }
        print('🖼️ [ImageUpload] Falling back to local file path');
      }
      // Fallback to local file path for development
      return 'file://${file.path}';
    }
  }

  Future<void> deleteImage(String url) async {
    try {
      if (url.startsWith('http')) {
        await http.delete(
          Uri.parse('$_baseUrl/api/upload'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': url}),
        );
      }
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  /// Process a list of image paths/URLs and ensure they're all server URLs
  /// Local file paths will be uploaded, server URLs will be returned as-is
  Future<List<String>> processImageUrls(List<String> imageUrls) async {
    final List<String> processedUrls = [];

    for (final url in imageUrls) {
      if (ImageUrlHelper.isLocalFilePath(url)) {
        // This is a local file, try to upload it
        if (kDebugMode) {
          print('🖼️ [ImageUpload] Processing local file: $url');
        }

        try {
          final file = File(url.replaceFirst('file://', ''));
          if (await file.exists()) {
            // Convert File to XFile for upload
            final xFile = XFile(file.path);
            final uploadedUrl = await uploadImage(xFile, 'images');
            if (uploadedUrl != null && !uploadedUrl.startsWith('file://')) {
              processedUrls.add(uploadedUrl);
            } else {
              if (kDebugMode) {
                print('⚠️ [ImageUpload] Failed to upload local file: $url');
              }
            }
          } else {
            if (kDebugMode) {
              print('⚠️ [ImageUpload] Local file does not exist: $url');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ [ImageUpload] Error processing local file $url: $e');
          }
        }
      } else if (ImageUrlHelper.isPlaceholderUrl(url)) {
        // Skip placeholder URLs
        if (kDebugMode) {
          print('🖼️ [ImageUpload] Skipping placeholder URL: $url');
        }
      } else {
        // This is already a server URL or valid external URL
        processedUrls.add(ImageUrlHelper.getFullImageUrl(url));
      }
    }

    return processedUrls;
  }
}
