// chat_list_screen.dart
// BUGS FIXED:
// 1. getConversations() always threw TypeError (ApiService.get cast fix in chat_service.dart)
//    — chat list now actually loads conversations from MongoDB
// 2. Every incoming WebSocket message triggered full API refetch (inefficient)
//    — now updates conversation in-place, only refetches when needed
// 3. No error state shown to user — now shows retry button on network failure
// 4. otherUser.username[0] could crash if username empty — guarded with isNotEmpty
// 5. No safe-area top padding — header overlapped status bar on some devices

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import 'glass_common.dart';
import 'chat_screen.dart';
import 'search_screen.dart';

class ActiveUser {
  final String name;
  final bool story;
  const ActiveUser(this.name, this.story);
}

const _active = <ActiveUser>[
  ActiveUser('mikhail', true),
  ActiveUser('aanya_', false),
  ActiveUser('devon.b', true),
  ActiveUser('kiraa', false),
  ActiveUser('ren.x', false),
  ActiveUser('noor.j', true),
];

class ChatListScreen extends StatefulWidget {
  final bool dark;
  const ChatListScreen({super.key, required this.dark});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  List<ChatConversation> _conversations = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reconnect WebSocket when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      ChatService().connectWebSocket();
      _loadConversations();
    }
  }

  Future<void> _initData() async {
    _myUserId = await AuthService.getCurrentUserId();
    // Connect WS and load conversations in parallel for faster startup
    await Future.wait([
      ChatService().connectWebSocket(),
      _loadConversations(),
    ]);

    // FIX: instead of refetching ALL conversations on every message,
    // update the matching conversation in-place (fast, no API call).
    ChatService().messageStream.listen((msg) {
      if (!mounted) return;
      final idx = _conversations.indexWhere((c) => c.id == msg.conversationId);
      if (idx == -1) {
        // New conversation appeared — do a full refresh
        _loadConversations();
        return;
      }
      final old = _conversations[idx];
      final updatedUnread = Map<String, int>.from(old.unreadCounts);
      // Increment unread for everyone except sender
      for (final p in old.participants) {
        if (p.id != msg.senderId) {
          updatedUnread[p.id] = (updatedUnread[p.id] ?? 0) + 1;
        }
      }
      final updated = ChatConversation(
        id: old.id,
        participants: old.participants,
        lastMessage: msg.text,
        lastMessageTime: msg.createdAt,
        unreadCounts: updatedUnread,
        isGroup: old.isGroup,
        name: old.name,
      );
      setState(() {
        _conversations.removeAt(idx);
        _conversations.insert(0, updated); // move to top
      });
    });
  }

  Future<void> _loadConversations() async {
    if (mounted) setState(() { _hasError = false; });
    try {
      final convs = await ChatService().getConversations();
      if (mounted) {
        setState(() {
          _conversations = convs;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _conversations.isEmpty; // only show error if no data
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);
    // FIX: respect status bar height
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(children: [
        GlassBackdrop(dark: widget.dark),

        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topPad + 10),

            // Header pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GlassHeader(
                dark: widget.dark,
                child: Row(children: [
                  Text('Messages',
                      style: manrope(
                          size: 17,
                          weight: FontWeight.w700,
                          color: fg,
                          letterSpacing: -0.34)),
                  const Spacer(),
                  GlassCircleButton(
                    dark: widget.dark,
                    icon: Icons.search_rounded,
                    iconSize: 18,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => SearchScreen(dark: widget.dark)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GlassCircleButton(
                      dark: widget.dark, icon: Icons.edit_outlined, iconSize: 18),
                ]),
              ),
            ),

            const SizedBox(height: 12),

            // Search bar (tappable, opens SearchScreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => SearchScreen(dark: widget.dark)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: widget.dark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.6),
                        border: Border.all(
                            color: widget.dark
                                ? Colors.white.withOpacity(0.10)
                                : Colors.white.withOpacity(0.95)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(children: [
                        Icon(Icons.search_rounded, size: 18, color: sub),
                        const SizedBox(width: 10),
                        Text('Search messages',
                            style: manrope(
                                size: 14,
                                weight: FontWeight.w500,
                                color: sub,
                                letterSpacing: -0.07)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Active now strip
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text('ACTIVE NOW',
                    style: manrope(
                        size: 11,
                        weight: FontWeight.w700,
                        color: sub,
                        letterSpacing: 0.88)),
              ),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _active.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) =>
                      _ActiveAvatar(a: _active[i], i: i, dark: widget.dark),
                ),
              ),
            ]),

            const SizedBox(height: 5),

            // Conversations list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('Could not load chats',
                                style: manrope(size: 14, color: sub)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadConversations,
                              child: const Text('Retry'),
                            ),
                          ]),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadConversations,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Text('CHATS',
                                    style: manrope(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: sub,
                                        letterSpacing: 0.88)),
                              ),
                              if (_conversations.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('No messages yet',
                                            style: manrope(
                                                size: 14,
                                                weight: FontWeight.w500,
                                                color: sub),
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 8),
                                        Text('Search for someone to start chatting',
                                            style: manrope(
                                                size: 12,
                                                weight: FontWeight.w400,
                                                color: sub),
                                            textAlign: TextAlign.center),
                                      ]),
                                ),
                              ..._conversations.asMap().entries.map((e) => Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 0, 10, 8),
                                    child: _ChatRow(
                                      c: e.value,
                                      i: e.key + 1,
                                      dark: widget.dark,
                                      myUserId: _myUserId ?? '',
                                      onReload: _loadConversations,
                                    ),
                                  )),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Active Avatar ────────────────────────────────────────────

