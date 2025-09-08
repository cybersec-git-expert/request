import 'package:flutter/material.dart';

class CustomLogo extends StatelessWidget {
  final double size;
  final String assetPath;

  const CustomLogo({
    Key? key,
    this.size = 120,
    this.assetPath = 'assets/images/app_logo.png',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Debug: Print the error to console
          print('Logo loading error: $error');

          // Fallback to a simple container with text for debugging
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.25),
              gradient: const LinearGradient(
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
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.north_rounded,
                    color: Colors.white,
                    size: size * 0.4,
                    weight: 700,
                  ),
                  if (size > 80) // Only show text for larger logos
                    Text(
                      'FALLBACK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.08,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Named constructors for different sizes/uses
  // Welcome screen logo (replace the asset with your welcome logo file)
  static CustomLogo large() => const CustomLogo(
        size: 120,
        assetPath: 'assets/images/logo_welcome.png',
      );

  static CustomLogo medium() => const CustomLogo(size: 80);
  static CustomLogo small() => const CustomLogo(size: 40);

  // Splash screen logo (replace the asset with your splash logo file)
  static CustomLogo splash() => const CustomLogo(
        size: 150,
        assetPath: 'assets/images/logo_splash.png',
      );
}
