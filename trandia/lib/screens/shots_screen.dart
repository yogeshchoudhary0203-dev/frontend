// shots_screen.dart
// Vertical short-video "Shots" feed — minimal, Instagram-Reels-style chrome
// over a full-bleed video placeholder. Glass theme.
//
// Top: pill segmented "Fun" / "Learn" feed switcher (center) + camera (right).
// Right rail: bare icons — like, comment, share, save, more + spinning audio disc.
// Bottom-left: avatar + @handle + Follow pill → single-line caption + 3-dot expand.
//
// Drop in `lib/` alongside glass_common.dart.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_common.dart';

// ───────────────────────────────────────────────────────────────
// Models
// ───────────────────────────────────────────────────────────────
enum ShotsFeed { fun, learn }

class ShotData {
  final String user;
  final int avatarSeed;
  final String caption;
  final String likes;
  final String comments;
  final String shares;
  const ShotData({
    required this.user,
    required this.avatarSeed,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.shares,
  });
}

const _funShot = ShotData(
  user: 'maya.kw',
  avatarSeed: 0,
  caption:
      'POV: monday morning, the kettle is on strike and the cat just stepped on the keyboard. send help (or oat milk). recorded in one take, no edits — the chaos is real.',
  likes: '128K',
  comments: '2.4K',
  shares: '912',
);

const _learnShot = ShotData(
  user: 'studio.atelier',
  avatarSeed: 2,
  caption:
      'Three rules that fix 90% of bad type: optical spacing beats math, capitals always need more air, and trust your eye over the metric. Save this for your next poster.',
  likes: '46.2K',
  comments: '1.1K',
  shares: '3.8K',
);

// ───────────────────────────────────────────────────────────────
// Screen
// ───────────────────────────────────────────────────────────────
class ShotsScreen extends StatefulWidget {
  final bool dark;
  const ShotsScreen({super.key, this.dark = true});

  @override
  State<ShotsScreen> createState() => _ShotsScreenState();
}

class _ShotsScreenState extends State<ShotsScreen>
    with TickerProviderStateMixin {
  ShotsFeed _feed = ShotsFeed.fun;
  bool _liked = false;
  bool _saved = false;
  bool _expanded = false;

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  ShotData get _data => _feed == ShotsFeed.fun ? _funShot : _learnShot;

  void _setFeed(ShotsFeed f) {
    if (f == _feed) return;
    setState(() {
      _feed = f;
      _expanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Shots is always over a black video frame regardless of theme.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        _Video(feed: _feed),
        _topFade(),
        _bottomFade(),
        // Top: search slot · pill · camera
        Positioned(
          top: 14, left: 16, right: 16,
          child: _TopBar(feed: _feed, onTap: _setFeed),
        ),
        // Right rail
        Positioned(
          right: 12, bottom: 150,
          child: _RightRail(
            data: _data,
            liked: _liked,
            saved: _saved,
            spin: _spin,
            onLike: () => setState(() => _liked = !_liked),
            onSave: () => setState(() => _saved = !_saved),
          ),
        ),
        // Bottom-left: author + 1-line caption + 3-dot expand
        Positioned(
          left: 16, right: 78, bottom: 32,
          child: _CaptionBlock(
            data: _data,
            expanded: _expanded,
            onToggleExpand: () => setState(() => _expanded = !_expanded),
          ),
        ),
      ]),
    );
  }

  Widget _topFade() => const IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 130,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x8C000000), Color(0x00000000)],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

  Widget _bottomFade() => const IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x8C000000),
                    Color(0xC7000000),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
}

// ───────────────────────────────────────────────────────────────
// Video placeholder — full-bleed mono gradient + grain + progress
// ───────────────────────────────────────────────────────────────
class _Video extends StatelessWidget {
  final ShotsFeed feed;
  const _Video({required this.feed});

  @override
  Widget build(BuildContext context) {
    final palette = feed == ShotsFeed.fun
        ? const [Color(0xFF2A2A30), Color(0xFF141418), Color(0xFF050507)]
        : const [Color(0xFF1F262B), Color(0xFF0D1216), Color(0xFF040608)];

    final begin =
        feed == ShotsFeed.fun ? Alignment.topLeft : Alignment.topRight;
    final end =
        feed == ShotsFeed.fun ? Alignment.bottomRight : Alignment.bottomLeft;

    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin, end: end,
            colors: palette, stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
      // soft vignette
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0x00000000), Color(0x59000000)],
          ),
        ),
      ),
      // center label
      Center(
        child: Text(
          feed == ShotsFeed.fun ? 'SHOT · FUN FEED' : 'SHOT · LEARN FEED',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1.8,
            color: Colors.white.withOpacity(0.32),
          ),
        ),
      ),
      // progress bar
      Positioned(
        left: 16, right: 16, bottom: 12,
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: feed == ShotsFeed.fun ? 0.38 : 0.64,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ───────────────────────────────────────────────────────────────
// Top bar — pill switcher + camera
// ───────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final ShotsFeed feed;
  final ValueChanged<ShotsFeed> onTap;
  const _TopBar({required this.feed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 24),
        Expanded(child: Center(child: _FeedPill(feed: feed, onTap: onTap))),
        _BareIcon(icon: Icons.photo_camera_outlined, size: 24, onTap: () {}),
      ],
    );
  }
}