class _ActiveAvatar extends StatelessWidget {
  final ActiveUser a;
  final int i;
  final bool dark;
  const _ActiveAvatar({required this.a, required this.i, required this.dark});

  @override
  Widget build(BuildContext context) {
    final sub = GlassTokens.sub(dark);
    return SizedBox(
      width: 62,
      child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
        SizedBox(
            width: 54,
            height: 54,
            child: Stack(clipBehavior: Clip.none, children: [
              if (a.story)
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: 3.49, endAngle: 9.77,
                      colors: dark
                          ? const [Colors.white, Color(0xFFAAAAAA), Color(0xFF555555), Colors.white]
                          : const [Color(0xFF111111), Color(0xFF555555), Color(0xFFAAAAAA), Color(0xFF111111)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA)),
                      padding: const EdgeInsets.all(2),
                      child: _innerAvatar(),
                    ),
                  ),
                )
              else
                _innerAvatar(),
              Positioned(
                right: 1, bottom: 1,
                child: Container(
                  width: 13, height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark ? Colors.white : const Color(0xFF0A0A0A),
                    border: Border.all(
                        color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA),
                        width: 2.5),
                  ),
                ),
              ),
            ])),
        const SizedBox(height: 5),
        Text(a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: manrope(size: 11, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
      ]),
    );
  }

  Widget _innerAvatar() => Container(
        decoration:
            BoxDecoration(shape: BoxShape.circle, gradient: monoAvatar(dark, i)),
        alignment: Alignment.center,
        child: Text(a.name[0].toUpperCase(),
            style: manrope(
                size: 18,
                weight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3)),
      );
}

// ── Chat Row ─────────────────────────────────────────────────

class _ChatRow extends StatelessWidget {
  final ChatConversation c;
  final int i;
  final bool dark;
  final String myUserId;
  final VoidCallback onReload;

  const _ChatRow({
    required this.c,
    required this.i,
    required this.dark,
    required this.myUserId,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    final otherUser = c.getOtherParticipant(myUserId);
    // FIX: guard against empty username to avoid RangeError
    final avatarLetter =
        otherUser.username.isNotEmpty ? otherUser.username[0].toUpperCase() : '?';

    final unread    = c.unreadCounts[myUserId] ?? 0;
    // Clean up encrypted/failed preview — show plain fallback instead
    final rawLast   = c.lastMessage ?? '';
    final lastText  = _cleanPreview(rawLast);
    final timeStr   = _formatTime(c.lastMessageTime);

    final previewColor  = unread > 0 ? fg : sub;
    final previewWeight = unread > 0 ? FontWeight.w600 : FontWeight.w500;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => ChatScreen(
              dark: dark,
              conversation: c,
              myUserId: myUserId,
            ),
            transitionDuration: const Duration(milliseconds: 350),
            reverseTransitionDuration: const Duration(milliseconds: 280),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(opacity: curved, child: child),
              );
            },
          ),
        );
        // Reload to refresh unread counts after returning
        onReload();
      },
      child: GlassSurface(
        dark: dark,
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // Avatar
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
                shape: BoxShape.circle, gradient: monoAvatar(dark, i)),
            alignment: Alignment.center,
            child: Text(avatarLetter,
                style: manrope(
                    size: 18,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.36)),
          ),
          const SizedBox(width: 12),
          // Name + preview
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherUser.username.isNotEmpty ? otherUser.username : otherUser.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: manrope(
                        size: 14.5,
                        weight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                        color: fg,
                        letterSpacing: -0.14),
                  ),
                  const SizedBox(height: 2),
                  Text(lastText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: manrope(
                          size: 12.5,
                          weight: previewWeight,
                          color: previewColor,
                          letterSpacing: -0.05)),
                ]),
          ),
          const SizedBox(width: 8),
          // Time + unread badge
          SizedBox(
            width: 40,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(timeStr,
                      style: manrope(
                          size: 11,
                          weight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          color: unread > 0 ? fg : sub,
                          letterSpacing: -0.05)),
                  if (unread > 0) ...[  // unread badge
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white : const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(unread > 99 ? '99+' : '$unread',
                          style: manrope(
                              size: 11,
                              weight: FontWeight.w800,
                              color: dark ? const Color(0xFF0A0A0A) : Colors.white,
                              letterSpacing: -0.1,
                              height: 1)),
                    ),
                  ],
                ]),
          ),
        ]),
      ),
    );
  }

  String _cleanPreview(String raw) {
    if (raw.isEmpty) return 'No messages yet';
    // Hide raw encrypted payloads and fallback strings from chat_service
    if (raw.contains('[Encrypted Message]') ||
        raw.startsWith('{"ct":') ||
        raw.startsWith('{"ct" :')) {
      return '\u{1F4AC} Message';
    }
    return raw;
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final localTime = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localTime);
    // Agar diff negative ho (future time) ya bahut chhota ho — 'now' dikhao
    if (diff.isNegative || diff.inSeconds < 30) return 'now';
    if (diff.inDays > 7) return '${localTime.day}/${localTime.month}';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}
