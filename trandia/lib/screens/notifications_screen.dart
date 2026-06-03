// notifications_screen.dart
// Matte glass notifications with cascade-stack scroll. Monochrome, light + dark.
// NOW BACKED BY REAL SERVER DATA — no fake notifications.
//
// Usage:
//   Scaffold(body: NotificationsScreen(dark: true))
//
// Requires glass_common.dart.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/follow_state.dart';
import '../l10n/app_localizations.dart';
import '../utils/error_dialog.dart';
import 'glass_common.dart';
import 'home/home_screen.dart';
import 'notification_settings_screen.dart';
import 'user_profile_screen.dart' as user_profile;

enum NfKind { like, comment, follow, mention, live, msg, system }

class NfItem {
  final String id;
  final NfKind kind;
  final String name;
  final String text;
  final String time;
  final String fromUserId;
  final String? fromPicture;
  final bool thumb;
  final bool unread;

  const NfItem({
    this.id = '',
    required this.kind,
    required this.name,
    required this.text,
    required this.time,
    this.fromUserId = '',
    this.fromPicture,
    this.thumb = false,
    this.unread = false,
  });

  /// Build an NfItem from the real API JSON.
  factory NfItem.fromJson(Map<String, dynamic> json) {
    return NfItem(
      id: json['id'] ?? '',
      kind: _parseKind(json['type'] ?? 'follow'),
      name: json['from_username'] ?? json['from_name'] ?? '',
      text: json['text'] ?? '',
      time: _timeAgo(json['created_at']),
      fromUserId: json['from_user_id'] ?? '',
      fromPicture: json['from_picture'] as String?,
      unread: !(json['read'] ?? false),
    );
  }

  static NfKind _parseKind(String type) {
    switch (type) {
      case 'like':    return NfKind.like;
      case 'comment': return NfKind.comment;
      case 'follow':  return NfKind.follow;
      case 'mention': return NfKind.mention;
      case 'live':    return NfKind.live;
      case 'message': return NfKind.msg;
      case 'system':  return NfKind.system;
      default:        return NfKind.follow;
    }
  }

  static String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final DateTime dt;
      if (createdAt is String) {
        dt = DateTime.parse(createdAt).toLocal();
      } else {
        return '';
      }
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) {
      return '';
    }
  }
}

IconData _kindIcon(NfKind k) {
  switch (k) {
    case NfKind.like:    return Icons.favorite;
    case NfKind.comment: return Icons.chat_bubble;
    case NfKind.follow:  return Icons.person;
    case NfKind.mention: return Icons.alternate_email;
    case NfKind.live:    return Icons.radio_button_checked;
    case NfKind.msg:     return Icons.mail_rounded;
    case NfKind.system:  return Icons.shield_rounded;
  }
}

/// Fixed item height so card sizing stays consistent.
const double _kCardHeight = 66;
const double _kCardGap    = 6;
const double _kListStartY = 112; // header(48) + 12 + chips(30) + 22 spacing
const double _kIslandCollapseRange = 80;
const double _kIslandPinLift = 64; // keeps the folded stack above the bottom safe area

