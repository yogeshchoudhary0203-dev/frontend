import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/fcm_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../notifications_screen.dart';
import '../search_screen.dart';
import '../shots_screen.dart';
import '../profile_screen.dart';
import '../user_profile_screen.dart' as user_profile;
import '../chat_list_screen.dart';
import '../create_post_screens.dart';
import '../comments_screen.dart';
import '../liked_by_screen.dart';
import '../../services/cryptography_service.dart';
import '../../l10n/app_localizations.dart';

extension _ColorOp on Color {
  Color op(double opacity) => withOpacity(opacity);
}

const double _kBtnSize  = 64.0;
const double _kNavWidth = _kBtnSize;
const double _kItemH    = 54.0;
const double _kNavGap   = 6.0;
const double _kIconSize = 20.0; // message icon — minor size reduction

// ─── Story data ───────────────────────────────────────
class _StoryData {
  final String name, initials;
  final Color  avatarColor;
  final bool   seen, isOwn;
  const _StoryData({
    required this.name, required this.initials, required this.avatarColor,
    this.seen = false, this.isOwn = false,
  });
}

const _kStories = <_StoryData>[
  _StoryData(name: 'Your Story', initials: '+',  avatarColor: Color(0xFF3A3A3E), isOwn: true),
  _StoryData(name: 'Arjun',      initials: 'AK', avatarColor: Color(0xFF2D3561)),
  _StoryData(name: 'Priya',      initials: 'PS', avatarColor: Color(0xFF1B4332)),
  _StoryData(name: 'Rohan',      initials: 'RV', avatarColor: Color(0xFF3D0C11)),
  _StoryData(name: 'Sneha',      initials: 'SN', avatarColor: Color(0xFF2C2C54)),
  _StoryData(name: 'Dev',        initials: 'DM', avatarColor: Color(0xFF1A1A2E)),
  _StoryData(name: 'Kavya',      initials: 'KR', avatarColor: Color(0xFF2D132C)),
  _StoryData(name: 'Nikhil',     initials: 'NK', avatarColor: Color(0xFF0D3349), seen: true),
];


