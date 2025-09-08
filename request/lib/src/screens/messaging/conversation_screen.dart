import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message_model.dart'
    show ConversationModel; // legacy conversation model
import '../../models/request_model.dart';
import '../../models/enhanced_user_model.dart' as models;
import '../../services/enhanced_user_service.dart';
import '../../services/chat_service.dart';
import '../../services/rest_auth_service.dart';
import '../../models/chat_models.dart';
import '../../theme/glass_theme.dart';
import '../unified_request_response/unified_request_view_screen.dart';

class ConversationScreen extends StatefulWidget {
  final ConversationModel conversation;
  final RequestModel? request;

  const ConversationScreen({
    super.key,
    required this.conversation,
    this.request,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final EnhancedUserService _userService = EnhancedUserService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  models.UserModel? _otherUser;
  bool _loadingMessages = true;
  bool _sending = false;
  String? _conversationId; // actual ID returned by backend when opening
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final me = RestAuthService.instance.currentUser?.uid;
    final otherId = widget.conversation.participantIds
        .firstWhere((id) => id != (me ?? ''), orElse: () => '');

    // Load header user (best-effort)
    if (otherId.isNotEmpty) {
      try {
        final u = await _userService.getUserById(otherId);
        if (mounted) setState(() => _otherUser = u);
      } catch (_) {}
    }

    if (me == null || otherId.isEmpty) {
      if (mounted) setState(() => _loadingMessages = false);
      return;
    }

    try {
      final result = await ChatService.instance.openConversation(
        requestId: widget.conversation.requestId,
        currentUserId: me,
        otherUserId: otherId,
      );
      final convo = result.$1;
      final msgs = result.$2;
      if (!mounted) return;
      setState(() {
        _conversationId = convo.id;
        _messages
          ..clear()
          ..addAll(msgs);
        _loadingMessages = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMessages = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to open chat: $e')));
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final cid = _conversationId ?? widget.conversation.id;
    if (text.isEmpty || _sending) return;

    try {
      setState(() => _sending = true);
      final senderId = RestAuthService.instance.currentUser?.uid;
      if (senderId == null) throw Exception('Not authenticated');
      final sent = await ChatService.instance
          .sendMessage(conversationId: cid, senderId: senderId, content: text);
      if (!mounted) return;
      setState(() {
        _messages.add(sent);
        _messageController.clear();
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sending: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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

  void _goToRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedRequestViewScreen(
          requestId: widget.conversation.requestId,
        ),
      ),
    );
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
              _otherUser?.name ?? 'Chat',
              style: TextStyle(
                color: GlassTheme.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.conversation.requestTitle,
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
                // Request header card
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
                                widget.conversation.requestTitle,
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

                // Messages list
                Expanded(
                  child: _loadingMessages
                      ? const Center(child: CircularProgressIndicator())
                      : (_messages.isEmpty
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Text(
                                          _formatTime(m.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                GlassTheme.colors.textTertiary,
                                          ),
                                        ),
                                      ),
                                    Align(
                                      alignment: me
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.75,
                                        ),
                                        decoration: BoxDecoration(
                                          color: me
                                              ? GlassTheme.colors.primaryBlue
                                              : GlassTheme
                                                  .colors.glassBackground.first,
                                          borderRadius:
                                              BorderRadius.circular(18),
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
                            )),
                ),

                // Composer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(),
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
                              controller: _messageController,
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
                              onSubmitted: (_) => _sendMessage(),
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
                            onPressed: _sending ? null : _sendMessage,
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) {
      return '${dt.day}/${dt.month}/${dt.year}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
