// chat_list_screen.dart
// Matte glass chat list — header + search + active-now strip + conversations.
// Monochrome, light + dark.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_common.dart';
import 'chat_screen.dart';

class ChatItem {
  final String name;
  final String last;
  final String time;
  final int unread;
  final bool online;
  final bool typing;
  final bool mine;
  final bool read;
  final bool delivered;
  final bool voice;
  final bool muted;
  final bool group;
  const ChatItem({
    required this.name, required this.last, required this.time,
    this.unread = 0, this.online = false, this.typing = false,
    this.mine = false, this.read = false, this.delivered = false,
    this.voice = false, this.muted = false, this.group = false,
  });
}

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

const _chats = <ChatItem>[
  ChatItem(name: 'sarah.d',        last: "lol that's perfect 🤍",       time: '2m',   unread: 2, online: true),
  ChatItem(name: 'mikhail',        last: 'see u at 7 then',             time: '12m',  online: true, read: true),
  ChatItem(name: 'aanya_',         last: 'Voice message · 0:32',        time: '1h',   unread: 1, voice: true),
  ChatItem(name: 'devon.b',        last: 'thanks! that worked',         time: '3h',   mine: true, delivered: true),
  ChatItem(name: 'kiraa',          last: 'typing…',                     time: 'now',  online: true, typing: true),
  ChatItem(name: 'ren.x',          last: 'did u get the file?',         time: 'yest', muted: true),
  ChatItem(name: 'noor.j',         last: 'omw',                         time: 'yest', mine: true, read: true),
  ChatItem(name: 'book.club',      last: 'joel: anyone read it yet?',   time: '2d',   muted: true, group: true),
  ChatItem(name: 'studio.atelier', last: 'Looking forward to it.',      time: '3d',   read: true),
  ChatItem(name: 'mom',            last: "call me when you're free",    time: '1w'),
  ChatItem(name: 'design.weekly',  last: 'New issue: matter & form',    time: '1w'),
  ChatItem(name: 'arjun',          last: '😂',                           time: '2w',  mine: true, delivered: true),
];

class ChatListScreen extends StatelessWidget {
  final bool dark;
  const ChatListScreen({super.key, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return Container(
      color: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      child: Stack(children: [
        GlassBackdrop(dark: dark),

        // Scrollable content under the floating chrome
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 232, 0, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('CHATS',
                  style: manrope(size: 11, weight: FontWeight.w700, color: sub, letterSpacing: 0.88)),
              ),
              ..._chats.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: _ChatRow(c: e.value, i: e.key + 1, dark: dark),
              )),
            ],
          ),
        ),

        // Header pill
        Positioned(
          top: 10, left: 12, right: 12,
          child: GlassHeader(
            dark: dark,
            child: Row(children: [
              Text('Messages',
                style: manrope(size: 17, weight: FontWeight.w700, color: fg, letterSpacing: -0.34)),
              const Spacer(),
              GlassCircleButton(dark: dark, icon: Icons.search_rounded, iconSize: 18),
              const SizedBox(width: 6),
              GlassCircleButton(dark: dark, icon: Icons.edit_outlined, iconSize: 18),
            ]),
          ),
        ),

        // Search bar
        Positioned(
          top: 70, left: 12, right: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.6),
                  border: Border.all(color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(children: [
                  Icon(Icons.search_rounded, size: 18, color: sub),
                  const SizedBox(width: 10),
                  Text('Search messages',
                    style: manrope(size: 14, weight: FontWeight.w500, color: sub, letterSpacing: -0.07)),
                ]),
              ),
            ),
          ),
        ),

        // Active now strip
        Positioned(
          top: 122, left: 0, right: 0,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text('ACTIVE NOW',
                style: manrope(size: 11, weight: FontWeight.w700, color: sub, letterSpacing: 0.88)),
            ),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _active.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => _ActiveAvatar(a: _active[i], i: i, dark: dark),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

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
        SizedBox(width: 54, height: 54, child: Stack(clipBehavior: Clip.none, children: [
          // story ring (gradient) or none
          if (a.story)
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  startAngle: 3.49, endAngle: 9.77, // ~200deg start
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
                    color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: _innerAvatar(),
                ),
              ),
            )
          else
            _innerAvatar(),
          // online dot
          Positioned(right: 1, bottom: 1, child: Container(
            width: 13, height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white : const Color(0xFF0A0A0A),
              border: Border.all(color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA), width: 2.5),
            ),
          )),
        ])),
        const SizedBox(height: 5),
        Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: manrope(size: 11, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
      ]),
    );
  }

  Widget _innerAvatar() => Container(
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: monoAvatar(dark, i)),
    alignment: Alignment.center,
    child: Text(a.name[0].toUpperCase(),
      style: manrope(size: 18, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
  );
}

class _ChatRow extends StatelessWidget {
  final ChatItem c;
  final int i;
  final bool dark;
  const _ChatRow({required this.c, required this.i, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    final previewColor = c.unread > 0 ? fg : sub;
    final previewWeight = c.unread > 0 ? FontWeight.w600 : FontWeight.w500;

    Widget previewLeading = const SizedBox.shrink();
    if (c.mine && !c.typing) {
      previewLeading = Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(Icons.done_all_rounded, size: 14, color: c.read ? fg : sub),
      );
    } else if (c.voice) {
      previewLeading = Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Icon(Icons.graphic_eq_rounded, size: 14, color: previewColor),
      );
    }

    final previewText = c.mine && !c.typing ? 'You: ${c.last}' : c.last;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => ChatScreen(dark: dark),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 300),
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
      },
      child: GlassSurface(
        dark: dark, radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          SizedBox(width: 50, height: 50, child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: monoAvatar(dark, i)),
              alignment: Alignment.center,
              child: Text(c.name[0].toUpperCase(),
                style: manrope(size: 18, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.36)),
            ),
            if (c.online) Positioned(right: 0, bottom: 0, child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? Colors.white : const Color(0xFF0A0A0A),
                border: Border.all(color: dark ? const Color(0xFF0C0C0E) : const Color(0xFFFAFAFA), width: 2.5),
              ),
            )),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: manrope(size: 14.5, weight: c.unread > 0 ? FontWeight.w800 : FontWeight.w700, color: fg, letterSpacing: -0.14))),
              if (c.muted) ...[
                const SizedBox(width: 6),
                Icon(Icons.volume_off_outlined, size: 14, color: sub),
              ],
            ]),
            const SizedBox(height: 2),
            Row(children: [
              previewLeading,
              Expanded(child: Text(previewText, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: manrope(
                  size: 12.5,
                  weight: previewWeight,
                  color: c.typing ? fg : previewColor,
                  letterSpacing: -0.05,
                ).copyWith(fontStyle: c.typing ? FontStyle.italic : FontStyle.normal),
              )),
            ]),
          ])),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text(c.time, style: manrope(size: 11, weight: c.unread > 0 ? FontWeight.w700 : FontWeight.w500, color: c.unread > 0 ? fg : sub, letterSpacing: -0.05)),
              if (c.unread > 0) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20, padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white : const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${c.unread}',
                    style: manrope(size: 11, weight: FontWeight.w800, color: dark ? const Color(0xFF0A0A0A) : Colors.white, letterSpacing: -0.1, height: 1)),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
