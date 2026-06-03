// lib/widgets/profile/user_profile_stats_header.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'user_profile_backdrop.dart';

class UserProfileStatsHeader extends StatelessWidget {
  const UserProfileStatsHeader({
    super.key,
    required this.t,
    required this.followers,
    required this.following,
    required this.posts,
    required this.initial,
    this.pictureUrl,
  });
  final UserProfileGlassTheme t;
  final String followers, following, posts, initial;
  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass card with diagonal stripes
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: t.cardShadow,
            ),
            child: UserProfileFrosted(
              radius: 28,
              sigma: 28,
              child: Container(
                height: 150,
                padding: const EdgeInsets.only(top: 22, left: 8, right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: t.cardBorder, width: 1),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: t.cardFill,
                  ),
                ),
                child: Stack(children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: UserProfileStat(
                              t: t, value: followers, label: 'FOLLOWERS')),
                      UserProfileStatDivider(t: t),
                      Expanded(
                          child: UserProfileStat(
                              t: t, value: following, label: 'FOLLOWING')),
                      UserProfileStatDivider(t: t),
                      Expanded(
                          child: UserProfileStat(t: t, value: posts, label: 'POSTS')),
                    ],
                  ),
                ]),
              ),
            ),
          ),

          // Avatar — overlapping bottom-center
          Positioned(
            bottom: -58,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 124,
                height: 124,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.dark
                      ? const Color(0xFF070709)
                      : const Color(0xFFFAFAFA),
                  boxShadow: [
                    BoxShadow(
                      color: t.dark
                          ? const Color(0xD9000000)
                          : const Color(0x47282050),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                      spreadRadius: -18,
                    ),
                  ],
                ),
                child: (pictureUrl != null && pictureUrl!.isNotEmpty)
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: pictureUrl!,
                          width: 114,
                          height: 114,
                          fit: BoxFit.cover,
                          memCacheWidth: 228,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholderFadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) => _avatarFallback(),
                          placeholder: (_, __) => _avatarFallback(),
                        ),
                      )
                    : _avatarFallback(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 114,
      height: 114,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: t.dark
              ? const [Color(0xFF8E8E92), Color(0xFF3A3A3D)]
              : const [Color(0xFFEDEDEF), Color(0xFFA8A8AC)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          color: Colors.white,
        ),
      ),
    );
  }
}

class UserProfileStat extends StatelessWidget {
  const UserProfileStat({super.key, required this.t, required this.value, required this.label});
  final UserProfileGlassTheme t;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: t.fg,
            letterSpacing: -0.8,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: t.muted,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

class UserProfileStatDivider extends StatelessWidget {
  const UserProfileStatDivider({super.key, required this.t});
  final UserProfileGlassTheme t;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.only(top: 6),
      color: t.dark ? const Color(0x14FFFFFF) : const Color(0x14000000),
    );
  }
}

class UserProfileStripesPainter extends CustomPainter {
  UserProfileStripesPainter({required this.color, required this.spacing});
  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    final diag = size.width + size.height;
    for (double x = -size.height; x < diag; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant UserProfileStripesPainter old) =>
      old.color != color || old.spacing != spacing;
}
