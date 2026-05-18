// chat_screen.dart
// Conversation view — glass header, message bubbles (text + voice + typing), glass input.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_common.dart';

class ChatMsg {
  final bool me;          // true → my bubble (filled), false → their bubble (glass)
  final String text;
  final String time;
  final bool read;
  final bool voice;
  final String? voiceDur;
  final bool typing;
  const ChatMsg.text({required this.me, required this.text, required this.time, this.read = false})
      : voice = false, voiceDur = null, typing = false;
  const ChatMsg.voice({required this.me, required this.time, required String dur})
      : text = '', read = false, voice = true, voiceDur = dur, typing = false;
  const ChatMsg.typing()
      : me = false, text = '', time = '', read = false, voice = false, voiceDur = null, typing = true;
}

const _msgs = <ChatMsg>[
  ChatMsg.text(me: false, text: 'hey! u up?',                                       time: '10:58'),
  ChatMsg.text(me: true,  text: "yeah barely 😅 what's up",                          time: '10:59'),
  ChatMsg.text(me: false, text: 'are u free this evening?',                          time: '11:02'),
  ChatMsg.text(me: false, text: 'thinking of grabbing coffee at that new place',     time: '11:02'),
  ChatMsg.text(me: true,  text: "🤍 i'd love to",                                     time: '11:03', read: true),
  ChatMsg.text(me: true,  text: 'send me the address',                                time: '11:03', read: true),
  ChatMsg.text(me: false, text: 'sec — pulling it up',                                time: '11:04'),
  ChatMsg.text(me: false, text: 'Studio Atelier, Linienstraße 144',                  time: '11:05'),
  ChatMsg.voice(me: false, time: '11:05', dur: '0:24'),
  ChatMsg.text(me: true,  text: 'perfect, see u at 7',                                time: '11:06', read: false),
  ChatMsg.typing(),
];

class ChatScreen extends StatelessWidget {
  final bool dark;
  const ChatScreen({super.key, required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    // group consecutive same-side messages → only last gets timestamp
    final runs = <List<ChatMsg>>[];
    for (final m in _msgs) {
      if (runs.isNotEmpty && !m.typing && !runs.last.first.typing && runs.last.first.me == m.me) {
        runs.last.add(m);
      } else {
        runs.add([m]);
      }
    }

    return Container(
      color: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      child: Stack(children: [
        GlassBackdrop(dark: dark),

        // Messages
        Positioned.fill(
          top: 76, bottom: 76,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              // date pill
              Center(child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.6),
                      border: Border.all(color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('TODAY',
                      style: manrope(size: 11, weight: FontWeight.w700, color: sub, letterSpacing: 0.88)),
                  ),
                ),
              )),
              const SizedBox(height: 10),
              for (final run in runs) ...[
                for (int i = 0; i < run.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _Bubble(m: run[i], dark: dark, last: i == run.length - 1),
                  ),
                const SizedBox(height: 7),
              ],
            ],
          ),
        ),

