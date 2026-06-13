// lib/widgets/chat/shared_post_card.dart
// Instagram-reel-style card shown inside a chat bubble when a user shares a
// Trandia post/reel. Renders entirely from the embedded [SharedPost] payload
// (no DB/API hit). Video thumbnails reuse the shared ProfileVideoThumbnailTile
// + its in-memory thumbCache, so the same poster shown in the feed/profile is
// reused here for free.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/shared_post.dart';
import '../profile/profile_video_thumbnail.dart';
import '../../screens/single_post_screen.dart';

class SharedPostCard extends StatelessWidget {
  final SharedPost post;
  final bool isMe;
  final bool dark;

  const SharedPostCard({
    super.key,
    required this.post,
    required this.isMe,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    // Reel-ish rectangle — clamp the aspect so neither extreme breaks the layout.
    final aspect = post.aspectRatio.clamp(0.62, 1.25).toDouble();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SinglePostScreen(postId: post.id, dark: dark),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 212,
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Media ────────────────────────────────────────────
              AspectRatio(
                aspectRatio: aspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _media(),
                    // Bottom gradient for legibility of any overlay.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x66000000)],
                          stops: [0.55, 1.0],
                        ),
                      ),
                    ),
                    if (post.isVideo)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    // Small reel/photo glyph top-left.
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(
                        post.isVideo
                            ? Icons.movie_creation_rounded
                            : Icons.image_rounded,
                        color: Colors.white.withValues(alpha: 0.92),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer: author + caption ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _avatar(),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            post.userUsername.isNotEmpty
                                ? '@${post.userUsername}'
                                : post.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (post.caption.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.caption.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _media() {
    if (!post.isVideo) {
      return CachedNetworkImage(
        imageUrl: post.mediaUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(color: Color(0xFF1A1A1C)),
        errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1C)),
      );
    }
    // Video: prefer server thumbnail; auto-generate from the video otherwise.
    final th = post.thumbnailUrl;
    if (th != null && th.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: th,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(color: Color(0xFF1A1A1C)),
        errorWidget: (_, __, ___) =>
            ProfileVideoThumbnailTile(videoUrl: post.mediaUrl),
      );
    }
    return ColoredBox(
      color: const Color(0xFF1A1A1C),
      child: ProfileVideoThumbnailTile(videoUrl: post.mediaUrl),
    );
  }

  Widget _avatar() {
    final pic = post.userPicture;
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A2A2E)),
      clipBehavior: Clip.antiAlias,
      child: (pic != null && pic.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: pic,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _avatarFallback(),
            )
          : _avatarFallback(),
    );
  }

  Widget _avatarFallback() {
    final ch = post.userName.isNotEmpty
        ? post.userName[0].toUpperCase()
        : (post.userUsername.isNotEmpty ? post.userUsername[0].toUpperCase() : '?');
    return Center(
      child: Text(
        ch,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
