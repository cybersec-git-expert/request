import 'package:flutter/material.dart';
import '../services/content_service.dart';

class ContentTestScreen extends StatefulWidget {
  const ContentTestScreen({super.key});

  @override
  State<ContentTestScreen> createState() => _ContentTestScreenState();
}

class _ContentTestScreenState extends State<ContentTestScreen> {
  final ContentService _contentService = ContentService.instance;
  List<ContentPage> _pages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final pages = await _contentService.getPages();

      if (mounted) {
        setState(() {
          _pages = pages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Pages Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPages,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading content pages...'),
          ],
        ),
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
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading pages:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No content pages found',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Group pages by category
    final pagesByCategory = <String, List<ContentPage>>{};
    for (final page in _pages) {
      final key =
          (page.category ?? '').isEmpty ? 'uncategorized' : page.category!;
      pagesByCategory.putIfAbsent(key, () => []).add(page);
    }

    return RefreshIndicator(
      onRefresh: _loadPages,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content Summary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text('Total pages: ${_pages.length}'),
                  Text('Categories: ${pagesByCategory.keys.length}'),
                  Text(
                      'Global pages: ${_pages.where((p) => p.type == 'centralized').length}'),
                  Text(
                      'Country pages: ${_pages.where((p) => p.type == 'country_specific').length}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Pages by category
          ...pagesByCategory.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                ...entry.value.map((page) {
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: page.type == 'centralized'
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          page.type == 'centralized'
                              ? Icons.public
                              : Icons.location_on,
                          color: page.type == 'centralized'
                              ? Colors.blue
                              : Colors.green,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        page.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Slug: ${page.slug}'),
                          Text('Type: ${page.type}'),
                          if (page.targetCountry != null)
                            Text('Country: ${page.targetCountry}'),
                          Text('Status: ${page.status}'),
                        ],
                      ),
                      trailing: Icon(
                        page.status == 'published'
                            ? Icons.check_circle
                            : Icons.schedule,
                        color: page.status == 'published'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      onTap: () {
                        // Show page content in dialog
                        _showPageContent(page);
                      },
                    ),
                  );
                }).toList(),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showPageContent(ContentPage page) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(page.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Slug: ${page.slug}'),
              Text('Category: ${page.category}'),
              Text('Type: ${page.type}'),
              if (page.targetCountry != null)
                Text('Country: ${page.targetCountry}'),
              Text('Status: ${page.status}'),
              const SizedBox(height: 16),
              Text(
                'Content Preview:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                page.content.length > 200
                    ? '${page.content.substring(0, 200)}...'
                    : page.content,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
