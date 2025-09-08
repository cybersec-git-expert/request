import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/glass_theme.dart';

class GlassPage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? appBarBackgroundColor;

  const GlassPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.bottom,
    this.bottomBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.appBarBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        title: Text(title),
        centerTitle: centerTitle,
        backgroundColor: appBarBackgroundColor ?? Colors.transparent,
        elevation: 0,
        foregroundColor: GlassTheme.colors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              GlassTheme.isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              GlassTheme.isDarkMode ? Brightness.dark : Brightness.light,
          // Use a light nav bar color to avoid black strip on some devices
          systemNavigationBarColor: const Color(0xFFF5F5F5),
          systemNavigationBarIconBrightness:
              GlassTheme.isDarkMode ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        actions: actions,
        leading: leading,
        bottom: bottom,
      ),
      body: GlassTheme.backgroundContainer(
        child: SafeArea(
          top: true,
          bottom: true,
          child: body,
        ),
      ),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
