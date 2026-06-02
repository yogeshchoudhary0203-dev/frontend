// shots_screen.dart
// Vertical short-video "Shots" feed — full-screen real video from backend.
// UI chrome is IDENTICAL to original design (pill switcher, right rail,
// caption block, gradients, audio disc). Only the video layer is real now.
//
// Changes vs original:
//   • _Video placeholder → _ShotVideoPage (real VideoPlayerController)
//   • Hardcoded ShotData → real PostModel from API (getShotsFeed)
//   • PageView.builder vertical swipe between shots
//   • Volume HIGH (1.0) by default — user wants sound on by default
//   • Battery: VideoControllerPool — exactly 3 controllers alive (prev/cur/next)
//   • Data: on mobile data controller init deferred until visible
//   • Switching Fun ↔ Learn disposes all controllers, loads fresh feed

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/video_controller_pool.dart';
import '../models/quiz_model.dart';
import '../services/quiz_service.dart';
import '../services/auth_service.dart';
import 'glass_common.dart';
import 'comments_screen.dart';
import 'create_post_screens.dart';
import 'user_profile_screen.dart' as user_profile;
import '../utils/share_helper.dart';
import 'quiz_screen.dart';
import '../utils/route_observer.dart';

// ───────────────────────────────────────────────────────────────
// Models / helpers (kept compatible with existing UI widgets)
// ───────────────────────────────────────────────────────────────

enum ShotsFeed { fun, learn }

/// Legacy display-only model — kept so _RightRail / _CaptionBlock don't change.
class ShotData {
  final String user;
  final int avatarSeed;
  final String caption;
  final String likes;
  final String comments;
  final String shares;
  const ShotData({
    required this.user,
    required this.avatarSeed,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.shares,
  });
}

/// Format a raw count into a compact string (128000 → "128K").
String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Adapt a real PostModel into the display-only ShotData.
ShotData _toShot(PostModel p) => ShotData(
  user: p.userUsername.isNotEmpty ? p.userUsername : p.userName,
  avatarSeed: p.userId.hashCode.abs() % 6,
  caption: p.caption,
  likes: _fmt(p.likesCount),
  comments: _fmt(p.commentsCount),
  shares: '0',
);

// ───────────────────────────────────────────────────────────────
// Screen
// ───────────────────────────────────────────────────────────────

class ShotsScreen extends StatefulWidget {
  final bool dark;
  const ShotsScreen({super.key, this.dark = true});

  @override
  State<ShotsScreen> createState() => _ShotsScreenState();
}

