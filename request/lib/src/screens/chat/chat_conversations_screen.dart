import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/rest_auth_service.dart';
import 'conversation_screen.dart';
import '../../theme/glass_theme.dart';

class ChatConversationsScreen extends StatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  final _auth = RestAuthService.instance;
  bool _loading = true;
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _conversations = [];
          _loading = false;
        });
        return;
      }
      final convos =
          await ChatService.instance.listConversations(userId: userId);
      if (mounted)
        setState(() {
          _conversations = convos;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load conversations: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.transparent,
        foregroundColor: GlassTheme.colors.textPrimary,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: GlassTheme.backgroundContainer(
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _conversations.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 56, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No conversations yet',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(12, 6, 12, 12),
                          itemCount: _conversations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final c = _conversations[i];
                            return Dismissible(
                              key: Key('conversation_${c.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 8),
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
                                    title: const Text('Delete Conversation'),
                                    content: Text(
                                        'Are you sure you want to delete this conversation about "${c.requestTitle ?? 'this request'}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                return confirmed ?? false;
                              },
                              onDismissed: (direction) async {
                                try {
                                  // TODO: Implement conversation deletion in ChatService
                                  // await ChatService.instance.deleteConversation(c.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Conversation deleted')),
                                    );
                                    // Remove from local list for immediate UI feedback
                                    setState(() {
                                      _conversations.removeAt(i);
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Error deleting conversation: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    final messages = await ChatService.instance
                                        .getMessages(conversationId: c.id);
                                    if (!mounted) return;
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ConversationScreen(
                                          conversation: c,
                                          initialMessages: messages,
                                        ),
                                      ),
                                    );
                                    _load();
                                  },
                                  child: Container(
                                    decoration: GlassTheme.glassContainer,
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: GlassTheme
                                                      .isDarkMode
                                                  ? Colors.white
                                                      .withOpacity(0.08)
                                                  : Colors.black
                                                      .withOpacity(0.06),
                                              child: Icon(Icons.person,
                                                  color: GlassTheme
                                                      .colors.textTertiary,
                                                  size: 22),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.requestTitle ??
                                                    'Request Chat',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: GlassTheme
                                                        .colors.textPrimary),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                c.lastMessageText ??
                                                    'Tap to open conversation',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: GlassTheme
                                                        .colors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _formatTime(c.lastMessageAt),
                                              style: TextStyle(
                                                color: GlassTheme
                                                    .colors.textTertiary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            if ((c.unreadCount ?? 0) > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: GlassTheme
                                                      .colors.textAccent,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  (c.unreadCount ?? 0)
                                                      .toString()
                                                      .padLeft(2, '0'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ),
      ),
    );
  }
}
