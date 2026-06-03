// lib/widgets/profile/profile_cover_band.dart
// Cover band + stats row shown at the top of the profile.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../screens/glass_common.dart';
import '../../l10n/app_localizations.dart';

class ProfileCoverBand extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final Color hairline;
  final int followersCount;
  final int followingCount;
  final int postCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const ProfileCoverBand({
    super.key,
    required this.dark,
    required this.fg,
    required this.sub,
    required this.hairline,
    required this.followersCount,
    required this.followingCount,
    required this.postCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: const Alignment(-0.2, -1),
          end: const Alignment(0.6, 1),
          colors: dark
              ? const [Color(0xFF1C1C1F), Color(0xFF0D0D10), Color(0xFF050507)]
              : const [Color(0xFFEFEFEF), Color(0xFFD6D6DA)],
          stops: dark ? const [0.0, 0.6, 1.0] : const [0.0, 1.0],
        ),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.95),
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.7)
                : const Color(0xFF14161E).withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // top sheen
            Positioned(
              top: 0,
              left: 24,
              right: 24,
              height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.18),
                            Colors.transparent,
                          ]
                        : [
                            Colors.transparent,
                            Colors.white,
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
            // diagonal stripe texture
            CustomPaint(
              painter: DiagonalStripesPainter(dark: dark),
              size: Size.infinite,
            ),
            Positioned(
              left: 18,
              right: 18,
              top: 42,
              child: ProfileCoverStatsRow(
                fg: fg,
                sub: sub,
                hairline: hairline,
                followersCount: followersCount,
                followingCount: followingCount,
                postCount: postCount,
                onFollowersTap: onFollowersTap,
                onFollowingTap: onFollowingTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileCoverStatsRow extends StatelessWidget {
  final Color fg;
  final Color sub;
  final Color hairline;
  final int followersCount;
  final int followingCount;
  final int postCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const ProfileCoverStatsRow({
    super.key,
    required this.fg,
    required this.sub,
    required this.hairline,
    required this.followersCount,
    required this.followingCount,
    required this.postCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProfileStat(
            value: _fmt(followersCount),
            label: 'Followers',
            fg: fg,
            sub: sub,
            onTap: onFollowersTap,
          ),
        ),
        Container(width: 1, height: 30, color: hairline),
        Expanded(
          child: ProfileStat(
            value: _fmt(followingCount),
            label: 'Following',
            fg: fg,
            sub: sub,
            onTap: onFollowingTap,
          ),
        ),
        Container(width: 1, height: 30, color: hairline),
        Expanded(
          child: ProfileStat(
            value: _fmt(postCount),
            label: 'Posts',
            fg: fg,
            sub: sub,
          ),
        ),
      ],
    );
  }
}

class ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  final Color fg;
  final Color sub;
  final VoidCallback? onTap;

  const ProfileStat({
    super.key,
    required this.value,
    required this.label,
    required this.fg,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: manrope(
            size: 20,
            weight: FontWeight.w800,
            color: fg,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.tr(context).toUpperCase(),
          style: manrope(
            size: 10.5,
            weight: FontWeight.w700,
            color: sub,
            letterSpacing: 1.05,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class DiagonalStripesPainter extends CustomPainter {
  final bool dark;
  DiagonalStripesPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(
        alpha: dark ? 0.04 : 0.025,
      )
      ..strokeWidth = 1;
    const step = 19.0;
    final diag = size.width + size.height;
    for (double x = -diag; x < diag; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DiagonalStripesPainter old) => old.dark != dark;
}
