import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../services/post_service.dart';
import '../l10n/app_localizations.dart';
import 'glass_common.dart';

class SinglePostScreen extends StatefulWidget {
  final String postId;
  final bool dark;

  const SinglePostScreen({
    super.key,
    required this.postId,
    required this.dark,
  });

  @override
  State<SinglePostScreen> createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  PostModel? _post;
  bool _isLoading = true;
  bool _hasError  = false;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final post = await PostService.instance.getPostById(widget.postId);
      if (mounted) {
        setState(() {
          _post      = post;
          _isLoading = false;
          _hasError  = post == null;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final p = _post!;
    final nextLiked = !p.isLiked;
    setState(() {
      _post = p.copyWith(
        isLiked:    nextLiked,
        likesCount: p.likesCount + (nextLiked ? 1 : -1),
      );
    });
    try {
      if (nextLiked) {
        await PostService.instance.likePost(p.id);
      } else {
        await PostService.instance.unlikePost(p.id);
      }
    } catch (_) {
      if (mounted) setState(() => _post = p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg     = GlassTokens.fg(widget.dark);
    final sub    = GlassTokens.sub(widget.dark);
    final topPad = MediaQuery.paddingOf(context).top;
    const headerH   = 66.0;
    final headerTop = topPad + 8;

    return Scaffold(
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(children: [

        // Background
        GlassBackdrop(dark: widget.dark),

        // Content
        Positioned(
          top: headerTop + headerH, bottom: 0, left: 0, right: 0,
          child: _isLoading
              ? Center(child: CircularProgressIndicator(
                  color: widget.dark ? Colors.white : Colors.black))
              : _hasError
                  ? _ErrorState(
                      dark: widget.dark, sub: sub, onRetry: _fetchPost)
                  : _PostContent(
                      post: _post!, dark: widget.dark,
                      onLike: _toggleLike),
        ),

        // Header
        Positioned(
          top: headerTop, left: 12, right: 12,
          child: GlassHeader(
            dark: widget.dark, height: headerH,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: fg, size: 20),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _post?.isVideo == true
                    ? 'Video'.tr(context)
                    : 'Post'.tr(context),
                style: manrope(size: 17, weight: FontWeight.w800,
                    color: fg, letterSpacing: -0.34),
              ),
              const Spacer(),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post content (media + info)
// ─────────────────────────────────────────────────────────────────────────────

class _PostContent extends StatelessWidget {
  final PostModel    post;
  final bool         dark;
  final VoidCallback onLike;

  const _PostContent({
    required this.post,
    required this.dark,
    required this.onLike,
  });

  Color _avatarColor(String userId) {
    const colors = [
      Color(0xFF2D3561), Color(0xFF1B4332), Color(0xFF3D0C11),
      Color(0xFF2C2C54), Color(0xFF1A1A2E), Color(0xFF0D3349),
    ];
    return colors[userId.hashCode.abs() % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final fg       = GlassTokens.fg(dark);
    final sub      = GlassTokens.sub(dark);
    final border   = (dark ? Colors.white : Colors.black).withOpacity(0.12);
    final likedCol = dark ? const Color(0xFFFF3040) : const Color(0xFFED4956);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _avatarColor(post.userId),
                border: Border.all(color: border, width: 0.8),
              ),
              child: ClipOval(child: post.userPicture != null
                  ? CachedNetworkImage(
                      imageUrl: post.userPicture!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(_initials(post.userName),
                            style: const TextStyle(color: Colors.white,
                                fontSize: 12, fontWeight: FontWeight.w600))),
                    )
                  : Center(child: Text(_initials(post.userName),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600)))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.userName,
                    style: manrope(size: 13.5, weight: FontWeight.w700,
                        color: fg)),
                Text('@${post.userUsername}',
                    style: manrope(size: 11, color: sub)),
              ],
            )),
            Text(post.timeAgo,
                style: manrope(size: 11, color: sub)),
          ]),
        ),

        // ── Media ──────────────────────────────────────────────────
        // ── Media ──────────────────────────────────────────────────
post.isVideo
    ? _VideoView(post: post)
    : InteractiveViewer(
        clipBehavior: Clip.none,
        panEnabled: true,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        child: AspectRatio(
          aspectRatio: post.aspectRatio,
          child: CachedNetworkImage(
            imageUrl: post.mediaUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
                color: (dark ? Colors.white : Colors.black)
                    .withOpacity(0.05)),
            errorWidget: (_, __, ___) => Container(
              color: (dark ? Colors.white : Colors.black)
                  .withOpacity(0.05),
              child: Icon(Icons.broken_image_outlined,
                  color: sub.withOpacity(0.4)),
            ),
          ),
        ),
      ),

        // ── Actions ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            // Like button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onLike();
              },
              child: Row(children: [
                Icon(
                  post.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: post.isLiked ? likedCol : fg.withOpacity(0.75),
                  size: 24,
                ),
                const SizedBox(width: 5),
                Text('${post.likesCount}',
                    style: manrope(size: 13, weight: FontWeight.w600,
                        color: fg)),
              ]),
            ),
            const SizedBox(width: 18),
            // Comment count
            Icon(Icons.chat_bubble_outline_rounded,
                color: fg.withOpacity(0.75), size: 22),
            const SizedBox(width: 5),
            Text('${post.commentsCount}',
                style: manrope(size: 13, weight: FontWeight.w600, color: fg)),
          ]),
        ),

        // ── Caption ────────────────────────────────────────────────
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: '${post.userName} ',
                style: manrope(size: 13.5, weight: FontWeight.w700, color: fg),
              ),
              TextSpan(
                text: post.caption,
                style: manrope(size: 13, color: fg.withOpacity(0.85),
                    height: 1.4),
              ),
            ])),
          )
        else
          const SizedBox(height: 16),

        const SizedBox(height: 40),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline video player
