// chat_list_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/app_lock_service.dart';
import '../services/fcm_service.dart';
import '../services/block_service.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import 'glass_common.dart';
import 'chat_screen.dart';
import 'search_screen.dart';


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
  Set<String> _onlineUserIds = {};
  double? _swipeStartX;
  double? _swipeStartY;
  final _chatScroll = ScrollController();

  // Filter state — persisted in SharedPreferences
  Set<String> _lockedIds = {};
  Set<String> _archivedIds = {};
  Set<String> _blockedIds = {};
  String _activeFilter = 'all'; // 'all' | 'locked' | 'archived' | 'blocked'
  bool _lockedTabUnlocked = false; // true once user has verified PIN in this session

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
  }

  @override
  void dispose() {
    _chatScroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatService().connectWebSocket();
      _loadConversations();
    }
  }

  Future<void> _initData() async {
    _myUserId = await AuthService.getCurrentUserId();
    // Sync all notification prefs (bell state is driven by ValueNotifier — no manual setState needed)
    await FcmService.reloadNotificationSettings();
    // Load server blocks BEFORE filter state so merge logic works correctly
    await BlockService.instance.load();
    await Future.wait([
      ChatService().connectWebSocket(),
      _loadConversations(),
    ]);
    // Filter state loaded after conversations so server blocks can be merged
    await _loadFilterState();

    // Sync initial online state (WS may already be connected from before)
    _onlineUserIds = Set.from(ChatService().onlineUserIds);

    ChatService().presenceStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _onlineUserIds = Set.from(ChatService().onlineUserIds);
      });
    });

    ChatService().messageStream.listen((msg) {
      if (!mounted) return;
      final idx = _conversations.indexWhere((c) => c.id == msg.conversationId);
      if (idx == -1) {
        _loadConversations();
        return;
      }
      final old = _conversations[idx];
      final updatedUnread = Map<String, int>.from(old.unreadCounts);
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
        _conversations.insert(0, updated);
      });
    });
  }

  // ── SharedPreferences persistence ────────────────────────────

  Future<void> _loadFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final lockedIds   = Set<String>.from(prefs.getStringList('chat_locked')   ?? []);
    final archivedIds = Set<String>.from(prefs.getStringList('chat_archived') ?? []);
    var   blockedIds  = Set<String>.from(prefs.getStringList('chat_blocked')  ?? []);

    // Merge with server blocks — if a conversation's other participant is
    // server-blocked, mark that conversation as blocked locally too.
    final serverBlockedUserIds = BlockService.instance.blockedIds;
    final myId = _myUserId ?? '';
    if (serverBlockedUserIds.isNotEmpty && myId.isNotEmpty) {
      for (final conv in _conversations) {
        final other = conv.getOtherParticipant(myId);
        if (serverBlockedUserIds.contains(other.id)) {
          blockedIds.add(conv.id);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _lockedIds   = lockedIds;
      _archivedIds = archivedIds;
      _blockedIds  = blockedIds;
    });

    // Persist merged state
    await prefs.setStringList('chat_blocked', blockedIds.toList());
  }

  Future<void> _saveFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('chat_locked', _lockedIds.toList());
    await prefs.setStringList('chat_archived', _archivedIds.toList());
    await prefs.setStringList('chat_blocked', _blockedIds.toList());
  }

  // ── Toggle actions (called from _ChatRow via callbacks) ──────

  void _toggleLock(String convId) {
    setState(() {
      if (_lockedIds.contains(convId)) {
        _lockedIds.remove(convId);
      } else {
        _lockedIds.add(convId);
        _archivedIds.remove(convId);
        _blockedIds.remove(convId);
      }
    });
    _saveFilterState();
  }

  void _toggleArchive(String convId) {
    setState(() {
      if (_archivedIds.contains(convId)) {
        _archivedIds.remove(convId);
      } else {
        _archivedIds.add(convId);
        _lockedIds.remove(convId);
        _blockedIds.remove(convId);
      }
    });
    _saveFilterState();
  }

  void _toggleBlock(String convId, String otherUserId) {
    final isCurrentlyBlocked = _blockedIds.contains(convId);
    setState(() {
      if (isCurrentlyBlocked) {
        _blockedIds.remove(convId);
      } else {
        _blockedIds.add(convId);
        _lockedIds.remove(convId);
        _archivedIds.remove(convId);
      }
    });
    _saveFilterState();
    // Server-side block/unblock
    if (isCurrentlyBlocked) {
      BlockService.instance.unblockUser(otherUserId).catchError((_) {
        // rollback on failure
        if (mounted) setState(() => _blockedIds.add(convId));
        _saveFilterState();
      });
    } else {
      BlockService.instance.blockUser(otherUserId).catchError((_) {
        if (mounted) setState(() => _blockedIds.remove(convId));
        _saveFilterState();
      });
    }
  }

  // ── Filtered list ─────────────────────────────────────────────

  List<ChatConversation> get _filteredConversations {
    switch (_activeFilter) {
      case 'locked':
        return _conversations.where((c) => _lockedIds.contains(c.id)).toList();
      case 'archived':
        return _conversations.where((c) => _archivedIds.contains(c.id)).toList();
      case 'blocked':
        return _conversations.where((c) => _blockedIds.contains(c.id)).toList();
      default:
        return _conversations.where((c) =>
          !_lockedIds.contains(c.id) &&
          !_archivedIds.contains(c.id) &&
          !_blockedIds.contains(c.id)
        ).toList();
    }
  }

  String _emptyStateMessage(BuildContext context) {
    switch (_activeFilter) {
      case 'locked':   return 'No locked chats'.tr(context);
      case 'archived': return 'No archived chats'.tr(context);
      case 'blocked':  return 'No blocked chats'.tr(context);
      default:         return 'No messages yet'.tr(context);
    }
  }

  String _emptyStateSubtitle(BuildContext context) {
    switch (_activeFilter) {
      case 'locked':   return 'Hold a chat and tap Lock to add it here'.tr(context);
      case 'archived': return 'Hold a chat and tap Archive to add it here'.tr(context);
      case 'blocked':  return 'Hold a chat and tap Block to add it here'.tr(context);
      default:         return 'Search for someone to start chatting'.tr(context);
    }
  }

  // ─────────────────────────────────────────────────────────────

  Future<void> _loadConversations() async {
    if (mounted) setState(() { _hasError = false; });
    try {
      // stale-while-revalidate: returns local cache immediately, then calls
      // onRefreshed when fresh API data arrives so the UI updates silently.
      final convs = await ChatService().getConversations(
        onRefreshed: (fresh) {
          if (mounted) setState(() { _conversations = fresh; });
        },
      );
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
          _hasError = _conversations.isEmpty;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);
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

              // Header
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
                    ValueListenableBuilder<bool>(
                      valueListenable: FcmService.chatNotifsNotifier,
                      builder: (_, notifsOn, __) => GlassCircleButton(
                        dark: widget.dark,
                        icon: notifsOn
                            ? Icons.notifications_outlined
                            : Icons.notifications_off_outlined,
                        iconSize: 18,
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          // Toggle only the messages flag (not master)
                          FcmService.setChatNotificationsEnabled(!FcmService.chatNotificationsEnabled);
                        },
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 10),


              _buildPillRow(context, widget.dark),
              const SizedBox(height: 5),

              // Favourites strip — only in 'all' filter and when not loading
              if (_activeFilter == 'all' && !_isLoading && _conversations.isNotEmpty)
                _buildFavouritesStrip(context),

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
                            child: _buildConversationList(context, sub),
                          ),
              ),
            ],
          ),

          // Floating Search Bar at the bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 8,
            child: _AnimatedFloatingSearchBar(dark: widget.dark),
          ),
        ]),
      ),
    );
  }

  // ── Favourites strip (top recent chat partners) ───────────────
  Widget _buildFavouritesStrip(BuildContext context) {
    final fg = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);
    final myId = _myUserId ?? '';

    final recent = _conversations
        .where((c) => !_lockedIds.contains(c.id) && !_archivedIds.contains(c.id) && !_blockedIds.contains(c.id))
        .take(8)
        .toList();

    // Online users first
    recent.sort((a, b) {
      final aOnline = _onlineUserIds.contains(a.getOtherParticipant(myId).id);
      final bOnline = _onlineUserIds.contains(b.getOtherParticipant(myId).id);
      if (aOnline == bOnline) return 0;
      return aOnline ? -1 : 1;
    });

    final display = recent.take(6).toList();
    if (display.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            'FAVOURITES'.tr(context),
            style: manrope(size: 11, weight: FontWeight.w700, color: sub, letterSpacing: 0.88),
          ),
        ),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: display.length,
            itemBuilder: (ctx, i) {
              final conv = display[i];
              final other = conv.getOtherParticipant(myId);
              final unread = (conv.unreadCounts[myId] ?? 0) > 0;
              final isOnline = _onlineUserIds.contains(other.id);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      dark: widget.dark,
                      conversation: conv,
                      myUserId: myId,
                    ),
                  ));
                },
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: widget.dark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                            backgroundImage: (other.picture != null && other.picture!.isNotEmpty)
                                ? NetworkImage(other.picture!)
                                : null,
                            child: (other.picture == null || other.picture!.isEmpty)
                                ? Text(
                                    other.name.isNotEmpty ? other.name[0].toUpperCase() : '?',
                                    style: manrope(size: 18, weight: FontWeight.w700, color: fg),
                                  )
                                : null,
                          ),
                          if (unread)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        other.name.isNotEmpty ? other.name.split(' ').first : other.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: manrope(size: 11, weight: FontWeight.w600, color: fg),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Locked chat PIN dialog ────────────────────────────────────
  Future<void> _showPinDialog() async {
    final lockEnabled = await AppLockService.isEnabled();
    if (!lockEnabled) {
      // No app lock set — just switch to locked tab
      if (mounted) setState(() { _activeFilter = 'locked'; _lockedTabUnlocked = true; });
      return;
    }

    final pinLength = await AppLockService.getPinLength();
    if (!mounted) return;

    final controller = TextEditingController();
    bool hasError = false;
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: dark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: fg, size: 20),
              const SizedBox(width: 8),
              Text('Enter PIN'.tr(context),
                  style: manrope(size: 16, weight: FontWeight.w700, color: fg)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your $pinLength-digit app lock PIN'.tr(context),
                  style: manrope(size: 13, color: sub)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: pinLength,
                onChanged: (_) { if (hasError) setS(() { hasError = false; }); },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '•' * pinLength,
                  hintStyle: manrope(size: 14, color: sub),
                  errorText: hasError ? 'Incorrect PIN'.tr(context) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: fg, width: 1.5),
                  ),
                ),
                style: manrope(size: 22, weight: FontWeight.w700, color: fg, letterSpacing: 8),
                textAlign: TextAlign.center,
                onSubmitted: (val) async {
                  final ok = await AppLockService.verifyPin(val);
                  if (ok) {
                    Navigator.of(ctx).pop();
                    if (mounted) setState(() { _activeFilter = 'locked'; _lockedTabUnlocked = true; });
                  } else {
                    controller.clear();
                    setS(() { hasError = true; });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel'.tr(context), style: manrope(size: 14, color: sub)),
            ),
            TextButton(
              onPressed: () async {
                final ok = await AppLockService.verifyPin(controller.text);
                if (ok) {
                  Navigator.of(ctx).pop();
                  if (mounted) setState(() { _activeFilter = 'locked'; _lockedTabUnlocked = true; });
                } else {
                  controller.clear();
                  setS(() { hasError = true; });
                }
              },
              child: Text('Unlock'.tr(context),
                  style: manrope(size: 14, weight: FontWeight.w700, color: fg)),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Widget _buildConversationList(BuildContext context, Color sub) {
    final list = _filteredConversations;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView.builder(
      controller: _chatScroll,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(0, 0, 0, 76 + bottomInset),
      itemCount: 1 + (list.isEmpty ? 1 : list.length),
      itemBuilder: (context, index) {
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
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_emptyStateMessage(context),
                    style: manrope(size: 14, weight: FontWeight.w500, color: sub),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_emptyStateSubtitle(context),
                    style: manrope(size: 12, weight: FontWeight.w400, color: sub),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }
        final i = index - 1;
        final conv = list[i];
        return _ChatIslandScrollCard(
          controller: _chatScroll,
          index: i,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: _ChatRow(
              c: conv,
              i: i + 1,
              dark: widget.dark,
              myUserId: _myUserId ?? '',
              onReload: _loadConversations,
              isLocked: _lockedIds.contains(conv.id),
              isArchived: _archivedIds.contains(conv.id),
              isBlocked: _blockedIds.contains(conv.id),
              isOnline: _onlineUserIds.contains(conv.getOtherParticipant(_myUserId ?? '').id),
              onLock: () => _toggleLock(conv.id),
              onArchive: () => _toggleArchive(conv.id),
              onBlock: () => _toggleBlock(
                conv.id,
                conv.getOtherParticipant(_myUserId ?? '').id,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPillRow(BuildContext context, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPill(context, 'all', 'All', Icons.chat_bubble_outline, dark),
            const SizedBox(width: 8),
            _buildPill(context, 'archived', 'Archived', Icons.archive_outlined, dark),
            const SizedBox(width: 8),
            _buildPill(context, 'locked', 'Locked', Icons.lock_outline, dark),
            const SizedBox(width: 8),
            _buildPill(context, 'blocked', 'Blocked', Icons.block_outlined, dark),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(BuildContext context, String filter, String title, IconData icon, bool dark) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final isActive = _activeFilter == filter;

    final bgColor = isActive
        ? (dark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.10))
        : (dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03));

    // Badge count for each filter
    int count = 0;
    if (filter == 'locked')   count = _lockedIds.length;
    if (filter == 'archived') count = _archivedIds.length;
    if (filter == 'blocked')  count = _blockedIds.length;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (filter == 'locked' && !_lockedTabUnlocked) {
          _showPinDialog();
        } else {
          setState(() {
            _activeFilter = filter;
            // Reset unlock flag when leaving locked tab
            if (filter != 'locked') _lockedTabUnlocked = false;
          });
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
                ? (dark ? Colors.white.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.12))
                : (dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06)),
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
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? (dark ? Colors.white : Colors.black)
                      : (dark ? Colors.white.withValues(alpha: 0.20) : Colors.black.withValues(alpha: 0.10)),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: manrope(
                    size: 10,
                    weight: FontWeight.w800,
                    color: isActive
                        ? (dark ? Colors.black : Colors.white)
                        : (dark ? Colors.white : Colors.black),
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// ── Chat Row ─────────────────────────────────────────────────

class _ChatRow extends StatelessWidget {
  final ChatConversation c;
  final int i;
  final bool dark;
  final String myUserId;
  final VoidCallback onReload;
  final bool isLocked;
  final bool isArchived;
  final bool isBlocked;
  final bool isOnline;
  final VoidCallback onLock;
  final VoidCallback onArchive;
  final VoidCallback onBlock;

  const _ChatRow({
    required this.c,
    required this.i,
    required this.dark,
    required this.myUserId,
    required this.onReload,
    required this.isLocked,
    required this.isArchived,
    required this.isBlocked,
    this.isOnline = false,
    required this.onLock,
    required this.onArchive,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    final otherUser = c.getOtherParticipant(myUserId);

    final unread    = c.unreadCounts[myUserId] ?? 0;
    final rawLast   = c.lastMessage ?? '';
    final lastText  = _cleanPreview(context, rawLast);
    final timeStr   = _formatTime(context, c.lastMessageTime);

    final previewColor  = unread > 0 ? fg : sub;
    final previewWeight = unread > 0 ? FontWeight.w600 : FontWeight.w500;

    // Status icon to show on the row
    IconData? statusIcon;
    if (isLocked)   statusIcon = Icons.lock_rounded;
    if (isArchived) statusIcon = Icons.archive_rounded;
    if (isBlocked)  statusIcon = Icons.block_rounded;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        // Blocked users — confirm before opening
        if (isBlocked) {
          final open = await _confirmDialog(
            context,
            title: 'Chat is Blocked',
            message: 'This user is blocked. You can unblock them from the hold menu.',
            confirmText: 'Open Anyway',
          );
          if (!open) return;
        }
        if (!context.mounted) return;
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
        onReload();
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showChatOptions(context);
      },
      child: GlassSurface(
        dark: dark,
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        blurSigma: 44,
        bgColors: dark
            ? [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)]
            : [Colors.white.withValues(alpha: 0.65), Colors.white.withValues(alpha: 0.40)],
        borderColor: dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.85),
        borderWidth: 0.5,
        child: Row(children: [
          // Avatar with optional status/online overlay
          Stack(clipBehavior: Clip.none, children: [
            UserAvatar(
              pictureUrl: otherUser.picture,
              name: otherUser.name.isNotEmpty ? otherUser.name : otherUser.username,
              size: 46,
              dark: dark,
              index: i,
            ),
            if (statusIcon != null)
              Positioned(
                right: -2, bottom: -2,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark ? const Color(0xFF1A1A1C) : const Color(0xFFF0F0F0),
                    border: Border.all(
                      color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(statusIcon, size: 10,
                      color: isBlocked ? Colors.redAccent : sub),
                ),
              )
            else if (isOnline)
              Positioned(
                right: -2, bottom: -2,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA),
                      width: 2,
                    ),
                  ),
                ),
              ),
          ]),
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
                  Text(
                    isBlocked ? 'Blocked'.tr(context) : lastText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: manrope(
                        size: 12.5,
                        weight: previewWeight,
                        color: isBlocked ? Colors.redAccent.withValues(alpha: 0.7) : previewColor,
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
                  if (unread > 0 && !isBlocked) ...[
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
      barrierColor: Colors.black.withValues(alpha: 0.5),
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
                    ? [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.05)]
                    : [Colors.white.withValues(alpha: 0.90), Colors.white.withValues(alpha: 0.75)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: dark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: dark ? Colors.black.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.12),
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
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: dark ? Colors.white.withValues(alpha: 0.20) : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: manrope(size: 16, weight: FontWeight.w700, color: fg, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose an action',
                    style: manrope(size: 12, weight: FontWeight.w500, color: sub, letterSpacing: -0.05),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 0.5,
                    color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),

                  // Lock / Unlock
                  _buildOptionTile(
                    ctx,
                    isLocked ? Icons.lock_open_rounded : Icons.lock_outline,
                    isLocked ? 'Unlock' : 'Lock',
                    isLocked ? 'Remove from locked chats' : 'Hide in Locked tab',
                    dark, fg, sub,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onLock();
                      _showSnackbar(ctx, isLocked ? 'Chat unlocked' : 'Chat locked', dark);
                    },
                  ),
                  _buildOptionDivider(dark),

                  // Archive / Unarchive
                  _buildOptionTile(
                    ctx,
                    isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                    isArchived ? 'Unarchive' : 'Archive',
                    isArchived ? 'Move back to main chats' : 'Hide in Archived tab',
                    dark, fg, sub,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onArchive();
                      _showSnackbar(ctx, isArchived ? 'Chat unarchived' : 'Chat archived', dark);
                    },
                  ),
                  _buildOptionDivider(dark),

                  // Block / Unblock
                  _buildOptionTile(
                    ctx,
                    isBlocked ? Icons.check_circle_outline : Icons.block_outlined,
                    isBlocked ? 'Unblock' : 'Block',
                    isBlocked ? 'Allow messages from this user' : 'Block messages from this user',
                    dark, fg, sub,
                    isDestructive: !isBlocked,
                    onTap: () async {
                      if (!isBlocked) {
                        // Confirm BEFORE closing bottom sheet so ctx stays valid
                        final confirmed = await _confirmDialog(
                          ctx,
                          title: 'Block $displayName?',
                          message: 'They will be moved to your Blocked tab.',
                          confirmText: 'Block',
                          isDestructive: true,
                        );
                        if (!confirmed) return;
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      onBlock();
                      if (ctx.mounted) {
                        _showSnackbar(ctx, isBlocked ? '$displayName unblocked' : '$displayName blocked', dark);
                      }
                    },
                  ),
                  _buildOptionDivider(dark),

                  // Chat Clean
                  _buildOptionTile(
                    ctx,
                    Icons.cleaning_services_outlined,
                    'Chat Clean',
                    'Clear chat history',
                    dark, fg, sub,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showSnackbar(ctx, 'Chat cleared', dark);
                    },
                  ),

                  const SizedBox(height: 8),
                  // Cancel
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
                          color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: manrope(size: 15, weight: FontWeight.w600, color: sub),
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

  Widget _buildOptionTile(
    BuildContext ctx,
    IconData icon,
    String title,
    String subtitle,
    bool dark,
    Color fg,
    Color sub, {
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final titleColor = isDestructive ? Colors.redAccent : fg;
    final iconColor  = isDestructive ? Colors.redAccent : fg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.redAccent.withValues(alpha: 0.10)
                      : (dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: manrope(size: 14.5, weight: FontWeight.w700, color: titleColor, letterSpacing: -0.1)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: manrope(size: 12, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
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
      color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
    );
  }

  void _showSnackbar(BuildContext ctx, String message, bool dark) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message,
            style: manrope(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: dark ? const Color(0xFF1A1A1C) : const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    final dark = this.dark;
    final fg   = GlassTokens.fg(dark);
    final sub  = GlassTokens.sub(dark);

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AlertDialog(
          backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: manrope(size: 16, weight: FontWeight.w700, color: fg, letterSpacing: -0.2)),
          content: Text(message,
              style: manrope(size: 13, weight: FontWeight.w500, color: sub)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: manrope(size: 14, weight: FontWeight.w600, color: sub)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmText,
                  style: manrope(
                    size: 14,
                    weight: FontWeight.w700,
                    color: isDestructive ? Colors.redAccent : fg,
                  )),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  String _cleanPreview(BuildContext context, String raw) {
    if (raw.isEmpty) return 'No messages yet'.tr(context);
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
    if (diff.isNegative || diff.inSeconds < 30) return 'now'.tr(context);
    if (diff.inDays > 7) return '${localTime.day}/${localTime.month}';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now'.tr(context);
  }
}

/// Smooth bottom-entry animation for chat rows.
/// Cards slide in from the bottom and collapse/stack as they reach the bottom edge,
/// giving a natural feel when scrolling down.
/// Stops well above the floating search bar so they never overlap.
class _ChatIslandScrollCard extends StatefulWidget {
  final ScrollController controller;
  final int index;
  final Widget child;

  const _ChatIslandScrollCard({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  State<_ChatIslandScrollCard> createState() => _ChatIslandScrollCardState();
}

class _ChatIslandScrollCardState extends State<_ChatIslandScrollCard> {
  /// How many px from the bottom edge the collapse starts.
  static const double _collapseRange = 120;
  /// How many px from the bottom edge the entry animation starts.
  static const double _entryRange = 160;
  /// Extra lift so cards collapse above the search bar (~56 bar + 8 gap + safe area).
  static const double _pinLift = 88;

  double _globalY = 0;
  double _itemHeight = 82;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurePosition();
    });
  }

  void _measurePosition() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && mounted) {
      final newY = box.localToGlobal(Offset.zero).dy;
      final newH = box.size.height;
      if (newY != _globalY || newH != _itemHeight || !_measured) {
        setState(() {
          _globalY = newY;
          _itemHeight = newH;
          _measured = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      child: widget.child,
      builder: (context, child) {
        if (!widget.controller.hasClients) return child!;

        // Re-measure position on every scroll frame for accuracy
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          _globalY = box.localToGlobal(Offset.zero).dy;
          _itemHeight = box.size.height;
          _measured = true;
        }

        if (!_measured) return child!;

        final screenHeight = MediaQuery.sizeOf(context).height;
        final bottomPad = MediaQuery.paddingOf(context).bottom;
        final itemTopY = _globalY;
        final itemBottomY = _globalY + _itemHeight;
        final bottomStackY = screenHeight - bottomPad - _pinLift;

        // ── Bottom-collapse: item approaching the bottom edge ──
        final distanceToBottom = bottomStackY - itemBottomY;
        final collapseRaw = (1.0 - (distanceToBottom / _collapseRange))
            .clamp(0.0, 1.0)
            .toDouble();
        final collapseT = Curves.easeInOutCubic.transform(collapseRaw);

        // ── Bottom-entry: item entering from below screen ──
        final distanceFromBottom = screenHeight - itemTopY;
        final entryRaw = (distanceFromBottom / _entryRange)
            .clamp(0.0, 1.0)
            .toDouble();
        // entryRaw == 0 → fully off-screen below, 1 → fully entered
        final entryT = Curves.easeOutCubic.transform(entryRaw);

        // Combine: entry wins when item is below screen, collapse wins near bottom edge
        final slideUp      = _lerp(22.0, 0.0, entryT);
        final entryOpacity = _lerp(0.0, 1.0, entryT);

        final collapseWidthFactor = _lerp(1.0, 0.60, collapseT);
        final collapseScaleY     = _lerp(1.0, 0.72, collapseT);
        final collapseDrop       = _lerp(0.0, 12.0, collapseT);
        final collapseOpacity    = _lerp(1.0, 0.10, Curves.easeInOutCubic.transform(collapseT));

        final finalOpacity = (entryOpacity * collapseOpacity).clamp(0.0, 1.0);
        final finalSlide   = slideUp + collapseDrop;

        if (collapseT == 0 && entryT == 1.0) return child!;

        Widget result = Transform.translate(
          offset: Offset(0, finalSlide),
          child: Transform.scale(
            alignment: Alignment.bottomCenter,
            scaleY: collapseScaleY,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: collapseWidthFactor,
                child: child,
              ),
            ),
          ),
        );
        if (finalOpacity < 0.99) {
          result = Opacity(opacity: finalOpacity, child: result);
        }
        return ClipRect(child: result);
      },
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _AnimatedFloatingSearchBar extends StatefulWidget {
  final bool dark;
  const _AnimatedFloatingSearchBar({required this.dark});

  @override
  State<_AnimatedFloatingSearchBar> createState() => _AnimatedFloatingSearchBarState();
}

class _AnimatedFloatingSearchBarState extends State<_AnimatedFloatingSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    HapticFeedback.selectionClick();
    _navigateToSearch();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _navigateToSearch() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => SearchScreen(dark: widget.dark),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = GlassTokens.sub(widget.dark);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Hero(
          tag: 'chat_search_bar',
          child: GlassSurface(
            dark: widget.dark,
            radius: 999,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: sub),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search'.tr(context),
                      style: manrope(
                        size: 14,
                        weight: FontWeight.w500,
                        color: sub,
                        letterSpacing: -0.07,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
