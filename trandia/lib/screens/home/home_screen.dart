import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _kBtnSize   = 64.0;
const double _kNavWidth  = _kBtnSize;
const double _kItemH     = 52.0;
const double _kNavGap    = 6.0; // visible but minimal gap

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _navOpen = false;
  int  _activeNav = 0;

  late AnimationController _navCtrl;
  late Animation<double>   _navFade;
  late Animation<double>   _navScale;
  late Animation<Offset>   _navSlide;

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _navFade  = CurvedAnimation(parent: _navCtrl, curve: Curves.easeOut);
    _navScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _navCtrl, curve: Curves.easeOutBack),
    );
    _navSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _navCtrl, curve: Curves.easeOutCubic));
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
        // ── Background
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

        // ── Content
        SafeArea(child: Stack(children: [

          // Trandia Island
          Align(alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.only(top: 8),
              child: _TrandiaIsland(background: islandBg, textColor: islandText))),

          // Message icon — clean stroke only, no box
          Align(alignment: Alignment.topRight,
            child: Padding(padding: const EdgeInsets.only(top: 8, right: 14),
              child: GestureDetector(
                onTap: () {},
                child: SizedBox(
                  width: 44, height: 44,
                  child: CustomPaint(painter: _MsgIconPainter(isDark: isDark)),
                ),
              ))),

          // Vertical navbar (above button)
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
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Infinity button
          Positioned(
            bottom: 30, right: 20,
            child: _InfinityBtn(isDark: isDark, isOpen: _navOpen, onTap: _toggleNav),
          ),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════
//  MESSAGE ICON — clean minimal stroke, no box
// ═══════════════════════════════════════════════════
class _MsgIconPainter extends CustomPainter {
  final bool isDark;
  const _MsgIconPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final c  = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final cx = size.width  / 2;
    final cy = size.height / 2 - 1;

    final p = Paint()
      ..color = c.withOpacity(0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Bubble outline — smooth rounded rect
    const bw = 20.0; // half-width
    const bh = 13.0; // half-height
    const r  = 5.0;

    final bubble = Path()
      ..moveTo(cx - bw + r, cy - bh)
      ..lineTo(cx + bw - r, cy - bh)
      ..quadraticBezierTo(cx + bw, cy - bh, cx + bw, cy - bh + r)
      ..lineTo(cx + bw, cy + bh - r - 3)
      ..quadraticBezierTo(cx + bw, cy + bh - 3, cx + bw - r, cy + bh - 3)
      ..lineTo(cx + 3, cy + bh - 3)
      // small curved tail
      ..quadraticBezierTo(cx + 1, cy + bh - 3, cx - 2, cy + bh + 4)
      ..quadraticBezierTo(cx - 5, cy + bh - 3, cx - bw + r + 2, cy + bh - 3)
      ..lineTo(cx - bw + r, cy + bh - 3)
      ..quadraticBezierTo(cx - bw, cy + bh - 3, cx - bw, cy + bh - r - 3)
      ..lineTo(cx - bw, cy - bh + r)
      ..quadraticBezierTo(cx - bw, cy - bh, cx - bw + r, cy - bh)
      ..close();

    canvas.drawPath(bubble, p);

    // Two inner lines
    final thin = Paint()
      ..color = c.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - 8, cy - 3), Offset(cx + 8, cy - 3), thin);
    canvas.drawLine(Offset(cx - 8, cy + 3), Offset(cx + 3, cy + 3), thin);
  }

  @override
  bool shouldRepaint(_MsgIconPainter o) => o.isDark != isDark;
}

