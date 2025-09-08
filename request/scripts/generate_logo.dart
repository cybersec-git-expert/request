import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// This is a script to generate the app logo programmatically
class LogoGenerator {
  static Future<void> generateLogo() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(512, 512);
    
    // Create gradient paint
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF6EC6FF), // Light blue
        Color(0xFF4FC3F7), // Medium blue
        Color(0xFF26C6DA), // Blue-cyan
        Color(0xFF4DD0E1), // Cyan
        Color(0xFF4CAF50), // Green
      ],
      stops: [0.0, 0.3, 0.5, 0.7, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Draw rounded rectangle background
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.25),
    );
    canvas.drawRRect(rect, paint);
    
    // Draw arrow icon
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final arrowSize = size.width * 0.5;
    final arrowOffset = Offset(
      (size.width - arrowSize) / 2,
      (size.height - arrowSize) / 2,
    );
    
    // Create arrow path (pointing up)
    final path = Path();
    final arrowWidth = arrowSize * 0.8;
    final arrowHeight = arrowSize * 0.8;
    final stemWidth = arrowWidth * 0.3;
    
    // Arrow head
    path.moveTo(arrowOffset.dx + arrowSize / 2, arrowOffset.dy);
    path.lineTo(arrowOffset.dx + arrowSize / 2 + arrowWidth / 3, arrowOffset.dy + arrowHeight / 3);
    path.lineTo(arrowOffset.dx + arrowSize / 2 + stemWidth / 2, arrowOffset.dy + arrowHeight / 3);
    
    // Arrow stem
    path.lineTo(arrowOffset.dx + arrowSize / 2 + stemWidth / 2, arrowOffset.dy + arrowHeight);
    path.lineTo(arrowOffset.dx + arrowSize / 2 - stemWidth / 2, arrowOffset.dy + arrowHeight);
    path.lineTo(arrowOffset.dx + arrowSize / 2 - stemWidth / 2, arrowOffset.dy + arrowHeight / 3);
    
    // Complete arrow head
    path.lineTo(arrowOffset.dx + arrowSize / 2 - arrowWidth / 3, arrowOffset.dy + arrowHeight / 3);
    path.close();
    
    canvas.drawPath(path, arrowPaint);
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    
    // Save to assets directory
    final file = File('assets/images/app_logo.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    
    print('Logo generated successfully at: ${file.path}');
  }
}
