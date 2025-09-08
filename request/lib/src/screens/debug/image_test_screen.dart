import 'package:flutter/material.dart';
import '../../utils/image_url_helper.dart';

/// Debug screen to test image loading functionality
class ImageTestScreen extends StatefulWidget {
  const ImageTestScreen({super.key});

  @override
  State<ImageTestScreen> createState() => _ImageTestScreenState();
}

class _ImageTestScreenState extends State<ImageTestScreen> {
  final List<String> testUrls = [
    // Test different URL formats that might come from the backend
    'test.txt',
    '/uploads/images/test.txt',
    'uploads/images/test.txt',
    'http://api.alphabet.lk/uploads/images/test.html',
    'test.html',
    '/uploads/images/test.html',

    // These would be actual image URLs in a real scenario
    'sample-image.jpg',
    '/uploads/images/sample-image.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🖼️ Image Loading Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Base URL info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔧 Configuration',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Base URL: ${ImageUrlHelper.baseUrl}'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _testBaseUrl(),
                      child: const Text('Test Base URL'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // URL transformation tests
            const Text(
              '🔄 URL Transformation Tests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: testUrls.length,
                itemBuilder: (context, index) =>
                    _buildUrlTestCard(testUrls[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlTestCard(String originalUrl) {
    final fullUrl = ImageUrlHelper.getFullImageUrl(originalUrl);
    final isValid = ImageUrlHelper.isValidImageUrl(fullUrl);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.error,
                  color: isValid ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Original:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              originalUrl,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Transformed:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              fullUrl,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: isValid ? Colors.green[700] : Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _testUrl(fullUrl),
                  child: const Text('Test URL'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _debugUrl(originalUrl),
                  child: const Text('Debug'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _testBaseUrl() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔧 Base URL Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Base URL: ${ImageUrlHelper.baseUrl}'),
            const SizedBox(height: 16),
            const Text('This should match your backend server address:'),
            const Text('• Web: http://localhost:3001'),
            const Text('• Android: http://10.0.2.2:3001'),
            const Text('• iOS: http://localhost:3001'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _testUrl(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔗 URL Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Testing URL: $url'),
            const SizedBox(height: 16),
            const Text('Attempting to load...'),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.red[100],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(height: 4),
                      Text(
                        'Failed to load',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _debugUrl(String originalUrl) {
    ImageUrlHelper.debugImageUrl(originalUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🐛 Debug info printed to console'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