// ═════════════════════════════════════════════════════
//  HOME SCREEN
// ═════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  bool _navOpen   = false;
  int  _activeNav = 0;
  double? _swipeStartX;
  double? _swipeStartY;
  int  _totalUnread = 0;
  int  _unreadNotifs = 0;
  late AnimationController      _navCtrl;
  final List<Animation<double>> _itemScales    = [];
  final List<Animation<double>> _itemOpacities = [];

  // ── Island expand / collapse ──────────────────────
  late AnimationController _islandCtrl;
  bool _islandOpen = false;

  // Island pill geometry (populated after first layout)
  Rect   _islandRect   = Rect.zero;
  final  GlobalKey _islandKey = GlobalKey();

  // ── Real-time notification listeners ─────────────
  StreamSubscription? _fcmNotifSub;
  StreamSubscription? _wsNotifSub;

  // ── Feed state ────────────────────────────────────
  final List<PostModel> _posts       = [];
  String?               _nextCursor;
  bool                  _loadingFeed    = false;
  bool                  _feedError      = false;
  bool                  _quickReelOpening = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 480));
    for (int i = 0; i < 5; i++) {
      final double start = (4 - i) * 0.08;
      final double end   = (start + 0.55).clamp(0.0, 1.0);
      _itemScales.add(Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _navCtrl,
              curve: Interval(start, end, curve: Curves.easeOutBack))));
      _itemOpacities.add(Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _navCtrl,
              curve: Interval(start, (start + 0.30).clamp(0.0, 1.0),
                  curve: Curves.easeOut))));
    }

    _islandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 400);
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.setupForHomeScreen();
      CryptographyService().ensurePublicKeyRegistered();
      _loadUnreadCount();
      _loadUnreadNotifCount();
      ChatService().connectWebSocket();
      _listenForNewNotifications();
      _loadFeed();
    });
  }

  @override
  void dispose() {
    _navCtrl.dispose();
    _islandCtrl.dispose();
    _scrollCtrl.dispose();
    _fcmNotifSub?.cancel();
    _wsNotifSub?.cancel();
    super.dispose();
  }

  // ── Feed loading ──────────────────────────────────
  Future<void> _loadFeed({bool refresh = false}) async {
    if (_loadingFeed) return;
    if (!refresh && _nextCursor == null && _posts.isNotEmpty) return;
    setState(() { _loadingFeed = true; _feedError = false; });
    try {
      final result = await PostService.instance.getFeed(
        cursor: refresh ? null : _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _posts.clear();
        _posts.addAll(result.posts);
        _nextCursor = result.nextCursor;
      });
    } catch (_) {
      if (mounted) setState(() => _feedError = true);
    } finally {
      if (mounted) setState(() => _loadingFeed = false);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadFeed();
    }
  }

  void _toggleLike(int index) async {
    final post = _posts[index];
    final wasLiked = post.isLiked;
    setState(() {
      _posts[index] = post.copyWith(
        isLiked: !wasLiked,
        likesCount: post.likesCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      if (wasLiked) {
        await PostService.instance.unlikePost(post.id);
      } else {
        await PostService.instance.likePost(post.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts[index] = post.copyWith(
          isLiked: wasLiked,
          likesCount: post.likesCount,
        );
      });
    }
  }

  // 🔔 Load unread follow notification count from backend
  Future<void> _loadUnreadNotifCount() async {
    // We count unread items from the already-loaded API response, but since
    // we don't want a full fetch here we rely on real-time updates + island open.
    // When the island opens, NotificationsScreen fetches and resets state.
    // This method is a no-op placeholder kept for future REST polling.
  }

  // ── FIX: Listen for new notifications in real-time so the island badge updates ──
  // Two channels:
  //  1. Firebase foreground message (type=follow) → increment badge
  //  2. WebSocket notification event               → increment badge
  void _listenForNewNotifications() {
    // Channel 1: FCM foreground
    _fcmNotifSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final msgType = msg.data['type'] as String?;
      if (msgType == 'follow') {
        if (mounted && !_islandOpen) {
          // Island is closed — user hasn't seen this yet → bump badge
          setState(() => _unreadNotifs++);
        }
      }
    });

    // Channel 2: WebSocket notification stream
    _wsNotifSub = ChatService().notificationStream.listen((data) {
      final type = data['type'] as String?;
      if (type == 'follow' || type == 'notification') {
        if (mounted && !_islandOpen) {
          setState(() => _unreadNotifs++);
        }
      }
    });
  }

  // 🔴 Load unread conversation count
  Future<void> _loadUnreadCount() async {
    try {
      final myUserId = await AuthService.getCurrentUserId();
      final convs = await ChatService().getConversations();
      if (!mounted) return;
      int unreadConversations = 0;
      for (final c in convs) {
        if ((c.unreadCounts[myUserId] ?? 0) > 0) {
          unreadConversations++;
        }
      }
      setState(() => _totalUnread = unreadConversations);
    } catch (_) {}
  }

  void _toggleNav() {
    HapticFeedback.mediumImpact();
    setState(() => _navOpen = !_navOpen);
    _navOpen ? _navCtrl.forward(from: 0) : _navCtrl.reverse();
  }

  void _openCreatePost(BuildContext context, bool isDark) async {
    HapticFeedback.selectionClick();
    if (_navOpen) {
      setState(() => _navOpen = false);
      _navCtrl.reverse();
    }
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => CreatePostHubScreen(dark: isDark),
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
    _loadFeed(refresh: true);
  }

  void _openScreen(BuildContext context, Widget screen) {
    HapticFeedback.selectionClick();
    if (_navOpen) {
      setState(() => _navOpen = false);
      _navCtrl.reverse();
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
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
  }

  Future<void> _openQuickReel(bool isDark) async {
    if (_quickReelOpening) return;
    _quickReelOpening = true;
    HapticFeedback.mediumImpact();
    if (_navOpen) {
      setState(() => _navOpen = false);
      _navCtrl.reverse();
    }
    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => ShotsScreen(dark: isDark),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        ),
      );
    } finally {
      _quickReelOpening = false;
    }
  }

  void _openChatScreen() async {
    HapticFeedback.selectionClick();
    if (_navOpen) {
      setState(() => _navOpen = false);
      _navCtrl.reverse();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ChatListScreen(dark: isDark),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
            reverseCurve: Curves.easeInQuart,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0), // native feel slide from right side
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
    _loadUnreadCount();
  }

  void _openIsland() {
    _captureIslandRect();
    HapticFeedback.mediumImpact();
    // Reset badge when user opens notification screen
    setState(() {
      _islandOpen = true;
      _unreadNotifs = 0;  // ← user is now viewing notifications
    });
    _islandCtrl.forward(from: 0);
  }

  void _closeIsland() {
    HapticFeedback.lightImpact();
    _islandCtrl.reverse().then((_) {
      if (mounted) setState(() => _islandOpen = false);
    });
  }

  void _captureIslandRect() {
    final ro = _islandKey.currentContext?.findRenderObject() as RenderBox?;
    if (ro == null) return;
    final pos  = ro.localToGlobal(Offset.zero);
    _islandRect = pos & ro.size;
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final topPad   = MediaQuery.of(context).padding.top;

    SystemChrome.setSystemUIOverlayStyle(isDark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _swipeStartX = e.position.dx;
          _swipeStartY = e.position.dy;
        },
        onPointerUp: (e) {
          if (_swipeStartX == null) return;
          final dx = e.position.dx - _swipeStartX!;
          final dy = (e.position.dy - (_swipeStartY ?? 0)).abs();
          if (dx > 60 && dy < dx * 0.65) _openChatScreen();
          _swipeStartX = null;
          _swipeStartY = null;
        },
        onPointerCancel: (_) {
          _swipeStartX = null;
          _swipeStartY = null;
        },
        child: Stack(children: [

        Positioned.fill(child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter, radius: 1.5,
              colors: isDark
                  ? [const Color(0xFF1C1C1F), const Color(0xFF050506)]
                  : [const Color(0xFFF8F8FA), const Color(0xFFE2E2E8)],
            ),
          ),
        )),
        _Orb(color: (isDark ? Colors.white : Colors.black).op(0.05),
            size: 300, top: 100, left: -50),
        _Orb(color: (isDark ? Colors.white : Colors.black).op(0.03),
            size: 250, bottom: 150, right: -30),
        Positioned.fill(child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
              color: (isDark ? Colors.black : Colors.white).op(0.1)),
        )),

        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: () => _loadFeed(refresh: true),
            color: isDark ? Colors.white : Colors.black,
            backgroundColor: isDark ? const Color(0xFF1C1C1F) : Colors.white,
            child: ListView.builder(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.only(top: topPad + 56),
              itemCount: _posts.isEmpty
                  ? 2
                  : _posts.length + 2,
              itemBuilder: (ctx, i) {
                if (i == 0) return _StorySection(isDark: isDark);
                if (i == 1 && _posts.isEmpty) {
                  if (_loadingFeed) {
                    return SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black,
                        strokeWidth: 1.5,
                      )),
                    );
                  }
                  if (_feedError) {
                    return SizedBox(
                      height: 200,
                      child: Center(child: GestureDetector(
                        onTap: () => _loadFeed(refresh: true),
                        child: Text('Tap to retry',
                          style: TextStyle(
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.45),
                            fontSize: 14,
                          )),
                      )),
                    );
                  }
                  return SizedBox(
                    height: 200,
                    child: Center(child: Text('No posts yet',
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.38),
                        fontSize: 14,
                      ))),
                  );
                }
                final postIdx = i - 1;
                if (postIdx == _posts.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 130, top: 16),
                    child: _loadingFeed
                        ? Center(child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.35),
                              strokeWidth: 1.5,
                            )))
                        : const SizedBox.shrink(),
                  );
                }
                final post = _posts[postIdx];
                return _PostCard(
                  key: ValueKey(post.id),
                  post: post,
                  isDark: isDark,
                  onLike: () => _toggleLike(postIdx),
                );
              },
            ),
          ),
        ),

        SafeArea(child: Stack(children: [

          // ── Island pill — now with unread notification badge ──
          Align(alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: _islandOpen ? null : _openIsland,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _TrandiaIsland(key: _islandKey, isDark: isDark),
                    // ── NEW: Unread notification dot on island ──
                    if (_unreadNotifs > 0)
                      Positioned(
                        top: -4, right: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : const Color(0xFF0A0A0A),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF8F8FA),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _unreadNotifs > 9 ? '9+' : '$_unreadNotifs',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ))),

          // Message icon
          Align(alignment: Alignment.topRight,
            child: Padding(padding: const EdgeInsets.only(top: 10, right: 14),
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  if (_navOpen) { setState(() => _navOpen = false); _navCtrl.reverse(); }
                  await Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, animation, __) => ChatListScreen(dark: isDark),
                      transitionDuration: const Duration(milliseconds: 260),
                      reverseTransitionDuration: const Duration(milliseconds: 220),
                      transitionsBuilder: (_, animation, __, child) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutQuart,
                          reverseCurve: Curves.easeInQuart,
                        );
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(curved),
                          child: FadeTransition(opacity: curved, child: child),
                        );
                      },
                    ),
                  );
                  _loadUnreadCount();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(width: 30, height: 30,
                      child: Center(child: CustomPaint(
                        size: const Size(_kIconSize, _kIconSize),
                        painter: _EnvelopeIconPainter(isDark: isDark)))),
                    if (_totalUnread > 0)
                      Positioned(
                        right: -5, top: -5,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1C1C1F)
                                  : const Color(0xFFF8F8FA),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _totalUnread > 9 ? '9+' : '$_totalUnread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ))),

          // Navbar
          Positioned(
            bottom: 30 + _kBtnSize + _kNavGap, right: 20,
            child: AnimatedBuilder(animation: _navCtrl,
              builder: (_, __) => IgnorePointer(ignoring: !_navOpen,
                child: _StaggeredNavbar(
                  isDark: isDark, activeIndex: _activeNav,
                  itemScales: _itemScales, itemOpacities: _itemOpacities,
                  onTap: (i) {
                    setState(() => _activeNav = i);
                    if (i == 1) _openScreen(context, ShotsScreen(dark: isDark));
                    if (i == 2) _openCreatePost(context, isDark);
                    if (i == 3) _openScreen(context, SearchScreen(dark: isDark));
                    if (i == 4) _openScreen(context, ProfileScreen(dark: isDark));
                  })))),

          // Infinity button
          Positioned(bottom: 30, right: 20,
            child: _InfinityBtn(
              isDark: isDark,
              isOpen: _navOpen,
              onTap: _toggleNav,
              onDoubleTap: () => _openQuickReel(isDark),
            )),
        ])),

        // ── Dynamic Island expand overlay ──────────────────
        if (_islandOpen)
          _IslandNotificationOverlay(
            islandRect : _islandRect,
            controller : _islandCtrl,
            isDark     : isDark,
            onClose    : _closeIsland,
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
//  STORY SECTION
// ═════════════════════════════════════════════════════
class _StorySection extends StatelessWidget {
  final bool isDark;
  const _StorySection({required this.isDark});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 110,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      physics: const BouncingScrollPhysics(),
      itemCount: _kStories.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: _StoryBubble(story: _kStories[i], isDark: isDark)),
    ),
  );
}

