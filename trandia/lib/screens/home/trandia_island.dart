import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../notifications_screen.dart';
import '../../widgets/shared/home_shared.dart';

class TrandiaIsland extends StatelessWidget {
  final bool isDark;
  const TrandiaIsland({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color glass  = (isDark ? Colors.white : Colors.black).op(0.10);
    final Color border = (isDark ? Colors.white : Colors.black).op(0.18);
    final Color text   = isDark ? Colors.white : const Color(0xFF0A0A0A);
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          width: 126, height: 37,
          decoration: BoxDecoration(color: glass, borderRadius: BorderRadius.circular(19), border: Border.all(color: border, width: 0.8)),
          child: Center(child: Text('Trandia',
            style: TextStyle(color: text, fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, decoration: TextDecoration.none))),
        ),
      ),
    );
  }
}

class IslandNotificationOverlay extends StatefulWidget {
  final Rect islandRect;
  final AnimationController controller;
  final bool isDark;
  final VoidCallback onClose;
  const IslandNotificationOverlay({
    super.key,
    required this.islandRect, required this.controller, required this.isDark, required this.onClose,
  });
  @override
  State<IslandNotificationOverlay> createState() => _IslandNotificationOverlayState();
}

class _IslandNotificationOverlayState extends State<IslandNotificationOverlay> {
  double _dragY    = 0;
  bool   _dragging = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    const dismissThreshold = 80.0;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final topPad   = MediaQuery.paddingOf(context).top;
        final t        = widget.controller.value;
        final expandT  = _expandCurve(t);
        final blurT    = _blurCurve(t);
        final fillT    = _fillCurve(t);
        final contentT = _contentCurve(t);

        final double left   = ui.lerpDouble(widget.islandRect.left,   screenRect.left,   expandT)!;
        final double top    = ui.lerpDouble(widget.islandRect.top,    screenRect.top,    expandT)! + (_dragging ? _dragY.clamp(0, dismissThreshold * 1.4) : 0);
        final double right  = ui.lerpDouble(widget.islandRect.right,  screenRect.right,  expandT)!;
        final double bottom = ui.lerpDouble(widget.islandRect.bottom, screenRect.bottom, expandT)!;
        final double borderR    = ui.lerpDouble(19, 0, expandT)!;
        final double bgBlur     = ui.lerpDouble(0, 14, blurT)!;
        final double bgDim      = ui.lerpDouble(0, widget.isDark ? 0.24 : 0.12, blurT)!;
        final double panelAlpha = ui.lerpDouble(widget.isDark ? 0.20 : 0.34, widget.isDark ? 0.94 : 0.97, fillT)!;
        final double contentAlpha = contentT;
        final double contentLift  = ui.lerpDouble(12, 0, contentT)!;
        final double dragAlpha    = _dragging ? (1.0 - (_dragY / (dismissThreshold * 2.0)).clamp(0.0, 0.5)) : 1.0;

        return Stack(children: [
          Positioned.fill(child: ClipRect(child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: bgBlur, sigmaY: bgBlur),
            child: ColoredBox(color: (widget.isDark ? Colors.black : Colors.white).withOpacity(bgDim))))),
          Positioned(left: left, top: top, width: right - left, height: bottom - top,
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) { if (!didPop) widget.onClose(); },
              child: Opacity(opacity: dragAlpha,
                child: ClipRRect(borderRadius: BorderRadius.circular(borderR),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: ui.lerpDouble(18, 26, fillT)!, sigmaY: ui.lerpDouble(18, 26, fillT)!),
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.black.withOpacity(panelAlpha) : Colors.white.withOpacity(panelAlpha),
                        borderRadius: BorderRadius.circular(borderR),
                      ),
                      child: GestureDetector(
                        onVerticalDragStart: (_) => setState(() { _dragging = true; _dragY = 0; }),
                        onVerticalDragUpdate: (d) { if (d.delta.dy > 0) setState(() => _dragY += d.delta.dy); },
                        onVerticalDragEnd: (d) {
                          if (_dragY > dismissThreshold || d.velocity.pixelsPerSecond.dy > 600) {
                            setState(() { _dragging = false; _dragY = 0; });
                            widget.onClose();
                          } else {
                            setState(() { _dragging = false; _dragY = 0; });
                          }
                        },
                        child: Stack(children: [
                          Transform.translate(offset: Offset(0, contentLift),
                            child: Opacity(opacity: contentAlpha,
                              child: NotificationsScreen(dark: widget.isDark, onClose: widget.onClose, backgroundOpacity: fillT))),
                          if (contentAlpha > 0.1)
                            Positioned(top: topPad + 6, left: 0, right: 0,
                              child: Opacity(opacity: contentAlpha,
                                child: Center(child: Container(
                                  width: 36, height: 4,
                                  decoration: BoxDecoration(
                                    color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(2)),
                                )))),
                        ]),
                      ),
                    ),
                  ))),
          )),
        ]);
      },
    );
  }

  static double _expandCurve(double t) => Curves.fastEaseInToSlowEaseOut.transform(t);
  static double _fillCurve(double t) {
    final v = ((t - 0.08) / 0.58).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(v.toDouble());
  }
  static double _contentCurve(double t) {
    final v = ((t - 0.16) / 0.46).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(v.toDouble());
  }
  static double _blurCurve(double t) => Curves.easeOutCubic.transform(t);
}
