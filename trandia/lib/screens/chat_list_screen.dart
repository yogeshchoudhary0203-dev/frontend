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
import '../l10n/app_localizations.dart';
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
  double? _swipeStartX;
  double? _swipeStartY;
  bool _notificationsOn = true;

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

  void _handleBackSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null || velocity > -150 || !Navigator.of(context).canPop()) {
      return;
    }

    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);
    // FIX: respect status bar height
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _swipeStartX = e.position.dx;
          _swipeStartY = e.position.dy;
        },
        onPointerUp: (e) {
          if (_swipeStartX == null) return;
          final dx = e.position.dx - _swipeStartX!;
          final dy = (e.position.dy - (_swipeStartY ?? 0)).abs();
          if (dx > 60 && dy < dx * 0.65) {
            HapticFeedback.selectionClick();
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          }
          _swipeStartX = null;
          _swipeStartY = null;
        },
        onPointerCancel: (_) {
          _swipeStartX = null;
          _swipeStartY = null;
        },
        child: Stack(children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(children: [
                  GlassCircleButton(
                    dark: widget.dark,
                    icon: Icons.arrow_back_ios_new,
                    iconSize: 15,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 8),
                  Text('Messages'.tr(context),
                      style: manrope(
                          size: 17,
                          weight: FontWeight.w700,
                          color: fg,
                          letterSpacing: -0.34)),
                  const Spacer(),
                  GlassCircleButton(
                    dark: widget.dark,
                    icon: _notificationsOn
                        ? Icons.notifications_outlined
                        : Icons.notifications_off_outlined,
                    iconSize: 18,
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      setState(() {
                        _notificationsOn = !_notificationsOn;
                      });
                    },
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 10),

            // Active now strip
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text('FAVOURITES'.tr(context),
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

            _buildPillRow(context, widget.dark),
            const SizedBox(height: 5),

            // Conversations list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('Could not load chats'.tr(context),
                                style: manrope(size: 14, color: sub)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadConversations,
                              child: Text('Retry'.tr(context)),
                            ),
                          ]),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadConversations,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                            // +1 for header, +1 if empty state
                            itemCount: 1 + (_conversations.isEmpty ? 1 : _conversations.length),
                            itemBuilder: (context, index) {
                              // Header row
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Text('CHATS'.tr(context),
                                      style: manrope(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: sub,
                                          letterSpacing: 0.88)),
                                );
                              }
                              // Empty state
                              if (_conversations.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('No messages yet'.tr(context),
                                            style: manrope(
                                                size: 14,
                                                weight: FontWeight.w500,
                                                color: sub),
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 8),
                                        Text('Search for someone to start chatting'.tr(context),
                                            style: manrope(
                                                size: 12,
                                                weight: FontWeight.w400,
                                                color: sub),
                                            textAlign: TextAlign.center),
                                      ]),
                                );
                              }
                              // Conversation row (index - 1 because of header)
                              final i = index - 1;
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                                child: _ChatRow(
                                  c: _conversations[i],
                                  i: i + 1,
                                  dark: widget.dark,
                                  myUserId: _myUserId ?? '',
                                  onReload: _loadConversations,
                                ),
                              );
                            },
                          ),
                        ),
              ),

            // Search bar (tappable, opens SearchScreen) — moved to bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => SearchScreen(dark: widget.dark)),
                ),
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
                    Text('Search'.tr(context),
                        style: manrope(
                            size: 14,
                            weight: FontWeight.w500,
                            color: sub,
                            letterSpacing: -0.07)),
                  ]),
                ),
              ),
            ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildPillRow(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPill(context, 'Archived', Icons.archive_outlined, dark, false),
            const SizedBox(width: 8),
            _buildPill(context, 'Locked', Icons.lock_outline, dark, false),
            const SizedBox(width: 8),
            _buildPill(context, 'Blocked', Icons.block_outlined, dark, false),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(BuildContext context, String title, IconData icon, bool dark, bool isActive) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final bgColor = isActive
        ? (dark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1))
        : (dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03));

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (title != 'Chats') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: IconThemeData(color: fg),
                  title: Text(title.tr(context), style: manrope(size: 17, weight: FontWeight.w700, color: fg)),
                ),
                body: Stack(
                  children: [
                    GlassBackdrop(dark: dark),
                  ],
                ),
              ),
            ),
          );
        }
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? (dark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.12))
                : (dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? fg : sub),
            const SizedBox(width: 5),
            Text(
              title.tr(context),
              style: manrope(
                size: 12.5,
                weight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? fg : sub,
                letterSpacing: -0.12,
              ),
            ),
          ],
        ),
      ),
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
                    color: Colors.green,
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
    final lastText  = _cleanPreview(context, rawLast);
    final timeStr   = _formatTime(context, c.lastMessageTime);

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
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showChatOptions(context);
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
                      child: Text(unread > 4 ? '4+' : '$unread',
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

  void _showChatOptions(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final otherUser = c.getOtherParticipant(myUserId);
    final displayName = otherUser.username.isNotEmpty ? otherUser.username : otherUser.name;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      isScrollControlled: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.05)]
                    : [Colors.white.withOpacity(0.90), Colors.white.withOpacity(0.75)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: dark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: dark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dark ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Chat name
                  Text(
                    displayName,
                    style: manrope(
                      size: 16,
                      weight: FontWeight.w700,
                      color: fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose an action',
                    style: manrope(
                      size: 12,
                      weight: FontWeight.w500,
                      color: sub,
                      letterSpacing: -0.05,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 0.5,
                    color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                  // Options
                  _buildOptionTile(ctx, Icons.lock_outline, 'Locked', 'Lock this chat', dark, fg, sub),
                  _buildOptionDivider(dark),
                  _buildOptionTile(ctx, Icons.archive_outlined, 'Archived', 'Archive this chat', dark, fg, sub),
                  _buildOptionDivider(dark),
                  _buildOptionTile(ctx, Icons.block_outlined, 'Blocked', 'Block this user', dark, fg, sub),
                  _buildOptionDivider(dark),
                  _buildOptionTile(ctx, Icons.cleaning_services_outlined, 'Chat Clean', 'Clear chat history', dark, fg, sub),
                  const SizedBox(height: 8),
                  // Cancel button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: manrope(
                            size: 15,
                            weight: FontWeight.w600,
                            color: sub,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(BuildContext ctx, IconData icon, String title, String subtitle, bool dark, Color fg, Color sub) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                '$title applied',
                style: manrope(size: 13, weight: FontWeight.w600, color: Colors.white),
              ),
              backgroundColor: dark ? const Color(0xFF1A1A1C) : const Color(0xFF333333),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: manrope(size: 14.5, weight: FontWeight.w700, color: fg, letterSpacing: -0.1),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: manrope(size: 12, weight: FontWeight.w500, color: sub, letterSpacing: -0.05),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: sub),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionDivider(bool dark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 0.5,
      color: dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
    );
  }

  String _cleanPreview(BuildContext context, String raw) {
    if (raw.isEmpty) return 'No messages yet'.tr(context);
    // Hide raw encrypted payloads and fallback strings from chat_service
    if (raw.contains('[Encrypted Message]') ||
        raw.startsWith('{"ct":') ||
        raw.startsWith('{"ct" :')) {
      return '\u{1F4AC} ${'Message'.tr(context)}';
    }
    return raw;
  }

  String _formatTime(BuildContext context, DateTime? time) {
    if (time == null) return '';
    final localTime = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localTime);
    // Agar diff negative ho (future time) ya bahut chhota ho — 'now' dikhao
    if (diff.isNegative || diff.inSeconds < 30) return 'now'.tr(context);
    if (diff.inDays > 7) return '${localTime.day}/${localTime.month}';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now'.tr(context);
  }
}
