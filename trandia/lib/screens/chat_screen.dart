// chat_screen.dart
// BUGS FIXED:
// 1. Header top: 10 ignored status bar → header overlapped OS bar on notched phones
// 2. Input bottom: 10 ignored keyboard insets → input hidden behind keyboard
// 3. No optimistic message insert → send felt laggy (had to wait for WS round-trip)
// 4. Typing event sent every keystroke → WS spam; now delegated to ChatService throttle
// 5. otherUser.username[0] crash when username is empty string
// 6. Dead `runs` variable in build()

import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import 'glass_common.dart';

class ChatScreen extends StatefulWidget {
  final bool dark;
  final ChatConversation conversation;
  final String myUserId;

  const ChatScreen({
    super.key,
    required this.dark,
    required this.conversation,
    required this.myUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _typingUserId;
  Timer? _typingTimer;
  late StreamSubscription<ChatMessage> _messageSub;
  late StreamSubscription<Map<String, dynamic>> _typingSub;

  // For optimistic send — track pending messages by temp id
  final Set<String> _pendingIds = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    ChatService().markAsRead(widget.conversation.id);

    _messageSub = ChatService().messageStream.listen((msg) {
      if (!mounted) return;
      if (msg.conversationId == widget.conversation.id) {
        setState(() {
          final existingIndex = _messages.indexWhere((m) => m.id == msg.id);
          if (existingIndex != -1) {
            _pendingIds.remove(msg.id);
          } else {
            final pendingIndex = _messages.indexWhere((m) =>
                _pendingIds.contains(m.id) &&
                m.senderId == msg.senderId &&
                (msg.text.isEmpty || m.text == msg.text));

            if (pendingIndex != -1) {
              final pending = _messages[pendingIndex];
              _pendingIds.remove(pending.id);
              _messages[pendingIndex] = _isDisplayableMessage(msg)
                  ? msg
                  : _confirmedFromPending(pending, msg);
            } else if (_isDisplayableMessage(msg)) {
              _messages.insert(0, msg);
            }
          }
          if (msg.senderId == _typingUserId) _typingUserId = null;
        });
        ChatService().markAsRead(widget.conversation.id);
      }
    });

    _typingSub = ChatService().typingStream.listen((event) {
      if (!mounted) return;
      if (event['conversation_id'] == widget.conversation.id &&
          event['user_id'] != widget.myUserId) {
        setState(() => _typingUserId = event['user_id'] as String?);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _typingUserId = null);
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _messageSub.cancel();
    _typingSub.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final msgs = await ChatService().getMessages(
        widget.conversation.id,
        limit: 25,
      );
      if (mounted) {
        setState(() {
          _messages = msgs.where(_isDisplayableMessage).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  ChatMessage _confirmedFromPending(ChatMessage pending, ChatMessage confirmed) {
    return ChatMessage(
      id: confirmed.id,
      conversationId: confirmed.conversationId,
      senderId: confirmed.senderId,
      text: pending.text,
      createdAt: confirmed.createdAt,
      readBy: confirmed.readBy,
      encryptedAesKeys: confirmed.encryptedAesKeys,
    );
  }

  bool _isDisplayableMessage(ChatMessage msg) {
    final text = msg.text.trim();
    if (text.isEmpty) return false;
    if (text.startsWith('[Decryption error:') ||
        text.contains('Decryption error:') ||
        text == '[Encrypted Message]') {
      return false;
    }
    return !_looksLikeEncryptedPayload(text);
  }

  bool _looksLikeEncryptedPayload(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    return normalized.startsWith('{"ct":') &&
        normalized.contains('"iv":') &&
        normalized.endsWith('}');
  }

  /// Optimistic send: insert locally first, then fire over WS.
  /// If WS echoes back, we de-dupe by id.
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Optimistic insert — use a temp id
    final sentAt = DateTime.now();
    final tempId = 'temp_${sentAt.millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      conversationId: widget.conversation.id,
      senderId: widget.myUserId,
      text: text,
      createdAt: sentAt,
      readBy: [widget.myUserId],
    );

    setState(() {
      _messages.insert(0, optimistic);
      _pendingIds.add(tempId);
    });

    _textController.clear();
    HapticFeedback.lightImpact();

    // Send via WebSocket with E2EE participants
    ChatService().sendMessage(
      widget.conversation.id,
      text,
      widget.conversation.participants,
      createdAt: sentAt,
    );
  }

  void _onTyping(String text) {
    // ChatService.sendTyping is already throttled to 1 event / 2 sec
    if (text.isNotEmpty) ChatService().sendTyping(widget.conversation.id);
  }

  Future<void> _deleteConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Delete this conversation? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ChatService().deleteConversation(widget.conversation.id);
      if (mounted) {
        Navigator.pop(context); // pop loading
        Navigator.pop(context, true); // pop chat screen
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Delete this message for everyone?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ChatService().deleteMessage(widget.conversation.id, messageId);
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == messageId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);

    // FIX: use actual safe area top + bottom insets
    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom; // keyboard height
    final navPad    = MediaQuery.paddingOf(context).bottom;    // nav bar

    final headerH  = 66.0;
    final inputH   = 54.0;
    final headerTop = topPad + 8;

    // FIX: guard empty username to avoid RangeError
    final otherUser = widget.conversation.getOtherParticipant(widget.myUserId);
    final avatarLetter =
        otherUser.username.isNotEmpty ? otherUser.username[0].toUpperCase() : '?';

    return Scaffold(
      // resizeToAvoidBottomInset false — we handle keyboard insets manually
      resizeToAvoidBottomInset: false,
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(children: [
        GlassBackdrop(dark: widget.dark),

        // ── Messages list ──────────────────────────────────────
        Positioned(
          top: headerTop + headerH,
          bottom: inputH + 16 + bottomPad + navPad,
          left: 0, right: 0,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Could not load messages',
                            style: manrope(size: 14, color: sub)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadMessages,
                          child: const Text('Retry'),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount:
                          _messages.length + (_typingUserId != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_typingUserId != null) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: _BubbleTyping(dark: widget.dark, sub: sub),
                            );
                          }
                          index--;
                        }

                        final msg = _messages[index];
                        final isMe = msg.senderId == widget.myUserId;
                        final isPending = _pendingIds.contains(msg.id);

                        bool last = true;
                        if (index > 0) {
                          final newer = _messages[index - 1];
                          if (newer.senderId == msg.senderId) last = false;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: GestureDetector(
                            onLongPress: isMe
                                ? () => _deleteMessage(msg.id)
                                : null,
                            child: _Bubble(
                              m: msg,
                              isMe: isMe,
                              dark: widget.dark,
                              last: last,
                              isPending: isPending,
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // ── Header ────────────────────────────────────────────
        Positioned(
          top: headerTop, left: 12, right: 12,
          child: GlassHeader(
            dark: widget.dark,
            height: headerH,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: fg, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: monoAvatar(widget.dark, 0)),
                alignment: Alignment.center,
                child: Text(avatarLetter,
                    style: manrope(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(otherUser.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: manrope(
                              size: 15,
                              weight: FontWeight.w800,
                              color: fg,
                              letterSpacing: -0.225)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            ChatService().isConnected ? 'Active now' : 'Connecting…',
                            style: manrope(size: 11, weight: FontWeight.w500, color: sub),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: sub),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.lock_outline_rounded, size: 10, color: sub),
                          const SizedBox(width: 2),
                          Text(
                            'E2EE',
                            style: manrope(size: 9.5, weight: FontWeight.w700, color: sub, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ]),
              ),
              GlassCircleButton(dark: widget.dark, icon: Icons.call_outlined, iconSize: 18),
              const SizedBox(width: 6),
              GlassCircleButton(dark: widget.dark, icon: Icons.videocam_outlined, iconSize: 20),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _deleteConversation,
                child: GlassCircleButton(
                    dark: widget.dark,
                    icon: Icons.delete_outline_rounded,
                    iconSize: 18,
                    fg: Colors.red),
              ),
            ]),
          ),
        ),

        // ── Input bar ─────────────────────────────────────────
        Positioned(
          // FIX: sits above keyboard + nav bar
          bottom: bottomPad + navPad + 8,
          left: 12, right: 12,
          child: SizedBox(
            height: inputH,
            child: GlassSurface(
              dark: widget.dark,
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              blurSigma: 28,
              shadow: BoxShadow(
                color: widget.dark
                    ? Colors.black.withOpacity(0.6)
                    : const Color(0xFF14161E).withOpacity(0.20),
                blurRadius: 30,
                offset: const Offset(0, -10),
                spreadRadius: -16,
              ),
              child: Row(children: [
                const SizedBox(width: 2),
                GlassCircleButton(
                  dark: widget.dark,
                  icon: Icons.add_rounded,
                  size: 38, iconSize: 22,
                  bg: widget.dark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.black.withOpacity(0.08),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: _onTyping,
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                    style: manrope(size: 14, weight: FontWeight.w500, color: fg, letterSpacing: -0.07),
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: manrope(size: 14, weight: FontWeight.w500, color: sub, letterSpacing: -0.07),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: GlassCircleButton(
                    dark: widget.dark,
                    icon: Icons.send_rounded,
                    size: 38, iconSize: 18,
                    bg: widget.dark ? Colors.white : const Color(0xFF0A0A0A),
                    fg: widget.dark ? const Color(0xFF0A0A0A) : Colors.white,
                  ),
                ),
                const SizedBox(width: 2),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Bubble ───────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final bool isMe;
  final bool dark;
  final bool last;
  final bool isPending; // optimistic, not yet confirmed by server
  const _Bubble({
    required this.m,
    required this.isMe,
    required this.dark,
    required this.last,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6))
        : const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(20));

    final timeStr =
        '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
    final read = m.readBy.length > 1;

    return Opacity(
      opacity: isPending ? 0.65 : 1.0, // dim pending messages slightly
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _bubbleBox(dark, radius),
              if (last)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(timeStr,
                        style: manrope(
                            size: 10.5,
                            weight: FontWeight.w500,
                            color: sub,
                            letterSpacing: -0.05)),
                    if (m.encryptedAesKeys.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_rounded, size: 9, color: sub.withOpacity(0.6)),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 5),
                      Icon(
                        isPending
                            ? Icons.access_time_rounded
                            : Icons.done_all_rounded,
                        size: 13,
                        color: (read && !isPending) ? fg : sub,
                      ),
                    ],
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubbleBox(bool dark, BorderRadius radius) {
    if (isMe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? Colors.white : const Color(0xFF0A0A0A),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.white.withOpacity(0.20)
                  : const Color(0xFF14161E).withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Text(m.text,
            style: manrope(
                size: 14.5,
                weight: FontWeight.w500,
                color: dark ? const Color(0xFF0A0A0A) : Colors.white,
                letterSpacing: -0.07,
                height: 1.4)),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.78),
            border: Border.all(
                color: dark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.95)),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: dark
                    ? Colors.black.withOpacity(0.6)
                    : const Color(0xFF14161E).withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -12,
              ),
            ],
          ),
          child: Text(m.text,
              style: manrope(
                  size: 14.5,
                  weight: FontWeight.w500,
                  color: GlassTokens.fg(dark),
                  letterSpacing: -0.07,
                  height: 1.4)),
        ),
      ),
    );
  }
}

// ── Typing bubble ────────────────────────────────────────────

class _BubbleTyping extends StatelessWidget {
  final bool dark;
  final Color sub;
  const _BubbleTyping({required this.dark, required this.sub});

  @override
  Widget build(BuildContext context) {
    const br = BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(18),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.75),
              border: Border.all(
                  color: dark
                      ? Colors.white.withOpacity(0.10)
                      : Colors.white.withOpacity(0.95)),
              borderRadius: br,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _TypingDot(delay: 0),
              const SizedBox(width: 5),
              _TypingDot(delay: 150),
              const SizedBox(width: 5),
              _TypingDot(delay: 300),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1200))
        ..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = ((_c.value * 1200) - widget.delay) % 1200 / 1200;
        final v = (t >= 0 && t <= 0.8)
            ? (t < 0.4 ? t / 0.4 : (0.8 - t) / 0.4)
            : 0.0;
        final scale = 0.7 + 0.3 * v.clamp(0.0, 1.0);
        final opacity = 0.4 + 0.6 * v.clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (dark ? Colors.white : Colors.black).withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }
}
