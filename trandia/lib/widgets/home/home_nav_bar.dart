import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/home_shared.dart';

// ═════════════════════════════════════════════════════
//  STAGGERED NAVBAR
// ═════════════════════════════════════════════════════

class StaggeredNavbar extends StatelessWidget {
  final bool isDark, isHorizontal;
  final int activeIndex;
  final Animation<double> animation;
  final List<Animation<double>> itemScales, itemOpacities;
  final String? userPicture, userName;
  final ValueChanged<int> onTap;

  /// Optional per-item keys (length 5) used to anchor first-run coachmarks to
  /// individual nav icons. Purely additive — no effect on layout.
  final List<GlobalKey>? itemKeys;

  const StaggeredNavbar({
    super.key,
    required this.isDark, required this.activeIndex, required this.isHorizontal,
    required this.animation, required this.itemScales, required this.itemOpacities,
    this.userPicture, this.userName, required this.onTap, this.itemKeys,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic).value;

    final double fullW = isHorizontal ? 5 * kItemH + 24.0 : kNavWidth;
    final double fullH = isHorizontal ? kNavWidth : 5 * kItemH + 24.0;
    final double navW  = isHorizontal ? kNavWidth + (fullW - kNavWidth) * progress : kNavWidth;
    final double navH  = isHorizontal ? kNavWidth : kNavWidth + (fullH - kNavWidth) * progress;

    final Color glass  = (isDark ? Colors.white : Colors.black).op(0.09);
    final Color border = (isDark ? Colors.white : Colors.black).op(0.16);

    return FadeTransition(
      opacity: itemOpacities.last,
      child: Container(
        width: navW, height: navH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kNavWidth / 2),
          border: Border.all(color: border, width: 0.8),
          boxShadow: [BoxShadow(color: Colors.black.op(isDark ? 0.35 : 0.10), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kNavWidth / 2 - 0.8),
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(
              bottom: isHorizontal ? null : 0, right: isHorizontal ? 0 : null,
              left: isHorizontal ? null : 0, top: isHorizontal ? 0 : null,
              child: SizedBox(width: fullW, height: fullH,
                child: ClipRRect(borderRadius: BorderRadius.circular(kNavWidth / 2),
                  child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(decoration: BoxDecoration(color: glass, borderRadius: BorderRadius.circular(kNavWidth / 2)))))),
            ),
            Align(
              alignment: isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
              child: SizedBox(width: fullW, height: fullH,
                child: Padding(
                  padding: isHorizontal ? const EdgeInsets.symmetric(horizontal: 12) : const EdgeInsets.symmetric(vertical: 6),
                  child: Flex(
                    direction: isHorizontal ? Axis.horizontal : Axis.vertical,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (i) {
                      final bool active    = activeIndex == i;
                      final double scaleVal   = itemScales[i].value;
                      final double offsetValue = (1.0 - scaleVal) * 28.0;
                      final Offset translateOffset = isHorizontal ? Offset(offsetValue, 0) : Offset(0, offsetValue);
                      final double angle = (1.0 - scaleVal) * -0.35;
                      final Widget item = ScaleTransition(scale: itemScales[i],
                        child: FadeTransition(opacity: itemOpacities[i],
                          child: Transform.translate(offset: translateOffset,
                            child: Transform.rotate(angle: angle,
                              child: GestureDetector(
                                onTap: () { HapticFeedback.selectionClick(); onTap(i); },
                                behavior: HitTestBehavior.opaque,
                                child: SizedBox(
                                  width: isHorizontal ? kItemH : kNavWidth,
                                  height: isHorizontal ? kNavWidth : kItemH,
                                  child: Center(child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(shape: BoxShape.circle,
                                      color: active ? (isDark ? Colors.white.op(0.18) : Colors.black.op(0.12)) : Colors.transparent),
                                    child: Center(child: CustomPaint(
                                      size: const Size(24.0, 24.0),
                                      painter: _NavIconPainter(index: i, isDark: isDark, active: active))))),
                                ))))));
                      return (itemKeys != null && i < itemKeys!.length)
                          ? KeyedSubtree(key: itemKeys![i], child: item)
                          : item;
                    }),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class EnvelopeIconPainter extends CustomPainter {
  final bool isDark;
  const EnvelopeIconPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final Color color = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final double w = size.width, h = size.height;
    final Paint p = Paint()..color = color.op(0.95)..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final bubble = Path()
      ..moveTo(w * 0.28, h * 0.08)..lineTo(w * 0.72, h * 0.08)
      ..quadraticBezierTo(w * 0.92, h * 0.08, w * 0.92, h * 0.28)
      ..lineTo(w * 0.92, h * 0.62)
      ..quadraticBezierTo(w * 0.92, h * 0.82, w * 0.72, h * 0.82)
      ..lineTo(w * 0.38, h * 0.82)
      ..quadraticBezierTo(w * 0.34, h * 0.90, w * 0.28, h * 0.94)
      ..quadraticBezierTo(w * 0.24, h * 0.96, w * 0.22, h * 0.92)
      ..quadraticBezierTo(w * 0.18, h * 0.85, w * 0.08, h * 0.72)
      ..lineTo(w * 0.08, h * 0.28)
      ..quadraticBezierTo(w * 0.08, h * 0.08, w * 0.28, h * 0.08)
      ..close();
    canvas.drawPath(bubble, p);
    canvas.drawLine(Offset(w * 0.32, h * 0.36), Offset(w * 0.68, h * 0.36), p);
    canvas.drawLine(Offset(w * 0.32, h * 0.54), Offset(w * 0.68, h * 0.54), p);
  }

  @override
  bool shouldRepaint(EnvelopeIconPainter o) => o.isDark != isDark;
}

class _NavIconPainter extends CustomPainter {
  final int index;
  final bool isDark, active;
  const _NavIconPainter({required this.index, required this.isDark, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final Color base   = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color col    = active ? base : base.op(0.50);
    final double sw    = active ? 1.6 : 1.4;
    final Paint stroke = Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final double w = size.width, h = size.height, cx = w / 2, cy = h / 2;

    switch (index) {
      case 0:
        final home = Path()
          ..moveTo(cx, h * 0.10)..lineTo(w * 0.90, h * 0.45)..lineTo(w * 0.90, h * 0.82)
          ..cubicTo(w * 0.90, h * 0.90, w * 0.85, h * 0.92, w * 0.78, h * 0.92)
          ..lineTo(w * 0.22, h * 0.92)
          ..cubicTo(w * 0.15, h * 0.92, w * 0.10, h * 0.90, w * 0.10, h * 0.82)
          ..lineTo(w * 0.10, h * 0.45)..close();
        canvas.drawPath(home, stroke);
        final door = Path()
          ..moveTo(cx - w * 0.10, h * 0.92)..lineTo(cx - w * 0.10, h * 0.68)
          ..cubicTo(cx - w * 0.10, h * 0.56, cx + w * 0.10, h * 0.56, cx + w * 0.10, h * 0.68)
          ..lineTo(cx + w * 0.10, h * 0.92);
        canvas.drawPath(door, stroke);
      case 1:
        final bounds = Offset.zero & size;
        canvas.saveLayer(bounds, Paint());
        final double inset = w * 0.10;
        final rr = RRect.fromRectAndRadius(Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2), Radius.circular(w * 0.26));
        canvas.drawRRect(rr, Paint()..color = col..style = PaintingStyle.fill);
        final double pw = w * 0.25, ph = h * 0.30;
        final playPath = Path()
          ..moveTo(cx - pw * 0.38, cy - ph / 2)..lineTo(cx + pw * 0.62, cy)..lineTo(cx - pw * 0.38, cy + ph / 2)..close();
        canvas.drawPath(playPath, Paint()..blendMode = BlendMode.clear);
        canvas.restore();
      case 2:
        final double inset = w * 0.12;
        final rr = RRect.fromRectAndRadius(Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2), Radius.circular(w * 0.25));
        canvas.drawRRect(rr, stroke);
        final double arm = w * 0.16;
        canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), stroke);
        canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), stroke);
      case 3:
        final double r = w * 0.30, ox = cx - w * 0.06, oy = cy - h * 0.06;
        canvas.drawCircle(Offset(ox, oy), r, stroke);
        final double hx = ox + r * 0.70, hy = oy + r * 0.70;
        canvas.drawLine(Offset(hx, hy), Offset(w * 0.88, h * 0.88),
          Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = sw + 0.3..strokeCap = StrokeCap.round);
      case 4:
        canvas.drawCircle(Offset(cx, h * 0.30), w * 0.16, stroke);
        final body = Path()
          ..moveTo(w * 0.14, h * 0.92)..cubicTo(w * 0.14, h * 0.60, w * 0.30, h * 0.52, cx, h * 0.52)
          ..cubicTo(w * 0.70, h * 0.52, w * 0.86, h * 0.60, w * 0.86, h * 0.92);
        canvas.drawPath(body, stroke);
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter o) => o.index != index || o.isDark != isDark || o.active != active;
}
