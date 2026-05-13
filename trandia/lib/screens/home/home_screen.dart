import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Button diameter (shared constant) ───────
const double _kBtnSize = 64.0;
const double _kNavbarWidth = _kBtnSize;
const double _kNavItemSize = 44.0;
const double _kGap = 2.0; // gap between btn and navbar

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _navOpen = false;
  int _activeNav = 0;

  late AnimationController _navCtrl;
  late Animation<double> _navScale;
  late Animation<double> _navOpacity;
  late Animation<Offset> _navSlide;

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _navScale = CurvedAnimation(parent: _navCtrl, curve: Curves.easeOutBack);
    _navOpacity = CurvedAnimation(parent: _navCtrl, curve: Curves.easeOut);
    _navSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _navCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _navCtrl.dispose();
    super.dispose();
  }

  void _toggleNav() {
    HapticFeedback.lightImpact();
    setState(() => _navOpen = !_navOpen);
    _navOpen ? _navCtrl.forward() : _navCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    );

    final islandBg   = isDark ? const Color(0xFFF0F0EC) : const Color(0xFF1A1A1A);
    final islandText = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // 1. Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: isDark
                      ? [const Color(0xFF1C1C1F), const Color(0xFF050506)]
                      : [const Color(0xFFF8F8FA), const Color(0xFFE2E2E8)],
                ),
              ),
            ),
          ),

          // 2. Background Orbs
          _Orb(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), size: 300, top: 100, left: -50),
          _Orb(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), size: 250, bottom: 150, right: -30),

          // 3. Frosted Glass Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: isDark ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // 4. Content
          SafeArea(
            child: Stack(
              children: [
                // Trandia Island (Top Center)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _TrandiaIsland(background: islandBg, textColor: islandText),
                  ),
                ),

                // 3D Glass Envelope Icon (Top Right)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5, right: 14),
                    child: GestureDetector(
                      onTap: () {/* TODO: Open Chat */},
                      child: _GlassEnvelopeIcon(isDark: isDark),
                    ),
                  ),
                ),

                // Vertical Pill Navbar (above infinity button)
                Positioned(
                  bottom: 30 + _kBtnSize + _kGap,
                  right: 20,
                  child: AnimatedBuilder(
                    animation: _navCtrl,
                    builder: (context, _) {
                      return IgnorePointer(
                        ignoring: !_navOpen,
                        child: FadeTransition(
                          opacity: _navOpacity,
                          child: SlideTransition(
                            position: _navSlide,
                            child: ScaleTransition(
                              scale: _navScale,
                              alignment: Alignment.bottomCenter,
                              child: _VerticalPillNavbar(
                                isDark: isDark,
                                activeIndex: _activeNav,
                                onTap: (i) => setState(() => _activeNav = i),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Infinity Toggle Button (Bottom Right)
                Positioned(
                  bottom: 30,
                  right: 20,
                  child: _InfinityToggleButton(
                    isDark: isDark,
                    isOpen: _navOpen,
                    onTap: _toggleNav,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 3D GLASS ENVELOPE ICON
// ══════════════════════════════════════════════
class _GlassEnvelopeIcon extends StatelessWidget {
  final bool isDark;
  const _GlassEnvelopeIcon({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          // Base squircle with gradient + shadow
          CustomPaint(
            size: const Size(46, 46),
            painter: _EnvelopeBackgroundPainter(isDark: isDark),
          ),
          // Envelope icon
          Positioned.fill(
            child: CustomPaint(
              painter: _EnvelopeIconPainter(isDark: isDark),
            ),
          ),
          // Top specular highlight
          Positioned(
            top: 4,
            left: 9,
            child: Container(
              width: 28,
              height: 9,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(isDark ? 0.30 : 0.65),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvelopeBackgroundPainter extends CustomPainter {
  final bool isDark;
  const _EnvelopeBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = 13.0; // squircle corner radius

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(r),
    );

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isDark ? 0.45 : 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 4, w, h), const Radius.circular(r)),
      shadowPaint,
    );

    // Base gradient fill
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w / 2, 0),
        Offset(w / 2, h),
        isDark
            ? [const Color(0xFF3A3A3E), const Color(0xFF1C1C1F)]
            : [const Color(0xFFFFFFFF), const Color(0xFFD8D8DC)],
      );
    canvas.drawRRect(rect, bgPaint);

    // Inner rim / border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(w, h),
        isDark
            ? [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.05)]
            : [Colors.white.withOpacity(0.90), Colors.black.withOpacity(0.06)],
      );
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(_EnvelopeBackgroundPainter old) => old.isDark != isDark;
}

class _EnvelopeIconPainter extends CustomPainter {
  final bool isDark;
  const _EnvelopeIconPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 1;
    const ew = 24.0; // envelope width
    const eh = 16.0; // envelope height
    const er = 3.0;  // envelope corner radius

    final envColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    final bodyPaint = Paint()
      ..color = envColor.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = envColor.withOpacity(0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Envelope body (rounded rect)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: ew, height: eh),
      const Radius.circular(er),
    );
    final bodyFillPaint = Paint()
      ..color = envColor.withOpacity(isDark ? 0.15 : 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bodyRect, bodyFillPaint);
    canvas.drawRRect(bodyRect, strokePaint);

    // Envelope flap (V-shape at top)
    final flapPath = Path()
      ..moveTo(cx - ew / 2 + er, cy - eh / 2)
      ..lineTo(cx, cy)
      ..lineTo(cx + ew / 2 - er, cy - eh / 2);
    canvas.drawPath(flapPath, strokePaint);

    // Bottom fold lines (subtle)
    final thinPaint = Paint()
      ..color = envColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - ew / 2 + er, cy + eh / 2),
      Offset(cx, cy + 1),
      thinPaint,
    );
    canvas.drawLine(
      Offset(cx + ew / 2 - er, cy + eh / 2),
      Offset(cx, cy + 1),
      thinPaint,
    );
  }

  @override
  bool shouldRepaint(_EnvelopeIconPainter old) => old.isDark != isDark;
}

// ══════════════════════════════════════════════
// INFINITY TOGGLE BUTTON
// ══════════════════════════════════════════════
class _InfinityToggleButton extends StatefulWidget {
  final bool isDark;
  final bool isOpen;
  final VoidCallback onTap;
  const _InfinityToggleButton({
    required this.isDark,
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<_InfinityToggleButton> createState() => _InfinityToggleButtonState();
}

class _InfinityToggleButtonState extends State<_InfinityToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor   = widget.isDark ? Colors.white : const Color(0xFF1A1A1A);
    final glassColor  = widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
    final borderColor = widget.isDark ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.12);

    return AnimatedBuilder(
      animation: _pressCtrl,
      builder: (context, _) => Transform.scale(
        scale: _pressScale.value,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
          onTapCancel: () => _pressCtrl.reverse(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring
              Container(
                width: _kBtnSize + 6,
                height: _kBtnSize + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withOpacity(widget.isOpen ? 0.22 : 0.10),
                      blurRadius: widget.isOpen ? 28 : 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              // Glass body
              ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: _kBtnSize,
                    height: _kBtnSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glassColor,
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: CustomPaint(
                      painter: _InfinityPainter(
                        color: baseColor,
                        glowAmount: widget.isOpen ? 1.0 : 0.0,
                      ),
                    ),
                  ),
                ),
              ),
              // Top specular
              Positioned(
                top: 7,
                child: Container(
                  width: 26,
                  height: 9,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(widget.isDark ? 0.22 : 0.55),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// VERTICAL PILL NAVBAR
// ══════════════════════════════════════════════
class _VerticalPillNavbar extends StatelessWidget {
  final bool isDark;
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _VerticalPillNavbar({
    required this.isDark,
    required this.activeIndex,
    required this.onTap,
  });

  static const _navItems = [
    _NavItemData(label: 'Home',    icon: _NavIcon.home),
    _NavItemData(label: 'Shots',   icon: _NavIcon.shots),
    _NavItemData(label: 'Add',     icon: _NavIcon.add),
    _NavItemData(label: 'Search',  icon: _NavIcon.search),
    _NavItemData(label: 'Profile', icon: _NavIcon.profile),
  ];

  @override
  Widget build(BuildContext context) {
    final navH = _navItems.length * _kNavItemSize + 16;
    final glassColor  = isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04);
    final borderColor = isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.10);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_kNavbarWidth / 2),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: _kNavbarWidth,
          height: navH,
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(_kNavbarWidth / 2),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.40 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              // Inner top shine
              BoxShadow(
                color: Colors.white.withOpacity(isDark ? 0.06 : 0.50),
                blurRadius: 0,
                spreadRadius: -1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top specular stripe
              Positioned(
                top: 0,
                left: 4,
                right: 4,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(isDark ? 0.12 : 0.40),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Nav items
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_navItems.length, (i) {
                    final item = _navItems[i];
                    final active = activeIndex == i;
                    return GestureDetector(
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _kNavItemSize,
                        height: _kNavItemSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? (isDark
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.10))
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(22, 22),
                            painter: _NavIconPainter(
                              icon: item.icon,
                              isDark: isDark,
                              active: active,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav item data ─────────────────────────────
enum _NavIcon { home, shots, add, search, profile }

class _NavItemData {
  final String label;
  final _NavIcon icon;
  const _NavItemData({required this.label, required this.icon});
}

// ── Nav icon painter ──────────────────────────
class _NavIconPainter extends CustomPainter {
  final _NavIcon icon;
  final bool isDark;
  final bool active;
  const _NavIconPainter({required this.icon, required this.isDark, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final c = isDark
        ? (active ? Colors.white : Colors.white.withOpacity(0.55))
        : (active ? Colors.black : Colors.black.withOpacity(0.45));

    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fp = Paint()
      ..color = c
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    switch (icon) {
      // HOME — rounded house
      case _NavIcon.home:
        final roof = Path()
          ..moveTo(cx, 1)
          ..lineTo(w - 1, h * 0.45)
          ..lineTo(w - 1, h - 1)
          ..quadraticBezierTo(w - 1, h - 1, w - 3, h - 1)
          ..lineTo(3, h - 1)
          ..quadraticBezierTo(1, h - 1, 1, h - 1)
          ..lineTo(1, h * 0.45)
          ..close();
        canvas.drawPath(roof, p);
        // Door
        final door = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 3, h * 0.58, 6, h - 1 - h * 0.58),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(door, p);
        break;

      // SHOTS — play inside rounded rect
      case _NavIcon.shots:
        final outerRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, w - 2, h - 2),
          const Radius.circular(4),
        );
        canvas.drawRRect(outerRect, p);
        // Play triangle
        final play = Path()
          ..moveTo(cx - 3, cy - 4)
          ..lineTo(cx + 5, cy)
          ..lineTo(cx - 3, cy + 4)
          ..close();
        canvas.drawPath(play, fp);
        break;

      // ADD — plus inside circle
      case _NavIcon.add:
        canvas.drawCircle(Offset(cx, cy), w / 2 - 1, p);
        canvas.drawLine(Offset(cx, 5), Offset(cx, h - 5), p);
        canvas.drawLine(Offset(5, cy), Offset(w - 5, cy), p);
        break;

      // SEARCH — magnifier
      case _NavIcon.search:
        canvas.drawCircle(Offset(cx - 1.5, cy - 1.5), w * 0.30, p);
        canvas.drawLine(
          Offset(cx + 3.5, cy + 3.5),
          Offset(w - 1.5, h - 1.5),
          p,
        );
        break;

      // PROFILE — head + shoulders
      case _NavIcon.profile:
        // Head
        canvas.drawCircle(Offset(cx, h * 0.33), h * 0.18, p);
        // Shoulders arc
        final shoulders = Path()
          ..moveTo(1, h - 1)
          ..quadraticBezierTo(cx, h * 0.58, w - 1, h - 1);
        canvas.drawPath(shoulders, p);
        break;
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.icon != icon || old.isDark != isDark || old.active != active;
}

// ══════════════════════════════════════════════
// INFINITY PAINTER (for toggle button)
// ══════════════════════════════════════════════
class _InfinityPainter extends CustomPainter {
  final Color color;
  final double glowAmount;
  const _InfinityPainter({required this.color, this.glowAmount = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const a = 11.0;
    const b = 7.0;

    if (glowAmount > 0) {
      canvas.drawPath(
        _path(cx, cy, a, b),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = color.withOpacity(0.18 * glowAmount)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawPath(
      _path(cx, cy, a, b),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withOpacity(0.90),
    );
  }

  Path _path(double cx, double cy, double a, double b) {
    final p = Path();
    p.moveTo(cx, cy);
    p.cubicTo(cx - a * 0.5, cy - b * 1.4, cx - a * 2.0, cy - b * 1.4, cx - a * 2.0, cy);
    p.cubicTo(cx - a * 2.0, cy + b * 1.4, cx - a * 0.5, cy + b * 1.4, cx, cy);
    p.cubicTo(cx + a * 0.5, cy - b * 1.4, cx + a * 2.0, cy - b * 1.4, cx + a * 2.0, cy);
    p.cubicTo(cx + a * 2.0, cy + b * 1.4, cx + a * 0.5, cy + b * 1.4, cx, cy);
    return p;
  }

  @override
  bool shouldRepaint(_InfinityPainter old) =>
      old.color != color || old.glowAmount != glowAmount;
}

// ══════════════════════════════════════════════
// ORB (background decoration — unchanged)
// ══════════════════════════════════════════════
class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;
  const _Orb({required this.color, required this.size, this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// TRANDIA ISLAND (unchanged)
// ══════════════════════════════════════════════
class _TrandiaIsland extends StatelessWidget {
  final Color background;
  final Color textColor;
  const _TrandiaIsland({required this.background, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 37,
      width: 124,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            decoration: TextDecoration.none,
          ),
          child: const Text('Trandia'),
        ),
      ),
    );
  }
}
