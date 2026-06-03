// lib/widgets/profile/user_profile_header_info.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_profile_backdrop.dart';

class UserProfileNameRow extends StatelessWidget {
  const UserProfileNameRow({
    super.key,
    required this.t,
    required this.name,
    required this.verified,
  });
  final UserProfileGlassTheme t;
  final String name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: t.fg,
                letterSpacing: -0.7,
              ),
            ),
          ),
          if (verified) ...[
            const SizedBox(width: 8),
            UserProfileVerified(color: t.fg, size: 20),
          ],
        ],
      ),
    );
  }
}

class UserProfileVerified extends StatelessWidget {
  const UserProfileVerified({super.key, required this.color, this.size = 16});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: UserProfileVerifiedPainter(color)),
    );
  }
}

class UserProfileVerifiedPainter extends CustomPainter {
  UserProfileVerifiedPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1.6 * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 16-point starburst (alternating outer/inner radius)
    const cx = 12.0, cy = 12.0;
    const outer = 9.5, inner = 7.8;
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * (2 * math.pi / 16);
      final px = (cx + r * math.cos(a)) * s;
      final py = (cy + r * math.sin(a)) * s;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, stroke);

    // Inner checkmark
    final check = Path()
      ..moveTo(8.5 * s, 12.2 * s)
      ..lineTo(10.9 * s, 14.5 * s)
      ..lineTo(15.5 * s, 9.9 * s);
    canvas.drawPath(check, stroke);
  }

  @override
  bool shouldRepaint(covariant UserProfileVerifiedPainter old) => old.color != color;
}

class UserProfileTitleChip extends StatelessWidget {
  const UserProfileTitleChip({super.key, required this.t, required this.label});
  final UserProfileGlassTheme t;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.fieldShadow,
      ),
      child: UserProfileFrosted(
        radius: 999,
        sigma: 16,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.fieldFill,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.fg.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserProfileWebsiteChip extends StatelessWidget {
  const UserProfileWebsiteChip({super.key, required this.t, required this.url});
  final UserProfileGlassTheme t;
  final String url;

  Future<void> _open() async {
    String full = url.trim();
    if (!full.startsWith('http://') && !full.startsWith('https://')) {
      full = 'https://$full';
    }
    try {
      await launchUrl(Uri.parse(full), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final display = url.replaceFirst(RegExp(r'^https?://'), '');
    return Center(
      child: GestureDetector(
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(colors: t.fieldFill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 14, color: t.muted),
              const SizedBox(width: 4),
              Text(
                display,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserProfileLocationBadge extends StatelessWidget {
  final UserProfileGlassTheme t;
  final String city;
  const UserProfileLocationBadge({super.key, required this.t, required this.city});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: t.cardFill,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: t.cardBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 12,
                color: Color(0xFFFF3B30),
              ),
              const SizedBox(width: 4),
              Text(
                city,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
