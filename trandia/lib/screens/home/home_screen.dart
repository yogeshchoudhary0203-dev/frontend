import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _kBtnSize  = 64.0;
const double _kNavWidth = _kBtnSize;
const double _kItemH    = 54.0;
const double _kNavGap   = 6.0;
const double _kIconSize = 24.0;

// ── Mock story data ───────────────────────────────────
class _StoryData {
  final String name;
  final String initials;
  final Color  avatarColor;
  final bool   seen;
  final bool   isOwn;
  const _StoryData({
    required this.name,
    required this.initials,
    required this.avatarColor,
    this.seen  = false,
    this.isOwn = false,
  });
}

const _kStories = [
  _StoryData(name: 'Your Story', initials: '+',  avatarColor: Color(0xFF3A3A3E), isOwn: true),
  _StoryData(name: 'Arjun',      initials: 'AK', avatarColor: Color(0xFF2D3561)),
  _StoryData(name: 'Priya',      initials: 'PS', avatarColor: Color(0xFF1B4332)),
  _StoryData(name: 'Rohan',      initials: 'RV', avatarColor: Color(0xFF3D0C11)),
  _StoryData(name: 'Sneha',      initials: 'SN', avatarColor: Color(0xFF2C2C54)),
  _StoryData(name: 'Dev',        initials: 'DM', avatarColor: Color(0xFF1A1A2E)),
  _StoryData(name: 'Kavya',      initials: 'KR', avatarColor: Color(0xFF2D132C)),
  _StoryData(name: 'Nikhil',     initials: 'NK', avatarColor: Color(0xFF0D3349), seen: true),
];

// ═════════════════════════════════════════════════════
//  HOME SCREEN
// ═════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _navOpen   = false;
  int  _activeNav = 0;

  late AnimationController        _navCtrl;
  final List<Animation<double>>   _itemScales    = [];
  final List<Animation<double>>   _itemOpacities = [];

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));

    for (int i = 0; i < 5; i++) {
      final start = (4 - i) * 0.08;
      final end   = start + 0.55;
      _itemScales.add(Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _navCtrl,
          curve: Interval(start, end.clamp(0,1).toDouble(),
              curve: Curves.easeOutBack))));
      _itemOpacities.add(Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _navCtrl,
          curve: Interval(start, (start + 0.30).clamp(0,1).toDouble(),
              curve: Curves.easeOut))));
    }
  }

  @override
  void dispose() { _navCtrl.dispose(); super.dispose(); }

  void _toggleNav() {
    HapticFeedback.mediumImpact();
    setState(() => _navOpen = !_navOpen);
    _navOpen ? _navCtrl.forward(from: 0) : _navCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final islandBg   = isDark ? const Color(0xFFF0F0EC) : const Color(0xFF1A1A1A);
    final islandText = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);

    SystemChrome.setSystemUIOverlayStyle(isDark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(children: [

        // Background gradient
        Positioned.fill(child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter, radius: 1.5,
              colors: isDark
                  ? [const Color(0xFF1C1C1F), const Color(0xFF050506)]
                  : [const Color(0xFFF8F8FA), const Color(0xFFE2E2E8)],
            ),
          ),
        )),
        _Orb(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), size: 300, top: 100, left: -50),
        _Orb(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), size: 250, bottom: 150, right: -30),
        Positioned.fill(child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: (isDark ? Colors.black : Colors.white).withOpacity(0.1)),
        )),

        SafeArea(child: Stack(children: [

          // ── Trandia Island ──────────────────────────────
          Align(alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.only(top: 8),
              child: _TrandiaIsland(background: islandBg, textColor: islandText))),

          // ── Message icon ────────────────────────────────
          Align(alignment: Alignment.topRight,
            child: Padding(padding: const EdgeInsets.only(top: 10, right: 16),
              child: GestureDetector(
                onTap: () {},
                child: SizedBox(
                  width: 36, height: 36,
                  child: Center(child: CustomPaint(
                    size: const Size(_kIconSize, _kIconSize),
                    painter: _EnvelopeIconPainter(isDark: isDark),
                  )),
                ),
              ))),

          // ── Story section (below island) ────────────────
          Positioned(
            top: 62,   // island top(8) + height(37) + gap(17)
            left: 0, right: 0,
            child: _StorySection(isDark: isDark),
          ),

          // ── Staggered navbar ────────────────────────────
          Positioned(
            bottom: 30 + _kBtnSize + _kNavGap,
            right: 20,
            child: AnimatedBuilder(
              animation: _navCtrl,
              builder: (_, __) => IgnorePointer(
                ignoring: !_navOpen,
                child: _StaggeredNavbar(
                  isDark: isDark,
                  activeIndex: _activeNav,
                  itemScales: _itemScales,
                  itemOpacities: _itemOpacities,
                  onTap: (i) => setState(() => _activeNav = i),
                ),
              ),
            ),
          ),

          // ── Infinity button ─────────────────────────────
          Positioned(
            bottom: 30, right: 20,
            child: _InfinityBtn(isDark: isDark, isOpen: _navOpen, onTap: _toggleNav),
          ),

        ])),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════