// ─────────────────────────────────────────────────────────────────────────────

class _VideoView extends StatefulWidget {
  final PostModel post;
  const _VideoView({required this.post});

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.post.mediaUrl));
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
    } catch (_) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) { ctrl.dispose(); _ctrl = null; return; }
    ctrl.setLooping(true);
    ctrl.setVolume(1.0);
    ctrl.play();
    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.post.aspectRatio,
      child: Stack(fit: StackFit.expand, children: [
        // Thumbnail
        if (widget.post.thumbnailUrl != null)
          CachedNetworkImage(
              imageUrl: widget.post.thumbnailUrl!, fit: BoxFit.cover),

        // Video
        if (_initialized && _ctrl != null)
          InteractiveViewer(
            clipBehavior: Clip.none,
            panEnabled: true,
            scaleEnabled: true,
            minScale: 1.0,
            maxScale: 4.0,
            child: GestureDetector(
              onTap: () {
                if (_ctrl!.value.isPlaying) {
                  _ctrl!.pause();
                } else {
                  _ctrl!.play();
                }
              },
              child: VideoPlayer(_ctrl!),
            ),
          ),

        // Loading
        if (!_initialized)
          const Center(child: SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(
                  color: Colors.white54, strokeWidth: 2))),

        // Mute button
        if (_initialized)
          Positioned(
            bottom: 10, right: 10,
            child: GestureDetector(
              onTap: () {
                setState(() => _muted = !_muted);
                _ctrl?.setVolume(_muted ? 0 : 1);
              },
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5)),
                child: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white, size: 16),
              ),
            ),
          ),

        // Progress bar
        if (_initialized && _ctrl != null)
          Positioned(bottom: 0, left: 0, right: 0,
            child: VideoProgressIndicator(
              _ctrl!, allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white.withOpacity(0.3),
                backgroundColor: Colors.transparent,
              ),
            )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final bool dark;
  final Color sub;
  final VoidCallback onRetry;
  const _ErrorState(
      {required this.dark, required this.sub, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: sub.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Post Not Found'.tr(context),
              style: manrope(size: 16, weight: FontWeight.w800,
                  color: fg, letterSpacing: -0.2)),
          const SizedBox(height: 8),
          Text(
            'The link may be invalid or the post has been deleted.'
                .tr(context),
            textAlign: TextAlign.center,
            style: manrope(size: 13, weight: FontWeight.w500,
                color: sub, height: 1.4),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: dark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              child: Text('Retry'.tr(context),
                  style: manrope(size: 13.5, weight: FontWeight.w700,
                      color: fg)),
            ),
          ),
        ]),
      ),
    );
  }
}
