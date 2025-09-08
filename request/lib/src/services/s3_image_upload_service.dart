import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'api_client.dart';

class S3ImageUploadService {
  // Get the base URL for the API
  static const String _apiHostOverride = String.fromEnvironment('API_HOST');
  static String get _baseUrl {
    if (_apiHostOverride.isNotEmpty) return _apiHostOverride;
    if (kIsWeb) return 'https://api.alphabet.lk';
    if (Platform.isAndroid) return 'https://api.alphabet.lk';
    if (Platform.isIOS) return 'https://api.alphabet.lk';
    return 'https://api.alphabet.lk';
  }

  /// Get signed URL for S3 object
  static Future<String?> getSignedUrlForKey(String s3Key) async {
    try {
      // Convert S3 key to full URL format expected by backend
      final fullUrl = 'https://requestappbucket.s3.amazonaws.com/$s3Key';

      final response = await ApiClient.instance.post<dynamic>(
        '/api/s3/signed-url',
        data: {'url': fullUrl},
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['signedUrl'] != null) {
          return data['signedUrl'] as String;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [S3Service] Error getting signed URL for $s3Key: $e');
      }
      return null;
    }
  }

  /// Upload image to S3 using the backend S3 service
  Future<String?> uploadImageToS3(XFile file, String uploadType,
      {String? userId}) async {
    try {
      if (kDebugMode) {
        print('🖼️ [S3Upload] Starting S3 upload to: $_baseUrl/api/s3/upload');
        print('🖼️ [S3Upload] File: ${file.path}');
        print('🖼️ [S3Upload] Upload type: $uploadType');
        print('🖼️ [S3Upload] User ID: $userId');
      }

      final bytes = await file.readAsBytes();

      // Create multipart request for S3 upload
      final uri = Uri.parse('$_baseUrl/api/s3/upload');
      final request = http.MultipartRequest('POST', uri);

      // Determine mime type
      final ext = file.path.toLowerCase().split('.').last;
      MediaType mediaType;
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          mediaType = MediaType('image', 'jpeg');
          break;
        case 'png':
          mediaType = MediaType('image', 'png');
          break;
        case 'gif':
          mediaType = MediaType('image', 'gif');
          break;
        case 'webp':
          mediaType = MediaType('image', 'webp');
          break;
        case 'bmp':
          mediaType = MediaType('image', 'bmp');
          break;
        case 'heic':
        case 'heif':
          mediaType = MediaType('image', 'heic');
          break;
        default:
          mediaType = MediaType('application', 'octet-stream');
      }

      // Add file to request
      request.files.add(http.MultipartFile.fromBytes(
        'file', // S3 service expects 'file' field name
        bytes,
        filename: file.name,
        contentType: mediaType,
      ));

      // Add metadata fields
      request.fields['uploadType'] = uploadType;
      if (userId != null) {
        request.fields['userId'] = userId;
      }

      // Add authentication header
      final token = await ApiClient.instance.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (kDebugMode) {
        print('🖼️ [S3Upload] Sending request to: ${uri.toString()}');
      }

      final response =
          await request.send().timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('🖼️ [S3Upload] Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        if (kDebugMode) {
          print('🖼️ [S3Upload] Success response: $responseBody');
        }

        try {
          final data = jsonDecode(responseBody);
          if (data['success'] == true && data['url'] != null) {
            final s3Url = data['url'] as String;
            if (kDebugMode) {
              print('🖼️ [S3Upload] Upload successful, S3 URL: $s3Url');
            }
            return s3Url;
          } else {
            if (kDebugMode) {
              print(
                  '⚠️ [S3Upload] Upload failed: ${data['error'] ?? 'Unknown error'}');
            }
            return null;
          }
        } catch (parseErr) {
          if (kDebugMode) {
            print('⚠️ [S3Upload] JSON parse error: $parseErr');
          }
          return null;
        }
      } else {
        final responseBody = await response.stream.bytesToString();
        if (kDebugMode) {
          print(
              '🖼️ [S3Upload] Upload failed with status: ${response.statusCode}');
          print('🖼️ [S3Upload] Response body: $responseBody');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('🖼️ [S3Upload] Error uploading to S3: $e');
      }
      return null;
    }
  }

  /// Delete image from S3
  Future<bool> deleteImageFromS3(String imageUrl) async {
    try {
      if (kDebugMode) {
        print('🗑️ [S3Delete] Deleting image: $imageUrl');
      }

      final uri = Uri.parse('$_baseUrl/api/s3/delete');

      // Get authentication token
      final token = await ApiClient.instance.getToken();
      final headers = {'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .delete(
            uri,
            headers: headers,
            body: jsonEncode({'url': imageUrl}),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('🗑️ [S3Delete] Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🗑️ [S3Delete] Error deleting from S3: $e');
      }
      return false;
    }
  }

  /// Get signed URL for private S3 objects (if needed)
  Future<String?> getSignedUrl(String s3Key) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/s3/signed-url');

      // Get authentication token
      final token = await ApiClient.instance.getToken();
      final headers = {'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'key': s3Key}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['signedUrl'] as String?;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('🔗 [S3SignedUrl] Error getting signed URL: $e');
      }
      return null;
    }
  }
}
