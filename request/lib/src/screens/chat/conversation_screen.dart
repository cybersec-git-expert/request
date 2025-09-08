import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/rest_auth_service.dart';
import '../../theme/glass_theme.dart';

class ConversationScreen extends StatefulWidget {
  final Conversation conversation;
  final List<ChatMessage> initialMessages;
  const ConversationScreen(
      {super.key, required this.conversation, required this.initialMessages});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.addAll(widget.initialMessages);
    // Auto-scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final senderId = RestAuthService.instance.currentUser?.uid;
      if (senderId == null) throw Exception('Not authenticated');
      final msg = await ChatService.instance.sendMessage(
          conversationId: widget.conversation.id,
          senderId: senderId,
          content: text);
      setState(() {
        _messages.add(msg);
        _controller.clear();
      });
      // Scroll to bottom after adding message
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _goToRequest() {
    // Navigate back to request view
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: GlassTheme.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.conversation.requestTitle ?? 'Request Chat',
              style: TextStyle(
                color: GlassTheme.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Tap to view request',
              style: TextStyle(
                color: GlassTheme.colors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline,
                color: GlassTheme.colors.textSecondary),
            onPressed: _goToRequest,
          ),
        ],
      ),
      body: GlassTheme.backgroundContainer(
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                // Request Header Card (Facebook-like)
                GestureDetector(
                  onTap: _goToRequest,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: GlassTheme.glassContainer,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                GlassTheme.colors.primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.description,
                            color: GlassTheme.colors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.conversation.requestTitle ?? 'Request',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: GlassTheme.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'View request details',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GlassTheme.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: GlassTheme.colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),

                // Messages List
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: GlassTheme.colors.textTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Start your conversation',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: GlassTheme.colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Send a message to begin',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: GlassTheme.colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) {
                            final m = _messages[i];
                            final me =
                                RestAuthService.instance.currentUser?.uid ==
                                    m.senderId;
                            final showTime = i == 0 ||
                                _messages[i - 1]
                                        .createdAt
                                        .difference(m.createdAt)
                                        .inMinutes
                                        .abs() >
                                    5;

                            return Column(
                              children: [
                                if (showTime)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      _formatTime(m.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: GlassTheme.colors.textTertiary,
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: me
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.75,
                                    ),
                                    decoration: BoxDecoration(
                                      color: me
                                          ? GlassTheme.colors.primaryBlue
                                          : GlassTheme
                                              .colors.glassBackground.first,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: me
                                            ? Colors.transparent
                                            : GlassTheme
                                                .colors.glassBorderSubtle,
                                      ),
                                    ),
                                    child: Text(
                                      m.content,
                                      style: TextStyle(
                                        color: me
                                            ? Colors.white
                                            : GlassTheme.colors.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),

                // Message Input
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: GlassTheme.colors.glassBackground.first,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: GlassTheme.colors.glassBorderSubtle,
                              ),
                            ),
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                    color: GlassTheme.colors.textTertiary),
                                border: InputBorder.none,
                              ),
                              minLines: 1,
                              maxLines: 5,
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: GlassTheme.colors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send,
                                    color: Colors.white, size: 20),
                            onPressed: _sending ? null : _send,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
