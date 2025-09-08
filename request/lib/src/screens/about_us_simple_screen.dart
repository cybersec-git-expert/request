import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import '../services/content_service.dart';
import '../services/api_client.dart';
import 'content_page_screen.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../theme/glass_theme.dart';

class AboutUsSimpleScreen extends StatefulWidget {
  const AboutUsSimpleScreen({super.key});

  @override
  State<AboutUsSimpleScreen> createState() => _AboutUsSimpleScreenState();
}

class _AboutUsSimpleScreenState extends State<AboutUsSimpleScreen> {
  final ContentService _contentService = ContentService.instance;
  List<ContentPage> _pages = [];
  bool _loading = true;
  String? _appVersion;
  String? _resolvedLogoUrl;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    try {
      // Add timeout to prevent hanging
      await Future.any([
        _loadPagesInternal(),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException('Content loading timed out after 10 seconds');
        }),
      ]);
    } catch (e) {
      print('Error loading About Us content: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _pages = []; // Set empty pages so UI shows fallback content
        });
      }
    }
  }

  Future<void> _loadPagesInternal() async {
    // Prefer published pages; if none, fall back to approved so global
    // admin content is visible prior to publishing.
    var pages = await _contentService.getPages(status: 'published');
    if (pages.isEmpty) {
      final approved = await _contentService.getPages(status: 'approved');
      if (approved.isNotEmpty) pages = approved;
    }
    // Resolve a displayable logo URL from the freshly fetched pages
    final rawLogo = _getMetaFromPages<String>(pages, 'logoUrl');
    String? logoToUse;
    if (rawLogo != null && rawLogo.isNotEmpty) {
      logoToUse = await _resolveDisplayUrl(rawLogo);
    }
    if (mounted) {
      setState(() {
        _pages = pages;
        _loading = false;
        _resolvedLogoUrl = logoToUse ?? rawLogo;
      });
    }
  }

  // Minimal API base resolver mirroring ContentService logic
  String get _apiBaseUrl {
    if (kIsWeb) return 'https://api.alphabet.lk';
    if (Platform.isAndroid) return 'https://api.alphabet.lk';
    return 'https://api.alphabet.lk';
  }

  Future<String?> _resolveDisplayUrl(String url) async {
    try {
      final lower = url.toLowerCase();
      final isS3 = lower.contains('amazonaws.com') || lower.contains('.s3.');
      final alreadySigned = lower.contains('x-amz-signature');
      if (!isS3 || alreadySigned) return url;
      final token = await ApiClient.instance.getToken();
      final resp = await http.post(
        Uri.parse('$_apiBaseUrl/api/s3/signed-url'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: '{"url":"${url.replaceAll('"', '\\"')}"}',
      );
      if (resp.statusCode == 200) {
        final data = convert.jsonDecode(resp.body) as Map<String, dynamic>;
        final signed = (data['signedUrl'] as String?)?.trim();
        if (signed != null && signed.isNotEmpty) return signed;
      }
    } catch (_) {}
    return url; // fallback to original
  }

  ContentPage? _findPageByKeywords(List<String> keywords) {
    // Prefer published, country_specific matches first, then any published, then any
    bool matches(ContentPage p) {
      final title = p.title.toLowerCase();
      final cat = (p.category ?? '').toLowerCase();
      return keywords.any((k) => title.contains(k) || cat.contains(k));
    }

    // 1) published + country_specific
    final pubCountry = _pages.where((p) =>
        p.status == 'published' && p.type == 'country_specific' && matches(p));
    if (pubCountry.isNotEmpty) return pubCountry.first;

    // 2) published (any type)
    final published =
        _pages.where((p) => p.status == 'published' && matches(p));
    if (published.isNotEmpty) return published.first;

    // 3) any status (fallback)
    for (final p in _pages) {
      if (matches(p)) return p;
    }
    return null;
  }

  Future<void> _openPreferredPage({
    required List<String> preferredSlugs,
    required List<String> keywordsFallback,
    required String defaultSlug,
    required String defaultTitle,
  }) async {
    // Try preferred slugs via service to ensure we get the published, country-specific page
    for (final slug in preferredSlugs) {
      try {
        final page = await _contentService.getPageBySlug(slug);
        if (page != null) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentPageScreen(slug: slug, title: page.title),
            ),
          );
          return;
        }
      } catch (_) {}
    }

    // Fallback to keyword search within already-fetched pages
    final preferred = _findPageByKeywords(keywordsFallback);
    if (preferred != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContentPageScreen(
            slug: preferred.slug,
            title: preferred.title,
          ),
        ),
      );
      return;
    }

    // Final fallback to default template slug
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ContentPageScreen(slug: defaultSlug, title: defaultTitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? aboutTextFallback() {
      // Use metadata.aboutText when available, otherwise use the content
      // body of the About Us page (plain text fallback).
      final metaText = _getMeta<String>('aboutText');
      if (metaText != null && metaText.trim().isNotEmpty) return metaText;
      final aboutPage = _findPageByKeywords(['about', 'company']);
      if (aboutPage != null) {
        final body = aboutPage.content.trim();
        if (body.isNotEmpty) return body;
      }
      return null;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('About Us'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: GlassTheme.colors.textPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: GlassTheme.backgroundGradient,
        ),
      ),
      body: GlassTheme.backgroundContainer(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pages.isEmpty
                ? _buildFallbackContent()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header logo + title (optional via metadata.logoUrl)
                      if ((_resolvedLogoUrl ?? _getMeta<String>('logoUrl'))
                              ?.isNotEmpty ==
                          true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Center(
                                child: Image.network(
                                  _resolvedLogoUrl ??
                                      _getMeta<String>('logoUrl')!,
                                  height: 72,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stack) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Request', style: GlassTheme.titleSmall),
                            ],
                          ),
                        ),

                      // About text (metadata or page content fallback)
                      if (aboutTextFallback()?.isNotEmpty == true)
                        _sectionCard(
                          child: Text(
                            aboutTextFallback()!,
                            style: GlassTheme.bodyLarge,
                          ),
                        ),

                      // Address
                      if (_getMeta<String>('hqTitle') != null ||
                          _getMeta<String>('hqAddress') != null)
                        _sectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_getMeta<String>('hqTitle')?.isNotEmpty ==
                                  true)
                                Text(_getMeta<String>('hqTitle')!,
                                    style: GlassTheme.titleSmall),
                              if (_getMeta<String>('hqAddress')?.isNotEmpty ==
                                  true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(_getMeta<String>('hqAddress')!,
                                      style: GlassTheme.bodyLarge),
                                ),
                            ],
                          ),
                        ),

                      // Support numbers row
                      if (_getMeta<String>('supportPassenger')?.isNotEmpty ==
                              true ||
                          _getMeta<String>('hotline')?.isNotEmpty == true)
                        _sectionCard(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _contactColumn('Support - Passenger',
                                  _getMeta<String>('supportPassenger')),
                              _contactColumn(
                                  'Hotline', _getMeta<String>('hotline')),
                            ],
                          ),
                        ),

                      // Website link
                      if (_getMeta<String>('websiteUrl')?.isNotEmpty == true)
                        _sectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Website', style: GlassTheme.titleSmall),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () =>
                                    _launchUrl(_getMeta<String>('websiteUrl')!),
                                child: Text(
                                  _getMeta<String>('websiteUrl')!,
                                  style: GlassTheme.accent,
                                ),
                              )
                            ],
                          ),
                        ),

                      // Feedback blurb
                      if (_getMeta<String>('feedbackText')?.isNotEmpty == true)
                        _sectionCard(
                          child: Text(_getMeta<String>('feedbackText')!,
                              style: GlassTheme.bodyLarge),
                        ),

                      // Legal and Privacy links
                      _sectionCard(
                        child: Column(
                          children: [
                            _tile(
                              icon: Icons.gavel_outlined,
                              title: 'Legal',
                              onTap: () {
                                _openPreferredPage(
                                  preferredSlugs: const [
                                    'legal',
                                    'terms-conditions'
                                  ],
                                  keywordsFallback: const [
                                    'terms',
                                    'legal',
                                    'conditions'
                                  ],
                                  defaultSlug: 'terms-conditions',
                                  defaultTitle: 'Terms & Conditions',
                                );
                              },
                            ),
                            _divider(),
                            _tile(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              onTap: () {
                                _openPreferredPage(
                                  preferredSlugs: const [
                                    'privacy-policy-central',
                                    'privacy-policy'
                                  ],
                                  keywordsFallback: const ['privacy', 'policy'],
                                  defaultSlug: 'privacy-policy',
                                  defaultTitle: 'Privacy Policy',
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Socials row (optional)
                      if (_getMeta<String>('facebookUrl')?.isNotEmpty == true ||
                          _getMeta<String>('xUrl')?.isNotEmpty == true)
                        _sectionCard(
                          child: Row(
                            children: [
                              Text('Follow Us', style: GlassTheme.titleSmall),
                              const SizedBox(width: 12),
                              if (_getMeta<String>('facebookUrl')?.isNotEmpty ==
                                  true)
                                IconButton(
                                  icon: Icon(Icons.facebook,
                                      color: GlassTheme.colors.infoColor),
                                  onPressed: () => _launchUrl(
                                      _getMeta<String>('facebookUrl')!),
                                ),
                              if (_getMeta<String>('xUrl')?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: IconButton(
                                    icon: Icon(Icons.public,
                                        color: GlassTheme.colors.textPrimary),
                                    onPressed: () =>
                                        _launchUrl(_getMeta<String>('xUrl')!),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // App version footer
                      if (_appVersion != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: Text('App version $_appVersion',
                                style: GlassTheme.bodySmall),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.blueGrey, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: Colors.grey[200]);

  // Helpers to build sections from metadata
  T? _getMeta<T>(String key) {
    // Prefer About Us page metadata; else search other pages
    final page = _findPageByKeywords(['about', 'company']);
    final meta = page?.metadata ?? {};
    final v = meta[key];
    if (v is T) return v;
    if (v is String && T == String) return v as T;
    return null;
  }

  // Read metadata from a provided pages list (used before setState updates _pages)
  T? _getMetaFromPages<T>(List<ContentPage> pages, String key) {
    ContentPage? about;
    for (final p in pages) {
      final title = p.title.toLowerCase();
      final cat = (p.category ?? '').toLowerCase();
      if (title.contains('about') ||
          title.contains('company') ||
          cat.contains('about') ||
          cat.contains('company')) {
        about = p;
        break;
      }
    }
    final meta = about?.metadata ?? {};
    final v = meta[key];
    if (v is T) return v;
    if (v is String && T == String) return v as T;
    return null;
  }

  Widget _sectionCard({required Widget child}) {
    return GlassTheme.glassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      subtle: true,
      child: child,
    );
  }

  Widget _contactColumn(String label, String? value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GlassTheme.titleSmall),
          const SizedBox(height: 6),
          if (value != null && value.isNotEmpty)
            InkWell(
              onTap: () => _launchUrl('tel:$value'),
              child: Text(value, style: GlassTheme.accent),
            )
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildFallbackContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // App logo/icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GlassTheme.colors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.info_outline,
              size: 64,
              color: GlassTheme.colors.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),

          // App title
          Text(
            'Request App',
            style: GlassTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: GlassTheme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Default about text
          _sectionCard(
            child: Text(
              'Request App is your comprehensive platform for connecting people with the products and services they need. Whether you\'re looking to buy, sell, rent, or request services, our app makes it easy to find what you\'re looking for in your local area.\n\n'
              'Our mission is to create a seamless marketplace that brings communities together, enabling efficient transactions and fostering local commerce.\n\n'
              'Features include:\n'
              '• Item and service requests\n'
              '• Price comparison\n'
              '• Delivery services\n'
              '• Rental marketplace\n'
              '• Local business directory',
              style: GlassTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 24),

          // Contact info fallback
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact Us', style: GlassTheme.titleMedium),
                const SizedBox(height: 12),
                Text(
                  'For support or inquiries, please contact us through the app or visit our website.',
                  style: GlassTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
