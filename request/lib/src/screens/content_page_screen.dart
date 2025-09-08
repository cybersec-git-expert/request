import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/content_service.dart';
import '../theme/glass_theme.dart';
import '../services/api_client.dart';

class ContentPageScreen extends StatefulWidget {
  final String slug;
  final String? title;

  const ContentPageScreen({
    super.key,
    required this.slug,
    this.title,
  });

  @override
  State<ContentPageScreen> createState() => _ContentPageScreenState();
}

class _ContentPageScreenState extends State<ContentPageScreen> {
  final ContentService _contentService = ContentService.instance;
  ContentPage? _page;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final page = await _contentService.getPageBySlug(widget.slug);

      if (mounted) {
        setState(() {
          _page = page;
          _isLoading = false;
          if (page == null) {
            _error = 'Page not found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load page: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.title ?? _page?.title ?? 'Loading...'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: GlassTheme.colors.textPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: GlassTheme.backgroundGradient,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPage,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_page == null) {
      return const Center(
        child: Text('Page not found'),
      );
    }

    return GlassTheme.backgroundContainer(
      child: RefreshIndicator(
        onRefresh: _loadPage,
        color: GlassTheme.colors.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Optional brand/header logo from page metadata
              if (_headerLogoUrl() != null) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Image.network(
                      _headerLogoUrl()!,
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              if (!_contentHasTopHeading(_page!.content))
                GlassTheme.glassCard(
                  subtle: true,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_page!.title, style: GlassTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (_effectiveDateText() != null)
                        Text(
                          'Effective Date: ${_effectiveDateText()!}',
                          style: GlassTheme.bodySmall,
                        )
                      else
                        Text(
                          'Updated on ${_formatDate(_page!.updatedAt)}',
                          style: GlassTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              // If content already has an H1, still show the effective date (if provided)
              if (_contentHasTopHeading(_page!.content) &&
                  _effectiveDateText() != null)
                GlassTheme.glassCard(
                  subtle: true,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Effective Date: ${_effectiveDateText()!}',
                    style: GlassTheme.bodySmall,
                  ),
                ),
              GlassTheme.glassCard(
                subtle: true,
                padding: const EdgeInsets.all(16),
                child: Html(
                  data: _renderedContent(_page!.content),
                  onLinkTap: (url, attributes, element) {
                    if (url != null) _launchUrl(url);
                  },
                  style: {
                    "body": Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      whiteSpace: WhiteSpace.normal,
                      color: GlassTheme.colors.textPrimary,
                    ),
                    "p": Style(
                      fontSize: FontSize(16),
                      lineHeight: const LineHeight(1.7),
                      margin: Margins.only(bottom: 16),
                      textAlign: TextAlign.justify,
                    ),
                    "h1": Style(
                      fontSize: FontSize(24),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(top: 24, bottom: 16),
                      color: GlassTheme.colors.textAccent,
                      textAlign: TextAlign.start,
                    ),
                    "h2": Style(
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(top: 20, bottom: 12),
                      color: GlassTheme.colors.textAccent,
                      textAlign: TextAlign.start,
                    ),
                    "h3": Style(
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(top: 16, bottom: 8),
                      color: GlassTheme.colors.textAccent,
                      textAlign: TextAlign.start,
                    ),
                    "a": Style(
                      color: GlassTheme.colors.textAccent,
                      textDecoration: TextDecoration.underline,
                    ),
                    "ul": Style(
                      margin: Margins.only(bottom: 16),
                      padding: HtmlPaddings.only(left: 16),
                    ),
                    "ol": Style(
                      margin: Margins.only(bottom: 16),
                      padding: HtmlPaddings.only(left: 16),
                    ),
                    "li": Style(margin: Margins.only(bottom: 8)),
                    "blockquote": Style(
                      border: Border(
                        left: BorderSide(
                          color: GlassTheme.colors.textAccent,
                          width: 4,
                        ),
                      ),
                      padding: HtmlPaddings.only(left: 16),
                      margin: Margins.only(bottom: 16),
                      backgroundColor:
                          GlassTheme.colors.glassBackgroundSubtle.first,
                    ),
                    "code": Style(
                      backgroundColor:
                          GlassTheme.colors.glassBackgroundSubtle.last,
                      padding:
                          HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
                      fontFamily: 'monospace',
                    ),
                    "pre": Style(
                      backgroundColor:
                          GlassTheme.colors.glassBackgroundSubtle.last,
                      padding: HtmlPaddings.all(12),
                      margin: Margins.only(bottom: 16),
                      fontFamily: 'monospace',
                    ),
                  },
                ),
              ),
              if (_shouldShowMetadata()) ...[
                const SizedBox(height: 16),
                _buildMetadata(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Only show metadata if explicitly enabled via metadata.showMeta == true
  bool _shouldShowMetadata() {
    final m = _page?.metadata;
    if (m == null) return false;
    final v = m['showMeta'];
    return v == true || v == 'true';
  }

  // Detect if content already includes a top-level heading, to avoid duplicate title
  bool _contentHasTopHeading(String content) {
    final lc = content.toLowerCase();
    return RegExp(r"<h1[\s>]").hasMatch(lc);
  }

  // If the content isn't HTML, convert newlines to <br/> so it's displayed correctly
  String _renderedContent(String content) {
    final looksLikeHtml = RegExp(r"<[a-zA-Z][^>]*>").hasMatch(content);
    if (looksLikeHtml) return content;
    return content.replaceAll('\n', '<br/>');
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildMetadata() {
    if (_page?.metadata == null) return const SizedBox.shrink();

    final metadata = _page!.metadata!;

    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(12),
      subtle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: GlassTheme.colors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Page Information',
                style: GlassTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: GlassTheme.colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...metadata.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: GlassTheme.bodySmall.copyWith(
                  color: GlassTheme.colors.textSecondary,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  String? _effectiveDateText() {
    final meta = _page?.metadata;
    if (meta == null) return null;
    final candidates = [
      'effectiveDate',
      'effective_date',
      'effectiveDateDisplay',
      'effective_date_display',
    ];
    for (final k in candidates) {
      final v = meta[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  String? _headerLogoUrl() {
    final meta = _page?.metadata;
    if (meta == null) return null;
    final candidates = [
      'headerLogoUrl',
      'logoUrl',
      'brandLogoUrl',
      'logo',
    ];
    for (final k in candidates) {
      final v = meta[k];
      if (v is String && v.trim().isNotEmpty) return _absoluteUrl(v.trim());
    }
    return null;
  }

  String _absoluteUrl(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('/')) return '${ApiClient.baseUrlPublic}$u';
    return u; // leave as-is if already absolute-like
  }
}