        // Header
        Positioned(
          top: 10, left: 12, right: 12,
          child: GlassHeader(
            dark: dark, height: 56,
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
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: monoAvatar(dark, 0)),
                  alignment: Alignment.center,
                  child: Text('S',
                    style: manrope(size: 15, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
                ),
                Positioned(right: -1, bottom: -1, child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark ? Colors.white : const Color(0xFF0A0A0A),
                    border: Border.all(color: dark ? const Color(0xFF0C0C0E) : const Color(0xFFFAFAFA), width: 2),
                  ),
                )),
              ]),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('sarah.d', style: manrope(size: 15, weight: FontWeight.w800, color: fg, letterSpacing: -0.225)),
                const SizedBox(height: 2),
                Text('Active now', style: manrope(size: 11, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
              ])),
              GlassCircleButton(dark: dark, icon: Icons.call_outlined, iconSize: 18),
              const SizedBox(width: 6),
              GlassCircleButton(dark: dark, icon: Icons.videocam_outlined, iconSize: 20),
              const SizedBox(width: 6),
              GlassCircleButton(dark: dark, icon: Icons.info_outline_rounded, iconSize: 18),
            ]),
          ),
        ),

        // Input bar
        Positioned(
          bottom: 10, left: 12, right: 12,
          child: SizedBox(
            height: 54,
            child: GlassSurface(
              dark: dark,
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              blurSigma: 28,
              shadow: BoxShadow(
                color: dark ? Colors.black.withOpacity(0.6) : const Color(0xFF14161E).withOpacity(0.20),
                blurRadius: 30, offset: const Offset(0, -10), spreadRadius: -16,
              ),
              child: Row(children: [
                const SizedBox(width: 2),
                GlassCircleButton(
                  dark: dark, icon: Icons.add_rounded, size: 38, iconSize: 22,
                  bg: dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                ),
                const SizedBox(width: 8),
                Expanded(child: Row(children: [
                  Expanded(child: Text('Message…',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: manrope(size: 14, weight: FontWeight.w500, color: sub, letterSpacing: -0.07))),
                  Icon(Icons.sentiment_satisfied_alt_outlined, size: 20, color: fg),
                ])),
                const SizedBox(width: 8),
                GlassCircleButton(
                  dark: dark, icon: Icons.photo_camera_outlined, size: 38, iconSize: 20,
                  bg: dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                ),
                const SizedBox(width: 6),
                GlassCircleButton(
                  dark: dark, icon: Icons.mic_none_rounded, size: 38, iconSize: 20,
                  bg: dark ? Colors.white : const Color(0xFF0A0A0A),
                  fg: dark ? const Color(0xFF0A0A0A) : Colors.white,
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
  final ChatMsg m;
  final bool dark;
  final bool last;
  const _Bubble({required this.m, required this.dark, required this.last});

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    if (m.typing) return _typingBubble(dark, sub);

    final radius = m.me
      ? const BorderRadius.only(
          topLeft: Radius.circular(20), topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20), bottomRight: Radius.circular(6))
      : const BorderRadius.only(
          topLeft: Radius.circular(20), topRight: Radius.circular(20),
          bottomLeft: Radius.circular(6), bottomRight: Radius.circular(20));

    if (m.voice) return _voiceBubble(m, dark, radius);

    return Align(
      alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: m.me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _bubbleBox(m, dark, radius),
            if (last) Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(m.time, style: manrope(size: 10.5, weight: FontWeight.w500, color: sub, letterSpacing: -0.05)),
                if (m.me) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.done_all_rounded, size: 13, color: m.read ? fg : sub),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleBox(ChatMsg m, bool dark, BorderRadius radius) {
    if (m.me) {
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

  Widget _voiceBubble(ChatMsg m, bool dark, BorderRadius radius) {
    final bgMe = dark ? Colors.white : const Color(0xFF0A0A0A);
    final txtMe = dark ? const Color(0xFF0A0A0A) : Colors.white;
    final bgThem = dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.78);
    final txtThem = GlassTokens.fg(dark);
    final bg = m.me ? bgMe : bgThem;
    final txt = m.me ? txtMe : txtThem;

    return Align(
      alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg, borderRadius: radius,
              border: m.me ? null : Border.all(color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: m.me
                    ? (dark ? const Color(0xFF0A0A0A) : Colors.white)
                    : (dark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.08)),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.play_arrow_rounded, size: 14,
                  color: m.me ? (dark ? Colors.white : const Color(0xFF0A0A0A)) : txt),
              ),
              const SizedBox(width: 10),
              // waveform
              SizedBox(height: 18, child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final pair in const [[6,1.0],[12,1.0],[9,1.0],[16,1.0],[10,1.0],[14,0.4],[8,0.4],[12,0.4],[6,0.4],[10,0.4],[14,0.4],[8,0.4]])
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Container(width: 2, height: pair[0].toDouble(),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(1),
                        color: txt.withOpacity(pair[1] as double))),
                  ),
              ])),
              const SizedBox(width: 10),
              Text(m.voiceDur!,
                style: manrope(size: 11, weight: FontWeight.w600, color: txt.withOpacity(0.8), letterSpacing: -0.05)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _typingBubble(bool dark, Color sub) {
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
    // dark from inherited theme? Use a heuristic via Theme brightness:
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = ((_c.value * 1200) - widget.delay) % 1200 / 1200;
        // bell curve 0..1..0 around 0.4
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
