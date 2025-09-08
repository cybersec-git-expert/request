import 'package:flutter/material.dart';
import '../../widgets/glass_page.dart';
import '../../theme/glass_theme.dart';
import '../../services/rest_user_service.dart';
import '../../services/api_client.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final RestUserService _service = RestUserService.instance;
  PublicProfile? _profile;
  PagedUserReviews? _reviews;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await _service.getPublicProfile(widget.userId);
    final reviews =
        await _service.getUserReviews(widget.userId, page: 1, limit: 10);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _reviews = reviews;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_reviews == null) return;
    if (_reviews!.page >= _reviews!.totalPages) return;
    final next = _reviews!.page + 1;
    final more = await _service.getUserReviews(widget.userId,
        page: next, limit: _reviews!.limit);
    if (!mounted || more == null) return;
    setState(() {
      _reviews = PagedUserReviews(
        reviews: [..._reviews!.reviews, ...more.reviews],
        page: more.page,
        limit: more.limit,
        total: more.total,
        totalPages: more.totalPages,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const GlassPage(
        title: 'Profile',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_profile == null) {
      return const GlassPage(
        title: 'Profile',
        body: Center(child: Text('User not found')),
      );
    }
    final p = _profile!;
    return GlassPage(
      title: p.displayName.isNotEmpty ? p.displayName : 'Profile',
      appBarBackgroundColor: GlassTheme.isDarkMode
          ? const Color(0x1AFFFFFF)
          : const Color(0xCCFFFFFF),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            // Transparent to let Glass gradient show
            color: Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(p),
                const SizedBox(height: 16),
                _statsRow(p),
                const SizedBox(height: 16),
                if (p.business != null) _businessCard(p),
                if (p.driver != null) ...[
                  if (p.business != null) const SizedBox(height: 12),
                  _driverCard(p),
                ],
                const SizedBox(height: 20),
                _reviewsSection(),
                if (_reviews != null && _reviews!.page < _reviews!.totalPages)
                  Center(
                    child: TextButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(PublicProfile p) {
    final photo = p.photoUrl;
    final displayUrl = photo == null || photo.isEmpty
        ? null
        : (photo.startsWith('http')
            ? photo
            : '${ApiClient.baseUrlPublic}$photo');
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[200],
            // Use foregroundImage so child fallback shows until load and on error
            backgroundImage:
                displayUrl != null ? NetworkImage(displayUrl) : null,
            child: Text(
              p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : 'U',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.displayName, style: GlassTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _stars(p.averageRating.round()),
                    const SizedBox(width: 6),
                    Text('(${p.reviewCount})',
                        style: GlassTheme.bodySmall
                            .copyWith(color: GlassTheme.colors.textTertiary)),
                  ],
                ),
                if ((p.email ?? '').isNotEmpty)
                  Text(p.email!,
                      style: GlassTheme.bodySmall
                          .copyWith(color: GlassTheme.colors.textTertiary)),
                if ((p.phone ?? '').isNotEmpty)
                  Text(p.phone!,
                      style: GlassTheme.bodySmall
                          .copyWith(color: GlassTheme.colors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(PublicProfile p) {
    return Row(
      children: [
        _statTile(
            Icons.star_rate_rounded,
            '${p.averageRating.toStringAsFixed(2)} (${p.reviewCount})',
            'Rating'),
        const SizedBox(width: 8),
        _statTile(
            Icons.reply_all_rounded, p.responsesCount.toString(), 'Responses'),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return Expanded(
      child: GlassTheme.glassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: Colors.black54),
              const SizedBox(width: 6),
              Text(label, style: GlassTheme.bodySmall)
            ]),
            const SizedBox(height: 6),
            Text(value, style: GlassTheme.titleSmall),
          ],
        ),
      ),
    );
  }

  Widget _businessCard(PublicProfile p) {
    final b = p.business!;
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.store_mall_directory_outlined,
                size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            const Text('Business',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          _kv('Name', (b['business_name'] ?? '').toString()),
          _kv('Status', (b['status'] ?? '').toString()),
          if ((b['country'] ?? '').toString().isNotEmpty)
            _kv('Country', b['country'].toString()),
          if ((b['category'] ?? '').toString().isNotEmpty)
            _kv('Category', b['category'].toString()),
        ],
      ),
    );
  }

  Widget _driverCard(PublicProfile p) {
    final d = p.driver!;
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.directions_car_filled_outlined,
                size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            const Text('Driver', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          if ((d['full_name'] ?? '').toString().isNotEmpty)
            _kv('Name', d['full_name'].toString()),
          _kv('Status', (d['status'] ?? '').toString()),
          if ((d['country'] ?? '').toString().isNotEmpty)
            _kv('Country', d['country'].toString()),
          if ((d['vehicle_type_name'] ?? '').toString().isNotEmpty)
            _kv('Vehicle', d['vehicle_type_name'].toString()),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 90,
              child: Text('$k:',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _reviewsSection() {
    final r = _reviews;
    if (r == null || r.reviews.isEmpty) {
      return GlassTheme.glassCard(
        padding: const EdgeInsets.all(16),
        child: const Text('No reviews yet'),
      );
    }
    return GlassTheme.glassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.reviews_outlined, size: 18, color: Colors.black54),
            SizedBox(width: 6),
            Text('Reviews', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          ...r.reviews.map((it) => _reviewTile(it)),
        ],
      ),
    );
  }

  Widget _reviewTile(UserReviewItem it) {
    return GlassTheme.glassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[200],
                child: Text(
                  (it.reviewerName ?? 'U').isNotEmpty
                      ? (it.reviewerName ?? 'U')[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.reviewerName ?? 'User',
                        style: GlassTheme.bodySmall),
                    Text(_relativeTime(it.createdAt),
                        style: GlassTheme.bodySmall
                            .copyWith(color: GlassTheme.colors.textTertiary)),
                  ],
                ),
              ),
              _stars(it.rating),
            ],
          ),
          if ((it.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(it.comment!, style: GlassTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _stars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          5,
          (i) => Icon(i < rating ? Icons.star : Icons.star_border,
              color: Colors.amber, size: 18)),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