// ═══════════════════════════════════════════════════
//  VERTICAL PILL NAVBAR
// ═══════════════════════════════════════════════════
class _VerticalNav extends StatelessWidget {
  final bool isDark;
  final int  activeIndex;
  final ValueChanged<int> onTap;
  const _VerticalNav({required this.isDark, required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final navH         = 5 * _kItemH + 12.0;
    final glass        = (isDark ? Colors.white : Colors.black).withOpacity(0.08);
    final border       = (isDark ? Colors.white : Colors.black).withOpacity(0.16);

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
                              ? (isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12))
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(22, 22),
                            painter: _NavIcon(index: i, isDark: isDark, active: active),
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

// ═══════════════════════════════════════════════════
//  NAV ICONS — modern minimal
// ═══════════════════════════════════════════════════
class _NavIcon extends CustomPainter {
  final int index;
  final bool isDark;
  final bool active;
  const _NavIcon({required this.index, required this.isDark, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? Colors.white : Colors.black;
    final c    = active ? base : base.withOpacity(0.50);
    final sw   = active ? 1.7 : 1.5;

    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fp = Paint()..color = c..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    switch (index) {

      // 0 — HOME: clean house with rounded roof peak
      case 0:
        final roof = Path()
          ..moveTo(cx, 1.5)
          ..lineTo(w - 2, h * 0.46)
          ..lineTo(1, h * 0.46);
        canvas.drawPath(roof, p..strokeJoin = StrokeJoin.round);
        // walls
        canvas.drawLine(Offset(1, h * 0.46), Offset(1, h - 1), p);
        canvas.drawLine(Offset(w - 2, h * 0.46), Offset(w - 2, h - 1), p);
        canvas.drawLine(Offset(1, h - 1), Offset(w - 2, h - 1), p);
        // door
        final door = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 2.8, h * 0.60, 5.5, h - 1 - h * 0.60),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(door, p);
        break;

      // 1 — SHOTS: rounded play square
      case 1:
        final box = RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, w - 2, h - 2),
          const Radius.circular(4),
        );
        canvas.drawRRect(box, p);
        final tri = Path()
          ..moveTo(cx - 2.5, cy - 4)
          ..lineTo(cx + 5, cy)
          ..lineTo(cx - 2.5, cy + 4)
          ..close();
        canvas.drawPath(tri, fp);
        break;

      // 2 — ADD: clean plus in thin circle
      case 2:
        canvas.drawCircle(Offset(cx, cy), w / 2 - 1.5, p);
        canvas.drawLine(Offset(cx, cy - 5), Offset(cx, cy + 5), p);
        canvas.drawLine(Offset(cx - 5, cy), Offset(cx + 5, cy), p);
        break;

      // 3 — SEARCH: magnifying glass, clean
      case 3:
        canvas.drawCircle(Offset(cx - 1.5, cy - 1.5), 5.8, p);
        final handle = Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw + 0.3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(cx + 2.5, cy + 2.5),
          Offset(w - 1.5, h - 1.5),
          handle,
        );
        break;

      // 4 — PROFILE: head + arc shoulders
      case 4:
        // Head circle
        canvas.drawCircle(Offset(cx, h * 0.32), h * 0.17, p);
        // Shoulders
        final path = Path()
          ..moveTo(0.5, h - 1)
          ..cubicTo(0.5, h * 0.62, cx * 0.6, h * 0.56, cx, h * 0.56)
          ..cubicTo(cx + cx * 0.6, h * 0.56, w - 0.5, h * 0.62, w - 0.5, h - 1);
        canvas.drawPath(path, p);
        break;
    }
  }

  @override
  bool shouldRepaint(_NavIcon o) =>
      o.index != index || o.isDark != isDark || o.active != active;
}

// ═══════════════════════════════════════════════════
//  INFINITY BUTTON — no glow, clean glass
// ═══════════════════════════════════════════════════
class _InfinityBtn extends StatefulWidget {
  final bool isDark;
  final bool isOpen;
  final VoidCallback onTap;
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
          onTapDown: (_) => _ctrl.forward(),
          onTapUp:   (_) { _ctrl.reverse(); widget.onTap(); },
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
                  // subtle shadow only, NO glow
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _InfinityPainter(color: iconC),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  INFINITY PAINTER — smooth lemniscate
// ═══════════════════════════════════════════════════
class _InfinityPainter extends CustomPainter {
  final Color color;
  const _InfinityPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    const a  = 13.0; // horizontal reach
    const b  =  7.0; // vertical reach

    // Smooth lemniscate via 4 cubic segments
    final path = Path()
      ..moveTo(cx, cy)
      ..cubicTo(cx + a * 0.5, cy - b,  cx + a,      cy - b,  cx + a, cy)
      ..cubicTo(cx + a,       cy + b,  cx + a * 0.5, cy + b,  cx, cy)
      ..cubicTo(cx - a * 0.5, cy - b,  cx - a,       cy - b,  cx - a, cy)
      ..cubicTo(cx - a,       cy + b,  cx - a * 0.5, cy + b,  cx, cy);

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

// ═══════════════════════════════════════════════════
//  ORB
// ═══════════════════════════════════════════════════
class _Orb extends StatelessWidget {
  final Color color; final double size;
  final double? top, bottom, left, right;
  const _Orb({required this.color, required this.size, this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]))));
}

// ═══════════════════════════════════════════════════
//  TRANDIA ISLAND
// ═══════════════════════════════════════════════════
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