class _StoryBubble extends StatelessWidget {
  final _StoryData story;
  final bool       isDark;
  const _StoryBubble({required this.story, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: SizedBox(width: 70,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 70, height: 70,
            child: CustomPaint(
              painter: _StoryRingPainter(
                  isDark: isDark, seen: story.seen, isOwn: story.isOwn),
              child: Padding(padding: const EdgeInsets.all(4.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: story.avatarColor,
                    border: Border.all(
                      color: isDark ? Colors.black.op(0.60)
                                    : Colors.white.op(0.70),
                      width: 2)),
                  child: Center(child: story.isOwn
                      ? CustomPaint(size: const Size(18, 18),
                          painter: _PlusPainter(
                              color: isDark ? Colors.white
                                           : const Color(0xFF1A1A1A)))
                      : Text(story.initials, style: const TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w600))),
                )))),
          const SizedBox(height: 6),
          Text(story.name.tr(context), maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black)
                  .op(story.seen ? 0.38 : 0.80),
              fontSize: 10.5, fontWeight: FontWeight.w500)),
        ])),
    );
  }
}

class _StoryRingPainter extends CustomPainter {
  final bool isDark, seen, isOwn;
  const _StoryRingPainter(
      {required this.isDark, this.seen = false, this.isOwn = false});
  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = size.width  / 2 - 1.5;
    if (isOwn) { _drawDashed(canvas, Offset(cx, cy), radius); return; }
    if (seen) {
      canvas.drawCircle(Offset(cx, cy), radius, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 1.8
        ..color = (isDark ? Colors.white : Colors.black).op(0.20));
      return;
    }
    canvas.drawCircle(Offset(cx, cy), radius, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.sweep(Offset(cx, cy),
        isDark
            ? const [Color(0xFFFFFFFF), Color(0xFFAAAAAA), Color(0xFF666666)]
            : const [Color(0xFF1A1A1A), Color(0xFF555555), Color(0xFF999999)],
        const [0.0, 0.5, 1.0], TileMode.clamp,
        -math.pi / 2, -math.pi / 2 + math.pi * 2));
  }
  void _drawDashed(Canvas canvas, Offset center, double radius) {
    const int n = 20;
    const double step = (2 * math.pi) / n;
    final Paint p = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = (isDark ? Colors.white : Colors.black).op(0.45);
    for (int i = 0; i < n; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          i * step - math.pi / 2, step * 0.70, false, p);
    }
  }
  @override
  bool shouldRepaint(_StoryRingPainter o) =>
      o.isDark != isDark || o.seen != seen || o.isOwn != isOwn;
}

