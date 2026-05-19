// chat_screen.dart
// Conversation view — glass header, message bubbles (text + voice + typing), glass input.

import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
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
  String? _typingUserId;
  Timer? _typingTimer;
  late StreamSubscription _messageSub;
  late StreamSubscription _typingSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    ChatService().markAsRead(widget.conversation.id);

    _messageSub = ChatService().messageStream.listen((msg) {
      if (msg.conversationId == widget.conversation.id) {
        setState(() {
          // insert at top because ListView is reversed
          _messages.insert(0, msg);
          if (msg.senderId == _typingUserId) {
            _typingUserId = null; // stop typing if they sent a message
          }
        });
        ChatService().markAsRead(widget.conversation.id);
      }
    });

    _typingSub = ChatService().typingStream.listen((event) {
      if (event['conversation_id'] == widget.conversation.id && event['user_id'] != widget.myUserId) {
        setState(() {
          _typingUserId = event['user_id'];
        });
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _typingUserId = null;
            });
          }
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
    try {
      final msgs = await ChatService().getMessages(widget.conversation.id);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    ChatService().sendMessage(widget.conversation.id, text);
    _textController.clear();
  }

  void _onTyping(String text) {
    if (text.isNotEmpty) {
      ChatService().sendTyping(widget.conversation.id);
    }
  }

  void _deleteConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this conversation? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      showDialog(
        context: context, barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator())
      );
      try {
        await ChatService().deleteConversation(widget.conversation.id);
        if (mounted) {
          Navigator.pop(context); // pop loading
          Navigator.pop(context, true); // pop chat screen, returning true to refresh
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // pop loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
        }
      }
    }
  }

  void _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Delete this message for everyone?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChatService().deleteMessage(widget.conversation.id, messageId);
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == messageId);
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);
    final otherUser = widget.conversation.getOtherParticipant(widget.myUserId);

    // Group consecutive same-side messages
    final runs = <List<ChatMessage>>[];
    // _messages is new-to-old (because of DB sorting). We iterate from old to new or handle grouped logic.
    // For reversed ListView, index 0 is at bottom (newest).
    // Let's group them properly while keeping it simple.
    
    return Scaffold(
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(children: [
        GlassBackdrop(dark: widget.dark),

        // Messages
        Positioned.fill(
          top: 76, bottom: 76,
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
            controller: _scrollController,
            reverse: true, // newest at bottom
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: _messages.length + (_typingUserId != null ? 1 : 0),
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
              
              // check if last in run (meaning it's the newest message of the consecutive block)
              // Since it's reversed, index-1 is newer.
              bool last = true;
              if (index > 0) {
                final newerMsg = _messages[index - 1];
                if (newerMsg.senderId == msg.senderId) last = false;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: GestureDetector(
                  onLongPress: isMe ? () => _deleteMessage(msg.id) : null,
                  child: _Bubble(m: msg, isMe: isMe, dark: widget.dark, last: last),
                ),
              );
            },
          ),
        ),

        // Header
        Positioned(
          top: 10, left: 12, right: 12,
          child: GlassHeader(
            dark: widget.dark, height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: fg, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: monoAvatar(widget.dark, 0)),
                  alignment: Alignment.center,
                  child: Text(otherUser.username[0].toUpperCase(),
                    style: manrope(size: 15, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
                ),
                // Positioned(right: -1, bottom: -1, child: Container(
                //   width: 11, height: 11,
                //   decoration: BoxDecoration(
                //     shape: BoxShape.circle,
                //     color: widget.dark ? Colors.white : const Color(0xFF0A0A0A),
                //     border: Border.all(color: widget.dark ? const Color(0xFF0C0C0E) : const Color(0xFFFAFAFA), width: 2),
                //   ),
                // )),
              ]),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(otherUser.username, style: manrope(size: 15, weight: FontWeight.w800, color: fg, letterSpacing: -0.225)),
                const SizedBox(height: 2),
                Text('Active now', style: manrope(size: 11, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
              ])),
              GlassCircleButton(dark: widget.dark, icon: Icons.call_outlined, iconSize: 18),
              const SizedBox(width: 6),
              GlassCircleButton(dark: widget.dark, icon: Icons.videocam_outlined, iconSize: 20),
              const SizedBox(width: 6),
              GlassCircleButton(dark: widget.dark, icon: Icons.info_outline_rounded, iconSize: 18),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _deleteConversation,
                child: GlassCircleButton(dark: widget.dark, icon: Icons.delete_outline_rounded, iconSize: 18, fg: Colors.red),
              ),
            ]),
          ),
        ),

        // Input bar
        Positioned(
          bottom: 10, left: 12, right: 12,
          child: SizedBox(
            height: 54,
            child: GlassSurface(
              dark: widget.dark,
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              blurSigma: 28,
              shadow: BoxShadow(
                color: widget.dark ? Colors.black.withOpacity(0.6) : const Color(0xFF14161E).withOpacity(0.20),
                blurRadius: 30, offset: const Offset(0, -10), spreadRadius: -16,
              ),
              child: Row(children: [
                const SizedBox(width: 2),
                GlassCircleButton(
                  dark: widget.dark, icon: Icons.add_rounded, size: 38, iconSize: 22,
                  bg: widget.dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _textController,
                  onChanged: _onTyping,
                  onSubmitted: (_) => _sendMessage(),
                  style: manrope(size: 14, weight: FontWeight.w500, color: fg, letterSpacing: -0.07),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle: manrope(size: 14, weight: FontWeight.w500, color: sub, letterSpacing: -0.07),
                    border: InputBorder.none,
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: GlassCircleButton(
                    dark: widget.dark, icon: Icons.send_rounded, size: 38, iconSize: 18,
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

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final bool isMe;
  final bool dark;
  final bool last;
  const _Bubble({required this.m, required this.isMe, required this.dark, required this.last});

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    final radius = isMe
      ? const BorderRadius.only(
          topLeft: Radius.circular(20), topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20), bottomRight: Radius.circular(6))
      : const BorderRadius.only(
          topLeft: Radius.circular(20), topRight: Radius.circular(20),
          bottomLeft: Radius.circular(6), bottomRight: Radius.circular(20));

    final timeStr = '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
    final read = m.readBy.length > 1; // Simplification

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _bubbleBox(m, dark, radius),
            if (last) Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(timeStr, style: manrope(size: 10.5, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
                if (isMe) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.done_all_rounded, size: 13, color: read ? fg : sub),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleBox(ChatMessage m, bool dark, BorderRadius radius) {
    if (isMe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? Colors.white : const Color(0xFF0A0A0A),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: dark ? Colors.white.withOpacity(0.20) : const Color(0xFF14161E).withOpacity(0.35),
              blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -10,
            ),
          ],
        ),
        child: Text(m.text,
          style: manrope(
            size: 14.5, weight: FontWeight.w500,
            color: dark ? const Color(0xFF0A0A0A) : Colors.white,
            letterSpacing: -0.07, height: 1.4,
          )),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.78),
            border: Border.all(color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95)),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: dark ? Colors.black.withOpacity(0.6) : const Color(0xFF14161E).withOpacity(0.18),
                blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -12,
              ),
            ],
          ),
          child: Text(m.text,
            style: manrope(size: 14.5, weight: FontWeight.w500, color: GlassTokens.fg(dark), letterSpacing: -0.07, height: 1.4)),
        ),
      ),
    );
  }
}

class _BubbleTyping extends StatelessWidget {
  final bool dark;
  final Color sub;
  const _BubbleTyping({required this.dark, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18), topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.75),
              border: Border.all(color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
              ),
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
  final int delay; // ms
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = ((_c.value * 1200) - widget.delay) % 1200 / 1200;
        final v = (t >= 0 && t <= 0.8)
            ? (t < 0.4 ? t / 0.4 : (0.8 - t) / 0.4)
            : 0.0;
        final scale = 0.7 + 0.3 * v.clamp(0, 1);
        final opacity = 0.4 + 0.6 * v.clamp(0, 1);
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
