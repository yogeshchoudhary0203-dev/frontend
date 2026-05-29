// glass_common.dart
// Shared monochrome / glass theme primitives for Notifications, Chat List, Chat screens.
// Requires: google_fonts: ^6.0.0  (add to pubspec.yaml)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Tokens — mirror exactly the values used in the design JSX.
class GlassTokens {
  // colors
  static const fgDark   = Color(0xFFFFFFFF);
  static const fgLight  = Color(0xFF0A0A0A);
  static Color fg(bool dark)  => dark ? fgDark : fgLight;
  static Color sub(bool dark) => dark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.55);
  static Color text78(bool dark) => dark ? Colors.white.withOpacity(0.78) : Colors.black.withOpacity(0.78);

  // backgrounds
  static const bgDark  = Color(0xFF000000);
  static const bgLight = Color(0xFFFAFAFA);

  // glass surfaces
  static List<Color> glassBg(bool dark) => dark
      ? [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.03)]
      : [Colors.white.withOpacity(0.78), Colors.white.withOpacity(0.55)];

  static Color glassBorder(bool dark) =>
      dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95);

  static BoxShadow cardShadow(bool dark) => BoxShadow(
    color: dark ? Colors.black.withOpacity(0.8) : const Color(0xFF14161E).withOpacity(0.18),
    blurRadius: 28, offset: const Offset(0, 10), spreadRadius: -16,
  );
}

/// Manrope text shortcut (matches JSX font system).
TextStyle manrope({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = Colors.white,
  double letterSpacing = -0.14, // px-equivalent of -0.01em ≈ size * -0.01
  double? height,
}) => GoogleFonts.manrope(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: height,
);

/// Monochrome avatar gradient (varied by index).
LinearGradient monoAvatar(bool dark, int i) {
  double top, bot;
  if (dark) {
    top = 58 - (i % 6) * 5.0;
    bot = (top - 28).clamp(10.0, 100.0);
  } else {
    top = 92 - (i % 6) * 3.0;
    bot = (top - 32).clamp(32.0, 100.0);
  }
  return LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [
      HSLColor.fromAHSL(1, 0, 0, top / 100).toColor(),
      HSLColor.fromAHSL(1, 0, 0, bot / 100).toColor(),
    ],
  );
}

/// Background: soft mono gradient + 3 blurred blobs.
class GlassBackdrop extends StatelessWidget {
  final bool dark;
  const GlassBackdrop({super.key, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1),
            radius: 1.2,
            colors: dark
                ? const [Color(0xFF161617), Color(0xFF08080A), Color(0xFF000000)]
                : const [Color(0xFFFAFAFA), Color(0xFFECECEE), Color(0xFFDCDCE0)],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
      _blob(dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95), const Alignment(-1, -0.8), 320),
      _blob(dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.10),  const Alignment( 1, -0.2), 280),
      _blob(dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.08),  const Alignment(-0.6, 0.9), 300),
    ]);
  }

  Widget _blob(Color c, Alignment a, double size) => Align(
    alignment: a,
    child: IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withOpacity(0)], stops: const [0, 0.7]),
          ),
        ),
      ),
    ),
  );
}

/// Glass pill / card container with frosted blur, gradient, border and top sheen line.
class GlassSurface extends StatelessWidget {
  final bool dark;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final double blurSigma;
  final BoxShadow? shadow;
  const GlassSurface({
    super.key,
    required this.dark,
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.blurSigma = 28,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: GlassTokens.glassBg(dark),
            ),
            border: Border.all(color: GlassTokens.glassBorder(dark), width: 1),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [shadow ?? GlassTokens.cardShadow(dark)],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
            // top sheen line
            Positioned(
              top: 0, left: 18, right: 18, height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? [Colors.transparent, Colors.white.withOpacity(0.14), Colors.transparent]
                        : [Colors.transparent, Colors.white.withOpacity(0.98), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
    );
  }
}

/// Small round icon button used in headers / input bars.
class GlassCircleButton extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? bg;
  final Color? fg;
  final VoidCallback? onTap;
  const GlassCircleButton({
    super.key,
    required this.dark,
    required this.icon,
    this.size = 34,
    this.iconSize = 18,
    this.bg,
    this.fg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg ?? (dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: iconSize, color: fg ?? GlassTokens.fg(dark)),
        ),
      ),
    );
  }
}

/// Pill header (top bar) used by every screen.
/// Reusable circle avatar: shows real photo if [pictureUrl] is available,
/// otherwise falls back to monochrome gradient + first-letter initial.
class UserAvatar extends StatelessWidget {
  final String? pictureUrl;
  final String name;
  final double size;
  final bool dark;
  final int index; // used to vary gradient shade

  const UserAvatar({
    super.key,
    this.pictureUrl,
    required this.name,
    required this.size,
    required this.dark,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = pictureUrl != null && pictureUrl!.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fontSize = size * 0.36;

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: pictureUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: (size * 2).toInt(),
                errorWidget: (_, __, ___) => _fallback(initial, fontSize),
                placeholder: (_, __) => _fallback(initial, fontSize),
              )
            : _fallback(initial, fontSize),
      ),
    );
  }

  Widget _fallback(String initial, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: monoAvatar(dark, index)),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: manrope(
          size: fontSize,
          weight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class GlassHeader extends StatelessWidget {
  final bool dark;
  final double height;
  final EdgeInsets padding;
  final Widget child;
  const GlassHeader({
    super.key,
    required this.dark,
    required this.child,
    this.height = 48,
    this.padding = const EdgeInsets.only(left: 18, right: 8),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: GlassSurface(
        dark: dark,
        radius: 999,
        padding: padding,
        blurSigma: 28,
        shadow: BoxShadow(
          color: dark ? Colors.black.withOpacity(0.7) : const Color(0xFF14161E).withOpacity(0.18),
          blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -16,
        ),
        child: child,
      ),
    );
  }
}