// ═════════════════════════════════════════════════════
//  POST CARD
// ═════════════════════════════════════════════════════
class _PostCard extends StatefulWidget {
  final PostModel   post;
  final bool        isDark;
  final VoidCallback onLike;
  const _PostCard({
    super.key,
    required this.post,
    required this.isDark,
    required this.onLike,
  });
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;

  Color _avatarColor(String userId) {
    final colors = [
      const Color(0xFF2D3561), const Color(0xFF1B4332),
      const Color(0xFF3D0C11), const Color(0xFF2C2C54),
      const Color(0xFF1A1A2E), const Color(0xFF0D3349),
    ];
    return colors[userId.hashCode.abs() % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _openUserProfile() {
    final p = widget.post;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => user_profile.ProfileScreen(
        displayName: p.userName,
        handle: p.userUsername,
        initialFollowing: false,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p    = widget.post;
    final dark = widget.isDark;
    final Color border      = (dark ? Colors.white : Colors.black).op(0.12);
    final Color textPrimary = (dark ? Colors.white : Colors.black).op(0.90);
    final Color textSub     = (dark ? Colors.white : Colors.black).op(0.45);
    final Color iconCol     = (dark ? Colors.white : Colors.black).op(0.80);
    final Color likedCol    = dark ? const Color(0xFFFF3040) : const Color(0xFFED4956);
    final avatarBg          = _avatarColor(p.userId);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Row(children: [
            GestureDetector(
              onTap: _openUserProfile,
              behavior: HitTestBehavior.opaque,
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarBg,
                    border: Border.all(color: border, width: 0.8)),
                  child: ClipOval(child: p.userPicture != null
                    ? CachedNetworkImage(
                        imageUrl: p.userPicture!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(
                          child: Text(_initials(p.userName),
                            style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w600))),
                        errorWidget: (_, __, ___) => Center(
                          child: Text(_initials(p.userName),
                            style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w600))),
                      )
                    : Center(child: Text(_initials(p.userName),
                        style: const TextStyle(color: Colors.white,
                          fontSize: 10, fontWeight: FontWeight.w600)))),
                ),
                const SizedBox(width: 8),
                Text(p.userName, style: TextStyle(
                  color: textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            Text(p.timeAgo, style: TextStyle(color: textSub, fontSize: 11)),
          ])),

        // ── Media ────────────────────────────────────
        p.isVideo
            ? _VideoCard(post: p, isDark: dark)
            : AspectRatio(aspectRatio: p.aspectRatio,
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(
                    imageUrl: p.mediaUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: (dark ? Colors.white : Colors.black).withOpacity(0.05)),
                    errorWidget: (_, __, ___) => Container(
                      color: (dark ? Colors.white : Colors.black).withOpacity(0.05),
                      child: Icon(Icons.broken_image_outlined,
                        color: (dark ? Colors.white : Colors.black).withOpacity(0.25))),
                  ),
                  Container(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.op(0.18)]))),
                ])),

        // ── Actions ──────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Row(children: [

            _LikeButton(
              isLiked: p.isLiked,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onLike();
              },
              onLongPress: () {
                HapticFeedback.heavyImpact();
                Navigator.of(context).push(PageRouteBuilder(
                  pageBuilder: (_, animation, __) => LikedByScreen(
                    dark: dark,
                    postUser: p.userName,
                    likeCount: p.likesCount,
                  ),
                  transitionDuration: const Duration(milliseconds: 380),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder: (_, animation, __, child) {
                    final curved = CurvedAnimation(parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic);
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06), end: Offset.zero,
                      ).animate(curved),
                      child: FadeTransition(opacity: curved, child: child));
                  },
                ));
              },
              likedColor: likedCol,
              iconColor: iconCol,
            ),

            const SizedBox(width: 16),

            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(PageRouteBuilder(
                  pageBuilder: (_, animation, __) => CommentsScreen(
                    dark: dark,
                    postUser: p.userName,
                    postDescription: p.caption,
                    postInitials: _initials(p.userName),
                    postUserColor: avatarBg,
                  ),
                  transitionDuration: const Duration(milliseconds: 380),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder: (_, animation, __, child) {
                    final curved = CurvedAnimation(parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic);
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06), end: Offset.zero,
                      ).animate(curved),
                      child: FadeTransition(opacity: curved, child: child));
                  },
                ));
              },
              child: SizedBox(width: 26, height: 26,
                child: CustomPaint(painter: _CommentBubblePainter(color: iconCol)))),

            const SizedBox(width: 16),

            GestureDetector(
              onTap: () => HapticFeedback.lightImpact(),
              child: SizedBox(width: 26, height: 26,
                child: Icon(Icons.near_me_rounded, size: 26, color: iconCol))),

            const Spacer(),

            GestureDetector(
              onTap: () => HapticFeedback.lightImpact(),
              child: SizedBox(width: 26, height: 26,
                child: CustomPaint(painter: _SaveCirclePainter(color: iconCol)))),
          ])),

        // ── Likes count ──────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Text('${p.likesCount} ${'likes'.tr(context)}',
            style: TextStyle(color: textPrimary, fontSize: 13,
              fontWeight: FontWeight.w600))),

        // ── Caption ──────────────────────────────────
        if (p.caption.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: GestureDetector(
              onTap: () {
                setState(() => _expanded = !_expanded);
                HapticFeedback.selectionClick();
              },
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Text.rich(TextSpan(children: [
                        TextSpan(text: '${p.userName} ', style: TextStyle(
                          color: textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                        TextSpan(text: p.caption, style: TextStyle(
                          color: textPrimary.op(0.85), fontSize: 13, height: 1.45)),
                      ]))
                    : Text.rich(TextSpan(children: [
                        TextSpan(text: '${p.userName} ', style: TextStyle(
                          color: textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                        TextSpan(text: p.caption, style: TextStyle(
                          color: textPrimary.op(0.85), fontSize: 13, height: 1.45)),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              ))),

        if (p.caption.isEmpty) const SizedBox(height: 10),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════
//  VIDEO CARD  —  inline autoplay, battery + data safe
// ═════════════════════════════════════════════════════
class _VideoCard extends StatefulWidget {
  final PostModel post;
  final bool      isDark;
  const _VideoCard({required this.post, required this.isDark});
  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _ctrl;
  bool _initialized    = false;
  bool _muted          = false;   // volume HIGH by default (unmuted)
  bool _manualPause    = false;   // user double-tapped to pause
  bool _dataSaver      = false;   // on mobile data → no autoplay
  bool _showOverlay    = false;   // brief play/pause icon flash

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (mounted) {
        // Any mobile data type → data-saver on; WiFi / ethernet → off
        final onMobile = result.contains(ConnectivityResult.mobile);
        setState(() => _dataSaver = onMobile);
      }
    } catch (_) {}
  }

  Future<void> _initAndPlay() async {
    if (_ctrl != null) return;
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.mediaUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
    } catch (_) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) { ctrl.dispose(); _ctrl = null; return; }
    ctrl.setLooping(true);
    ctrl.setVolume(_muted ? 0.0 : 1.0);
    setState(() => _initialized = true);
    if (!_manualPause) ctrl.play();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.65;
    if (visible) {
      if (!_initialized && !_dataSaver) {
        _initAndPlay();
      } else if (_initialized && !_manualPause) {
        _ctrl?.play();
      }
    } else {
      if (_initialized) {
        _ctrl?.pause();
        // Clear manual-pause state so next scroll-in auto-plays
        if (_manualPause) _manualPause = false;
      }
    }
  }

  void _onDoubleTap() {
    HapticFeedback.lightImpact();
    if (!_initialized) {
      _dataSaver = false;
      _initAndPlay();
      return;
    }
    final playing = _ctrl?.value.isPlaying ?? false;
    if (playing) {
      _ctrl?.pause();
      _manualPause = true;
    } else {
      _ctrl?.play();
      _manualPause = false;
    }
    setState(() => _showOverlay = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _onTapManualPlay() {
    _dataSaver = false;
    _manualPause = false;
    if (!_initialized) {
      _initAndPlay();
    } else {
      _ctrl?.play();
      setState(() {});
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _ctrl?.setVolume(_muted ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = widget.post.thumbnailUrl ?? widget.post.mediaUrl;
    final isPlaying    = _ctrl?.value.isPlaying ?? false;

    return VisibilityDetector(
      key: Key('vid_${widget.post.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: widget.post.aspectRatio,
        child: GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: Stack(fit: StackFit.expand, children: [

            // ── Thumbnail (always shown until video ready) ──
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.black12),
              errorWidget: (_, __, ___) => Container(
                color: Colors.black12,
                child: const Icon(Icons.broken_image_outlined,
                    color: Colors.white30)),
            ),

            // ── Video frame (on top once initialized) ──────
            if (_initialized && _ctrl != null)
              VideoPlayer(_ctrl!),

            // ── Bottom gradient ────────────────────────────
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
                )),
            ))),

            // ── Data-saver: big manual play button ─────────
            if (_dataSaver && !_initialized)
              Center(child: GestureDetector(
                onTap: _onTapManualPlay,
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.55),
                    border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5)),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 30)),
              )),

            // ── Loading spinner (WiFi, waiting for init) ───
            if (!_dataSaver && !_initialized)
              const Center(child: SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2))),

            // ── Double-tap play/pause flash overlay ────────
            if (_showOverlay)
              Center(child: AnimatedOpacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.55)),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 34),
                ),
              )),

            // ── Mute / unmute button (bottom-right) ────────
            if (_initialized)
              Positioned(bottom: 10, right: 10,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.50)),
                    child: Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white, size: 16)),
                )),

            // ── Progress bar (bottom edge) ─────────────────
            if (_initialized && _ctrl != null)
              Positioned(bottom: 0, left: 0, right: 0,
                child: VideoProgressIndicator(
                  _ctrl!,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withOpacity(0.30),
                    backgroundColor: Colors.transparent,
                  ),
                )),
          ]),
        ),
      ),
    );
  }
}

