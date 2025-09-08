import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_page.dart';
import '../services/auth_service.dart';
import '../services/rest_request_service.dart' as rest;
import '../services/rest_support_services.dart';
import '../services/api_client.dart';
import '../services/country_service.dart';
import '../models/request_model.dart' as ui;
import '../models/enhanced_user_model.dart' as em;
import 'unified_request_response/unified_request_view_screen.dart';
import 'unified_request_response/unified_request_edit_screen.dart';
import 'unified_request_response/unified_response_view_screen.dart';
import 'unified_request_response/unified_response_edit_screen.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _rest = rest.RestRequestService.instance;
  final _api = ApiClient.instance;

  // Data
  List<rest.RequestModel> _myRequests = [];
  List<_ResponseSummary> _myResponses = [];
  List<rest.RequestModel> _completedRequests = [];

  // Filter for Responses tab: all | accepted | to_complete | completed
  String _responsesFilter = 'all';

  // Loading states
  bool _loadingRequests = false;
  bool _loadingResponses = false;
  bool _loadingCompleted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'My Activities',
      body: Column(
        children: [
          // Flat tab bar without gradients
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(
                color: GlassTheme.colors.primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'My Requests'),
                Tab(text: 'My Responses'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildResponsesTab(),
                _buildCompletedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _loadingRequests ? 3 : _myRequests.length,
        itemBuilder: (context, index) {
          if (_loadingRequests) {
            return _skeletonCard();
          }
          final r = _myRequests[index];
          return _requestCard(r);
        },
      ),
    );
  }

  Widget _buildResponsesTab() {
    // Counts for chips
    final int allCount = _myResponses.length;
    final int acceptedCount = _myResponses
        .where((e) => e.status == 'accepted')
        .length;
    final int completedCount = _myResponses
        .where((e) => e.status == 'completed')
        .length;

    List<_ResponseSummary> list = _myResponses;
    if (_responsesFilter == 'accepted') {
      list = list.where((e) => e.status == 'accepted').toList();
    } else if (_responsesFilter == 'to_complete') {
      list = list.where((e) => e.status == 'accepted').toList();
    } else if (_responsesFilter == 'completed') {
      list = list.where((e) => e.status == 'completed').toList();
    }

    return RefreshIndicator(
      onRefresh: _loadResponses,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Simple flat filter chips row
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('All', 'all', count: allCount),
                _filterChip('Accepted', 'accepted', count: acceptedCount),
                _filterChip('To Complete', 'to_complete', count: acceptedCount),
                _filterChip('Completed', 'completed', count: completedCount),
              ],
            ),
          ),
          if (_loadingResponses)
            ...List.generate(3, (_) => _skeletonCard())
          else if (list.isEmpty)
            _emptyState('No responses found for this filter.')
          else
            ...list.map(_responseCard),
        ],
      ),
    );
  }

  Widget _buildCompletedTab() {
    return RefreshIndicator(
      onRefresh: _loadCompleted,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _loadingCompleted ? 3 : _completedRequests.length,
        itemBuilder: (context, index) {
          if (_loadingCompleted) return _skeletonCard();
          final r = _completedRequests[index];
          return _requestCard(
            r,
            statusLabel: 'Completed',
            statusColor: GlassTheme.colors.textTertiary,
          );
        },
      ),
    );
  }

  // Removed History tab

  Widget _requestCard(
    rest.RequestModel r, {
    bool isOrder = false,
    String? statusLabel,
    Color? statusColor,
  }) {
    // Maintain backwards-compatibility but allow overrides for Accepted/Completed tabs
    final color = statusColor ?? (isOrder ? Colors.blue : Colors.green);
    final label = statusLabel ?? (isOrder ? 'Accepted' : 'Active');
    return _flatGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(
            isOrder ? Icons.shopping_bag : Icons.receipt_long,
            color: color,
          ),
        ),
        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          r.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label, style: TextStyle(color: color, fontSize: 11)),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (v) async {
                if (v == 'view') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UnifiedRequestViewScreen(requestId: r.id),
                    ),
                  );
                } else if (v == 'edit') {
                  final full = await _rest.getRequestById(r.id);
                  if (full != null && mounted) {
                    final uiReq = _toUiRequestModel(full);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UnifiedRequestEditScreen(request: uiReq),
                      ),
                    );
                  }
                } else if (v == 'delete') {
                  final ok = await _confirm('Delete this request?');
                  if (ok) {
                    final done = await _rest.deleteRequest(r.id);
                    if (done) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Request deleted')),
                      );
                      _loadRequests();
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _responseCard(_ResponseSummary s) {
    // Determine status color and icon based on response status
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (s.status) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Accepted';
        break;
      case 'declined':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Declined';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.task_alt;
        statusText = 'Completed';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
    }

    return _flatGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          s.requestTitle ?? 'Response',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.message ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 11),
              ),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (v) async {
                if (v == 'view' || v == 'edit') {
                  final req = await _rest.getRequestById(s.requestId);
                  if (req == null) return;
                  final page = await _rest.getResponses(
                    s.requestId,
                    limit: 100,
                  );
                  rest.ResponseModel? resp;
                  try {
                    resp = page.responses.firstWhere((e) => e.id == s.id);
                  } catch (_) {
                    resp = page.responses.isNotEmpty
                        ? page.responses.first
                        : null;
                  }
                  if (!mounted || resp == null) return;
                  if (v == 'view') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UnifiedResponseViewScreen(
                          request: _toUiRequestModel(req),
                          response: _toUiResponseModel(resp!, req),
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UnifiedResponseEditScreen(
                          request: _toUiRequestModel(req),
                          response: _toUiResponseModel(resp!, req),
                        ),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'view', child: Text('View')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Converters from REST models to UI models
  ui.RequestModel _toUiRequestModel(rest.RequestModel r) {
    return ui.RequestModel(
      id: r.id,
      requesterId: r.userId,
      title: r.title,
      description: r.description,
      type: _getRequestTypeFromString(
        r.metadata?['type']?.toString() ?? 'item',
      ),
      status: _getRequestStatusFromString(r.status),
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      budget: r.budget,
      currency: r.currency,
      images: r.imageUrls ?? const [],
      tags: const [],
      priority: ui.Priority.medium,
      location:
          (r.locationAddress != null &&
              r.locationLatitude != null &&
              r.locationLongitude != null)
          ? ui.LocationInfo(
              latitude: r.locationLatitude ?? 0.0,
              longitude: r.locationLongitude ?? 0.0,
              address: r.locationAddress!,
              city: r.cityName ?? r.locationAddress!,
              country: r.countryCode,
            )
          : (r.cityName != null
                ? ui.LocationInfo(
                    latitude: 0.0,
                    longitude: 0.0,
                    address: r.cityName!,
                    city: r.cityName!,
                    country: r.countryCode,
                  )
                : null),
      typeSpecificData: r.metadata ?? const {},
      country: r.countryCode,
    );
  }

  ui.RequestStatus _getRequestStatusFromString(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'active':
      case 'open':
        return ui.RequestStatus.active;
      case 'inprogress':
      case 'in_progress':
        return ui.RequestStatus.inProgress;
      case 'completed':
        return ui.RequestStatus.completed;
      case 'cancelled':
        return ui.RequestStatus.cancelled;
      case 'expired':
        return ui.RequestStatus.expired;
      default:
        return ui.RequestStatus.draft;
    }
  }

  em.RequestType _getRequestTypeFromString(String type) {
    final t = type.toLowerCase();
    switch (t) {
      case 'item':
        return em.RequestType.item;
      case 'service':
        return em.RequestType.service;
      case 'delivery':
        return em.RequestType.delivery;
      case 'rental':
      case 'rent':
        return em.RequestType.rental;
      case 'ride':
        return em.RequestType.ride;
      case 'price':
        return em.RequestType.price;
      default:
        return em.RequestType.item;
    }
  }

  ui.ResponseModel _toUiResponseModel(
    rest.ResponseModel r,
    rest.RequestModel req,
  ) {
    return ui.ResponseModel(
      id: r.id,
      requestId: r.requestId,
      responderId: r.userId,
      message: r.message,
      price: r.price,
      currency: r.currency,
      availableFrom: null,
      availableUntil: null,
      images: r.imageUrls ?? const [],
      additionalInfo: r.metadata ?? const {},
      createdAt: r.createdAt,
      isAccepted:
          (req.acceptedResponseId != null && req.acceptedResponseId == r.id),
      rejectionReason: null,
      country: r.countryCode,
      countryName: null,
    );
  }

  Widget _skeletonCard() => _flatGlassCard(
    margin: const EdgeInsets.only(bottom: 12),
    child: Container(height: 76, padding: const EdgeInsets.all(16)),
  );

  // Small helpers for Responses tab UI
  Widget _filterChip(String label, String key, {int? count}) {
    final bool selected = _responsesFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _responsesFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? GlassTheme.colors.primaryBlue : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? GlassTheme.colors.primaryBlue : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              _countBadge(count, selected: selected),
            ],
          ],
        ),
      ),
    );
  }

  Widget _countBadge(int count, {bool selected = false}) {
    // For selected chips, show a light badge for contrast; otherwise a subtle grey badge
    final bg = selected ? Colors.white : Colors.grey[200]!;
    final fg = selected ? GlassTheme.colors.primaryBlue : Colors.grey[800]!;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey<int>(count),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white : Colors.grey[300]!,
          ),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Text(
        message,
        style: GlassTheme.labelMedium.copyWith(
          color: GlassTheme.colors.textSecondary,
        ),
      ),
    );
  }

  // Local flat glass card (no border, no shadow) for this screen
  Widget _flatGlassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double radius = 20,
  }) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: GlassTheme.colors.glassBackground,
        ),
        borderRadius: BorderRadius.circular(radius),
        // No border, no boxShadow to keep it flat
      ),
      child: child,
    );
  }

  // Removed history helper

  Future<void> _loadAll() async {
    await Future.wait([_loadRequests(), _loadResponses(), _loadCompleted()]);
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final r = await _rest.getUserRequests(limit: 50);
      setState(() => _myRequests = r?.requests ?? []);
    } finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  // Removed Orders loading function

  Future<void> _loadResponses() async {
    setState(() => _loadingResponses = true);
    try {
      final uid = AuthService.instance.currentUser?.uid;
      final country = CountryService.instance.getCurrentCountryCode();
      final res = await _api.get<dynamic>(
        '/api/responses',
        queryParameters: {'country': country, 'limit': '100'},
      );
      final list = (res.data is List)
          ? res.data as List
          : (res.data is Map && (res.data as Map)['data'] is List
                ? (res.data as Map)['data'] as List
                : []);
      final mine = list
          .where((e) => (e['user_id'] ?? e['userId']) == uid)
          .toList();

      // Derive status (accepted/completed) using embedded request when available
      final mapped = <_ResponseSummary>[];
      for (final raw in mine) {
        final m = raw as Map<String, dynamic>;
        final request = (m['request'] is Map<String, dynamic>)
            ? m['request'] as Map<String, dynamic>
            : null;
        final String respId = (m['id']?.toString() ?? '');
        final String requestId =
            (m['request_id']?.toString() ?? m['requestId']?.toString() ?? '');

        // base accepted
        bool accepted =
            m['accepted'] == true ||
            (m['raw_status']?.toString() == 'accepted');
        // derive acceptance via request link
        if (!accepted && request != null) {
          final accId = request['accepted_response_id']?.toString();
          if (accId != null && accId == respId) accepted = true;
        }

        // derive completed via request status when this response is the accepted one
        bool completed = false;
        if (request != null) {
          final reqCompleted = request['status']?.toString() == 'completed';
          final accId = request['accepted_response_id']?.toString();
          if (reqCompleted && accId == respId) completed = true;
        } else if (m['raw_status']?.toString() == 'completed') {
          completed = true;
        }

        String status = 'pending';
        if (completed)
          status = 'completed';
        else if (accepted)
          status = 'accepted';
        else if (m['raw_status']?.toString() == 'declined')
          status = 'declined';

        mapped.add(
          _ResponseSummary(
            id: respId,
            requestId: requestId,
            message: m['message']?.toString(),
            price: m['price'] is num
                ? m['price'] as num
                : num.tryParse('${m['price']}'),
            currency: m['currency']?.toString(),
            accepted: accepted,
            requestTitle: request != null
                ? (request['title']?.toString() ??
                      m['request_title']?.toString())
                : m['request_title']?.toString(),
            status: status,
          ),
        );
      }

      setState(() {
        _myResponses = mapped;
      });
    } catch (_) {
      setState(() => _myResponses = []);
    } finally {
      if (mounted) setState(() => _loadingResponses = false);
    }
  }

  Future<void> _loadCompleted() async {
    setState(() => _loadingCompleted = true);
    try {
      final uid = AuthService.instance.currentUser?.uid;
      final r = await _rest.getRequests(
        userId: uid,
        status: 'completed',
        limit: 50,
      );
      setState(() => _completedRequests = r?.requests ?? []);
    } catch (_) {
      setState(() => _completedRequests = []);
    } finally {
      if (mounted) setState(() => _loadingCompleted = false);
    }
  }

  Future<bool> _confirm(String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return res == true;
  }
}

class _ResponseSummary {
  final String id;
  final String requestId;
  final String? message;
  final num? price;
  final String? currency;
  final bool accepted;
  final String? requestTitle;
  final String status; // 'pending', 'accepted', 'declined', 'completed'

  _ResponseSummary({
    required this.id,
    required this.requestId,
    this.message,
    this.price,
    this.currency,
    this.accepted = false,
    this.requestTitle,
    this.status = 'pending',
  });
}
