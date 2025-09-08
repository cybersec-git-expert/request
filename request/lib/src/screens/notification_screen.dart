import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/rest_notification_service.dart';
import '../models/notification_model.dart';
import '../screens/unified_request_response/unified_request_view_screen.dart';
import '../screens/requests/ride/view_ride_request_screen.dart';
import '../screens/chat/conversation_screen.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_page.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final RestNotificationService _restNotifications =
      RestNotificationService.instance;
  final AuthService _auth = AuthService.instance;

  Future<void> _refresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return GlassPage(
        title: 'Notifications',
        body: const Center(child: Text('Please log in to view notifications')),
      );
    }

    return GlassPage(
      title: 'Notifications',
      body: FutureBuilder<List<NotificationModel>>(
        future: _restNotifications.fetchMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text('Error: ${snapshot.error}',
                      style: TextStyle(color: GlassTheme.colors.textSecondary)),
                ],
              ),
            );
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: GlassTheme.colors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: GlassTheme.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You'll see notifications here when something happens",
                    style: TextStyle(color: GlassTheme.colors.textTertiary),
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
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _buildDismissibleCard(n);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDismissibleCard(NotificationModel n) {
    return Dismissible(
      key: Key('notification_${n.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text(
                'Are you sure you want to delete this notification?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (direction) async {
        await _restNotifications.delete(n.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification deleted')),
          );
          await _refresh();
        }
      },
      child: _buildCard(n),
    );
  }

  Widget _buildCard(NotificationModel n) {
    final isUnread = n.status == NotificationStatus.unread;
    final color = _color(n.type);
    return Container(
      decoration: GlassTheme.glassContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _onTap(n),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Borderless circular icon with soft tinted background
              CircleAvatar(
                radius: 21,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(_icon(n.type), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w600,
                        color: GlassTheme.colors.textPrimary,
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
                        color: GlassTheme.colors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: GlassTheme.colors.textTertiary, size: 20),
                onSelected: (v) => _menu(v, n),
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

  Color _color(NotificationType t) {
    switch (t) {
      case NotificationType.newResponse:
        return Colors.green;
      case NotificationType.requestEdited:
        return Colors.blue;
      case NotificationType.responseEdited:
        return Colors.orange;
      case NotificationType.responseAccepted:
        return Colors.green;
      case NotificationType.responseRejected:
        return Colors.red;
      case NotificationType.newMessage:
        return Colors.purple;
      case NotificationType.newRideRequest:
        return Colors.blue;
      case NotificationType.rideResponseAccepted:
        return Colors.green;
      case NotificationType.rideDetailsUpdated:
        return Colors.orange;
      case NotificationType.productInquiry:
        return Colors.indigo;
      case NotificationType.systemMessage:
        return Colors.grey;
    }
  }

  IconData _icon(NotificationType t) {
    switch (t) {
      case NotificationType.newResponse:
        return Icons.reply;
      case NotificationType.requestEdited:
        return Icons.edit;
      case NotificationType.responseEdited:
        return Icons.edit_note;
      case NotificationType.responseAccepted:
        return Icons.check_circle;
      case NotificationType.responseRejected:
        return Icons.cancel;
      case NotificationType.newMessage:
        return Icons.message;
      case NotificationType.newRideRequest:
        return Icons.directions_car;
      case NotificationType.rideResponseAccepted:
        return Icons.check_circle;
      case NotificationType.rideDetailsUpdated:
        return Icons.update;
      case NotificationType.productInquiry:
        return Icons.shopping_bag;
      case NotificationType.systemMessage:
        return Icons.info;
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

  Future<void> _onTap(NotificationModel n) async {
    if (n.status == NotificationStatus.unread) {
      await _restNotifications.markRead(n.id);
    }
    await _navigate(n);
    if (mounted) await _refresh();
  }

  void _menu(String action, NotificationModel n) async {
    switch (action) {
      case 'mark_read':
        await _restNotifications.markRead(n.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification marked as read')),
          );
          await _refresh();
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text(
                'Are you sure you want to delete this notification?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        );
        if (confirmed == true) {
          await _restNotifications.delete(n.id);
          if (mounted) await _refresh();
        }
        break;
    }
  }

  Future<void> _navigate(NotificationModel n) async {
    final data = n.data;
    switch (n.type) {
      case NotificationType.newResponse:
      case NotificationType.requestEdited:
      case NotificationType.responseEdited:
      case NotificationType.responseAccepted:
      case NotificationType.responseRejected:
        final requestId = (data['requestId'] ?? data['request_id']) as String?;
        if (requestId != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UnifiedRequestViewScreen(requestId: requestId),
            ),
          );
        }
        break;
      case NotificationType.newMessage:
        final conversationId =
            (data['conversationId'] ?? data['conversation_id']) as String?;
        final requestId = (data['requestId'] ?? data['request_id']) as String?;
        if (conversationId != null) {
          try {
            final msgs = await ChatService.instance
                .getMessages(conversationId: conversationId);
            final convo = Conversation(
              id: conversationId,
              requestId: requestId ?? '',
              participantA: null,
              participantB: null,
              lastMessageText: msgs.isNotEmpty ? msgs.last.content : null,
              lastMessageAt: msgs.isNotEmpty ? msgs.last.createdAt : null,
              requestTitle: data['requestTitle'] as String?,
            );
            if (mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConversationScreen(
                    conversation: convo,
                    initialMessages: msgs,
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unable to open conversation: $e')));
            }
          }
        }
        break;
      case NotificationType.newRideRequest:
      case NotificationType.rideResponseAccepted:
      case NotificationType.rideDetailsUpdated:
        final requestId = (data['requestId'] ?? data['request_id']) as String?;
        if (requestId != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewRideRequestScreen(requestId: requestId),
            ),
          );
        }
        break;
      case NotificationType.productInquiry:
      case NotificationType.systemMessage:
        break;
    }
  }
}