// ─── Bouncy Like Button ──────────────────────────────
class _LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color likedColor;
  final Color iconColor;

  const _LikeButton({
    required this.isLiked,
    required this.onTap,
    this.onLongPress,
    required this.likedColor,
    required this.iconColor,
  });

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap();
        _controller.forward(from: 0.0);
      },
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 26,
          height: 26,
          child: CustomPaint(
            painter: _IgHeartPainter(
              color: widget.isLiked ? widget.likedColor : widget.iconColor,
              filled: widget.isLiked,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Instagram Heart ──────────────────────────────────
class _IgHeartPainter extends CustomPainter {
  final Color color;
  final bool  filled;
  const _IgHeartPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double sx = w / 26.0;
    final double sy = h / 26.0;

    final path = Path()
      ..moveTo(13.0 * sx, 23.0 * sy)
      ..cubicTo(
         6.0 * sx, 19.0 * sy,
         1.0 * sx, 14.0 * sy,
         1.0 * sx, 9.5  * sy)
      ..cubicTo(
         1.0 * sx,  5.0 * sy,
         4.5 * sx,  2.5 * sy,
         7.5 * sx,  2.5 * sy)
      ..cubicTo(
        10.0 * sx,  2.5 * sy,
        12.0 * sx,  4.0 * sy,
        13.0 * sx,  6.0 * sy)
      ..cubicTo(
        14.0 * sx,  4.0 * sy,
        16.0 * sx,  2.5 * sy,
        18.5 * sx,  2.5 * sy)
      ..cubicTo(
        21.5 * sx,  2.5 * sy,
        25.0 * sx,  5.0 * sy,
        25.0 * sx,  9.5 * sy)
      ..cubicTo(
        25.0 * sx, 14.0 * sy,
        20.0 * sx, 19.0 * sy,
        13.0 * sx, 23.0 * sy)
      ..close();

    if (filled) {
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    } else {
      canvas.drawPath(path, Paint()
        ..color = color..style = PaintingStyle.stroke
        ..strokeWidth = 1.5..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_IgHeartPainter o) =>
      o.color != color || o.filled != filled;
}

class _CommentBubblePainter extends CustomPainter {
  final Color color;
  const _CommentBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 26.0;
    final sy = size.height / 26.0;
    final bounds = Offset.zero & size;
    final bubble = Path()
      ..moveTo(8.0 * sx, 4.0 * sy)
      ..lineTo(18.0 * sx, 4.0 * sy)
      ..cubicTo(22.0 * sx, 4.0 * sy, 24.0 * sx, 7.0 * sy, 24.0 * sx, 11.0 * sy)
      ..lineTo(24.0 * sx, 15.0 * sy)
      ..cubicTo(24.0 * sx, 19.0 * sy, 21.0 * sx, 21.0 * sy, 17.0 * sx, 21.0 * sy)
      ..lineTo(15.0 * sx, 21.0 * sy)
      ..cubicTo(12.5 * sx, 21.0 * sy, 10.6 * sx, 22.0 * sy, 8.0 * sx, 24.0 * sy)
      ..cubicTo(7.4 * sx, 24.5 * sy, 6.6 * sx, 24.0 * sy, 6.6 * sx, 23.2 * sy)
      ..lineTo(6.6 * sx, 20.8 * sy)
      ..cubicTo(3.6 * sx, 19.9 * sy, 2.0 * sx, 17.3 * sy, 2.0 * sx, 14.0 * sy)
      ..lineTo(2.0 * sx, 11.0 * sy)
      ..cubicTo(2.0 * sx, 7.0 * sy, 4.0 * sx, 4.0 * sy, 8.0 * sx, 4.0 * sy)
      ..close();

    canvas.saveLayer(bounds, Paint());
    canvas.drawPath(bubble, Paint()..color = color);
    final clear = Paint()..blendMode = BlendMode.clear;
    for (final cx in [9.5, 13.0, 16.5]) {
      canvas.drawCircle(Offset(cx * sx, 13.0 * sy), 1.6 * sx, clear);
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
    final sx = size.width / 26.0;
    final sy = size.height / 26.0;

    final bookmark = Path()
      ..moveTo(5.0 * sx, 22.5 * sy)
      ..lineTo(5.0 * sx, 6.8 * sy)
      ..cubicTo(5.0 * sx, 4.0 * sy, 7.0 * sx, 2.7 * sy, 9.4 * sx, 2.7 * sy)
      ..lineTo(16.6 * sx, 2.7 * sy)
      ..cubicTo(19.0 * sx, 2.7 * sy, 21.0 * sx, 4.0 * sy, 21.0 * sx, 6.8 * sy)
      ..lineTo(21.0 * sx, 22.5 * sy)
      ..lineTo(13.0 * sx, 15.6 * sy)
      ..close();

    canvas.drawPath(
      bookmark,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SaveCirclePainter o) => o.color != color;
}

// ═════════════════════════════════════════════════════
//  STAGGERED NAVBAR
// ═════════════════════════════════════════════════════
class _StaggeredNavbar extends StatelessWidget {
  final bool isDark;
  final int  activeIndex;
  final List<Animation<double>> itemScales, itemOpacities;
  final ValueChanged<int> onTap;
  const _StaggeredNavbar({
    required this.isDark, required this.activeIndex,
    required this.itemScales, required this.itemOpacities,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final double navH   = 5 * _kItemH + 24.0;
    final Color  glass  = (isDark ? Colors.white : Colors.black).op(0.09);
    final Color  border = (isDark ? Colors.white : Colors.black).op(0.16);
    return FadeTransition(
      opacity: itemOpacities.last,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kNavWidth / 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            width: _kNavWidth, height: navH,
            decoration: BoxDecoration(
              color: glass,
              borderRadius: BorderRadius.circular(_kNavWidth / 2),
              border: Border.all(color: border, width: 0.8),
              boxShadow: [BoxShadow(
                  color: Colors.black.op(isDark ? 0.35 : 0.10),
                  blurRadius: 20, offset: const Offset(0, 6))]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final bool active = activeIndex == i;
                  return ScaleTransition(scale: itemScales[i],
                    child: FadeTransition(opacity: itemOpacities[i],
                      child: GestureDetector(
                        onTap: () { HapticFeedback.selectionClick(); onTap(i); },
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(width: _kNavWidth, height: _kItemH,
                          child: Center(child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? (isDark ? Colors.white.op(0.18)
                                            : Colors.black.op(0.12))
                                  : Colors.transparent),
                            child: Center(child: CustomPaint(
                              size: const Size(24.0, 24.0),
                              painter: _NavIconPainter(
                                  index: i, isDark: isDark,
                                  active: active)))))))));
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
//  ENVELOPE ICON
// ═════════════════════════════════════════════════════
class _EnvelopeIconPainter extends CustomPainter {
  final bool isDark;
  const _EnvelopeIconPainter({required this.isDark});
  @override
  void paint(Canvas canvas, Size size) {
    final Color  color = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final double w = size.width;
    final double h = size.height;
    final Paint  p = Paint()
      ..color = color.op(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bubble = Path()
      ..moveTo(w * 0.28, h * 0.08)
      ..lineTo(w * 0.72, h * 0.08)
      ..quadraticBezierTo(w * 0.92, h * 0.08, w * 0.92, h * 0.28)
      ..lineTo(w * 0.92, h * 0.62)
      ..quadraticBezierTo(w * 0.92, h * 0.82, w * 0.72, h * 0.82)
      ..lineTo(w * 0.38, h * 0.82)
      // Tail
      ..quadraticBezierTo(w * 0.34, h * 0.90, w * 0.28, h * 0.94)
      ..quadraticBezierTo(w * 0.24, h * 0.96, w * 0.22, h * 0.92)
      ..quadraticBezierTo(w * 0.18, h * 0.85, w * 0.08, h * 0.72)
      ..lineTo(w * 0.08, h * 0.28)
      ..quadraticBezierTo(w * 0.08, h * 0.08, w * 0.28, h * 0.08)
      ..close();

    canvas.drawPath(bubble, p);

    // Inner horizontal lines
    // Line 1: top
    canvas.drawLine(
      Offset(w * 0.32, h * 0.36),
      Offset(w * 0.68, h * 0.36),
      p,
    );
    // Line 2: bottom
    canvas.drawLine(
      Offset(w * 0.32, h * 0.54),
      Offset(w * 0.68, h * 0.54),
      p,
    );
  }
  @override
  bool shouldRepaint(_EnvelopeIconPainter o) => o.isDark != isDark;
}

// ═════════════════════════════════════════════════════
//  NAV ICON PAINTERS
// ═════════════════════════════════════════════════════
class _NavIconPainter extends CustomPainter {
  final int  index;
  final bool isDark, active;
  const _NavIconPainter(
      {required this.index, required this.isDark, required this.active});
  @override
  void paint(Canvas canvas, Size size) {
    final Color  base   = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final Color  col    = active ? base : base.op(0.50);
    final double sw     = active ? 1.6 : 1.4;
    final Paint  stroke = Paint()..color = col..style = PaintingStyle.stroke
        ..strokeWidth = sw..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    final double w = size.width; final double h = size.height;
    final double cx = w / 2;    final double cy = h / 2;
    switch (index) {
      case 0:
        final home = Path()
          ..moveTo(cx, h * 0.10)
          ..lineTo(w * 0.90, h * 0.45)
          ..lineTo(w * 0.90, h * 0.82)
          ..cubicTo(w * 0.90, h * 0.90, w * 0.85, h * 0.92, w * 0.78, h * 0.92)
          ..lineTo(w * 0.22, h * 0.92)
          ..cubicTo(w * 0.15, h * 0.92, w * 0.10, h * 0.90, w * 0.10, h * 0.82)
          ..lineTo(w * 0.10, h * 0.45)
          ..close();
        canvas.drawPath(home, stroke);
        final door = Path()
          ..moveTo(cx - w * 0.10, h * 0.92)
          ..lineTo(cx - w * 0.10, h * 0.68)
          ..cubicTo(cx - w * 0.10, h * 0.56, cx + w * 0.10, h * 0.56, cx + w * 0.10, h * 0.68)
          ..lineTo(cx + w * 0.10, h * 0.92);
        canvas.drawPath(door, stroke);
        break;
      case 1:
        final double r = w * 0.42;
        canvas.drawCircle(Offset(cx, cy), r, stroke);
        final needle = Path()
          ..moveTo(cx, cy - r * 0.50)
          ..lineTo(cx + r * 0.20, cy)
          ..lineTo(cx, cy + r * 0.50)
          ..lineTo(cx - r * 0.20, cy)
          ..close();
        canvas.drawPath(
          needle,
          Paint()
            ..color = col
            ..style = PaintingStyle.fill,
        );
        break;
      case 2:
        final double inset = w * 0.12;
        final rr = RRect.fromRectAndRadius(
            Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2),
            Radius.circular(w * 0.25));
        canvas.drawRRect(rr, stroke);
        final double arm = w * 0.16;
        canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), stroke);
        canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), stroke);
        break;
      case 3:
        final double r  = w * 0.30;
        final double ox = cx - w * 0.06;
        final double oy = cy - h * 0.06;
        canvas.drawCircle(Offset(ox, oy), r, stroke);
        final double hx = ox + r * 0.70;
        final double hy = oy + r * 0.70;
        canvas.drawLine(
          Offset(hx, hy),
          Offset(w * 0.88, h * 0.88),
          Paint()..color = col..style = PaintingStyle.stroke
              ..strokeWidth = sw + 0.3..strokeCap = StrokeCap.round);
        break;
      case 4:
        final double headR = w * 0.16;
        canvas.drawCircle(Offset(cx, h * 0.30), headR, stroke);
        final body = Path()
          ..moveTo(w * 0.14, h * 0.92)
          ..cubicTo(w * 0.14, h * 0.60, w * 0.30, h * 0.52, cx, h * 0.52)
          ..cubicTo(w * 0.70, h * 0.52, w * 0.86, h * 0.60, w * 0.86, h * 0.92);
        canvas.drawPath(body, stroke);
        break;
    }
  }
  @override
  bool shouldRepaint(_NavIconPainter o) =>
      o.index != index || o.isDark != isDark || o.active != active;
}

// ═════════════════════════════════════════════════════
//  INFINITY BUTTON
// ═════════════════════════════════════════════════════
class _InfinityBtn extends StatefulWidget {
  final bool isDark, isOpen;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  const _InfinityBtn({
    required this.isDark,
    required this.isOpen,
    required this.onTap,
    required this.onDoubleTap,
  });
  @override
  State<_InfinityBtn> createState() => _InfinityBtnState();
}
class _InfinityBtnState extends State<_InfinityBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final Color glass  = (widget.isDark ? Colors.white : Colors.black).op(0.09);
    final Color border = (widget.isDark ? Colors.white : Colors.black).op(0.18);
    return AnimatedBuilder(animation: _ctrl,
      builder: (_, __) => Transform.scale(scale: _scale.value,
        child: GestureDetector(
          onTapDown:   (_) => _ctrl.forward(),
          onTapUp:     (_) => _ctrl.reverse(),
          onTapCancel: () => _ctrl.reverse(),
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          child: ClipOval(child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(width: _kBtnSize, height: _kBtnSize,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: glass,
                boxShadow: [BoxShadow(color: Colors.black.op(0.22),
                    blurRadius: 12, offset: const Offset(0, 4))]),
              child: ClipOval(
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              )))))));
  }
}