//  STORY SECTION
// ═════════════════════════════════════════════════════
class _StorySection extends StatelessWidget {
  final bool isDark;
  const _StorySection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        itemCount: _kStories.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _StoryBubble(story: _kStories[i], isDark: isDark),
        ),
      ),
    );
  }
}

// ── Individual story bubble ───────────────────────────
class _StoryBubble extends StatelessWidget {
  final _StoryData story;
  final bool       isDark;
  const _StoryBubble({required this.story, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ring + Avatar
            SizedBox(
              width: 64, height: 64,
              child: CustomPaint(
                painter: _StoryRingPainter(
                  isDark: isDark,
                  seen:   story.seen,
                  isOwn:  story.isOwn,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: story.avatarColor,
                      // subtle inner border to separate avatar from ring
                      border: Border.all(
                        color: isDark
                            ? Colors.black.withOpacity(0.60)
                            : Colors.white.withOpacity(0.70),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: story.isOwn
                          ? _AddPlusIcon(isDark: isDark)
                          : Text(
                              story.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Name label
            Text(
              story.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(
                    story.seen ? 0.38 : 0.80),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Story ring painter ────────────────────────────────
class _StoryRingPainter extends CustomPainter {
  final bool isDark;
  final bool seen;
  final bool isOwn;
  const _StoryRingPainter(
      {required this.isDark, this.seen = false, this.isOwn = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = size.width  / 2 - 1.5;

    if (isOwn) {
      // "Your Story" — dashed ring with theme color
      _drawDashedCircle(canvas, Offset(cx, cy), radius, isDark);
      return;
    }

    if (seen) {
      // Seen — faint single-color ring
      canvas.drawCircle(
        Offset(cx, cy), radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.20),
      );
      return;
    }

    // Unseen — smooth gradient ring
    final List<Color> gradColors = isDark
        ? [const Color(0xFFFFFFFF), const Color(0xFFAAAAAA), const Color(0xFF666666)]
        : [const Color(0xFF1A1A1A), const Color(0xFF555555), const Color(0xFF999999)];

    final sweepGradient = ui.Gradient.sweep(
      Offset(cx, cy),
      gradColors,
      [0.0, 0.5, 1.0],
      TileMode.clamp,
      -math.pi / 2,
      -math.pi / 2 + math.pi * 2,
    );

    canvas.drawCircle(
      Offset(cx, cy), radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..shader = sweepGradient
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawDashedCircle(
      Canvas canvas, Offset center, double radius, bool isDark) {
    const dashCount  = 20;
    const dashAngle  = (2 * math.pi) / dashCount;
    const gapFraction = 0.30;
    final color = (isDark ? Colors.white : Colors.black).withOpacity(0.45);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = color;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle - math.pi / 2;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StoryRingPainter o) =>
      o.isDark != isDark || o.seen != seen || o.isOwn != isOwn;
}

// ── Add-story plus icon ───────────────────────────────
class _AddPlusIcon extends StatelessWidget {
  final bool isDark;
  const _AddPlusIcon({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = isDark ? Colors.white : const Color(0xFF1A1A1A);
    return CustomPaint(
      size: const Size(18, 18),
      painter: _PlusPainter(color: c),
    );
  }
}

class _PlusPainter extends CustomPainter {
  final Color color;
  const _PlusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx, cy - 5.5), Offset(cx, cy + 5.5), p);
    canvas.drawLine(Offset(cx - 5.5, cy), Offset(cx + 5.5, cy), p);
  }

  @override
  bool shouldRepaint(_PlusPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════
//  STAGGERED NAVBAR
// ══════════════════════════════════════════════════════
class _StaggeredNavbar extends StatelessWidget {
  final bool isDark;
  final int  activeIndex;
  final List<Animation<double>> itemScales;
  final List<Animation<double>> itemOpacities;
  final ValueChanged<int> onTap;

  const _StaggeredNavbar({
    required this.isDark,
    required this.activeIndex,
    required this.itemScales,
    required this.itemOpacities,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navH   = 5 * _kItemH + 12.0;
    final glass  = (isDark ? Colors.white : Colors.black).withOpacity(0.09);
    final border = (isDark ? Colors.white : Colors.black).withOpacity(0.16);

    return FadeTransition(
      opacity: itemOpacities.last,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kNavWidth / 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            width: _kNavWidth,
            height: navH,
            decoration: BoxDecoration(
              color: glass,
              borderRadius: BorderRadius.circular(_kNavWidth / 2),
              border: Border.all(color: border, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.10),
                  blurRadius: 20, offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final active = activeIndex == i;
                  return ScaleTransition(
                    scale: itemScales[i],
                    child: FadeTransition(
                      opacity: itemOpacities[i],
                      child: GestureDetector(
                        onTap: () { HapticFeedback.selectionClick(); onTap(i); },
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: _kNavWidth, height: _kItemH,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? (isDark
                                        ? Colors.white.withOpacity(0.18)
                                        : Colors.black.withOpacity(0.12))
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: CustomPaint(
                                  size: const Size(_kIconSize, _kIconSize),
                                  painter: _NavIconPainter(
                                      index: i, isDark: isDark, active: active),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  ENVELOPE ICON
// ══════════════════════════════════════════════════════
class _EnvelopeIconPainter extends CustomPainter {
  final bool isDark;
  const _EnvelopeIconPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final color = isDark ? Colors.white : const Color(0xFF2A2A2A);
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color.withOpacity(0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 1.2, w - 1.0, h - 2.4),
          const Radius.circular(5.0)),
      p,
    );

    canvas.drawPath(
      Path()
        ..moveTo(0.5 + 5.0, 1.2)
        ..quadraticBezierTo(w / 2, h * 0.55, w - 0.5 - 5.0, 1.2),
      p,
    );
  }

  @override
  bool shouldRepaint(_EnvelopeIconPainter o) => o.isDark != isDark;
}

// ══════════════════════════════════════════════════════
//  NAV ICON PAINTERS
// ══════════════════════════════════════════════════════
class _NavIconPainter extends CustomPainter {
  final int  index;
  final bool isDark;
  final bool active;
  const _NavIconPainter({required this.index, required this.isDark, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final base   = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final col    = active ? base : base.withOpacity(0.50);
    final sw     = active ? 1.8 : 1.6;
    final p      = Paint()..color = col..style = PaintingStyle.stroke
        ..strokeWidth = sw..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final filled = Paint()..color = col..style = PaintingStyle.fill;
    final w = size.width; final h = size.height;
    final cx = w / 2;    final cy = h / 2;

    switch (index) {
      case 0: // HOME
        canvas.drawPath(Path()
          ..moveTo(w * 0.05, h * 0.52)
          ..quadraticBezierTo(cx, h * 0.02, w * 0.95, h * 0.52), p..strokeWidth = sw + 0.2);
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.50, w * 0.76, h * 0.46),
            const Radius.circular(3.0)), p);
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w * 0.13, h * 0.64, w * 0.26, h * 0.32),
            const Radius.circular(2.5)), p);
        break;

      case 1: // SHOTS
        canvas.drawCircle(Offset(cx, cy), w / 2 - 1.0, p);
        canvas.drawPath(Path()
          ..moveTo(cx - 3.5, cy - 5.0)
          ..cubicTo(cx - 3.5, cy - 6.0, cx + 6.5, cy - 1.5, cx + 6.5, cy)
          ..cubicTo(cx + 6.5, cy + 1.5, cx - 3.5, cy + 6.0, cx - 3.5, cy + 5.0)
          ..close(), filled);
        break;

      case 2: // ADD
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(0.8, 0.8, w - 1.6, h - 1.6),
            const Radius.circular(6.0)), p);
        canvas.drawLine(Offset(cx, cy - 5.0), Offset(cx, cy + 5.0), p);
        canvas.drawLine(Offset(cx - 5.0, cy), Offset(cx + 5.0, cy), p);
        break;

      case 3: // SEARCH
        final r = w * 0.265; final ox = cx - 2.8; final oy = cy - 2.8;
        canvas.drawCircle(Offset(ox, oy), r, p);
        canvas.drawLine(Offset(ox + r * 0.72, oy + r * 0.72), Offset(w - 1.0, h - 1.0),
            Paint()..color = col..style = PaintingStyle.stroke
                ..strokeWidth = sw + 0.5..strokeCap = StrokeCap.round);
        break;

      case 4: // PROFILE
        canvas.drawCircle(Offset(cx, h * 0.30), h * 0.185, filled);
        canvas.drawPath(Path()
          ..moveTo(w * 0.06, h - 1.0)
          ..cubicTo(w * 0.06, h * 0.62, w * 0.94, h * 0.62, w * 0.94, h - 1.0)
          ..close(), filled);
        break;
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter o) =>
      o.index != index || o.isDark != isDark || o.active != active;
}

// ══════════════════════════════════════════════════════
//  INFINITY BUTTON
// ══════════════════════════════════════════════════════
class _InfinityBtn extends StatefulWidget {
  final bool isDark; final bool isOpen; final VoidCallback onTap;
  const _InfinityBtn({required this.isDark, required this.isOpen, required this.onTap});
  @override
  State<_InfinityBtn> createState() => _InfinityBtnState();
}

class _InfinityBtnState extends State<_InfinityBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final glass  = (widget.isDark ? Colors.white : Colors.black).withOpacity(0.09);
    final border = (widget.isDark ? Colors.white : Colors.black).withOpacity(0.18);
    final iconC  = widget.isDark ? Colors.white : const Color(0xFF1A1A1A);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: GestureDetector(
          onTapDown: (_) => _ctrl.forward(),
          onTapUp:   (_) { _ctrl.reverse(); widget.onTap(); },
          onTapCancel: () => _ctrl.reverse(),
          child: ClipOval(child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: _kBtnSize, height: _kBtnSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: glass,
                border: Border.all(color: border, width: 0.9),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: CustomPaint(painter: _InfinityPainter(color: iconC)),
            ),
          )),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  INFINITY PAINTER
// ══════════════════════════════════════════════════════
class _InfinityPainter extends CustomPainter {
  final Color color;
  const _InfinityPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    const a = 13.0; const b = 7.0;
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy)
        ..cubicTo(cx + a * 0.5, cy - b, cx + a, cy - b, cx + a, cy)
        ..cubicTo(cx + a, cy + b, cx + a * 0.5, cy + b, cx, cy)
        ..cubicTo(cx - a * 0.5, cy - b, cx - a, cy - b, cx - a, cy)
        ..cubicTo(cx - a, cy + b, cx - a * 0.5, cy + b, cx, cy),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
          ..color = color.withOpacity(0.88),
    );
  }
  @override
  bool shouldRepaint(_InfinityPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════
//  ORB
// ══════════════════════════════════════════════════════
class _Orb extends StatelessWidget {
  final Color color; final double size;
  final double? top, bottom, left, right;
  const _Orb({required this.color, required this.size,
      this.top, this.bottom, this.left, this.right});
  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]))));
}

// ══════════════════════════════════════════════════════
//  TRANDIA ISLAND
// ══════════════════════════════════════════════════════
class _TrandiaIsland extends StatelessWidget {
  final Color background, textColor;
  const _TrandiaIsland({required this.background, required this.textColor});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    height: 37, width: 124,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(22)),
    child: Center(
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600,
            letterSpacing: -0.2, decoration: TextDecoration.none),
        child: const Text('Trandia'),
      ),
    ),
  );
}
