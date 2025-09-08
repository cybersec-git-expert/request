import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/glass_theme.dart';
import '../services/rest_notification_service.dart';
import '../models/notification_model.dart';
import 'requests/ride/view_ride_request_screen.dart';

class RiderAlertsScreen extends StatefulWidget {
  const RiderAlertsScreen({super.key});

  @override
  State<RiderAlertsScreen> createState() => _RiderAlertsScreenState();
}

class _RiderAlertsScreenState extends State<RiderAlertsScreen> {
  final _api = RestNotificationService.instance;

  Future<void> _refresh() async {
    setState(() {});
  }

  bool _isRideType(NotificationType t) {
    return t == NotificationType.newRideRequest ||
        t == NotificationType.rideResponseAccepted ||
        t == NotificationType.rideDetailsUpdated;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Rider Alerts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: GlassTheme.colors.textPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: Icon(Icons.mark_email_read,
                color: GlassTheme.colors.textSecondary),
            onPressed: () async {
              await _api.markAllRead();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: GlassTheme.backgroundContainer(
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FutureBuilder<List<NotificationModel>>(
              future: _api.fetchMyNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data ?? const <NotificationModel>[];
                final items = all.where((n) => _isRideType(n.type)).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car,
                            size: 64, color: GlassTheme.colors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No rider alerts yet',
                          style: TextStyle(
                            color: GlassTheme.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When ride requests or updates arrive, they will appear here.',
                          style:
                              TextStyle(color: GlassTheme.colors.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = items[index];
                      return _RiderAlertCard(
                        notification: n,
                        onOpen: () async {
                          await _open(context, n);
                          if (mounted) setState(() {});
                        },
                        onMenu: (action) => _onMenu(action, n),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, NotificationModel n) async {
    // Mark as read when opened
    if (n.status == NotificationStatus.unread) {
      await _api.markRead(n.id);
    }

    final data = n.data;
    final requestId = (data['requestId'] ?? data['request_id']) as String?;
    if (requestId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewRideRequestScreen(requestId: requestId),
        ),
      );
    }
  }

  Future<void> _onMenu(String action, NotificationModel n) async {
    switch (action) {
      case 'mark_read':
        await _api.markRead(n.id);
        if (mounted) setState(() {});
        break;
      case 'delete':
        await _api.delete(n.id);
        if (mounted) setState(() {});
        break;
    }
  }
}

class _RiderAlertCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onOpen;
  final Future<void> Function(String action) onMenu;

  const _RiderAlertCard({
    required this.notification,
    required this.onOpen,
    required this.onMenu,
  });

  Color _color(NotificationType t) {
    switch (t) {
      case NotificationType.newRideRequest:
        return Colors.blue;
      case NotificationType.rideResponseAccepted:
        return Colors.green;
      case NotificationType.rideDetailsUpdated:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _time(DateTime dt) {
    final now = DateTime.now();
    final d = now.difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final color = _color(n.type);
    final isUnread = n.status == NotificationStatus.unread;

    return Container(
      decoration: GlassTheme.glassContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(Icons.directions_car, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title.isNotEmpty ? n.title : 'Ride alert',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GlassTheme.colors.textPrimary,
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: GlassTheme.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _time(n.createdAt),
                    style: TextStyle(
                      color: GlassTheme.colors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: GlassTheme.colors.textTertiary, size: 20),
                onSelected: (v) => onMenu(v),
                itemBuilder: (context) => [
                  if (isUnread)
                    const PopupMenuItem(
                      value: 'mark_read',
                      child: Row(
                        children: [
                          Icon(Icons.check, size: 16),
                          SizedBox(width: 8),
                          Text('Mark as read'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