// ═════════════════════════════════════════════════════
//  PLUS PAINTER
// ═════════════════════════════════════════════════════
class _PlusPainter extends CustomPainter {
  final Color color;
  const _PlusPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color.op(0.85)..style = PaintingStyle.stroke
        ..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    final double cx = size.width / 2; final double cy = size.height / 2;
    canvas.drawLine(Offset(cx, cy - 5.5), Offset(cx, cy + 5.5), p);
    canvas.drawLine(Offset(cx - 5.5, cy), Offset(cx + 5.5, cy), p);
  }
  @override bool shouldRepaint(_PlusPainter o) => o.color != color;
}

// ═════════════════════════════════════════════════════
//  ORB
// ═════════════════════════════════════════════════════
class _Orb extends StatelessWidget {
  final Color color; final double size;
  final double? top, bottom, left, right;
  const _Orb({required this.color, required this.size,
      this.top, this.bottom, this.left, this.right});
  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Container(width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.op(0.0)]))));
}

// ═════════════════════════════════════════════════════
//  TRANDIA ISLAND
// ═════════════════════════════════════════════════════
class _TrandiaIsland extends StatelessWidget {
  final bool isDark;
  const _TrandiaIsland({super.key, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final Color glass  = (isDark ? Colors.white : Colors.black).op(0.10);
    final Color border = (isDark ? Colors.white : Colors.black).op(0.18);
    final Color text   = isDark ? Colors.white : const Color(0xFF0A0A0A);
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          width: 126, height: 37,
          decoration: BoxDecoration(
            color: glass,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: border, width: 0.8)),
          child: Center(
            child: Text('Trandia',
              style: TextStyle(
                color: text,
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                decoration: TextDecoration.none,
              )),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
//  DYNAMIC ISLAND → NOTIFICATION SCREEN OVERLAY
// ═════════════════════════════════════════════════════
class _IslandNotificationOverlay extends StatefulWidget {
  final Rect               islandRect;
  final AnimationController controller;
  final bool               isDark;
  final VoidCallback        onClose;
  const _IslandNotificationOverlay({
    required this.islandRect,
    required this.controller,
    required this.isDark,
    required this.onClose,
  });
  @override
  State<_IslandNotificationOverlay> createState() =>
      _IslandNotificationOverlayState();
}

class _IslandNotificationOverlayState
    extends State<_IslandNotificationOverlay> {

  double _dragY    = 0;
  bool   _dragging = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenRect = Rect.fromLTWH(
        0, 0, screenSize.width, screenSize.height);

    const dismissThreshold = 80.0;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final topPad = MediaQuery.paddingOf(context).top;
        final t = widget.controller.value;

        final double left   = ui.lerpDouble(
            widget.islandRect.left,   screenRect.left,   _expandCurve(t))!;
        final double top    = ui.lerpDouble(
            widget.islandRect.top,    screenRect.top,    _expandCurve(t))!
            + (_dragging ? _dragY.clamp(0, dismissThreshold * 1.4) : 0);
        final double right  = ui.lerpDouble(
            widget.islandRect.right,  screenRect.right,  _expandCurve(t))!;
        final double bottom = ui.lerpDouble(
            widget.islandRect.bottom, screenRect.bottom, _expandCurve(t))!;
        final double borderR = ui.lerpDouble(19, 0, _expandCurve(t))!;

        final double contentAlpha =
            ((t - 0.35) / 0.65).clamp(0.0, 1.0);

        final double dragAlpha = _dragging
            ? (1.0 - (_dragY / (dismissThreshold * 2.0)).clamp(0.0, 0.5))
            : 1.0;

        return Positioned(
          left  : left,
          top   : top,
          width : right - left,
          height: bottom - top,
          child : Opacity(
            opacity: dragAlpha,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderR),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.black.withOpacity(0.92)
                        : Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(borderR),
                  ),
                  child: GestureDetector(
                    onVerticalDragStart: (_) {
                      setState(() { _dragging = true; _dragY = 0; });
                    },
                    onVerticalDragUpdate: (d) {
                      if (d.delta.dy > 0) {
                        setState(() => _dragY += d.delta.dy);
                      }
                    },
                    onVerticalDragEnd: (d) {
                      if (_dragY > dismissThreshold ||
                          (d.velocity.pixelsPerSecond.dy > 600)) {
                        setState(() { _dragging = false; _dragY = 0; });
                        widget.onClose();
                      } else {
                        setState(() { _dragging = false; _dragY = 0; });
                      }
                    },
                    child: Stack(children: [
                      Opacity(
                        opacity: contentAlpha,
                        child: NotificationsScreen(dark: widget.isDark, onClose: widget.onClose),
                      ),

                      if (contentAlpha > 0.1)
                        Positioned(
                          top: topPad + 6, left: 0, right: 0,
                          child: Opacity(
                            opacity: contentAlpha,
                            child: Center(
                              child: Container(
                                width : 36, height: 4,
                                decoration: BoxDecoration(
                                  color: (widget.isDark
                                      ? Colors.white
                                      : Colors.black).withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(2)),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _expandCurve(double t) =>
      Curves.fastEaseInToSlowEaseOut.transform(t);
}
