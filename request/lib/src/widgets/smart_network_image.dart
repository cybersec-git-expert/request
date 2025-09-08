import 'package:flutter/material.dart';
import '../services/image_url_service.dart';

/// A widget that displays images with automatic AWS S3 signed URL support
class SmartNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget? placeholder;

  const SmartNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.placeholder,
  });

  @override
  State<SmartNetworkImage> createState() => _SmartNetworkImageState();
}

class _SmartNetworkImageState extends State<SmartNetworkImage> {
  String? _processedUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _processImageUrl();
  }

  @override
  void didUpdateWidget(SmartNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _processImageUrl();
    }
  }

  Future<void> _processImageUrl() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final processedUrl =
          await ImageUrlService.instance.processImageUrl(widget.imageUrl);
      if (mounted) {
        setState(() {
          _processedUrl = processedUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error processing image URL ${widget.imageUrl}: $e');
      if (mounted) {
        setState(() {
          _processedUrl = widget.imageUrl; // Fallback to original URL
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.shade100,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    if (_processedUrl == null) {
      return widget.errorBuilder?.call(context, 'No processed URL', null) ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.shade200,
            child: const Icon(Icons.error, color: Colors.grey),
          );
    }

    return Image.network(
      _processedUrl!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: widget.errorBuilder ??
          (context, error, stackTrace) {
            print('Network image error for ${_processedUrl}: $error');
            return Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
    );
  }
}