class _ShotsScreenState extends State<ShotsScreen>
    with TickerProviderStateMixin
    implements RouteAware {
  // ── Feed state ────────────────────────────────────────────────
  ShotsFeed _feed = ShotsFeed.fun;
  final List<PostModel> _posts = [];
  String? _nextCursor;
  bool _loading = false;
  bool _error = false;

  // ── Video controller pool ─────────────────────────────────────
  // Exactly 3 controllers alive at once (prev / cur / next).
  // The pool is the sole owner of every VideoPlayerController.
  late VideoControllerPool _pool;
  bool _poolInitialized = false;
  int _curIdx = 0;
  bool _muted = false; // HIGH volume by default

  // ── PageView ──────────────────────────────────────────────────
  final PageController _pageCtrl = PageController();

  // ── Per-post UI state (index → bool / int) ───────────────────
  final Map<int, bool> _liked = {};
  final Map<int, int> _commentsCount = {}; // exact count override after comment
  final Map<int, bool> _saved = {};
  final Map<int, int> _likesDelta = {}; // +1 / -1 per optimistic like
  final Map<String, bool> _followedUsers = {};
  bool _expanded = false;

  // ── Learn-feed nudge counter ──────────────────────────────────
  int _funReelCount = 0; // reels watched in fun feed this session
  bool _nudgePending = false; // debounce: don't stack multiple dialogs

  // ── Quiz watch tracking ───────────────────────────────────────
  // videoId → set of thresholds already fired: {35, 65}
  final Map<String, Set<int>> _firedThresholds = {};
  // videoId → wall-clock start time (for watchDurationSeconds)
  final Map<String, DateTime> _watchStartTimes = {};
  // Background poll after quiz is triggered
  Timer? _quizPollTimer;
  String? _pendingQuizId;
  bool _quizBannerShown = false;

  // ── Per-index progress listeners attached to pool controllers ─
  // We store them so we can remove them before the pool recycles.
  final Map<int, VoidCallback> _progressListeners = {};

  // ── Spinning audio disc (purely decorative) ───────────────────
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pool = VideoControllerPool(
      urlResolver: (i) => _posts[i].mediaUrl,
      itemCount: 0,
      muted: _muted,
      looping: true,
      onReady: (idx, ctrl) {
        if (!mounted) return;
        // Attach quiz progress listener for learn feed.
        if (_feed == ShotsFeed.learn && idx < _posts.length) {
          _attachProgressListener(idx, ctrl);
        }
        // Auto-play if this is the current index.
        if (idx == _curIdx) {
          ctrl.setVolume(_muted ? 0.0 : 1.0);
          ctrl.play();
          setState(() {});
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadFeed(refresh: true),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  // ── RouteAware — pause current video when another screen covers this one ──
  @override
  void didPushNext() => _pool.pauseAll();

  @override
  void didPopNext() {
    // Resume current video when returning from comments/profile etc.
    _pool.setMuted(_muted);
    _pool.resumeCurrent();
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _quizPollTimer?.cancel();
    _spin.dispose();
    _pageCtrl.dispose();
    _pool.disposeAll();
    _progressListeners.clear();
    super.dispose();
  }

  // ── Feed loading ──────────────────────────────────────────────

  Future<void> _loadFeed({bool refresh = false}) async {
    if (_loading) return;
    if (!refresh && _nextCursor == null && _posts.isNotEmpty) return;

    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final result = await PostService.instance.getShotsFeed(
        section: _feed == ShotsFeed.fun ? 'fun' : 'learn',
        cursor: refresh ? null : _nextCursor,
        refresh: refresh,
      );
      if (!mounted) return;

      if (refresh) {
        // Remove all progress listeners before pool disposes controllers.
        _detachAllProgressListeners();
        _pool.disposeAll();
        _poolInitialized = false;
        _posts.clear();
        _liked.clear();
        _saved.clear();
        _likesDelta.clear();
        _commentsCount.clear();
        _curIdx = 0;
        _expanded = false;
        // Jump page controller back to top without animation.
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(0);
        }
      }

      final startIdx = _posts.length;
      _posts.addAll(result.posts);
      _nextCursor = result.nextCursor;

      // Update pool item count (must happen before warmUp).
      _pool.updateItemCount(_posts.length);

      // Initialise liked state from real API data.
      for (int i = startIdx; i < _posts.length; i++) {
        _liked[i] = _posts[i].isLiked;
      }

      setState(() {});

      // Warm up first video immediately after a refresh.
      if (refresh && _posts.isNotEmpty && !_poolInitialized) {
        _poolInitialized = true;
        await _pool.warmUp(0);
        if (mounted) setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Like / Unlike (real API + optimistic UI) ─────────────────

  Future<void> _onLikeTap(int idx) async {
    if (idx < 0 || idx >= _posts.length) return;
    final post = _posts[idx];
    final wasLiked = _liked[idx] ?? post.isLiked;
    final nowLiked = !wasLiked;

    // Optimistic update — show result immediately.
    setState(() {
      _liked[idx] = nowLiked;
      _likesDelta[idx] = (_likesDelta[idx] ?? 0) + (nowLiked ? 1 : -1);
    });

    try {
      if (nowLiked) {
        await PostService.instance.likePost(post.id);
      } else {
        await PostService.instance.unlikePost(post.id);
      }
    } catch (_) {
      // API failed — revert optimistic update.
      if (mounted) {
        setState(() {
          _liked[idx] = wasLiked;
          _likesDelta[idx] = (_likesDelta[idx] ?? 0) + (wasLiked ? 1 : -1);
        });
      }
    }
  }

  // ── Follow / Unfollow (real API + optimistic UI) ─────────────

  Future<void> _onFollowTap(PostModel post) async {
    final targetId = post.userId;
    if (targetId.isEmpty) return;

    final wasFollowing = _followedUsers[targetId] ?? false;
    final nowFollowing = !wasFollowing;

    HapticFeedback.mediumImpact();

    // Optimistically update.
    setState(() {
      _followedUsers[targetId] = nowFollowing;
    });

    try {
      bool success = false;
      if (nowFollowing) {
        success = await UserService.followUser(targetId);
      } else {
        success = await UserService.unfollowUser(targetId);
      }
      if (!success) {
        if (mounted) {
          setState(() {
            _followedUsers[targetId] = wasFollowing;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _followedUsers[targetId] = wasFollowing;
        });
      }
    }
  }

  // ── Quiz watch-progress tracking ─────────────────────────────

  /// Attach a per-frame listener to [ctrl] for quiz threshold detection.
  /// Only called in learn feed. Stored in [_progressListeners] so it can
  /// be removed before the pool recycles the controller.
  void _attachProgressListener(int idx, VideoPlayerController ctrl) {
    // Remove any stale listener for this slot first.
    _detachProgressListener(idx);

    void listener() => _onVideoProgress(idx, ctrl, _posts[idx]);
    _progressListeners[idx] = listener;
    ctrl.addListener(listener);
  }

  void _detachProgressListener(int idx) {
    final listener = _progressListeners.remove(idx);
    if (listener != null) {
      _pool.controllerAt(idx)?.removeListener(listener);
    }
  }

  void _detachAllProgressListeners() {
    for (final entry in _progressListeners.entries) {
      _pool.controllerAt(entry.key)?.removeListener(entry.value);
    }
    _progressListeners.clear();
  }

  void _recordWatchStart(String videoId) {
    _watchStartTimes.putIfAbsent(videoId, () => DateTime.now());
  }

  // Called ~every frame by VideoPlayerController listener.
  void _onVideoProgress(int idx, VideoPlayerController ctrl, PostModel post) {
    if (_feed != ShotsFeed.learn) return;
    if (!ctrl.value.isPlaying) return;
    final dur = ctrl.value.duration.inMilliseconds;
    if (dur == 0) return;
    final pct = (ctrl.value.position.inMilliseconds / dur * 100).toInt();
    final fired = _firedThresholds.putIfAbsent(post.id, () => {});

    if (pct >= 35 && !fired.contains(35)) {
      fired.add(35);
      _fireWatchEvent(post, 35);
    }
    if (pct >= 65 && !fired.contains(65)) {
      fired.add(65);
      _fireWatchEvent(post, 65);
    }
  }

  Future<void> _fireWatchEvent(PostModel post, int threshold) async {
    final userId = await AuthService.getUserId();
    if (userId == null || !mounted) return;
    final startTime = _watchStartTimes[post.id] ?? DateTime.now();
    final wallSec =
        DateTime.now().difference(startTime).inMilliseconds / 1000.0;

    // Use actual elapsed time, but ensure it's at least 30% of video duration
    // so short videos (10s) aren't blocked by a fixed minimum.
    final ctrl = _pool.controllerAt(_posts.indexOf(post));
    final videoDurSec = (ctrl?.value.duration.inMilliseconds ?? 0) / 1000.0;
    final minRequired = videoDurSec > 0
        ? (videoDurSec * 0.3).clamp(2.0, 30.0)
        : 2.0;
    final durationSec = wallSec < minRequired ? minRequired : wallSec;

    try {
      final result = await QuizService.sendWatchEvent(
        userId: userId,
        videoId: post.id,
        watchPercentage: threshold.toDouble(),
        watchDurationSeconds: durationSec.clamp(0, 3600),
        videoTopic: post.learnTopic ?? post.section ?? 'general',
        videoUrl: post.mediaUrl,
      );

      if (result['quiz_triggered'] == true && mounted) {
        final quizId = result['quiz_id'] as String?;
        if (quizId != null && quizId != _pendingQuizId) {
          _pendingQuizId = quizId;
          _startQuizPolling(quizId);
        }
      }
    } catch (_) {}
  }

  // ── Background polling — every 5 seconds until quiz is ready ──

  void _startQuizPolling(String quizId) {
    _quizPollTimer?.cancel();
    _quizBannerShown = false;
    int attempts = 0;
    _quizPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) {
        _quizPollTimer?.cancel();
        return;
      }
      attempts++;
      if (attempts > 36) {
        _quizPollTimer?.cancel();
        return;
      } // 3 min max

      final quiz = await QuizService.getQuiz(quizId);
      if (!mounted) return;
      if (quiz?.status == 'ready' && !_quizBannerShown) {
        _quizPollTimer?.cancel();
        _quizBannerShown = true;
        _autoOpenQuiz(quiz!);
      } else if (quiz?.status == 'failed') {
        _quizPollTimer?.cancel();
      }
    });
  }

  // ── Quiz ready → auto-open quiz screen, video pauses ────────

  void _autoOpenQuiz(QuizModel quiz) {
    if (!mounted) return;
    // Pause current video while quiz is open.
    _pool.controllerAt(_curIdx)?.pause();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz))).then((_) {
      // Resume video when user comes back from quiz.
      if (mounted) {
        _pendingQuizId = null;
        _quizBannerShown = false;
        _pool.resumeCurrent();
      }
    });
  }

  // ── Page-change handler — delegates lifecycle to pool ────────

  void _onPageChanged(int idx) {
    HapticFeedback.selectionClick();

    setState(() {
      _curIdx = idx;
      _expanded = false;
    });

    // Record watch start for new video (learn feed).
    if (_feed == ShotsFeed.learn && idx < _posts.length) {
      _recordWatchStart(_posts[idx].id);
    }

    // Hand off to the pool — it handles pause/play/preload/prune.
    _pool.onPageChanged(idx);

    // Fetch more when 3 posts from the end.
    if (idx >= _posts.length - 3) _loadFeed();

    // Track fun-feed watch count and nudge every 10 reels.
    if (_feed == ShotsFeed.fun) {
      _funReelCount++;
      if (_funReelCount % 10 == 0 && !_nudgePending) {
        _nudgePending = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showLearnNudge();
        });
      }
    }
  }

  void _setFeed(ShotsFeed f) {
    if (f == _feed) return;
    HapticFeedback.selectionClick();
    _pool.pauseAll();
    _quizPollTimer?.cancel();
    _detachAllProgressListeners();
    setState(() {
      _feed = f;
      _expanded = false;
      _funReelCount = 0;
      _nudgePending = false;
      _firedThresholds.clear();
      _watchStartTimes.clear();
      _pendingQuizId = null;
      _quizBannerShown = false;
    });
    _loadFeed(refresh: true);
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _pool.setMuted(_muted);
  }

  Future<void> _openShotsCamera() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Create a Shot',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final file = await picker.pickVideo(
                    source: ImageSource.camera,
                  );
                  if (file != null && mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreatePostEditScreen(
                          dark: widget.dark,
                          file: file,
                          isVideo: true,
                          initialSection: _feed == ShotsFeed.learn
                              ? CpVideoSection.learn
                              : CpVideoSection.fun,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.07),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Record Video (Camera)',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final file = await picker.pickVideo(
                    source: ImageSource.gallery,
                  );
                  if (file != null && mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreatePostEditScreen(
                          dark: widget.dark,
                          file: file,
                          isVideo: true,
                          initialSection: _feed == ShotsFeed.learn
                              ? CpVideoSection.learn
                              : CpVideoSection.fun,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.07),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.video_library_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Choose Video (Gallery)',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLearnNudge() async {
    // Pause current video while dialog is up.
    _pool.controllerAt(_curIdx)?.pause();

    await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 340),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => _LearnFeedNudge(
        onSwitch: () {
          Navigator.of(ctx).pop(true);
          _setFeed(ShotsFeed.learn);
        },
        onSkip: () {
          Navigator.of(ctx).pop(false);
          // Resume video and reset nudge flag so it fires again after next 10.
          _pool.resumeCurrent();
          setState(() => _nudgePending = false);
        },
      ),
    );

    // Safety: ensure flag is cleared if dialog dismissed any other way.
    if (mounted) setState(() => _nudgePending = false);
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).viewPadding.top;
    final hasPost = _posts.isNotEmpty;
    // Build curData with adjusted likes count (reflects optimistic like/unlike).
    final curData = hasPost
        ? () {
            final p = _posts[_curIdx];
            final adjustedCount = (p.likesCount + (_likesDelta[_curIdx] ?? 0))
                .clamp(0, 999999999);
            return ShotData(
              user: p.userUsername.isNotEmpty ? p.userUsername : p.userName,
              avatarSeed: p.userId.hashCode.abs() % 6,
              caption: p.caption,
              likes: _fmt(adjustedCount),
              comments: _fmt(_commentsCount[_curIdx] ?? p.commentsCount),
              shares: '0',
            );
          }()
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video layer ────────────────────────────────────────
          _buildBody(),

          // ── Gradient overlays ──────────────────────────────────
          _topFade(),
          _bottomFade(),

          // ── Top bar: back + pill + camera ─────────────────────
          Positioned(
            top: topInset == 0 ? 14 : topInset + 10,
            left: 16,
            right: 16,
            child: _TopBar(
              feed: _feed,
              onTap: _setFeed,
              onExit: () => Navigator.of(context).pop(),
              onCamera: _openShotsCamera,
            ),
          ),

          // ── Mute / unmute (top-right under camera) ─────────────
          if (hasPost)
            Positioned(
              top: topInset == 0 ? 54 : topInset + 50,
              right: 16,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.45),
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

          // ── Right rail: like, comment, share, save, more, disc ─
          if (hasPost && curData != null)
            Positioned(
              right: 12,
              bottom: 70,
              child: _RightRail(
                data: curData,
                liked:
                    _liked[_curIdx] ??
                    (_posts.isNotEmpty ? _posts[_curIdx].isLiked : false),
                saved: _saved[_curIdx] ?? false,
                spin: _spin,
                onLike: () => _onLikeTap(_curIdx),
                onSave: () => setState(
                  () => _saved[_curIdx] = !(_saved[_curIdx] ?? false),
                ),
                post: _posts[_curIdx],
                onCommentPosted: (newCount) {
                  setState(() => _commentsCount[_curIdx] = newCount);
                },
              ),
            ),

          // ── Bottom-left: @handle + caption + 3-dot ─────────────
          if (hasPost && curData != null)
            Positioned(
              left: 16,
              right: 78,
              bottom: 32,
              child: _CaptionBlock(
                data: curData,
                post: _posts[_curIdx],
                expanded: _expanded,
                onToggleExpand: () => setState(() => _expanded = !_expanded),
                followed: _followedUsers[_posts[_curIdx].userId] ?? false,
                onFollowTap: () => _onFollowTap(_posts[_curIdx]),
              ),
            ),
        ],
      ),
    );
  }

  // ── Body: states + PageView ───────────────────────────────────

  Widget _buildBody() {
    // Initial loading.
    if (_loading && _posts.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: Colors.white38,
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Error.
    if (_error && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 44),
            const SizedBox(height: 12),
            Text(
              'Could not load shots',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _loadFeed(refresh: true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Empty (no videos in this section yet).
    if (!_loading && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Colors.white24,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              _feed == ShotsFeed.fun
                  ? 'No fun videos yet.\nBe the first to post!'
                  : 'No learn videos yet.\nBe the first to post!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Real full-screen vertical PageView.
    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: _posts.length,
      itemBuilder: (_, i) {
        final post = _posts[i];
        // Read controller from the pool — null if not yet initialised.
        final ctrl = _pool.controllerAt(i);
        final thumb = post.thumbnailUrl ?? post.mediaUrl;
        return _ShotVideoPage(controller: ctrl, thumbnailUrl: thumb);
      },
    );
  }

  // ── Gradient helpers (unchanged from original) ────────────────

  Widget _topFade() => const IgnorePointer(
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: 130,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x8C000000), Color(0x00000000)],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    ),
  );

  Widget _bottomFade() => const IgnorePointer(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 260,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x8C000000), Color(0xC7000000)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    ),
  );
}

