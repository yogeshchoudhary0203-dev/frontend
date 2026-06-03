// lib/widgets/profile/user_profile_backdrop.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class UserProfileBackdrop extends StatelessWidget {
  const UserProfileBackdrop({super.key, required this.t});
  final UserProfileGlassTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: t.bgStops,
        ),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            UserProfileOrb(color: t.orbColors[0], size: 320, left: -60, top: -40),
            UserProfileOrb(color: t.orbColors[1], size: 300, right: -60, top: 40),
            UserProfileOrb(color: t.orbColors[2], size: 360, left: 30, top: 320),
            UserProfileOrb(color: t.orbColors[3], size: 260, right: -50, bottom: 80),
            UserProfileOrb(color: t.orbColors[4], size: 300, left: -40, bottom: -30),
          ],
        ),
      ),
    );
  }
}

class UserProfileOrb extends StatelessWidget {
  const UserProfileOrb({
    super.key,
    required this.color,
    required this.size,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });
  final Color color;
  final double size;
  final double? left, right, top, bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}

class UserProfileFrosted extends StatelessWidget {
  const UserProfileFrosted({
    super.key,
    required this.child,
    required this.radius,
    this.sigma = 24,
  });
  final Widget child;
  final double radius;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

class UserProfileCircleIconButton extends StatelessWidget {
  const UserProfileCircleIconButton({
    super.key,
    required this.t,
    required this.icon,
    required this.onTap,
  });
  final UserProfileGlassTheme t;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: t.fieldShadow,
      ),
      child: UserProfileFrosted(
        radius: 999,
        sigma: 18,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.fieldBorder, width: 1),
                gradient: LinearGradient(
                  colors: t.fieldFill,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Icon(
                icon,
                color: t.fg,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserProfileGlassTheme {
  final bool dark;
  final Color fg;
  final Color muted;
  final List<Color> bgStops;
  final List<Color> orbColors;
  final List<Color> cardFill;
  final Color cardBorder;
  final List<BoxShadow> cardShadow;
  final List<Color> fieldFill;
  final Color fieldBorder;
  final List<BoxShadow> fieldShadow;
  final List<Color> btnFill;
  final Color btnFg;
  final Color btnBorder;
  final List<BoxShadow> btnShadow;
  final Color innerHi;

  const UserProfileGlassTheme({
    required this.dark,
    required this.fg,
    required this.muted,
    required this.bgStops,
    required this.orbColors,
    required this.cardFill,
    required this.cardBorder,
    required this.cardShadow,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldShadow,
    required this.btnFill,
    required this.btnFg,
    required this.btnBorder,
    required this.btnShadow,
    required this.innerHi,
  });

  static UserProfileGlassTheme of(bool dark) => dark ? _dark : _light;

  Color get locationIconColor => const Color(0xFFFF3B30);

  static final _light = UserProfileGlassTheme(
    dark: false,
    fg: const Color(0xFF0E1124),
    muted: const Color(0x8C141628),
    bgStops: const [Color(0xFFF4F4F6), Color(0xFFE4E4E8), Color(0xFFD6D6DC)],
    orbColors: const [
      Color(0x52141416),
      Color(0x42141416),
      Color(0xF2FFFFFF),
      Color(0x38141416),
      Color(0x3D141416),
    ],
    cardFill: const [Color(0x61FFFFFF), Color(0x2EFFFFFF)],
    cardBorder: const Color(0xD9FFFFFF),
    cardShadow: const [
      BoxShadow(
          color: Color(0x40282050),
          blurRadius: 60,
          offset: Offset(0, 30),
          spreadRadius: -20),
    ],
    fieldFill: const [Color(0x73FFFFFF), Color(0x33FFFFFF)],
    fieldBorder: const Color(0xD9FFFFFF),
    fieldShadow: const [
      BoxShadow(
          color: Color(0x2E282050),
          blurRadius: 18,
          offset: Offset(0, 6),
          spreadRadius: -8),
    ],
    btnFill: const [Color(0xFF1A1A1D), Color(0xFF0A0A0C)],
    btnFg: const Color(0xFFFFFFFF),
    btnBorder: const Color(0x33FFFFFF),
    btnShadow: const [
      BoxShadow(
          color: Color(0x59282026),
          blurRadius: 30,
          offset: Offset(0, 14),
          spreadRadius: -10),
    ],
    innerHi: const Color(0xF2FFFFFF),
  );

  static final _dark = UserProfileGlassTheme(
    dark: true,
    fg: const Color(0xFFF5F4FF),
    muted: const Color(0x99F5F4FF),
    bgStops: const [Color(0xFF0C0C0E), Color(0xFF060608), Color(0xFF000000)],
    orbColors: const [
      Color(0x66FFFFFF),
      Color(0x47FFFFFF),
      Color(0x52FFFFFF),
      Color(0x38FFFFFF),
      Color(0x42FFFFFF),
    ],
    cardFill: const [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
    cardBorder: const Color(0x2EFFFFFF),
    cardShadow: const [
      BoxShadow(
          color: Color(0xB3000000),
          blurRadius: 60,
          offset: Offset(0, 30),
          spreadRadius: -20),
    ],
    fieldFill: const [Color(0x1AFFFFFF), Color(0x08FFFFFF)],
    fieldBorder: const Color(0x29FFFFFF),
    fieldShadow: const [
      BoxShadow(
          color: Color(0x80000000),
          blurRadius: 18,
          offset: Offset(0, 6),
          spreadRadius: -8),
    ],
    btnFill: const [Color(0xFFFFFFFF), Color(0xFFF2F2F7)],
    btnFg: const Color(0xFF0A0A0C),
    btnBorder: const Color(0x66FFFFFF),
    btnShadow: const [
      BoxShadow(
          color: Color(0x99000000),
          blurRadius: 30,
          offset: Offset(0, 14),
          spreadRadius: -10),
    ],
    innerHi: const Color(0x59FFFFFF),
  );
}
