import 'api_client.dart';

/// Service to handle image URLs, especially S3 signed URLs for AWS images
class ImageUrlService {
  ImageUrlService._();
  static final instance = ImageUrlService._();

  /// Get a signed URL for S3 images using AWS API
  Future<String?> getSignedUrl(String s3Url) async {
    try {
      final resp =
          await ApiClient.instance.post<dynamic>('/api/s3/signed-url', data: {
        'url': s3Url,
      });

      if (resp.data is Map && resp.data['success'] == true) {
        return resp.data['signedUrl'] as String?;
      }
    } catch (e) {
      print('Error getting AWS signed URL for $s3Url: $e');
    }
    return null;
  }

  /// Check if URL is an S3 URL that needs signing
  bool isS3Url(String url) {
    return url.contains('requestappbucket.s3') ||
        url.contains('s3.amazonaws.com') ||
        url.contains('.s3.us-east-1.amazonaws.com');
  }

  /// Process image URL - convert S3 URLs to signed URLs, handle localhost URLs
  Future<String> processImageUrl(String imageUrl) async {
    final base = ApiClient.baseUrlPublic;

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // Check if it's an S3 URL that needs signing
      if (isS3Url(imageUrl)) {
        final signedUrl = await getSignedUrl(imageUrl);
        return signedUrl ?? imageUrl; // Use signed URL or fallback to original
      } else if (imageUrl.contains('localhost') ||
          imageUrl.contains('127.0.0.1')) {
        // If the admin saved an absolute URL pointing to localhost/127.0.0.1,
        // rewrite it to use the app's API host so Android emulator/devices can load it.
        try {
          final u = Uri.parse(imageUrl);
          if (u.host == 'localhost' || u.host == '127.0.0.1') {
            final b = Uri.parse(base);
            final rebuilt = Uri(
              scheme: b.scheme,
              host: b.host,
              port: b.port,
              path: u.path.startsWith('/') ? u.path : '/${u.path}',
              query: u.query.isEmpty ? null : u.query,
              fragment: u.fragment.isEmpty ? null : u.fragment,
            );
            return rebuilt.toString();
          } else {
            return imageUrl;
          }
        } catch (_) {
          return imageUrl;
        }
      } else {
        return imageUrl;
      }
    } else {
      // Relative URL - prepend base URL
      return '$base${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
    }
  }

  /// Process multiple image URLs in parallel
  Future<List<String>> processImageUrls(List<String> imageUrls) async {
    final futures = imageUrls.map((url) => processImageUrl(url));
    return await Future.wait(futures);
  }
}
