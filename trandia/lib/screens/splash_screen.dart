// lib/screens/splash/splash_screen.dart
//
// Single-file splash screen.
//   • Light + dark theme (follows system)
//   • Squircle logo with entry / breathe / exit animations
//   • 3-dot pulsing loader at the bottom
//   • No placeholder widgets — logo animates in immediately on launch
//
// Drop this file into your project. To wire it into your existing app,
// either run it as-is (it has a main()), or import SplashScreen from
// your real main.dart and use it as home:
//
//     home: const SplashScreen(nextScreen: LoginScreen()),
//
// No external packages required.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Standalone entry point — delete this main() when wiring into your app.
// ---------------------------------------------------------------------------

void main() => runApp(const _SplashApp());

class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Splash',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }

  static ThemeData _theme(Brightness b) {
    final isLight = b == Brightness.light;
    final bg = isLight ? SplashPalette.lightBg : SplashPalette.darkBg;
    final fg = isLight ? SplashPalette.lightFg : SplashPalette.darkFg;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: fg,
        brightness: b,
        surface: bg,
        onSurface: fg,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

class SplashPalette {
  static const lightBg = Color(0xFFF6F6F4);
  static const lightFg = Color(0xFF111111);

  static const darkBg = Color(0xFF0E0E0F);
  static const darkFg = Color(0xFFFAFAFA);
}

// ---------------------------------------------------------------------------
// SPLASH SCREEN
// ---------------------------------------------------------------------------

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.nextScreen,
    this.duration = const Duration(milliseconds: 2400),
  });

  /// Screen to push after the splash animation completes.
  /// If null, the splash just stays on screen (useful while wiring).
  final Widget? nextScreen;

  /// Total time the splash is visible (incl. entry + hold + exit).
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _breathe;
  late final AnimationController _exit;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    // Kick the entry on the very first frame so the logo is the first
    // thing painted — no flash of background widgets before it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    await _entry.forward();
    _breathe.repeat(reverse: true);

    // Hold long enough to feel intentional, scaled with overall duration.
    final hold = widget.duration -
        _entry.duration! -
        _exit.duration! +
        const Duration(milliseconds: 100);
    if (hold > Duration.zero) await Future.delayed(hold);

    _breathe.stop();
    await _exit.forward();

    if (!mounted || widget.nextScreen == null) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, __, ___) => widget.nextScreen!,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _breathe.dispose();
    _exit.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SplashPalette.darkBg : SplashPalette.lightBg;
    final fg = isDark ? SplashPalette.darkFg : SplashPalette.lightFg;
    final logoSize = MediaQuery.of(context).size.shortestSide * 0.34;

    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entry, _breathe, _exit, _dots]),
        builder: (context, _) {
          // ENTRY — scale from 0.5 → 1 with easeOutBack + fade
          final entryT = Curves.easeOutBack.transform(_entry.value);
          final entryScale = 0.5 + 0.5 * entryT;
          final entryRotate = (1 - _entry.value) * -0.18; // -10deg → 0
          final entryOpacity = Curves.easeOut.transform(_entry.value);

          // BREATHE — subtle 1.0 → 1.04 loop
          final breatheScale =
              1.0 + 0.04 * Curves.easeInOut.transform(_breathe.value);

          // EXIT — scale up + fade + blur out
          final exitT = Curves.easeInCubic.transform(_exit.value);
          final exitScale = 1.0 + 0.55 * exitT;
          final exitOpacity = 1.0 - exitT;
          final exitBlur = 8.0 * exitT;

          final totalScale = entryScale * breatheScale * exitScale;
          final totalOpacity = entryOpacity * exitOpacity;

          // Mark reveal — driven by entry progress after a small delay.
          final markProgress = Curves.easeOutCubic
              .transform(((_entry.value - 0.25).clamp(0.0, 1.0)) / 0.75);

          return Stack(
            children: [
              // LOGO
              Center(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                      sigmaX: exitBlur, sigmaY: exitBlur),
                  child: Opacity(
                    opacity: totalOpacity,
                    child: Transform.rotate(
                      angle: entryRotate,
                      child: Transform.scale(
                        scale: totalScale,
                        child: _SquircleLogo(
                          size: logoSize,
                          background: fg,
                          markColor: bg,
                          markProgress: markProgress,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // DOTS
              Positioned(
                left: 0,
                right: 0,
                bottom: 56,
                child: Opacity(
                  opacity: ((1 - exitT) * entryOpacity).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 10 * exitT),
                    child: _Dots(color: fg, progress: _dots.value),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SQUIRCLE LOGO  (superellipse outer shape + abstract inner mark)
// ---------------------------------------------------------------------------

class _SquircleLogo extends StatelessWidget {
  const _SquircleLogo({
    required this.size,
    required this.background,
    required this.markColor,
    required this.markProgress,
  });

  final double size;
  final Color background;
  final Color markColor;
  final double markProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SquirclePainter(
          background: background,
          markColor: markColor,
          markProgress: markProgress,
        ),
      ),
    );
  }
}

class _SquirclePainter extends CustomPainter {
  _SquirclePainter({
    required this.background,
    required this.markColor,
    required this.markProgress,
  });

  final Color background;
  final Color markColor;
  final double markProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Outer squircle (iOS-style superellipse via cubic bezier).
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.84, 0, w, h * 0.16, w, h * 0.5)
      ..cubicTo(w, h * 0.84, w * 0.84, h, w * 0.5, h)
      ..cubicTo(w * 0.16, h, 0, h * 0.84, 0, h * 0.5)
      ..cubicTo(0, h * 0.16, w * 0.16, 0, w * 0.5, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = background);

    // Inner mark — pops in with markProgress.
    if (markProgress <= 0) return;
    final markPaint = Paint()
      ..color = markColor.withValues(alpha: 0.96 * markProgress);

    canvas.save();
    final center = Offset(w / 2, h / 2);
    canvas.translate(center.dx, center.dy);
    final s = 0.6 + 0.4 * markProgress;
    canvas.scale(s, s);
    canvas.translate(-center.dx, -center.dy);

    final mark = Path()
      ..moveTo(w * 0.35, h * 0.35)
      ..lineTo(w * 0.65, h * 0.35)
      ..cubicTo(w * 0.69, h * 0.35, w * 0.69, h * 0.41, w * 0.65, h * 0.41)
      ..lineTo(w * 0.475, h * 0.41)
      ..cubicTo(w * 0.435, h * 0.41, w * 0.435, h * 0.47, w * 0.475, h * 0.47)
      ..lineTo(w * 0.65, h * 0.47)
      ..cubicTo(w * 0.69, h * 0.47, w * 0.69, h * 0.65, w * 0.65, h * 0.65)
      ..lineTo(w * 0.35, h * 0.65)
      ..cubicTo(w * 0.31, h * 0.65, w * 0.31, h * 0.59, w * 0.35, h * 0.59)
      ..lineTo(w * 0.525, h * 0.59)
      ..cubicTo(w * 0.565, h * 0.59, w * 0.565, h * 0.53, w * 0.525, h * 0.53)
      ..lineTo(w * 0.35, h * 0.53)
      ..cubicTo(w * 0.31, h * 0.53, w * 0.31, h * 0.35, w * 0.35, h * 0.35)
      ..close();
    canvas.drawPath(mark, markPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SquirclePainter old) =>
      old.markProgress != markProgress ||
      old.background != background ||
      old.markColor != markColor;
}

// ---------------------------------------------------------------------------
// 3-DOT LOADER
// ---------------------------------------------------------------------------

class _Dots extends StatelessWidget {
  const _Dots({required this.color, required this.progress});

  final Color color;
  final double progress; // 0..1 looping

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final t = (progress - i * 0.14) % 1.0;
        final phase = t < 0 ? t + 1 : t;
        final wave = 1 - (phase * 2 - 1).abs();
        final eased = Curves.easeInOut.transform(wave);
        final opacity = 0.25 + 0.75 * eased;
        final dy = -2.0 * eased;

        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
