import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/post_service.dart';
import '../../services/video_controller_pool.dart';
import '../shared/home_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FeedVideoPool
//
// A single shared VideoControllerPool for the home feed.  We keep it as a
// module-level singleton so the pool survives widget rebuilds and is shared
// across all VideoCard instances in the same feed list.
//
// The pool is lazily created when the first VideoCard calls [FeedVideoPool.get]
// and is torn down (disposeAll) by calling [FeedVideoPool.reset] — typically
// when the feed is refreshed or the screen is disposed.
// ─────────────────────────────────────────────────────────────────────────────

class FeedVideoPool {
  FeedVideoPool._();

  static VideoControllerPool? _instance;

  /// Return (or create) the shared pool for a given feed snapshot.
  ///
  /// [posts]    — the current ordered list of video posts.
  /// [muted]    — initial mute state.
  static VideoControllerPool get({
    required List<PostModel> posts,
    bool muted = false,
  }) {
    // If the pool already covers the same posts, reuse it.
    if (_instance != null && _instance!.itemCount == posts.length) {
      return _instance!;
    }
    // Feed changed (refresh / first load) — build a fresh pool.
    _instance?.disposeAll();
    _instance = VideoControllerPool(
      itemCount: posts.length,
      muted: muted,
      urlResolver: (i) => posts[i].mediaUrl,
      onReady: (_, __) {},   // VideoCard rebuilds via listener below
    );
    return _instance!;
  }

  /// Grow the pool when more posts are appended (infinite scroll).
  static void grow(List<PostModel> posts) {
    _instance?.updateItemCount(posts.length);
    if (_instance != null) {
      // Patch the resolver — create new pool with same controllers but new count.
      // Simpler: just update itemCount; urlResolver already closed over the list.
      // Because Dart lists are passed by reference, the closed-over list grows
      // automatically, so updating itemCount is sufficient.
    }
  }

  /// Dispose all controllers and forget the pool.
  static void reset() {
    _instance?.disposeAll();
    _instance = null;
  }

  /// Pause everything (e.g. app goes to background).
  static void pauseAll() => _instance?.pauseAll();

  /// Resume the current-index video.
  static void resumeCurrent() => _instance?.resumeCurrent();

  static void setMuted(bool v) => _instance?.setMuted(v);
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoCard
//
// Stateful widget that renders a single video post inside the home feed.
// Controller lifecycle is fully delegated to [FeedVideoPool]; this widget only
// holds the local UI state (mute toggle, overlay icon, manual-pause flag).
// ─────────────────────────────────────────────────────────────────────────────

class VideoCard extends StatefulWidget {
  final PostModel post;
  final bool isDark;

  /// Index of this card in the feed list — used to address the pool.
  final int postIndex;

  /// The live post list (passed by reference; pool grows with it).
  final List<PostModel> allPosts;

  final ValueChanged<PostModel>? onLearnWatched;

  const VideoCard({
    super.key,
    required this.post,
    required this.isDark,
    required this.postIndex,
    required this.allPosts,
    this.onLearnWatched,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _muted        = false;
  bool _manualPause  = false;
  bool _showOverlay  = false;
  IconData _overlayIcon = Icons.pause_rounded;

  VideoControllerPool get _pool => FeedVideoPool.get(
    posts: widget.allPosts,
    muted: _muted,
  );

  VideoPlayerController? get _ctrl => _pool.controllerAt(widget.postIndex);
  bool get _initialized => _pool.isReady(widget.postIndex);

  @override
  void initState() {
    super.initState();
    homeFeedActive.addListener(_onFeedActiveChanged);
    // Warm up pool at the current index (fire-and-forget; setState via listener).
    _pool.warmUp(widget.postIndex).then((_) {
      if (mounted) {
        // Attach a listener so we rebuild once the controller is ready.
        _ctrl?.addListener(_onControllerUpdate);
        setState(() {});
      }
    });
  }

  void _onFeedActiveChanged() {
    if (!homeFeedActive.value && _initialized) _ctrl?.pause();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.5;
    if (visible) {
      widget.onLearnWatched?.call(widget.post);

      if (!_initialized) {
        // Ask the pool to prepare this index; rebuild when done.
        _pool.warmUp(widget.postIndex).then((_) {
          if (mounted) {
            _ctrl?.addListener(_onControllerUpdate);
            if (!_manualPause) {
              _ctrl?.setVolume(_muted ? 0.0 : 1.0);
              _ctrl?.play();
            }
            setState(() {});
          }
        });
      } else if (!_manualPause) {
        _ctrl?.setVolume(_muted ? 0.0 : 1.0);
        _ctrl?.play();
      }

      // Tell the pool which index is "current" so it prunes distant ones.
      _pool.onPageChanged(widget.postIndex);
    } else {
      if (_initialized) _ctrl?.pause();
    }
  }

  void _onTap() {
    if (!_initialized) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
      _manualPause = true;
      setState(() { _showOverlay = true; _overlayIcon = Icons.pause_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    } else {
      _manualPause = false;
      ctrl.play();
      setState(() { _showOverlay = true; _overlayIcon = Icons.play_arrow_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    }
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    if (!_initialized) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
      _manualPause = true;
      setState(() { _showOverlay = true; _overlayIcon = Icons.pause_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _ctrl?.setVolume(_muted ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    homeFeedActive.removeListener(_onFeedActiveChanged);
    _ctrl?.removeListener(_onControllerUpdate);
    // Do NOT dispose the controller here — the pool owns its lifecycle.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.post.thumbnailUrl;
    final ctrl = _ctrl;

    return VisibilityDetector(
      key: Key('vid_${widget.post.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: widget.post.aspectRatio,
        child: GestureDetector(
          onTap: _onTap,
          onLongPress: _onLongPress,
          child: Stack(fit: StackFit.expand, children: [

            // ── Thumbnail background ─────────────────────────────
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFF111111)),
                errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF111111)),
              )
            else
              Container(
                color: const Color(0xFF111111),
                child: const Center(
                  child: Icon(Icons.play_circle_outline_rounded, color: Colors.white24, size: 44),
                ),
              ),

            // ── Video layer ──────────────────────────────────────
            if (_initialized && ctrl != null) VideoPlayer(ctrl),

            // ── Subtle bottom gradient ───────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
                    ),
                  ),
                ),
              ),
            ),

            // ── Loading spinner (before first frame) ────────────
            if (!_initialized)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                ),
              ),

            // ── Tap overlay (play / pause flash) ────────────────
            if (_showOverlay)
              Center(
                child: AnimatedOpacity(
                  opacity: _showOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    child: Icon(_overlayIcon, color: Colors.white, size: 34),
                  ),
                ),
              ),

            // ── Mute button ──────────────────────────────────────
            if (_initialized)
              Positioned(
                bottom: 10, right: 10,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.50),
                    ),
                    child: Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white, size: 16,
                    ),
                  ),
                ),
              ),

            // ── Progress bar ─────────────────────────────────────
            if (_initialized && ctrl != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: VideoProgressIndicator(
                  ctrl,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withValues(alpha: 0.30),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
