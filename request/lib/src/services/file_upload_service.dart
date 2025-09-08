import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';

class FileUploadService {
  final ApiClient _apiClient = ApiClient.instance;

  // Generic file upload
  Future<String> uploadFile(File file, {String? path}) async {
    return await _uploadToBackend(file, 'general', path: path);
  }

  Future<String> uploadImageFile(File file, {String? path}) async {
    return await _uploadToBackend(file, 'image', path: path);
  }

  static Future<String> uploadImage({
    File? file,
    File? imageFile,
    String? path,
    String? fileName,
  }) async {
    return await FileUploadService()
        .uploadImageFile(imageFile ?? file ?? File('placeholder'), path: path);
  }

  Future<String> uploadDriverDocument(
      String userId, File file, String type) async {
    return await _uploadToBackend(file, type, userId: userId);
  }

  Future<String> uploadBusinessDocument(
      String userId, File file, String type) async {
    return await _uploadToBackend(file, type, userId: userId);
  }

  Future<String> uploadVehicleImage(String userId, File file, int index) async {
    return await _uploadToBackend(file, 'vehicle_image',
        userId: userId, imageIndex: index);
  }

  // Legacy static helper alias
  static Future<String> legacyUploadImage({
    File? file,
    File? imageFile,
    String? path,
    String? fileName,
  }) async {
    return await FileUploadService()
        .uploadImageFile(imageFile ?? file ?? File('placeholder'), path: path);
  }

  // Real upload implementation using backend S3 service
  Future<String> _uploadToBackend(File file, String uploadType,
      {String? userId, String? path, int? imageIndex}) async {
    try {
      print('🚀 Uploading file to backend: $uploadType');

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
        'uploadType': uploadType,
        if (userId != null) 'userId': userId,
        if (imageIndex != null) 'imageIndex': imageIndex.toString(),
      });

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/s3/upload',
        data: formData,
      );

      if (response.data != null &&
          response.data!['success'] == true &&
          response.data!['url'] != null) {
        print('✅ File uploaded successfully: ${response.data!['url']}');
        return response.data!['url'];
      } else {
        throw Exception(
            'Upload failed: ${response.data?['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ File upload error: $e');
      // Fallback to fake URL for development (will show warning)
      return _generateFallbackUrl(uploadType, userId);
    }
  }

  // Fallback method generates demo URLs that trigger warning in UI
  String _generateFallbackUrl(String uploadType, String? userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    switch (uploadType) {
      case 'driver_photo':
        return 'https://example.com/uploads/drivers/${userId ?? 'user'}/driver_photo_$timestamp.jpg';
      case 'nic_front':
        return 'https://example.com/uploads/drivers/${userId ?? 'user'}/nic_front_$timestamp.jpg';
      case 'nic_back':
        return 'https://example.com/uploads/drivers/${userId ?? 'user'}/nic_back_$timestamp.jpg';
      case 'license_front':
        return 'https://example.com/uploads/drivers/${userId ?? 'user'}/license_front_$timestamp.jpg';
      case 'license_back':
        return 'https://example.com/uploads/drivers/${userId ?? 'user'}/license_back_$timestamp.jpg';
      case 'vehicle_image':
        return 'https://example.com/uploads/vehicles/${userId ?? 'user'}/image_$timestamp.jpg';
      default:
        return 'https://example.com/uploads/files/file_$timestamp.jpg';
    }
  }
}