// ───────────────────────────────────────────────────────────────
// Learn-feed nudge dialog — shown every 10 fun reels
// ───────────────────────────────────────────────────────────────

class _LearnFeedNudge extends StatelessWidget {
  final VoidCallback onSwitch;
  final VoidCallback onSkip;
  const _LearnFeedNudge({required this.onSwitch, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.22),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 40,
                    spreadRadius: -4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icon badge ─────────────────────────────────
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.45),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🎓', style: TextStyle(fontSize: 34)),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Headline ───────────────────────────────────
                  Text(
                    'You\'ve Watched 10 Fun Shots!',
                    textAlign: TextAlign.center,
                    style: manrope(
                      size: 20,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Sub-text ───────────────────────────────────
                  Text(
                    'Switch to the Learn feed and discover something new?',
                    textAlign: TextAlign.center,
                    style: manrope(
                      size: 14,
                      weight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.72),
                      letterSpacing: -0.1,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Primary button: Switch ─────────────────────
                  GestureDetector(
                    onTap: onSwitch,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Switch to Learn Feed',
                        style: manrope(
                          size: 15,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Secondary button: Skip ─────────────────────
                  GestureDetector(
                    onTap: onSkip,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Keep Watching Fun',
                        style: manrope(
                          size: 14,
                          weight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Real video page — full-screen cover with thumbnail fallback
// ───────────────────────────────────────────────────────────────

class _ShotVideoPage extends StatelessWidget {
  final VideoPlayerController? controller;
  final String? thumbnailUrl;
  const _ShotVideoPage({this.controller, this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    final isReady = ctrl != null && ctrl.value.isInitialized;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (ctrl != null && ctrl.value.isInitialized) {
          if (ctrl.value.isPlaying) {
            ctrl.pause();
          } else {
            ctrl.play();
          }
        }
      },
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Thumbnail always shown as background ───────────────
            if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                maxWidthDiskCache: 400,
                placeholder: (_, __) => Container(color: Colors.black),
                errorWidget: (_, __, ___) => Container(color: Colors.black),
              )
            else
              Container(color: Colors.black),

            // ── Video player (covers thumbnail once ready) ─────────
            if (isReady)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: ctrl.value.size.width,
                  height: ctrl.value.size.height,
                  child: VideoPlayer(ctrl),
                ),
              ),

            // ── Play/Pause Icon Overlay ─────────────────────────────
            if (ctrl != null)
              ValueListenableBuilder(
                valueListenable: ctrl,
                builder: (context, VideoPlayerValue value, child) {
                  if (!value.isInitialized || value.isPlaying) {
                    return const SizedBox.shrink();
                  }
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  );
                },
              ),

            // ── Loading spinner while controller initialises ────────
            if (!isReady)
              Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.35),
                    strokeWidth: 2,
                  ),
                ),
              ),

            // ── Progress bar at bottom edge ────────────────────────
            if (isReady)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  ctrl,
                  allowScrubbing: false,
                  padding: EdgeInsets.zero,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withOpacity(0.30),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Top bar — back + pill switcher + camera  (UNCHANGED)
// ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final ShotsFeed feed;
  final ValueChanged<ShotsFeed> onTap;
  final VoidCallback onExit;
  final VoidCallback? onCamera;
  const _TopBar({
    required this.feed,
    required this.onTap,
    required this.onExit,
    this.onCamera,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _BareIcon(icon: Icons.arrow_back_ios_new, size: 22, onTap: onExit),
      Expanded(
        child: Center(
          child: _FeedPill(feed: feed, onTap: onTap),
        ),
      ),
      _BareIcon(icon: Icons.photo_camera_outlined, size: 24, onTap: onCamera),
    ],
  );
}

class _FeedPill extends StatelessWidget {
  final ShotsFeed feed;
  final ValueChanged<ShotsFeed> onTap;
  const _FeedPill({required this.feed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const pillWidth = 168.0;
    const pillHeight = 36.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: pillWidth,
          height: pillHeight,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.32),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                alignment: feed == ShotsFeed.fun
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: (pillWidth - 8) / 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _PillTab(
                      label: 'Fun',
                      active: feed == ShotsFeed.fun,
                      onTap: () => onTap(ShotsFeed.fun),
                    ),
                  ),
                  Expanded(
                    child: _PillTab(
                      label: 'Learn',
                      active: feed == ShotsFeed.learn,
                      onTap: () => onTap(ShotsFeed.learn),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PillTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Center(
        child: Text(
          label.tr(context),
          style: manrope(
            size: 13,
            weight: active ? FontWeight.w800 : FontWeight.w600,
            color: active
                ? const Color(0xFF0A0A0A)
                : Colors.white.withOpacity(0.85),
            letterSpacing: -0.13,
          ),
        ),
      ),
    ),
  );
}

// ───────────────────────────────────────────────────────────────
// Right rail — like, comment, share, save, more, disc  (UNCHANGED)
// ───────────────────────────────────────────────────────────────

class _RightRail extends StatelessWidget {
  final ShotData data;
  final bool liked;
  final bool saved;
  final AnimationController spin;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final PostModel post;
  final void Function(int newCount)? onCommentPosted;
  const _RightRail({
    required this.data,
    required this.liked,
    required this.saved,
    required this.spin,
    required this.onLike,
    required this.onSave,
    required this.post,
    this.onCommentPosted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BareIconWithCount(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? const Color(0xFFFF3B5C) : Colors.white,
          size: 30,
          count: data.likes,
          onTap: onLike,
        ),
        const SizedBox(height: 18),
        _BareCustomIconWithCount(
          child: CustomPaint(
            painter: _CommentBubblePainter(color: Colors.white),
          ),
          size: 28,
          count: data.comments,
          onTap: () {
            final initial = data.user
                .substring(0, data.user.length >= 2 ? 2 : 1)
                .toUpperCase();
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, animation, __) => CommentsScreen(
                  dark: true,
                  postUser: data.user,
                  postDescription: data.caption,
                  postInitials: initial,
                  postUserColor: const Color(0xFF2D3561),
                  postId: post.id,
                  onCommentPosted: onCommentPosted,
                ),
                transitionDuration: const Duration(milliseconds: 380),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder: (_, animation, __, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(curved),
                    child: FadeTransition(opacity: curved, child: child),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        _BareIconWithCount(
          icon: Icons.near_me_rounded,
          size: 28,
          count: data.shares,
          onTap: () => ShareHelper.showShareBottomSheet(context, post),
        ),
        const SizedBox(height: 18),
        _BareCustomIcon(
          child: CustomPaint(painter: _SaveCirclePainter(color: Colors.white)),
          size: 28,
          onTap: onSave,
        ),
        const SizedBox(height: 18),
        _BareIcon(icon: Icons.more_horiz, size: 26, onTap: () {}),
        const SizedBox(height: 12),
        _AudioDisc(seed: data.avatarSeed, spin: spin),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Caption block  (UNCHANGED)
// ───────────────────────────────────────────────────────────────

class _CaptionBlock extends StatelessWidget {
  final ShotData data;
  final PostModel post;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final bool followed;
  final VoidCallback onFollowTap;

  const _CaptionBlock({
    required this.data,
    required this.post,
    required this.expanded,
    required this.onToggleExpand,
    required this.followed,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = data.user.substring(0, 1).toUpperCase();
    const shadow = Shadow(
      color: Color(0x8C000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => user_profile.ProfileScreen(
                      userId: post.userId,
                      username: post.userUsername.isNotEmpty
                          ? post.userUsername
                          : post.userName,
                      displayName: post.userName,
                    ),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xF2FFFFFF),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: monoAvatar(true, data.avatarSeed),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: manrope(
                          size: 13,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '@${data.user}',
                    style: manrope(
                      size: 14,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.14,
                    ).copyWith(shadows: [shadow]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: followed ? Colors.white.withOpacity(0.2) : Colors.white,
              shape: const StadiumBorder(),
              elevation: 2,
              shadowColor: const Color(0x40000000),
              child: InkWell(
                onTap: onFollowTap,
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  child: Text(
                    followed ? 'Following'.tr(context) : 'Follow'.tr(context),
                    style: manrope(
                      size: 12,
                      weight: FontWeight.w800,
                      color: followed ? Colors.white : const Color(0xFF0A0A0A),
                      letterSpacing: -0.06,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onToggleExpand,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topLeft,
                  curve: Curves.easeInOut,
                  child: Text(
                    data.caption,
                    maxLines: expanded ? null : 1,
                    overflow: expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: manrope(
                      size: 13,
                      weight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: -0.065,
                      height: 1.45,
                    ).copyWith(shadows: [shadow]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _BareIcon(icon: Icons.more_horiz, size: 18, onTap: onToggleExpand),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Shared icon primitives  (UNCHANGED)
// ───────────────────────────────────────────────────────────────

class _BareIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;
  const _BareIcon({
    required this.icon,
    required this.size,
    this.color = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, size: size, color: color),
      ),
    ),
  );
}

class _BareCustomIcon extends StatelessWidget {
  final Widget child;
  final double size;
  final VoidCallback? onTap;
  const _BareCustomIcon({required this.child, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: SizedBox(width: size, height: size, child: child),
      ),
    ),
  );
}

class _BareIconWithCount extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final String count;
  final VoidCallback onTap;
  const _BareIconWithCount({
    required this.icon,
    required this.size,
    this.color = Colors.white,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _BareIcon(icon: icon, size: size, color: color, onTap: onTap),
      const SizedBox(height: 4),
      Text(
        count,
        style:
            manrope(
              size: 11.5,
              weight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.115,
            ).copyWith(
              shadows: const [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
      ),
    ],
  );
}

class _BareCustomIconWithCount extends StatelessWidget {
  final Widget child;
  final double size;
  final String count;
  final VoidCallback onTap;
  const _BareCustomIconWithCount({
    required this.child,
    required this.size,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: SizedBox(width: size, height: size, child: child),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        count,
        style:
            manrope(
              size: 11.5,
              weight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.115,
            ).copyWith(
              shadows: const [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
      ),
    ],
  );
}

// ───────────────────────────────────────────────────────────────
// Audio disc  (UNCHANGED)
// ───────────────────────────────────────────────────────────────

class _AudioDisc extends StatelessWidget {
  final int seed;
  final AnimationController spin;
  const _AudioDisc({required this.seed, required this.spin});

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: spin,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF333333), Color(0xFF0A0A0A), Color(0xFF1F1F22)],
          stops: [0.0, 0.6, 1.0],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: monoAvatar(true, seed),
        ),
      ),
    ),
  );
}

// ───────────────────────────────────────────────────────────────
// Custom painters  (UNCHANGED)
// ───────────────────────────────────────────────────────────────

class _CommentBubblePainter extends CustomPainter {
  final Color color;
  const _CommentBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 28.0;
    final sy = size.height / 28.0;
    final bounds = Offset.zero & size;
    final bubble = Path()
      ..moveTo(8.6 * sx, 4.3 * sy)
      ..lineTo(19.4 * sx, 4.3 * sy)
      ..cubicTo(23.7 * sx, 4.3 * sy, 25.8 * sx, 7.5 * sy, 25.8 * sx, 11.8 * sy)
      ..lineTo(25.8 * sx, 16.2 * sy)
      ..cubicTo(
        25.8 * sx,
        20.5 * sy,
        22.6 * sx,
        22.6 * sy,
        18.3 * sx,
        22.6 * sy,
      )
      ..lineTo(16.2 * sx, 22.6 * sy)
      ..cubicTo(13.5 * sx, 22.6 * sy, 11.4 * sx, 23.7 * sy, 8.6 * sx, 25.8 * sy)
      ..cubicTo(8.0 * sx, 26.4 * sy, 7.1 * sx, 25.8 * sy, 7.1 * sx, 24.9 * sy)
      ..lineTo(7.1 * sx, 22.4 * sy)
      ..cubicTo(3.9 * sx, 21.4 * sy, 2.2 * sx, 18.6 * sy, 2.2 * sx, 15.1 * sy)
      ..lineTo(2.2 * sx, 11.8 * sy)
      ..cubicTo(2.2 * sx, 7.5 * sy, 4.3 * sx, 4.3 * sy, 8.6 * sx, 4.3 * sy)
      ..close();
    canvas.saveLayer(bounds, Paint());
    canvas.drawPath(bubble, Paint()..color = color);
    final clear = Paint()..blendMode = BlendMode.clear;
    for (final cx in [10.2, 14.0, 17.8]) {
      canvas.drawCircle(Offset(cx * sx, 14.0 * sy), 1.7 * sx, clear);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CommentBubblePainter o) => o.color != color;
}

class _SaveCirclePainter extends CustomPainter {
  final Color color;
  const _SaveCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 28.0;
    final sy = size.height / 28.0;
    final bookmark = Path()
      ..moveTo(7.5 * sx, 3.4 * sy)
      ..lineTo(20.5 * sx, 3.4 * sy)
      ..cubicTo(22.3 * sx, 3.4 * sy, 23.7 * sx, 4.8 * sy, 23.7 * sx, 6.7 * sy)
      ..lineTo(23.7 * sx, 22.6 * sy)
      ..cubicTo(
        23.7 * sx,
        24.3 * sy,
        21.8 * sx,
        25.2 * sy,
        20.5 * sx,
        23.9 * sy,
      )
      ..lineTo(14.0 * sx, 17.9 * sy)
      ..lineTo(7.5 * sx, 23.9 * sy)
      ..cubicTo(6.2 * sx, 25.2 * sy, 4.3 * sx, 24.3 * sy, 4.3 * sx, 22.6 * sy)
      ..lineTo(4.3 * sx, 6.7 * sy)
      ..cubicTo(4.3 * sx, 4.8 * sy, 5.7 * sx, 3.4 * sy, 7.5 * sx, 3.4 * sy)
      ..close();
    canvas.drawPath(bookmark, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SaveCirclePainter o) => o.color != color;
}
