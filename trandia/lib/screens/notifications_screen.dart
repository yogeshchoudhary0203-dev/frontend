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
import 'glass_common.dart';

enum NfKind { like, comment, follow, mention, live, msg, system }

class NfItem {
  final String id;
  final NfKind kind;
  final String name;
  final String text;
  final String time;
  final String fromUserId;
  final bool thumb;
  final bool unread;

  const NfItem({
    this.id = '',
    required this.kind,
    required this.name,
    required this.text,
    required this.time,
    this.fromUserId = '',
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

/// Fixed item height so cascade math works deterministically.
const double _kCardHeight = 76;
const double _kCardGap    = 10;
const double _kListStartY = 112; // header(48) + 12 + chips(30) + 22 spacing
const int    _kMaxStack   = 4;

class NotificationsScreen extends StatefulWidget {
  final bool dark;
  const NotificationsScreen({super.key, required this.dark});

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _fetchNotifications() async {
    setState(() { _loading = true; _error = false; });
    try {
      final data = await ApiService.getList(
        '/notifications?limit=50',
        requiresAuth: true,
      );
      final items = data
          .map((d) => NfItem.fromJson(d as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() { _items = items; _loading = false; });
      }
    } catch (e) {
      debugPrint('[Notifications] fetch error: $e');
      if (mounted) {
        setState(() { _loading = false; _error = true; });
      }
    }
  }

  /// Listen for FCM foreground messages and prepend follow notifications in real-time.
  void _listenForRealtimeNotifications() {
    _fcmSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final msgType = msg.data['type'] as String?;
      if (msgType == 'follow') {
        final String notifId = msg.data['id'] ?? '';
        if (notifId.isNotEmpty && _items.any((item) => item.id == notifId)) {
          return; // Skip duplicate
        }
        final newItem = NfItem(
          id: notifId,
          kind: NfKind.follow,
          name: msg.data['username'] ?? msg.data['title'] ?? '',
          text: msg.data['body'] ?? 'started following you',
          time: 'just now',
          unread: true,
        );
        if (mounted) {
          setState(() { _items.insert(0, newItem); });
        }
      }
    });

    _wsNotifSub = ChatService().notificationStream.listen((data) {
      try {
        final newItem = NfItem.fromJson(data);
        if (newItem.id.isNotEmpty && _items.any((item) => item.id == newItem.id)) {
          return; // Skip duplicate
        }
        if (mounted) {
          setState(() {
            _items.insert(0, newItem);
          });
        }
      } catch (e) {
        debugPrint('[Notifications] WS parse error: $e');
      }
    });
  }

  List<NfItem> get _filtered {
    switch (_filter) {
      case 'Follows':  return _items.where((n) => n.kind == NfKind.follow).toList();
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

    return Container(
      color: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      child: Stack(children: [
        GlassBackdrop(dark: dark),

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
            child: Row(children: [
              Text('Notifications',
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
                GlassCircleButton(dark: dark, icon: Icons.settings_outlined, iconSize: 18),
            ]),
          ),
        ),

        // ── Filter chips ──
        Positioned(
          top: chipsTop, left: 0, right: 0,
          child: SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _Chip(label: 'All',      active: _filter=='All',      count: _unread, dark: dark, onTap: () => setState(() => _filter='All')),
                const SizedBox(width: 8),
                _Chip(label: 'Follows',  active: _filter=='Follows',  dark: dark, onTap: () => setState(() => _filter='Follows')),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCascadeList(List<NfItem> items, bool dark, double listInnerTopPadding, double listStartGlobalY) {
    final viewportHeight = MediaQuery.of(context).size.height;
    return AnimatedBuilder(
      animation: _scroll,
      builder: (context, _) {
        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
        return RefreshIndicator(
          onRefresh: _fetchNotifications,
          color: dark ? Colors.white : Colors.black,
          backgroundColor: dark ? const Color(0xFF1A1A1A) : Colors.white,
          child: SingleChildScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: listInnerTopPadding, bottom: 40, left: 10, right: 10),
            child: SizedBox(
              height: items.length * (_kCardHeight + _kCardGap),
              child: Stack(clipBehavior: Clip.none, children: [
                for (int i = items.length - 1; i >= 0; i--)
                  _buildCascadeCard(items[i], i, offset, dark, viewportHeight, listStartGlobalY),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer(bool dark) {
    final shimmerBase = dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, left: 10, right: 10),
      itemCount: 6,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          height: _kCardHeight,
          decoration: BoxDecoration(
            color: shimmerBase,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07),
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
                      color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10, width: 80,
                    decoration: BoxDecoration(
                      color: dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ]),
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
            color: dark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12)),
          const SizedBox(height: 16),
          Text('No notifications yet',
            style: manrope(size: 16, weight: FontWeight.w700, color: fg, letterSpacing: -0.2)),
          const SizedBox(height: 6),
          Text('When someone follows you, it\'ll show up here',
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
            color: dark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12)),
          const SizedBox(height: 16),
          Text('Couldn\'t load notifications',
            style: manrope(size: 15, weight: FontWeight.w700, color: fg)),
          const SizedBox(height: 6),
          Text('Check your connection and try again',
            style: manrope(size: 13, weight: FontWeight.w500, color: sub)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _fetchNotifications,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06),
              ),
              child: Text('Retry',
                style: manrope(size: 13, weight: FontWeight.w700, color: fg)),
            ),
          ),
        ],
      ),
    );
  }

  /// Computes per-card transform & places each card via Positioned + Transform.
  Widget _buildCascadeCard(NfItem item, int i, double scrollOffset, bool dark, double viewportHeight, double listStartGlobalY) {
    final stride = _kCardHeight + _kCardGap;
    final cardTop = i * stride;
    final card = _NfCardInner(n: item, i: i, dark: dark);

    final screenY = listStartGlobalY - scrollOffset + cardTop;
    final stackZoneScreenY = viewportHeight - 100.0;

    final overage = screenY - stackZoneScreenY;

    if (overage <= 0) {
      return Positioned(
        left: 0, right: 0, top: cardTop,
        height: _kCardHeight,
        child: card,
      );
    }

    final double depth = overage / stride;
    if (depth >= _kMaxStack) {
      return const SizedBox.shrink();
    }

    final pinScreenY = stackZoneScreenY + depth * 14.0;
    final pinY = pinScreenY - (listStartGlobalY - scrollOffset);
    final ty = pinY - cardTop;
    final scale = 1.0 - depth * 0.05;
    final opacity = (1.0 - depth * 0.25).clamp(0.0, 1.0);

    return Positioned(
      left: 0, right: 0, top: cardTop,
      height: _kCardHeight,
      child: Transform.translate(
        offset: Offset(0, ty),
        child: Transform.scale(
          alignment: Alignment.topCenter,
          scale: scale,
          child: Opacity(opacity: opacity, child: card),
        ),
      ),
    );
  }
}

/// Single notification card body.
class _NfCardInner extends StatelessWidget {
  final NfItem n;
  final int i;
  final bool dark;
  const _NfCardInner({required this.n, required this.i, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final iconChipBg = dark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.08);
    final chipBorder = dark ? const Color(0xFF0C0C0E) : const Color(0xFFFAFAFA);

    return GlassSurface(
      dark: dark, radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      blurSigma: 28,
      child: Row(children: [
        if (n.unread) Positioned(
          // unread dot rendered via Stack overlay below; use SizedBox here
          child: Container(),
        ),
        // avatar + chip
        SizedBox(width: 44, height: 44, child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: monoAvatar(dark, i),
            ),
            alignment: Alignment.center,
            child: Text(
              n.name.isEmpty ? '•' : n.name[0].toUpperCase(),
              style: manrope(size: 16, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
            ),
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

        // text
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          RichText(
            maxLines: 2, overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(text: n.name,
                style: manrope(size: 13.5, weight: FontWeight.w700, color: fg, letterSpacing: -0.07)),
              TextSpan(text: '  ${n.text}',
                style: manrope(size: 13.5, weight: FontWeight.w500, color: GlassTokens.text78(dark), letterSpacing: -0.07, height: 1.35)),
            ]),
          ),
          const SizedBox(height: 2),
          Text(n.time, style: manrope(size: 11, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
        ])),

        const SizedBox(width: 10),

        // trailing
        if (n.kind == NfKind.follow && !n.unread)
          _ActionButton(label: 'Follow', filled: false, dark: dark)
        else if (n.kind == NfKind.follow && n.unread)
          _ActionButton(label: 'Follow back', filled: true, dark: dark)
        else if (n.thumb)
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: monoAvatar(dark, i + 2),
            ),
          ),
      ]),
    );
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
        child: Text(label,
          style: manrope(size: 12, weight: FontWeight.w700,
            color: dark ? const Color(0xFF0A0A0A) : Colors.white, letterSpacing: -0.12)),
      );
    }
    return Container(
      height: 30, padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.6),
        border: Border.all(color: dark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.10)),
      ),
      child: Text(label, style: manrope(size: 12, weight: FontWeight.w700, color: fg, letterSpacing: -0.12)),
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
                  ? (dark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.85))
                  : (dark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45)),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active
                ? (dark ? Colors.white.withOpacity(0.30) : Colors.black.withOpacity(0.12))
                : (dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06))),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
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