class _FeedPill extends StatelessWidget {
  final ShotsFeed feed;
  final ValueChanged<ShotsFeed> onTap;
  const _FeedPill({required this.feed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const pillWidth = 168.0;  // 2 * 80 + 8 padding
    const pillHeight = 36.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: pillWidth,
          height: pillHeight,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.32),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(children: [
            // sliding thumb
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              alignment: feed == ShotsFeed.fun
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: (pillWidth - 8) / 2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(children: [
              Expanded(
                child: _PillTab(
                  label: 'Fun',
                  active: feed == ShotsFeed.fun,
                  onTap: () => onTap(ShotsFeed.fun),
                ),
              ),
              Expanded(
                child: _PillTab(
                  label: 'Learn',
                  active: feed == ShotsFeed.learn,
                  onTap: () => onTap(ShotsFeed.learn),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PillTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: Text(
            label,
            style: manrope(
              size: 13,
              weight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? const Color(0xFF0A0A0A) : Colors.white.withOpacity(0.85),
              letterSpacing: -0.13,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Right rail — bare icons + spinning audio disc
// ───────────────────────────────────────────────────────────────
class _RightRail extends StatelessWidget {
  final ShotData data;
  final bool liked;
  final bool saved;
  final AnimationController spin;
  final VoidCallback onLike;
  final VoidCallback onSave;
  const _RightRail({
    required this.data,
    required this.liked,
    required this.saved,
    required this.spin,
    required this.onLike,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BareIconWithCount(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? const Color(0xFFFF3B5C) : Colors.white,
          size: 30, count: data.likes, onTap: onLike,
        ),
        const SizedBox(height: 18),
        _BareIconWithCount(
          icon: Icons.mode_comment_outlined,
          size: 28, count: data.comments, onTap: () {},
        ),
        const SizedBox(height: 18),
        _BareIconWithCount(
          icon: Icons.send_outlined,
          size: 28, count: data.shares, onTap: () {},
        ),
        const SizedBox(height: 18),
        _BareIcon(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          size: 28, onTap: onSave,
        ),
        const SizedBox(height: 18),
        _BareIcon(icon: Icons.more_horiz, size: 26, onTap: () {}),
        const SizedBox(height: 12),
        _AudioDisc(seed: data.avatarSeed, spin: spin),
      ],
    );
  }
}

class _BareIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;
  const _BareIcon({
    required this.icon,
    required this.size,
    this.color = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Color(0x8C000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}

class _BareIconWithCount extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final String count;
  final VoidCallback onTap;
  const _BareIconWithCount({
    required this.icon,
    required this.size,
    this.color = Colors.white,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BareIcon(icon: icon, size: size, color: color, onTap: onTap),
        const SizedBox(height: 4),
        Text(
          count,
          style: manrope(
            size: 11.5,
            weight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.115,
          ).copyWith(
            shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ],
    );
  }
}

class _AudioDisc extends StatelessWidget {
  final int seed;
  final AnimationController spin;
  const _AudioDisc({required this.seed, required this.spin});

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: spin,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF333333), Color(0xFF0A0A0A), Color(0xFF1F1F22)],
            stops: [0.0, 0.6, 1.0],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x8C000000), blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        alignment: Alignment.center,
        child: Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: monoAvatar(true, seed),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Bottom-left — author + one-line caption + 3-dot expand
// ───────────────────────────────────────────────────────────────
class _CaptionBlock extends StatelessWidget {
  final ShotData data;
  final bool expanded;
  final VoidCallback onToggleExpand;
  const _CaptionBlock({
    required this.data,
    required this.expanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final initial = data.user.substring(0, 1).toUpperCase();
    final shadow = const Shadow(color: Color(0x8C000000), blurRadius: 3, offset: Offset(0, 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // author row
        Row(children: [
          Container(
            width: 34, height: 34,
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xF2FFFFFF),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: monoAvatar(true, data.avatarSeed),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: manrope(
                  size: 13, weight: FontWeight.w800,
                  color: Colors.white, letterSpacing: -0.26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '@${data.user}',
            style: manrope(
              size: 14, weight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.14,
            ).copyWith(shadows: [shadow]),
          ),
          const SizedBox(width: 10),
          // Solid white pill Follow button
          Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            elevation: 2,
            shadowColor: const Color(0x40000000),
            child: InkWell(
              onTap: () {},
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                child: Text(
                  'Follow',
                  style: manrope(
                    size: 12, weight: FontWeight.w800,
                    color: const Color(0xFF0A0A0A), letterSpacing: -0.06,
                  ),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // caption + 3-dot expand
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onToggleExpand,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topLeft,
                  curve: Curves.easeInOut,
                  child: Text(
                    data.caption,
                    maxLines: expanded ? null : 1,
                    overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: manrope(
                      size: 13, weight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: -0.065,
                      height: 1.45,
                    ).copyWith(shadows: [shadow]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _BareIcon(
              icon: Icons.more_horiz,
              size: 18,
              onTap: onToggleExpand,
            ),
          ],
        ),
      ],
    );
  }
}
