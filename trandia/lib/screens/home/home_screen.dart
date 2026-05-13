import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _kBtnSize  = 64.0;
const double _kNavWidth = _kBtnSize;
const double _kItemH    = 52.0;
const double _kNavGap   = 6.0;
const double _kIconSize = 24.0; // same for both msg icon & navbar icons

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _navOpen   = false;
  int  _activeNav = 0;

  late AnimationController _navCtrl;
  late Animation<double>   _navFade;
  late Animation<double>   _navScale;
  late Animation<Offset>   _navSlide;

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _navFade  = CurvedAnimation(parent: _navCtrl, curve: Curves.easeOut);
    _navScale = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _navCtrl, curve: Curves.easeOutBack));
    _navSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _navCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _navCtrl.dispose(); super.dispose(); }

  void _toggleNav() {
    HapticFeedback.lightImpact();
    setState(() => _navOpen = !_navOpen);
    _navOpen ? _navCtrl.forward() : _navCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(isDark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));

    final islandBg   = isDark ? const Color(0xFFF0F0EC) : const Color(0xFF1A1A1A);
    final islandText = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(children: [
        // Background
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

        // Content
        SafeArea(child: Stack(children: [

          // Trandia Island
          Align(alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.only(top: 8),
              child: _TrandiaIsland(background: islandBg, textColor: islandText))),

          // ── Message icon top-right ──
          Align(alignment: Alignment.topRight,
            child: Padding(padding: const EdgeInsets.only(top: 10, right: 16),
              child: GestureDetector(
                onTap: () {},
                child: SizedBox(
                  width: 36, height: 36,   // smaller tap container
                  child: Center(
                    child: CustomPaint(
                      size: const Size(_kIconSize, _kIconSize),
                      painter: _EnvelopeIconPainter(isDark: isDark),
                    ),
                  ),
                ),
              ))),

          // ── Vertical navbar ──
          Positioned(
            bottom: 30 + _kBtnSize + _kNavGap,
            right: 20,
            child: AnimatedBuilder(
              animation: _navCtrl,
              builder: (_, __) => IgnorePointer(
                ignoring: !_navOpen,
                child: FadeTransition(opacity: _navFade,
                  child: SlideTransition(position: _navSlide,
                    child: ScaleTransition(
                      scale: _navScale,
                      alignment: Alignment.bottomCenter,
                      child: _VerticalNav(
                        isDark: isDark,
                        activeIndex: _activeNav,
                        onTap: (i) => setState(() => _activeNav = i),
                      ),
                    ))),
              ),
            ),
          ),

          // ── Infinity button ──
          Positioned(
            bottom: 30, right: 20,
            child: _InfinityBtn(isDark: isDark, isOpen: _navOpen, onTap: _toggleNav),
          ),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════
//  ENVELOPE / MAIL ICON  (matches image 1)
//  Rounded rect body + V-fold lines, stroke style
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
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Rounded rect body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.9, 1.5, w - 1.8, h - 3.0),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(body, p);

    // V-fold: left-top corner → center-top-area → right-top corner
    final fold = Path()
      ..moveTo(0.9 + 3.5, 1.5)          // top-left corner of body
      ..lineTo(w / 2, h * 0.52)          // center fold point
      ..lineTo(w - 0.9 - 3.5, 1.5);     // top-right corner of body
    canvas.drawPath(fold, p);
  }

  @override
  bool shouldRepaint(_EnvelopeIconPainter o) => o.isDark != isDark;
}

// ══════════════════════════════════════════════════════
//  VERTICAL PILL NAVBAR
// ══════════════════════════════════════════════════════
class _VerticalNav extends StatelessWidget {
  final bool isDark;
  final int  activeIndex;
  final ValueChanged<int> onTap;
  const _VerticalNav({required this.isDark, required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final navH   = 5 * _kItemH + 12.0;
    final glass  = (isDark ? Colors.white : Colors.black).withOpacity(0.08);
    final border = (isDark ? Colors.white : Colors.black).withOpacity(0.16);

    return ClipRRect(
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
                return GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: _kNavWidth,
                    height: _kItemH,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
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
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  NAV ICON PAINTERS  (exact match to reference images)
// ══════════════════════════════════════════════════════
class _NavIconPainter extends CustomPainter {
  final int index;
  final bool isDark;
  final bool active;
  const _NavIconPainter(
      {required this.index, required this.isDark, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final col  = active ? base : base.withOpacity(0.52);

    final stroke = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = col
      ..style = PaintingStyle.fill;

    final w  = size.width;
    final h  = size.height;
    final cx = w / 2;
    final cy = h / 2;

    switch (index) {

      // ── 0: HOME — filled solid house (image 2) ──────────────────────
      case 0:
        // Roof triangle (filled)
        final roof = Path()
          ..moveTo(cx, 1.0)
          ..lineTo(w, h * 0.46)
          ..lineTo(0, h * 0.46)
          ..close();
        canvas.drawPath(roof, fill);

        // Body (filled rectangle)
        final body = Rect.fromLTWH(w * 0.15, h * 0.46, w * 0.70, h * 0.54);
        canvas.drawRect(body, fill);

        // Door cutout (punch out with background color)
        final doorC = isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF8F8FA);
        final door  = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.14, h * 0.66, w * 0.28, h * 0.34),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(door, Paint()..color = doorC..style = PaintingStyle.fill);
        break;

      // ── 1: SHOTS — circle + rounded-corner play triangle (image 3) ──
      case 1:
        // Outer circle stroke
        canvas.drawCircle(Offset(cx, cy), w / 2 - 1.0, stroke);
        // Rounded play triangle (filled)
        const offset = 1.5;
        final tri = Path()
          ..moveTo(cx - 3.5 + offset, cy - 5.5)
          ..lineTo(cx + 6.0 + offset, cy)
          ..lineTo(cx - 3.5 + offset, cy + 5.5)
          ..close();
        canvas.drawPath(tri, Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
        break;

      // ── 2: ADD — rounded square + plus (image 5) ────────────────────
      case 2:
        // Rounded square
        final box = RRect.fromRectAndRadius(
          Rect.fromLTWH(0.8, 0.8, w - 1.6, h - 1.6),
          const Radius.circular(5.5),
        );
        canvas.drawRRect(box, stroke);
        // Plus arms
        canvas.drawLine(Offset(cx, cy - 5.5), Offset(cx, cy + 5.5), stroke);
        canvas.drawLine(Offset(cx - 5.5, cy), Offset(cx + 5.5, cy), stroke);
        break;

      // ── 3: SEARCH — magnifying glass (image 4) ──────────────────────
      case 3:
        const r = 6.2;
        final ox = cx - 2.5;
        final oy = cy - 2.5;
        // Glass circle
        canvas.drawCircle(Offset(ox, oy), r, stroke);
        // Handle — thick & rounded
        canvas.drawLine(
          Offset(ox + r * 0.68, oy + r * 0.68),
          Offset(w - 1.2, h - 1.2),
          Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
        break;

      // ── 4: PROFILE — head circle + body dome (image 6) ──────────────
      case 4:
        // Head (filled circle)
        canvas.drawCircle(Offset(cx, h * 0.30), h * 0.185, fill);
        // Body (filled half-ellipse / dome)
        final bodyRect = Rect.fromCenter(
          center: Offset(cx, h * 0.825),
          width: w * 0.72,
          height: h * 0.50,
        );
        canvas.drawArc(bodyRect, 3.14159, 3.14159, true, fill); // top half arc
        break;
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter o) =>
      o.index != index || o.isDark != isDark || o.active != active;
}

// ══════════════════════════════════════════════════════
//  INFINITY BUTTON — glass, no glow
// ══════════════════════════════════════════════════════
class _InfinityBtn extends StatefulWidget {
  final bool isDark;
  final bool isOpen;
  final VoidCallback onTap;
  const _InfinityBtn(
      {required this.isDark, required this.isOpen, required this.onTap});

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
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
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
          onTapDown:   (_) => _ctrl.forward(),
          onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
          onTapCancel: () => _ctrl.reverse(),
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: _kBtnSize, height: _kBtnSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glass,
                  border: Border.all(color: border, width: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CustomPaint(
                    painter: _InfinityPainter(color: iconC)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  INFINITY PAINTER — smooth lemniscate
// ══════════════════════════════════════════════════════
class _InfinityPainter extends CustomPainter {
  final Color color;
  const _InfinityPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    const a  = 13.0;
    const b  =  7.0;

    final path = Path()
      ..moveTo(cx, cy)
      ..cubicTo(cx + a * 0.5, cy - b, cx + a, cy - b, cx + a, cy)
      ..cubicTo(cx + a, cy + b, cx + a * 0.5, cy + b, cx, cy)
      ..cubicTo(cx - a * 0.5, cy - b, cx - a, cy - b, cx - a, cy)
      ..cubicTo(cx - a, cy + b, cx - a * 0.5, cy + b, cx, cy);

    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withOpacity(0.88));
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
  const _Orb(
      {required this.color, required this.size,
        this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [color, color.withOpacity(0)]))));
}

// ══════════════════════════════════════════════════════
//  TRANDIA ISLAND
// ══════════════════════════════════════════════════════
class _TrandiaIsland extends StatelessWidget {
  final Color background, textColor;
  const _TrandiaIsland(
      {required this.background, required this.textColor});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    height: 37, width: 124,
    decoration: BoxDecoration(
        color: background, borderRadius: BorderRadius.circular(22)),
    child: Center(
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
            color: textColor, fontSize: 14, fontWeight: FontWeight.w600,
            letterSpacing: -0.2, decoration: TextDecoration.none),
        child: const Text('Trandia'),
      ),
    ),
  );
}