class NotificationsScreen extends StatefulWidget {
  final bool dark;
  final VoidCallback? onClose;
  final double backgroundOpacity;
  const NotificationsScreen({
    super.key,
    required this.dark,
    this.onClose,
    this.backgroundOpacity = 1.0,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();
  String _filter = 'All';

  List<NfItem> _items = [];
  bool _loading = true;
  bool _error = false;
  StreamSubscription? _fcmSub;
  StreamSubscription? _wsNotifSub;

  // Pagination
  static const int _pageSize = 40;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _skip = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fetchNotifications();
    _listenForRealtimeNotifications();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _fcmSub?.cancel();
    _wsNotifSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _fetchMoreNotifications();
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() { _loading = true; _error = false; _skip = 0; _hasMore = true; });
    try {
      final data = await ApiService.getList(
        '/notifications?limit=$_pageSize',
        requiresAuth: true,
      );
      final items = data
          .map((d) => NfItem.fromJson(d as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _items = items;
          _skip = items.length;
          _hasMore = items.length == _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Notifications] fetch error: $e');
      if (mounted) {
        setState(() { _loading = false; _error = true; });
      }
    }
  }

  Future<void> _fetchMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final data = await ApiService.getList(
        '/notifications?skip=$_skip&limit=$_pageSize',
        requiresAuth: true,
      );
      final newItems = data
          .map((d) => NfItem.fromJson(d as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          for (final item in newItems) {
            if (!_isDuplicate(item.id)) _items.add(item);
          }
          _skip += newItems.length;
          _hasMore = newItems.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[Notifications] fetch more error: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Returns true if this notification id already exists in the list.
  /// An empty id is NEVER treated as duplicate — it would suppress all
  /// notifications from older backend versions that didn't send an id.
  bool _isDuplicate(String id) {
    if (id.isEmpty) return false;
    return _items.any((item) => item.id == id);
  }

  /// Listen for FCM foreground messages and WebSocket events.
  /// Both paths carry the same `id` so duplicates are filtered out.
  void _listenForRealtimeNotifications() {
    // ── FCM foreground ──────────────────────────────────────────────────────
    _fcmSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final msgType = msg.data['type'] as String?;
      if (msgType == null) return;

      final String notifId = msg.data['id'] ?? '';
      if (_isDuplicate(notifId)) return;

      final newItem = NfItem(
        id: notifId,
        kind: NfItem._parseKind(msgType),
        name: msg.data['username'] ?? msg.data['from_username'] ?? msg.data['title'] ?? '',
        text: msg.data['text'] ?? msg.data['body'] ?? '',
        time: 'just now',
        unread: true,
      );
      if (mounted) {
        setState(() { _items.insert(0, newItem); });
      }
    });

    // ── WebSocket real-time ─────────────────────────────────────────────────
    _wsNotifSub = ChatService().notificationStream.listen((data) {
      try {
        final newItem = NfItem.fromJson(data);
        if (_isDuplicate(newItem.id)) return;
        if (mounted) {
          setState(() { _items.insert(0, newItem); });
        }
      } catch (e) {
        debugPrint('[Notifications] WS parse error: $e');
      }
    });
  }

  List<NfItem> get _filtered {
    switch (_filter) {
      case 'Follows':  return _items.where((n) => n.kind == NfKind.follow).toList();
      case 'Like':     return _items.where((n) => n.kind == NfKind.like).toList();
      case 'Comment':  return _items.where((n) => n.kind == NfKind.comment).toList();
      default:         return _items.toList();
    }
  }

  int get _unread => _items.where((n) => n.unread).length;

  Future<void> _markAllRead() async {
    try {
      await ApiService.put('/notifications/read-all', {}, requiresAuth: true);
      if (mounted) {
        setState(() {
          _items = _items.map((n) => NfItem(
            id: n.id, kind: n.kind, name: n.name, text: n.text,
            time: n.time, fromUserId: n.fromUserId, thumb: n.thumb, unread: false,
          )).toList();
        });
      }
    } catch (e) {
      debugPrint('[Notifications] mark-all-read error: $e');
    }
  }

  Future<void> _deleteNotification(NfItem item) async {
    if (item.id.isEmpty) return;

    final index = _items.indexWhere((n) => n.id == item.id);
    if (index == -1) return;

    final removed = _items[index];
    setState(() { _items.removeAt(index); });

    try {
      await ApiService.delete('/notifications/${item.id}', requiresAuth: true);
    } catch (e) {
      debugPrint('[Notifications] delete error: $e');
      if (!mounted) return;
      final restoreIndex = index >= _items.length ? _items.length : index;
      setState(() { _items.insert(restoreIndex, removed); });
      showErrorDialog(context, message: 'Could not delete notification'.tr(context));
    }
  }

  void _openHome() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(dark: widget.dark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final items = _filtered;
    final topPad = MediaQuery.paddingOf(context).top;
    final headerTop = topPad + 10;
    final chipsTop = topPad + 70;
    final listTop = topPad + 104;
    const listInnerTopPadding = _kListStartY - 104;
    final listStartGlobalY = listTop + listInnerTopPadding;
    final bgOpacity = widget.backgroundOpacity.clamp(0.0, 1.0).toDouble();

    return Container(
      color: (dark ? GlassTokens.bgDark : GlassTokens.bgLight)
          .withValues(alpha: bgOpacity),
      child: Stack(children: [
        Opacity(
          opacity: bgOpacity,
          child: GlassBackdrop(dark: dark),
        ),

        // ── Content area ──
        Positioned(
          top: listTop, bottom: 0, left: 0, right: 0,
          child: _loading
              ? _buildLoadingShimmer(dark)
              : _error
                  ? _buildError(dark)
                  : items.isEmpty
                      ? _buildEmpty(dark)
                      : _buildCascadeList(items, dark, listInnerTopPadding, listStartGlobalY),
        ),

        // ── Floating header pill ──
        Positioned(
          top: headerTop, left: 12, right: 12,
          child: GlassHeader(
            dark: dark,
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Row(children: [
              GestureDetector(
                onTap: _openHome,
                child: GlassCircleButton(dark: dark, icon: Icons.arrow_back_ios_new_rounded, iconSize: 18),
              ),
              const SizedBox(width: 4),
              Text('Notifications'.tr(context),
                style: manrope(size: 17, weight: FontWeight.w700,
                  color: GlassTokens.fg(dark), letterSpacing: -0.34)),
              if (_unread > 0) ...[
                const SizedBox(width: 10),
                _CountBadge(count: _unread, dark: dark, big: true),
              ],
              const Spacer(),
              if (_unread > 0)
                GestureDetector(
                  onTap: _markAllRead,
                  child: GlassCircleButton(dark: dark, icon: Icons.done_all, iconSize: 18),
                )
              else
                GlassCircleButton(
                  dark: dark,
                  icon: Icons.settings_outlined,
                  iconSize: 18,
                  onTap: _openSettings,
                ),
            ]),
          ),
        ),

        // ── Filter chips ──
        Positioned(
          top: chipsTop, left: 0, right: 0,
          child: _StaggeredEntrance(
            index: 1,
            child: SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _Chip(label: 'All',      active: _filter=='All',      count: _unread, dark: dark, onTap: () => setState(() => _filter='All')),
                  const SizedBox(width: 8),
                  _Chip(label: 'Follows',  active: _filter=='Follows',  dark: dark, onTap: () => setState(() => _filter='Follows')),
                  const SizedBox(width: 8),
                  _Chip(label: 'Like',     active: _filter=='Like',     dark: dark, onTap: () => setState(() => _filter='Like')),
                  const SizedBox(width: 8),
                  _Chip(label: 'Comment',  active: _filter=='Comment',  dark: dark, onTap: () => setState(() => _filter='Comment')),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCascadeList(List<NfItem> items, bool dark, double listInnerTopPadding, double listStartGlobalY) {
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: dark ? Colors.white : Colors.black,
      backgroundColor: dark ? const Color(0xFF1A1A1A) : Colors.white,
      child: ListView.builder(
        controller: _scroll,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.only(top: listInnerTopPadding, bottom: 40, left: 10, right: 10),
        itemCount: items.length + (_isLoadingMore ? 1 : 0),
        addAutomaticKeepAlives: false,
        itemBuilder: (context, i) {
          if (i >= items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          }
          return _DynamicIslandScrollCard(
            controller: _scroll,
            index: i,
            listStartGlobalY: listStartGlobalY,
            child: RepaintBoundary(
              key: ValueKey(items[i].id.isEmpty ? i.toString() : items[i].id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: _kCardGap),
                child: SizedBox(
                  height: _kCardHeight,
                  child: _NfCardInner(
                    n: items[i],
                    i: i,
                    dark: dark,
                    onDelete: () => _deleteNotification(items[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingShimmer(bool dark) {
    final shimmerBase = dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, left: 10, right: 10),
      itemCount: 6,
      itemBuilder: (_, i) => _StaggeredEntrance(
        index: i + 2,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: _kCardHeight,
            decoration: BoxDecoration(
              color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.80),
                width: 0.5,
              ),
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 12, width: 120,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10, width: 80,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool dark) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 56,
            color: dark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Text('No notifications yet'.tr(context),
            style: manrope(size: 16, weight: FontWeight.w700, color: fg, letterSpacing: -0.2)),
          const SizedBox(height: 6),
          Text('When someone follows you, it\'ll show up here'.tr(context),
            style: manrope(size: 13, weight: FontWeight.w500, color: sub, letterSpacing: -0.1)),
        ],
      ),
    );
  }

  Widget _buildError(bool dark) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48,
            color: dark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Text('Couldn\'t load notifications'.tr(context),
            style: manrope(size: 15, weight: FontWeight.w700, color: fg)),
          const SizedBox(height: 6),
          Text('Check your connection and try again'.tr(context),
            style: manrope(size: 13, weight: FontWeight.w500, color: sub)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _fetchNotifications,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06),
              ),
              child: Text('Retry'.tr(context),
                style: manrope(size: 13, weight: FontWeight.w700, color: fg)),
            ),
          ),
        ],
      ),
    );
  }

}

/// How many px from the bottom the entry slide starts.
const double _kEntryRange = 160;

class _DynamicIslandScrollCard extends StatelessWidget {
  final ScrollController controller;
  final int index;
  final double listStartGlobalY;
  final Widget child;

  const _DynamicIslandScrollCard({
    required this.controller,
    required this.index,
    required this.listStartGlobalY,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final bottomPad = MediaQuery.paddingOf(context).bottom;
        final scrollY = controller.hasClients ? controller.offset : 0.0;
        final itemY = listStartGlobalY +
            (index * (_kCardHeight + _kCardGap)) -
            scrollY;
        final itemBottomY = itemY + _kCardHeight;
        final bottomStackY = screenHeight - bottomPad - _kIslandPinLift;

        // ── Bottom-collapse: item approaching the bottom edge ──
        final distanceToBottomStack = bottomStackY - itemBottomY;
        final collapseRaw = (1.0 - (distanceToBottomStack / _kIslandCollapseRange))
            .clamp(0.0, 1.0)
            .toDouble();
        final collapseT = Curves.easeInOutCubic.transform(collapseRaw);

        // ── Bottom-entry: item entering from below screen ──
        final distanceFromBottom = screenHeight - itemY;
        final entryRaw = (distanceFromBottom / _kEntryRange)
            .clamp(0.0, 1.0)
            .toDouble();
        // entryRaw == 0 → fully off-screen below, 1 → fully entered
        final entryT = Curves.easeOutCubic.transform(entryRaw);

        // Combine both effects
        final slideUp      = _lerp(22.0, 0.0, entryT);
        final entryOpacity = _lerp(0.0, 1.0, entryT);

        final collapseWidthFactor = _lerp(1.0, 0.62, collapseT);
        final collapseScaleY      = _lerp(1.0, 0.74, collapseT);
        final collapseDrop        = _lerp(0.0, 14.0, collapseT);
        final collapseOpacity     = _lerp(1.0, 0.12, Curves.easeInOutCubic.transform(collapseT));

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

/// Single notification card body.
class _NfCardInner extends StatefulWidget {
  final NfItem n;
  final int i;
  final bool dark;
  final VoidCallback onDelete;
  const _NfCardInner({
    required this.n,
    required this.i,
    required this.dark,
    required this.onDelete,
  });

  @override
  State<_NfCardInner> createState() => _NfCardInnerState();
}

class _NfCardInnerState extends State<_NfCardInner> {
  bool _following = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    final userId = widget.n.fromUserId;
    _following = FollowState.get(userId) ?? false;
    FollowState.notifier.addListener(_onGlobalFollowChanged);
  }

  @override
  void dispose() {
    FollowState.notifier.removeListener(_onGlobalFollowChanged);
    super.dispose();
  }

  void _onGlobalFollowChanged() {
    final v = FollowState.get(widget.n.fromUserId);
    if (v != null && mounted && v != _following) setState(() => _following = v);
  }

  void _openProfile() {
    final n = widget.n;
    if (n.fromUserId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => user_profile.ProfileScreen(
          userId: n.fromUserId,
          username: n.name,
          displayName: n.name,
        ),
      ),
    );
  }

  Future<void> _onFollowTap() async {
    final n = widget.n;
    if (n.fromUserId.isEmpty || _followLoading) return;
    final wasFollowing = _following;
    setState(() { _following = !wasFollowing; _followLoading = true; });
    bool success = false;
    try {
      if (!wasFollowing) {
        success = await UserService.followUser(n.fromUserId);
      } else {
        success = await UserService.unfollowUser(n.fromUserId);
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        if (!success) _following = wasFollowing;
        _followLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    final i = widget.i;
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final iconChipBg = dark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.08);
    final chipBorder = dark ? const Color(0xFF0C0C0E) : const Color(0xFFFAFAFA);

    return GestureDetector(
      onTap: _openProfile,
      child: GlassSurface(
      dark: dark, radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      blurSigma: 44,
      bgColors: dark
          ? [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)]
          : [Colors.white.withValues(alpha: 0.65), Colors.white.withValues(alpha: 0.40)],
      borderColor: dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.85),
      borderWidth: 0.5,
      child: Row(children: [
        // ── Avatar + kind chip ────────────────────────────────────────────
        SizedBox(width: 44, height: 44, child: Stack(clipBehavior: Clip.none, children: [
          UserAvatar(
            pictureUrl: n.fromPicture,
            name: n.name,
            size: 44,
            dark: dark,
            index: i,
          ),
          Positioned(right: -2, bottom: -2, child: Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: iconChipBg,
              border: Border.all(color: chipBorder, width: 2),
            ),
            alignment: Alignment.center,
            child: Icon(_kindIcon(n.kind), size: 12, color: fg),
          )),
        ])),
        const SizedBox(width: 12),

        // ── Text ──────────────────────────────────────────────────────────
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          RichText(
            maxLines: 2, overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(text: n.name,
                style: manrope(size: 13.5, weight: FontWeight.w700, color: fg, letterSpacing: -0.07, height: 1.18)),
              TextSpan(text: '  ${n.text}',
                style: manrope(size: 13.5, weight: FontWeight.w500, color: GlassTokens.text78(dark), letterSpacing: -0.07, height: 1.18)),
            ]),
          ),
          const SizedBox(height: 1),
          Text(n.time, style: manrope(size: 10.5, weight: FontWeight.w500, color: sub, letterSpacing: -0.05, height: 1.0)),
        ])),

        const SizedBox(width: 10),

        // ── Trailing action ───────────────────────────────────────────────
        if (n.kind == NfKind.follow)
          GestureDetector(
            onTap: _onFollowTap,
            child: _ActionButton(
              label: _following ? 'Following' : (n.unread ? 'Follow back' : 'Follow'),
              filled: !_following && n.unread,
              dark: dark,
            ),
          )
        else if (n.thumb)
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: monoAvatar(dark, i + 2),
            ),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onDelete,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: dark
                  ? Colors.white.withValues(alpha: 0.72)
                  : Colors.black.withValues(alpha: 0.62),
            ),
          ),
        ),
      ]),
    ));
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool dark;
  const _ActionButton({required this.label, required this.filled, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    if (filled) {
      return Container(
        height: 30, padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: dark ? Colors.white : const Color(0xFF0A0A0A),
        ),
        child: Text(label.tr(context),
          style: manrope(size: 12, weight: FontWeight.w700,
            color: dark ? const Color(0xFF0A0A0A) : Colors.white, letterSpacing: -0.12)),
      );
    }
    return Container(
      height: 30, padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.10)),
      ),
      child: Text(label.tr(context), style: manrope(size: 12, weight: FontWeight.w700, color: fg, letterSpacing: -0.12)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final int? count;
  final bool dark;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.dark, required this.onTap, this.count});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active
                  ? (dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.85))
                  : (dark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active
                ? (dark ? Colors.white.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.12))
                : (dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06))),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label.tr(context),
                style: manrope(size: 12.5, weight: active ? FontWeight.w700 : FontWeight.w600, color: fg, letterSpacing: -0.12)),
              if ((count ?? 0) > 0) ...[
                const SizedBox(width: 6),
                _CountBadge(count: count!, dark: dark, big: false),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool dark;
  final bool big;
  const _CountBadge({required this.count, required this.dark, required this.big});

  @override
  Widget build(BuildContext context) {
    final h = big ? 22.0 : 16.0;
    return Container(
      constraints: BoxConstraints(minWidth: h),
      height: h,
      padding: EdgeInsets.symmetric(horizontal: big ? 7 : 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? Colors.white : const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$count',
        style: manrope(
          size: big ? 11 : 10,
          weight: FontWeight.w800,
          color: dark ? const Color(0xFF0A0A0A) : Colors.white,
          letterSpacing: -0.1,
          height: 1,
        )),
    );
  }
}

class _StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;

  const _StaggeredEntrance({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 24),
  });

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
    );

    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      ),
    );

    final delayMs = (widget.delay.inMilliseconds * widget.index)
        .clamp(0, 168)
        .toInt();
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final p = _progress.value;
        final depth = widget.index.clamp(0, 7).toDouble();
        final dy = (72.0 + depth * 6.0) * (1.0 - p);
        final scale = 0.965 + (0.035 * p);

        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              alignment: Alignment.bottomCenter,
              scale: scale,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
