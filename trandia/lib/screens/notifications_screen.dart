// notifications_screen.dart
// Matte glass notifications with cascade-stack scroll. Monochrome, light + dark.
//
// Usage:
//   Scaffold(body: NotificationsScreen(dark: true))
//
// Requires glass_common.dart.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_common.dart';

enum NfKind { like, comment, follow, mention, live, msg, system }

class NfItem {
  final NfKind kind;
  final String name;
  final String text;
  final String time;
  final bool thumb;
  final bool unread;
  const NfItem({
    required this.kind, required this.name, required this.text, required this.time,
    this.thumb = false, this.unread = false,
  });
}

const _items = <NfItem>[
  NfItem(kind: NfKind.live,    name: 'mikhail',        text: 'is live now',                            time: 'just now', unread: true),
  NfItem(kind: NfKind.like,    name: 'sarah.d',        text: 'liked your post',                        time: '2m',  thumb: true, unread: true),
  NfItem(kind: NfKind.follow,  name: 'aanya_',         text: 'started following you',                  time: '14m', unread: true),
  NfItem(kind: NfKind.mention, name: 'devon.b',        text: 'mentioned you in a comment',             time: '1h',  thumb: true, unread: true),
  NfItem(kind: NfKind.comment, name: 'kiraa',          text: 'commented: "this is unreal 🤍"',          time: '1h',  thumb: true),
  NfItem(kind: NfKind.like,    name: 'ren.x',          text: 'and 3 others liked your photo',          time: '2h',  thumb: true),
  NfItem(kind: NfKind.msg,     name: 'noor.j',         text: 'sent you a message',                     time: '3h'),
  NfItem(kind: NfKind.follow,  name: 'studio.atelier', text: 'started following you',                  time: '5h'),
  NfItem(kind: NfKind.like,    name: 'mikhail',        text: 'and 14 others liked your photo',         time: '8h',  thumb: true),
  NfItem(kind: NfKind.mention, name: 'sarah.d',        text: 'tagged you in a post',                   time: '1d',  thumb: true),
  NfItem(kind: NfKind.system,  name: 'Security',       text: 'New login from Chrome on macOS',         time: '1d'),
  NfItem(kind: NfKind.comment, name: 'aanya_',         text: 'commented: "send the moodboard please"', time: '2d',  thumb: true),
  NfItem(kind: NfKind.follow,  name: 'noor.j',         text: 'started following you',                  time: '2d'),
  NfItem(kind: NfKind.like,    name: 'devon.b',        text: 'liked your post',                        time: '3d',  thumb: true),
  NfItem(kind: NfKind.system,  name: 'Trandia',        text: 'Your weekly summary is ready',           time: '4d'),
];

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
const double _kStackPinY  = 0;   // where the top-most stacked card visually sits, relative to list viewport top
const double _kPeek       = 5;
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

  List<NfItem> get _filtered {
    switch (_filter) {
      case 'Mentions': return _items.where((n) => n.kind == NfKind.mention || n.kind == NfKind.comment).toList();
      case 'Follows':  return _items.where((n) => n.kind == NfKind.follow).toList();
      case 'System':   return _items.where((n) => n.kind == NfKind.system).toList();
      default:         return _items.toList();
    }
  }

  int get _unread => _items.where((n) => n.unread).length;

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final items = _filtered;

    return Container(
      color: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      child: Stack(children: [
        GlassBackdrop(dark: dark),

        // ── Cascade list (positioned full-bleed, padding via Stack) ──
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _scroll,
            builder: (context, _) {
              final offset = _scroll.hasClients ? _scroll.offset : 0.0;
              return SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.only(top: _kListStartY, bottom: 24, left: 10, right: 10),
                child: SizedBox(
                  // explicit height so we can absolute-position cards inside
                  height: items.length * (_kCardHeight + _kCardGap),
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (int i = 0; i < items.length; i++)
                      _buildCascadeCard(items[i], i, offset, dark),
                  ]),
                ),
              );
            },
          ),
        ),

        // ── Floating header pill ──
        Positioned(
          top: 10, left: 12, right: 12,
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
              GlassCircleButton(dark: dark, icon: Icons.settings_outlined, iconSize: 18),
            ]),
          ),
        ),

        // ── Filter chips ──
        Positioned(
          top: 70, left: 0, right: 0,
          child: SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _Chip(label: 'All',      active: _filter=='All',      count: _unread, dark: dark, onTap: () => setState(() => _filter='All')),
                const SizedBox(width: 8),
                _Chip(label: 'Mentions', active: _filter=='Mentions', dark: dark, onTap: () => setState(() => _filter='Mentions')),
                const SizedBox(width: 8),
                _Chip(label: 'Follows',  active: _filter=='Follows',  dark: dark, onTap: () => setState(() => _filter='Follows')),
                const SizedBox(width: 8),
                _Chip(label: 'System',   active: _filter=='System',   dark: dark, onTap: () => setState(() => _filter='System')),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  /// Computes per-card transform & places each card via Positioned + Transform.
  Widget _buildCascadeCard(NfItem item, int i, double scrollOffset, bool dark) {
    final stride = _kCardHeight + _kCardGap;
    final naturalTop = i * stride - scrollOffset;
    final stackZone = 64.0;
    final card = _NfCardInner(n: item, i: i, dark: dark);

    if (naturalTop >= stackZone) {
      return Positioned(
        left: 0, right: 0, top: i * stride,
        height: _kCardHeight,
        child: card,
      );
    }

    // count how many cards are in stack (have naturalTop < stackZone) up to & including this index
    int stackTotal = 0;
    int posInStack = 0;
    for (int k = 0; k <= i; k++) {
      final ny = k * stride - scrollOffset;
      if (ny < stackZone) {
        stackTotal++;
        if (k == i) posInStack = stackTotal - 1;
      }
    }
    // include cards after this index that also fall in stack zone
    for (int k = i + 1; k < _filtered.length; k++) {
      final ny = k * stride - scrollOffset;
      if (ny < stackZone) stackTotal++;
    }

    final depth = stackTotal - 1 - posInStack;
    if (depth >= _kMaxStack) {
      return const SizedBox.shrink();
    }

    final pinY  = stackZone - depth * _kPeek - 28;     // pin slightly above stack-zone
    final ty    = pinY - naturalTop;
    final scale = 1.0 - depth * 0.05;
    final opacity = depth == 0 ? 1.0 : (1.0 - depth * 0.28).clamp(0.0, 1.0);

    return Positioned(
      left: 0, right: 0, top: i * stride,
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
