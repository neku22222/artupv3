import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';

// ── DM List Screen ────────────────────────────────────────────────────────────

class DMScreen extends StatefulWidget {
  const DMScreen({super.key});

  @override
  State<DMScreen> createState() => _DMScreenState();
}

class _DMScreenState extends State<DMScreen> {
  List<ConversationModel> _convos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final convos = await dmService.getConversations();
      if (mounted) setState(() { _convos = convos; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.peach));

    if (_convos.isEmpty) {
      return const EmptyState(
        emoji: '💬',
        title: 'No messages yet',
        subtitle: 'Visit an artist\'s profile and tap the message button to start a conversation',
      );
    }

    return RefreshIndicator(
      color: AppColors.peach,
      onRefresh: () async { setState(() => _loading = true); await _load(); },
      child: ListView.separated(
        itemCount: _convos.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76, color: AppColors.border),
        itemBuilder: (_, i) {
          final c = _convos[i];
          final other = c.otherProfile;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: UserAvatar(url: other?.avatarUrl ?? '', size: 46),
            title: Text(
              other?.fullName.isNotEmpty == true ? other!.fullName : '@${other?.handle ?? ''}',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark),
            ),
            subtitle: Text(
              c.lastMessage.isNotEmpty ? c.lastMessage : 'Start a conversation',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              timeago.format(c.updatedAt, locale: 'en_short'),
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(conversation: c, otherProfile: other!))).then((_) => _load()),
          );
        },
      ),
    );
  }
}

// ── Chat Screen ───────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  final ProfileModel otherProfile;

  const ChatScreen({super.key, required this.conversation, required this.otherProfile});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await dmService.getMessages(widget.conversation.id);
      if (mounted) setState(() { _messages = msgs; _loading = false; });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await dmService.sendMessage(widget.conversation.id, body);
      final msgs = await dmService.getMessages(widget.conversation.id);
      if (mounted) setState(() => _messages = msgs);
      _scrollToBottom();
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = authService.currentUserId;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.warmWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.dark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [
          UserAvatar(url: widget.otherProfile.avatarUrl, size: 32),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.otherProfile.fullName.isNotEmpty
                  ? widget.otherProfile.fullName
                  : '@${widget.otherProfile.handle}',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark),
            ),
            Text('@${widget.otherProfile.handle}',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
          ]),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
              : _messages.isEmpty
                  ? const EmptyState(emoji: '👋', title: 'Say hello!', subtitle: 'Start the conversation')
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg  = _messages[i];
                        final isMine = msg.senderId == me;
                        return _MessageBubble(message: msg, isMine: isMine);
                      },
                    ),
        ),
        _buildInput(),
      ]),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 12, top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 10),
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _msgCtrl,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Message @${widget.otherProfile.handle}…',
                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted),
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero, filled: false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: AppColors.peach, shape: BoxShape.circle),
            child: _sending
                ? const Padding(padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? AppColors.peach : AppColors.cardBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
              border: isMine ? null : Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(message.body,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: isMine ? Colors.white : AppColors.dark, height: 1.4)),
              const SizedBox(height: 3),
              Text(timeago.format(message.createdAt, locale: 'en_short'),
                  style: GoogleFonts.dmSans(
                      fontSize: 9,
                      color: isMine ? Colors.white.withOpacity(0.7) : AppColors.muted)),
            ]),
          ),
        ],
      ),
    );
  }
}
