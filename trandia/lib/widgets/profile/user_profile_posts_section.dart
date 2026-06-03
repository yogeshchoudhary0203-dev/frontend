// lib/widgets/profile/user_profile_posts_section.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import 'user_profile_backdrop.dart';

class UserProfilePostsSection extends StatelessWidget {
  const UserProfilePostsSection({
    super.key,
    required this.t,
    required this.posts,
    required this.isLoading,
    this.isLoadingMore = false,
  });
  final UserProfileGlassTheme t;
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: t.cardShadow,
      ),
      child: UserProfileFrosted(
        radius: 22,
        sigma: 24,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.cardBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: t.cardFill,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, color: t.fg, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Posts',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: t.fg,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${posts.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ),
              UserProfilePostsGrid(t: t, posts: posts, isLoading: isLoading, isLoadingMore: isLoadingMore),
            ],
          ),
        ),
      ),
    );
  }
}

class UserProfilePostsGrid extends StatelessWidget {
  const UserProfilePostsGrid({
    super.key,
    required this.t,
    required this.posts,
    required this.isLoading,
    this.isLoadingMore = false,
  });
  final UserProfileGlassTheme t;
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(t.fg),
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: t.muted,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) => UserProfilePostTile(t: t, post: posts[i], i: i),
        ),
        if (isLoadingMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(t.fg),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class UserProfilePostTile extends StatelessWidget {
  const UserProfilePostTile({super.key, required this.t, required this.post, required this.i});
  final UserProfileGlassTheme t;
  final PostModel post;
  final int i;

  @override
  Widget build(BuildContext context) {
    final isVideo = post.mediaType == 'video';
    final imageUrl = isVideo && post.thumbnailUrl != null
        ? post.thumbnailUrl!
        : post.mediaUrl;

    final aPct = t.dark ? (22 - (i % 5) * 3) : (92 - (i % 5) * 4);
    final bPct = (aPct - (t.dark ? 12 : 18))
        .clamp(t.dark ? 4 : 56, 100)
        .toDouble();
    final g1 = HSLColor.fromAHSL(1, 0, 0, aPct / 100).toColor();
    final g2 = HSLColor.fromAHSL(1, 0, 0, bPct / 100).toColor();
    final angle = (135 + (i * 29) % 90) * math.pi / 180;
    final dx = math.cos(angle);
    final dy = math.sin(angle);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-dx, -dy),
            end: Alignment(dx, dy),
            colors: [g1, g2],
          ),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          if (isVideo)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x73000000),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
