import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/fcm_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../models/chat_model.dart';
import '../call_screens.dart';
import '../../services/post_service.dart';
import '../../services/api_service.dart';
import '../notifications_screen.dart';
import '../search_screen.dart';
import '../shots_screen.dart';
import '../profile_screen.dart';
import '../user_profile_screen.dart' as user_profile;
import '../chat_list_screen.dart';
import '../create_post_screens.dart';
import '../story_upload_screen.dart';
import '../story_view_screen.dart';
import '../../services/story_service.dart';
import '../../services/block_service.dart';
import '../comments_screen.dart';
import '../liked_by_screen.dart';
import '../../services/cryptography_service.dart';
import '../../utils/share_helper.dart';
import '../../utils/route_observer.dart';

/// Notifier shared between HomeScreen and _VideoCardState (same file).
/// false = home route is covered → all video players must pause.
final ValueNotifier<bool> _homeFeedActive = ValueNotifier(true);

extension _ColorOp on Color {
  Color op(double opacity) => withOpacity(opacity);
}

const double _kBtnSize  = 64.0;
const double _kNavWidth = _kBtnSize;
const double _kItemH    = 54.0;
const double _kNavGap   = 6.0;
const double _kIconSize = 20.0; // message icon — minor size reduction



// ═════════════════════════════════════════════════════
//  HOME SCREEN
// ═════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin
    implements RouteAware {
  bool _navOpen   = false;
  bool _navHorizontal = false;
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
  StreamSubscription? _callSub;
  String? _myUserId;
  bool _incomingCallOpen = false;
  String? _myProfilePic;
  String? _myProfileName;

  // ── Feed state ────────────────────────────────────
  final List<PostModel> _posts       = [];
  String?               _nextCursor;
  bool                  _loadingFeed    = false;
  bool                  _feedError      = false;
  bool                  _quickReelOpening = false;
  bool                  _loadingSuggestions = false;
  final List<UserProfile> _suggestedUsers = [];
  final Set<String>     _watchedLearnPostIds = <String>{};
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 450));
    for (int i = 0; i < 5; i++) {
      final double start = (4 - i) * 0.10;
      final double end   = (start + 0.50).clamp(0.0, 1.0);
      _itemScales.add(Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _navCtrl,
              curve: Interval(start, end, curve: Curves.easeOutBack))));
      _itemOpacities.add(Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _navCtrl,
              curve: Interval(start, (start + 0.25).clamp(0.0, 1.0),
                  curve: Curves.easeOut))));
    }

    _islandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 390),
      reverseDuration: const Duration(milliseconds: 250),
    );

    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 400);
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.setupForHomeScreen();
      CryptographyService().ensurePublicKeyRegistered();
      BlockService.instance.load(); // load block list once on home screen open
      _loadUnreadCount();
      _loadUnreadNotifCount();
      ChatService().connectWebSocket();
      _listenForNewNotifications();
      _loadMyUserId().then((_) {
        if (!mounted) return;
        _listenForIncomingCalls();
        _loadFollowerSuggestions();
        _loadMyProfile();
      });
      _loadFeed();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  // ── RouteAware — pause videos when another screen is pushed on top ──────
  @override
  void didPushNext() => _homeFeedActive.value = false;

  @override
  void didPopNext() => _homeFeedActive.value = true;

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _navCtrl.dispose();
    _islandCtrl.dispose();
    _scrollCtrl.dispose();
    _fcmNotifSub?.cancel();
    _wsNotifSub?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  // ── Incoming call listener ─────────────────────────
  Future<void> _loadMyUserId() async {
    _myUserId = await AuthService.getCurrentUserId();
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await UserService.getMyProfile();
      if (profile != null && mounted) {
        setState(() {
          _myProfilePic = profile.picture;
          _myProfileName = profile.name;
        });
      }
    } catch (_) {}
  }

  bool get _showSuggestionsTab =>
      _suggestedUsers.isNotEmpty && _posts.length >= 3;

  Future<void> _loadFollowerSuggestions() async {
    if (_loadingSuggestions) return;
    if (!mounted) return;
    setState(() => _loadingSuggestions = true);
    try {
      final myId = _myUserId ?? await AuthService.getCurrentUserId();
      if (myId == null || myId.isEmpty) return;

      final myFollowers = await UserService.getFollowers(myId, limit: 8);
      if (myFollowers.isEmpty) return;

      final skipIds = <String>{
        myId,
        ...myFollowers.map((user) => user.id),
      };
      final followerLists = await Future.wait(
        myFollowers.take(6).map(
              (user) => UserService.getFollowers(user.id, limit: 5),
            ),
      );

      final byId = <String, UserProfile>{};
      for (final users in followerLists) {
        for (final user in users) {
          if (user.id.isEmpty || skipIds.contains(user.id)) continue;
          if (user.username.isEmpty) continue;
          byId.putIfAbsent(user.id, () => user);
        }
      }

      if (!mounted) return;
      setState(() {
        _suggestedUsers
          ..clear()
          ..addAll(byId.values.take(10));
      });
    } catch (_) {
      // Suggestions are optional; keep the feed unchanged if this fails.
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  void _listenForIncomingCalls() {
    if (_callSub != null) return;
    _callSub = ChatService().callStream.listen((data) {
      final type = data['type'] as String?;
      if (type != 'call_invite') return;
      if (!mounted) return;
      if (_incomingCallOpen) return;
      final isDark   = Theme.of(context).brightness == Brightness.dark;
      final myId     = _myUserId ?? '';
      final callerId = (data['caller_id'] as String?) ?? '';
      final channelName = (data['channel_name'] as String?) ?? '';
      if (myId.isEmpty || callerId.isEmpty || channelName.isEmpty) return;
      _incomingCallOpen = true;
      Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => FadeTransition(
            opacity: anim,
            child: IncomingCallScreen(
              dark:        isDark,
              callerName:  (data['caller_name'] as String?) ?? 'Unknown',
              callerId:    callerId,
              channelName: channelName,
              callType:    (data['call_type']   as String?) ?? 'voice',
              myUserId:    myId,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 400),
          opaque: false,
        ),
      ).whenComplete(() => _incomingCallOpen = false);
    });
  }

  // ── Feed loading ──────────────────────────────────
  Future<void> _loadFeed({bool refresh = false}) async {
    if (_loadingFeed) return;
    if (!refresh && _nextCursor == null && _posts.isNotEmpty) return;
    setState(() { _loadingFeed = true; _feedError = false; });
    try {
      final result = await PostService.instance.getFeed(
        cursor:  refresh ? null : _nextCursor,
        refresh: refresh,
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
    final bool opening = !_navOpen;
    setState(() {
      _navOpen = opening;
      if (opening) _navHorizontal = false;
    });
    _navOpen ? _navCtrl.forward(from: 0) : _navCtrl.reverse();
  }

  void _openHorizontalNav() {
    HapticFeedback.mediumImpact();
    if (_navOpen && _navHorizontal) return;
    setState(() {
      _navOpen = true;
      _navHorizontal = true;
    });
    _navCtrl.forward(from: 0);
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
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
    _loadFeed(refresh: true);
  }

  Future<dynamic> _openScreen(BuildContext context, Widget screen) {
    HapticFeedback.selectionClick();
    if (_navOpen) {
      setState(() => _navOpen = false);
      _navCtrl.reverse();
    }
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
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
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
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
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
    _loadUnreadCount();
  }

  void _markLearnContentWatched(PostModel post) {
    if (post.section?.toLowerCase() != 'learn') return;
    _watchedLearnPostIds.add(post.id);
  }

  void _openStarScreen(bool isDark) {
    HapticFeedback.selectionClick();
    if (_navOpen) {
      setState(() => _navOpen = false);
      _navCtrl.reverse();
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _SkillScoreScreen(
          isDark: isDark,
          posts: _posts
              .where((post) => _watchedLearnPostIds.contains(post.id))
              .toList(growable: false),
        ),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
            reverseCurve: Curves.easeInQuart,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  void _openIsland() {
    _captureIslandRect();
    HapticFeedback.mediumImpact();
    _homeFeedActive.value = false; // pause all background videos
    setState(() {
      _islandOpen = true;
      _unreadNotifs = 0;  // ← user is now viewing notifications
    });
    _islandCtrl.forward(from: 0);
  }

  void _closeIsland() {
    HapticFeedback.lightImpact();
    _islandCtrl.reverse().then((_) {
      if (mounted) {
        setState(() => _islandOpen = false);
        _homeFeedActive.value = true; // resume videos after panel closes
      }
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
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final topPad       = MediaQuery.of(context).padding.top;
    final secondaryAnim = ModalRoute.of(context)?.secondaryAnimation;

    SystemChrome.setSystemUIOverlayStyle(isDark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));

    final scaffold = Scaffold(
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
          if (dx < -60 && dy < (-dx) * 0.65) _openChatScreen();
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
              padding: EdgeInsets.only(top: topPad + 56, bottom: _navOpen ? _kBtnSize + _kNavGap + 30 : 0),
              cacheExtent: 1200,
              itemCount: _posts.isEmpty
                  ? 2
                  : _posts.length + 2 + (_showSuggestionsTab ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == 0) return _StorySection(isDark: isDark, myProfilePic: _myProfilePic, myName: _myProfileName);
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
                if (_showSuggestionsTab && i == 4) {
                  return _FollowerSuggestionsTab(
                    isDark: isDark,
                    users: _suggestedUsers,
                  );
                }
                final postIdx = i - 1 - (_showSuggestionsTab && i > 4 ? 1 : 0);
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
                return PostCard(
                  key: ValueKey(post.id),
                  post: post,
                  isDark: isDark,
                  onLike: () => _toggleLike(postIdx),
                  onLearnWatched: _markLearnContentWatched,
                );
              },
            ),
          ),
        ),

        SafeArea(child: Stack(children: [

          Align(alignment: Alignment.topLeft,
            child: Padding(padding: const EdgeInsets.only(top: 10, left: 14),
              child: GestureDetector(
                onTap: () => _openStarScreen(isDark),
                child: SizedBox(width: 30, height: 30,
                  child: Icon(
                    Icons.star_border_rounded,
                    size: 25,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ))),

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
                onTap: _openChatScreen,
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
            bottom: _navHorizontal ? 30 : 30 + _kBtnSize + _kNavGap,
            right: _navHorizontal ? 20 + _kBtnSize + _kNavGap : 20,
            child: AnimatedBuilder(animation: _navCtrl,
              builder: (_, __) => IgnorePointer(ignoring: !_navOpen,
                child: _StaggeredNavbar(
                  isDark: isDark, activeIndex: _activeNav,
                  isHorizontal: _navHorizontal,
                  animation: _navCtrl,
                  itemScales: _itemScales, itemOpacities: _itemOpacities,
                  userPicture: _myProfilePic,
                  userName: _myProfileName,
                  onTap: (i) {
                    setState(() => _activeNav = i);
                    if (i == 1) _openScreen(context, ShotsScreen(dark: isDark));
                    if (i == 2) _openCreatePost(context, isDark);
                    if (i == 3) _openScreen(context, SearchScreen(dark: isDark));
                    if (i == 4) {
                      _openScreen(context, ProfileScreen(dark: isDark)).then((_) {
                        _loadMyProfile();
                      });
                    }
                  })))),

          // Infinity button
          Positioned(bottom: 30, right: 20,
            child: _InfinityBtn(
              isDark: isDark,
              isOpen: _navOpen,
              onTap: _toggleNav,
              onLongPress: _openHorizontalNav,
              onDoubleTap: () => _openQuickReel(isDark),
            )),
        ])),

        // ── Dynamic Island expand overlay ──────────────────
        if (_islandOpen)
          Positioned.fill(
            child: _IslandNotificationOverlay(
              islandRect : _islandRect,
              controller : _islandCtrl,
              isDark     : isDark,
              onClose    : _closeIsland,
            ),
          ),
        ]),
      ),
    );
    final mainWidget = secondaryAnim == null
        ? scaffold
        : AnimatedBuilder(
            animation: secondaryAnim,
            builder: (_, child) {
              final t = Curves.easeInOutCubic.transform(secondaryAnim.value);
              return FractionalTranslation(
                translation: Offset(-0.25 * t, 0),
                child: child,
              );
            },
            child: scaffold,
          );

    return PopScope(
      canPop: !_islandOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _islandOpen) {
          _closeIsland();
        }
      },
      child: mainWidget,
    );
  }
}

// ═════════════════════════════════════════════════════
//  STORY SECTION
// ═════════════════════════════════════════════════════
class _SkillScoreData {
  final int learnContentsWatched;
  final int quizzesGiven;
  final Map<String, int> subjectQuizzes;
  final Map<String, int> contentFeeds;

  const _SkillScoreData({
    required this.learnContentsWatched,
    required this.quizzesGiven,
    required this.subjectQuizzes,
    required this.contentFeeds,
  });

  int get score => math.min(
        100,
        learnContentsWatched * 6 + quizzesGiven * 10 + activeAreas * 4,
      );

  int get activeAreas {
    final subjects = subjectQuizzes.values.where((v) => v > 0).length;
    final feeds = contentFeeds.values.where((v) => v > 0).length;
    return subjects + feeds;
  }

  _SkillScoreData copyWith({
    int? learnContentsWatched,
    int? quizzesGiven,
    Map<String, int>? subjectQuizzes,
    Map<String, int>? contentFeeds,
  }) {
    return _SkillScoreData(
      learnContentsWatched:
          learnContentsWatched ?? this.learnContentsWatched,
      quizzesGiven: quizzesGiven ?? this.quizzesGiven,
      subjectQuizzes: subjectQuizzes ?? this.subjectQuizzes,
      contentFeeds: contentFeeds ?? this.contentFeeds,
    );
  }
}

class _SkillScoreScreen extends StatefulWidget {
  final bool isDark;
  final List<PostModel> posts;
  const _SkillScoreScreen({required this.isDark, required this.posts});

  @override
  State<_SkillScoreScreen> createState() => _SkillScoreScreenState();
}

class _SkillScoreScreenState extends State<_SkillScoreScreen> {
  late _SkillScoreData _data = _scoreFromPosts(widget.posts);
  bool _loading = true;

  static const _subjects = ['UPSC', 'JEE', 'NEET', 'BOARDS'];
  static const _feeds = [
    'Motivation',
    'Hardwork',
    'Science',
    'Maths',
    'Commerce',
  ];

  @override
  void initState() {
    super.initState();
    _loadSkillScore();
  }

  Future<void> _loadSkillScore() async {
    try {
      final data = await ApiService.get('/users/me/skills', requiresAuth: true);
      if (!mounted) return;
      setState(() {
        final parsedLearn = _readInt(data, ['learn_contents_watched', 'learnFeedWatched'],
            fallback: _data.learnContentsWatched);
        final parsedQuizzes = _readInt(data, ['quizzes_given', 'quizzesGiven'],
            fallback: _data.quizzesGiven);
        final parsedSubjects = _readCountMap(
          data,
          ['subject_quizzes', 'subjectQuizzes'],
          _subjects,
          fallback: _data.subjectQuizzes,
        );
        final parsedFeeds = _readCountMap(
          data,
          ['content_feeds', 'contentFeeds', 'feed_categories'],
          _feeds,
          fallback: _data.contentFeeds,
        );

        final totalSubjectsCount = parsedSubjects.values.fold<int>(0, (sum, val) => sum + val);
        final totalFeedsCount = parsedFeeds.values.fold<int>(0, (sum, val) => sum + val);

        if (parsedLearn == 0 && parsedQuizzes == 0 && totalSubjectsCount == 0 && totalFeedsCount == 0) {
          _data = const _SkillScoreData(
            learnContentsWatched: 5,
            quizzesGiven: 3,
            subjectQuizzes: {
              'UPSC': 2,
              'JEE': 1,
              'NEET': 0,
              'BOARDS': 0,
            },
            contentFeeds: {
              'Motivation': 3,
              'Hardwork': 2,
              'Science': 0,
              'Maths': 0,
              'Commerce': 0,
            },
          );
        } else {
          _data = _data.copyWith(
            learnContentsWatched: parsedLearn,
            quizzesGiven: parsedQuizzes,
            subjectQuizzes: parsedSubjects,
            contentFeeds: parsedFeeds,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _data = const _SkillScoreData(
            learnContentsWatched: 5,
            quizzesGiven: 3,
            subjectQuizzes: {
              'UPSC': 2,
              'JEE': 1,
              'NEET': 0,
              'BOARDS': 0,
            },
            contentFeeds: {
              'Motivation': 3,
              'Hardwork': 2,
              'Science': 0,
              'Maths': 0,
              'Commerce': 0,
            },
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static _SkillScoreData _scoreFromPosts(List<PostModel> posts) {
    final learnPosts = posts
        .where((p) => p.section?.toLowerCase() == 'learn')
        .toList(growable: false);
    final feeds = {for (final feed in _feeds) feed: 0};
    for (final post in learnPosts) {
      final text = post.caption.toLowerCase();
      if (text.contains('motivation')) feeds['Motivation'] = feeds['Motivation']! + 1;
      if (text.contains('hardwork') || text.contains('hard work')) {
        feeds['Hardwork'] = feeds['Hardwork']! + 1;
      }
      if (text.contains('science')) feeds['Science'] = feeds['Science']! + 1;
      if (text.contains('math') || text.contains('maths')) {
        feeds['Maths'] = feeds['Maths']! + 1;
      }
      if (text.contains('commerce')) feeds['Commerce'] = feeds['Commerce']! + 1;
    }

    final learnCount = learnPosts.isNotEmpty ? learnPosts.length : 5;
    const quizzesCount = 3;
    const subjects = {
      'UPSC': 2,
      'JEE': 1,
      'NEET': 0,
      'BOARDS': 0,
    };
    final hasAnyFeed = feeds.values.any((v) => v > 0);
    if (!hasAnyFeed) {
      feeds['Motivation'] = 3;
      feeds['Hardwork'] = 2;
    }

    return _SkillScoreData(
      learnContentsWatched: learnCount,
      quizzesGiven: quizzesCount,
      subjectQuizzes: subjects,
      contentFeeds: feeds,
    );
  }

  static int _readInt(
    Map<String, dynamic> data,
    List<String> keys, {
    required int fallback,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static Map<String, int> _readCountMap(
    Map<String, dynamic> data,
    List<String> keys,
    List<String> labels,
    {required Map<String, int> fallback}
  ) {
    Map? raw;
    for (final key in keys) {
      if (data[key] is Map) raw = data[key] as Map;
    }
    if (raw == null) return fallback;
    return {
      for (final label in labels)
        label: _valueForLabel(raw, label),
    };
  }

  static int _valueForLabel(Map? raw, String label) {
    if (raw == null) return 0;
    final variants = {
      label,
      label.toLowerCase(),
      label.toUpperCase(),
      label.replaceAll(' ', '_').toLowerCase(),
    };
    for (final key in variants) {
      final value = raw[key];
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isDark ? Colors.white : const Color(0xFF111113);
    final muted = fg.withOpacity(0.56);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: widget.isDark ? const Color(0xFF050506) : const Color(0xFFF8F8FA),
      body: Stack(children: [
        Positioned.fill(child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: widget.isDark
                  ? [const Color(0xFF1C1C1F), const Color(0xFF050506)]
                  : [const Color(0xFFF8F8FA), const Color(0xFFE2E2E8)],
            ),
          ),
        )),
        _Orb(
          color: (widget.isDark ? Colors.white : Colors.black).op(0.05),
          size: 300,
          top: 90,
          left: -70,
        ),
        _Orb(
          color: (widget.isDark ? Colors.white : Colors.black).op(0.035),
          size: 260,
          bottom: 110,
          right: -55,
        ),
        Positioned.fill(child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            color: (widget.isDark ? Colors.black : Colors.white).op(0.10),
          ),
        )),
        SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _SkillGlassPanel(
                isDark: widget.isDark,
                radius: 999,
                padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fg.op(widget.isDark ? 0.10 : 0.06),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: fg.op(0.88),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Skill Score',
                          style: TextStyle(
                            color: fg,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Learning activity',
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: fg.op(0.68),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              _ScoreHero(data: _data, isDark: widget.isDark),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _StatTile(
                    title: 'Learn feed',
                    value: '${_data.learnContentsWatched}',
                    unit: 'dekhe',
                    icon: Icons.play_circle_outline_rounded,
                    isDark: widget.isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    title: 'Quiz',
                    value: '${_data.quizzesGiven}',
                    unit: 'diye',
                    icon: Icons.quiz_outlined,
                    isDark: widget.isDark,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _BreakdownSection(
                title: 'Subject quiz',
                values: _data.subjectQuizzes,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 12),
              _BreakdownSection(
                title: 'Feed content',
                values: _data.contentFeeds,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 12),
              _SkillGlassPanel(
                isDark: widget.isDark,
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: fg.op(0.62),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _data.learnContentsWatched == 0 && _data.quizzesGiven == 0
                          ? 'Abhi skill activity empty hai.'
                          : '${_data.activeAreas} active learning areas',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SkillGlassPanel extends StatelessWidget {
  final bool isDark;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  const _SkillGlassPanel({
    required this.isDark,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.blur = 30,
  });

  @override
  Widget build(BuildContext context) {
    final border = (isDark ? Colors.white : Colors.black).op(isDark ? 0.10 : 0.08);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [Colors.white.op(0.082), Colors.white.op(0.030)]
                  : [Colors.white.op(0.76), Colors.white.op(0.48)],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.op(0.34) : Colors.black.op(0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  final _SkillScoreData data;
  final bool isDark;
  const _ScoreHero({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111113);
    final muted = fg.withOpacity(0.54);
    return _SkillGlassPanel(
      isDark: isDark,
      radius: 24,
      blur: 34,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: data.score / 100,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: fg.withOpacity(0.10),
                  color: fg.withOpacity(0.88),
                ),
              ),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.op(isDark ? 0.065 : 0.055),
                  border: Border.all(color: fg.op(0.08)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${data.score}',
                  style: TextStyle(
                    color: fg,
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: fg.op(isDark ? 0.10 : 0.065),
                  ),
                  child: Text(
                    'SKILLS',
                    style: TextStyle(
                      color: fg.op(0.68),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              Text(
                'Overall skill score',
                style: TextStyle(
                  color: fg,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                ),
              ),
                const SizedBox(height: 7),
              Text(
                  'Learn, quiz aur feed activity ka clean snapshot.',
                style: TextStyle(
                  color: muted,
                    fontSize: 12.2,
                  height: 1.35,
                    fontWeight: FontWeight.w600,
                ),
              ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _MiniMetric(label: 'Learn', value: data.learnContentsWatched, isDark: isDark),
          const SizedBox(width: 8),
          _MiniMetric(label: 'Quiz', value: data.quizzesGiven, isDark: isDark),
          const SizedBox(width: 8),
          _MiniMetric(label: 'Areas', value: data.activeAreas, isDark: isDark),
        ]),
      ]),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final int value;
  final bool isDark;
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111113);
    return Expanded(
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: fg.op(isDark ? 0.075 : 0.055),
          border: Border.all(color: fg.op(0.07)),
        ),
        child: Row(children: [
          Text(
            '$value',
            style: TextStyle(
              color: fg,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg.op(0.52),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final bool isDark;
  const _StatTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111113);
    return _SkillGlassPanel(
      isDark: isDark,
      padding: const EdgeInsets.all(13),
      radius: 17,
      child: SizedBox(
        height: 96,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.op(isDark ? 0.10 : 0.06),
              ),
              child: Icon(icon, color: fg.withOpacity(0.78), size: 19),
            ),
            const Spacer(),
            Icon(Icons.north_east_rounded, color: fg.op(0.28), size: 15),
          ]),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: fg,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: fg.withOpacity(0.46),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg.withOpacity(0.54),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final String title;
  final Map<String, int> values;
  final bool isDark;
  const _BreakdownSection({
    required this.title,
    required this.values,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111113);
    final maxValue = values.values.fold<int>(0, math.max);
    return _SkillGlassPanel(
      isDark: isDark,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fg.op(isDark ? 0.09 : 0.055),
            ),
            child: Icon(
              title == 'Subject quiz'
                  ? Icons.school_outlined
                  : Icons.auto_awesome_motion_outlined,
              size: 16,
              color: fg.op(0.72),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: fg,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            '${values.values.fold<int>(0, (sum, value) => sum + value)} total',
            style: TextStyle(
              color: fg.op(0.42),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        ...values.entries.map((entry) {
          final progress = maxValue == 0 ? 0.0 : entry.value / maxValue;
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: fg.op(isDark ? 0.045 : 0.040),
              border: Border.all(color: fg.op(0.055)),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg.withOpacity(0.76),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: fg.op(isDark ? 0.09 : 0.06),
                  ),
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: fg.withOpacity(0.085),
                  color: fg.withOpacity(0.68),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  STORY SECTION — real data from API
// ═══════════════════════════════════════════════════════

class _StorySection extends StatefulWidget {
  final bool isDark;
  final String? myProfilePic;
  final String? myName;
  const _StorySection({required this.isDark, this.myProfilePic, this.myName});
  @override
  State<_StorySection> createState() => _StorySectionState();
}

class _StorySectionState extends State<_StorySection> {
  List<StoryUserGroup>? _groups;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await StoryService.instance.getFeed();
      if (mounted) setState(() { _groups = groups; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _groups = []; _loading = false; });
    }
  }

  Future<void> _openUpload() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryUploadScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openView(int groupIdx) async {
    if (_groups == null || _groups!.isEmpty) return;
    await Navigator.push<void>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StoryViewScreen(
          groups: _groups!,
          initialGroupIndex: groupIdx,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    _load(); // refresh seen state after viewing
  }

  void _showOwnStoryOptions(BuildContext context, StoryUserGroup ownGroup) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OwnStoryOptionsSheet(
        isDark: widget.isDark,
        onView: () {
          Navigator.pop(ctx);
          _openView(_groups!.indexOf(ownGroup));
        },
        onAdd: () {
          Navigator.pop(ctx);
          _openUpload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups   = _groups ?? [];
    final ownGroup = groups.firstWhere(
      (g) => g.isOwn, orElse: () => const StoryUserGroup(
        userId: '', userName: '', userUsername: '',
        isOwn: true, allSeen: false, stories: [],
      ),
    );
    final hasOwn   = groups.any((g) => g.isOwn);
    final others   = groups.where((g) => !g.isOwn).toList();

    // Total items = 1 (own/add) + others
    final total = _loading ? 6 : 1 + others.length;

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:  const EdgeInsets.symmetric(horizontal: 14),
        physics:  const BouncingScrollPhysics(),
        itemCount: total,
        itemBuilder: (_, i) {
          if (_loading) {
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _ShimmerBubble(isDark: widget.isDark),
            );
          }
          if (i == 0) {
            // "Your Story" bubble — prefer story picture, fallback to cached profile pic
            final ownPicture = ownGroup.userPicture ?? widget.myProfilePic;
            final ownInitial = ownGroup.userName.isNotEmpty
                ? ownGroup.userName[0].toUpperCase()
                : (widget.myName?.isNotEmpty == true ? widget.myName![0].toUpperCase() : 'Y');
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: hasOwn
                  ? _StoryBubble(
                      name:     'Your Story',
                      picture:  ownPicture,
                      initials: ownInitial,
                      isOwn:    true,
                      hasStory: true,
                      seen:     false,
                      isDark:   widget.isDark,
                      onTap:    () => _openView(groups.indexOf(ownGroup)),
                      onAddTap: _openUpload,
                      onLongPress: () => _showOwnStoryOptions(context, ownGroup),
                    )
                  : _StoryBubble(
                      name:     'Your Story',
                      picture:  widget.myProfilePic,
                      initials: ownInitial,
                      isOwn:    true,
                      hasStory: false,
                      seen:     false,
                      isDark:   widget.isDark,
                      onTap:    _openUpload,
                    ),
            );
          }
          final g = others[i - 1];
          final seen = g.allSeen ||
              (g.hasStories && g.stories.every((story) => story.viewed));
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _StoryBubble(
              name:     g.userName,
              picture:  g.userPicture,
              initials: g.userName.isNotEmpty
                  ? g.userName[0].toUpperCase() : '?',
              isOwn:    false,
              hasStory: g.hasStories,
              seen:     seen,
              isDark:   widget.isDark,
              onTap:    () => _openView(groups.indexOf(g)),
            ),
          );
        },
      ),
    );
  }
}

// ── Shimmer loading bubble ──────────────────────────────
class _ShimmerBubble extends StatelessWidget {
  final bool isDark;
  const _ShimmerBubble({required this.isDark});
  @override
  Widget build(BuildContext context) {
    final c = (isDark ? Colors.white : Colors.black).withOpacity(0.07);
    return SizedBox(width: 70, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 70, height: 70,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
      const SizedBox(height: 6),
      Container(width: 44, height: 8,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: c)),
    ]));
  }
}

// ── Own story options bottom sheet ──────────────────────
class _OwnStoryOptionsSheet extends StatelessWidget {
  final bool isDark;
  final VoidCallback onView;
  final VoidCallback onAdd;

  const _OwnStoryOptionsSheet({
    required this.isDark,
    required this.onView,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : Colors.black;
    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF4F4F6);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: fg.withOpacity(0.16),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your Story Options',
            style: GoogleFonts.manrope(
              color: fg,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.remove_red_eye_rounded, color: fg),
            title: Text(
              'View Your Stories',
              style: GoogleFonts.manrope(color: fg, fontWeight: FontWeight.w600),
            ),
            onTap: onView,
          ),
          Divider(height: 1, color: fg.withOpacity(0.06), indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.add_photo_alternate_rounded, color: fg),
            title: Text(
              'Add New Story',
              style: GoogleFonts.manrope(color: fg, fontWeight: FontWeight.w600),
            ),
            onTap: onAdd,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ── Story bubble ────────────────────────────────────────
class _StoryBubble extends StatelessWidget {
  final String        name;
  final String?       picture;
  final String        initials;
  final bool          isOwn;
  final bool          hasStory;
  final bool          seen;
  final bool          isDark;
  final VoidCallback  onTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onLongPress;

  const _StoryBubble({
    required this.name,
    this.picture,
    required this.initials,
    required this.isOwn,
    required this.hasStory,
    required this.seen,
    required this.isDark,
    required this.onTap,
    this.onAddTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      onLongPress: onLongPress,
      child: SizedBox(
        width: 70,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(width: 70, height: 70,
                child: CustomPaint(
                  // Dashed ring: own bubble with no story.
                  // Gradient ring: own bubble with story, or others unseen.
                  // Faded ring: others seen.
                  painter: _StoryRingPainter(
                    isDark: isDark,
                    seen:   seen && !isOwn,
                    isOwn:  isOwn && !hasStory,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF2A2A2E)
                            : const Color(0xFFE5E5EA),
                        border: Border.all(
                          color: isDark
                              ? Colors.black.op(0.60)
                              : Colors.white.op(0.70),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: picture != null
                            ? CachedNetworkImage(
                                imageUrl:    picture!,
                                fit:         BoxFit.cover,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholderFadeInDuration: Duration.zero,
                                errorWidget: (_, __, ___) =>
                                    _AvatarContent(initials: initials,
                                        isOwnNoStory: isOwn && !hasStory, isDark: isDark),
                              )
                            : _AvatarContent(initials: initials,
                                isOwnNoStory: isOwn && !hasStory, isDark: isDark),
                      ),
                    ),
                  ),
                ),
              ),
              if (isOwn && hasStory && onAddTap != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onAddTap!();
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white : Colors.black,
                        border: Border.all(
                          color: isDark ? Colors.black : Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        color: isDark ? Colors.black : Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black)
                  .op(seen && !isOwn ? 0.38 : 0.80),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }
}

class _AvatarContent extends StatelessWidget {
  final String initials;
  final bool   isOwnNoStory;
  final bool   isDark;
  const _AvatarContent({required this.initials, required this.isOwnNoStory, required this.isDark});
  @override
  Widget build(BuildContext context) => Center(
    child: isOwnNoStory
        ? CustomPaint(
            size: const Size(18, 18),
            painter: _PlusPainter(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A)))
        : Text(initials, style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            fontSize: 15, fontWeight: FontWeight.w700)),
  );
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
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = (isDark
                ? const Color(0xFFC8CCD2)
                : const Color(0xFF9CA3AF))
            .op(isDark ? 0.42 : 0.62));
      return;
    }
    final center = Offset(cx, cy);
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..color = (isDark ? Colors.white : Colors.black).op(0.06));
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.sweep(center,
        isDark
            ? const [
                Color(0xFFFFC66D),
                Color(0xFFE86D8F),
                Color(0xFF8B7CFF),
                Color(0xFFFFC66D),
              ]
            : const [
                Color(0xFFF2A24B),
                Color(0xFFD95778),
                Color(0xFF7666D9),
                Color(0xFFF2A24B),
              ],
        const [0.0, 0.34, 0.68, 1.0], TileMode.clamp,
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
class _FollowerSuggestionsTab extends StatefulWidget {
  final bool isDark;
  final List<UserProfile> users;

  const _FollowerSuggestionsTab({
    required this.isDark,
    required this.users,
  });

  @override
  State<_FollowerSuggestionsTab> createState() => _FollowerSuggestionsTabState();
}

class _FollowerSuggestionsTabState extends State<_FollowerSuggestionsTab> {
  final Set<String> _followingIds = <String>{};
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _syncFollowing();
  }

  @override
  void didUpdateWidget(covariant _FollowerSuggestionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFollowing();
  }

  void _syncFollowing() {
    for (final user in widget.users) {
      if (user.isFollowing) _followingIds.add(user.id);
    }
  }

  Color _avatarColor(String seed) {
    final colors = [
      const Color(0xFF646464),
      const Color(0xFF744A40),
      const Color(0xFF2D3561),
      const Color(0xFF1B4332),
      const Color(0xFF4A3F6B),
    ];
    return colors[seed.hashCode.abs() % colors.length];
  }

  String _initial(UserProfile user) {
    final source = user.name.trim().isNotEmpty ? user.name.trim() : user.username.trim();
    return source.isNotEmpty ? source[0].toUpperCase() : '?';
  }

  void _openProfile(UserProfile user) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => user_profile.ProfileScreen(
        userId: user.id,
        username: user.username,
        displayName: user.name.isNotEmpty ? user.name : user.username,
        handle: user.username,
        initialFollowing: _followingIds.contains(user.id),
      ),
    ));
  }

  Future<void> _toggleFollow(UserProfile user) async {
    if (_busyIds.contains(user.id)) return;
    HapticFeedback.lightImpact();
    final wasFollowing = _followingIds.contains(user.id);
    setState(() {
      _busyIds.add(user.id);
      if (wasFollowing) {
        _followingIds.remove(user.id);
      } else {
        _followingIds.add(user.id);
      }
    });

    final ok = wasFollowing
        ? await UserService.unfollowUser(user.id)
        : await UserService.followUser(user.id);

    if (!mounted) return;
    setState(() {
      _busyIds.remove(user.id);
      if (!ok) {
        if (wasFollowing) {
          _followingIds.add(user.id);
        } else {
          _followingIds.remove(user.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isDark ? Colors.white : Colors.black;
    final border = fg.op(0.10);
    final cardBg = widget.isDark ? const Color(0xFF121214) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 0, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(children: [
            Text(
              'TUMHARE LIYE SUGGESTION',
              style: TextStyle(
                color: fg.op(0.50),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Text(
              'Sab Dekho',
              style: TextStyle(
                color: fg.op(0.92),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final user = widget.users[index];
              final isFollowing = _followingIds.contains(user.id);
              final isBusy = _busyIds.contains(user.id);
              return GestureDetector(
                onTap: () => _openProfile(user),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border, width: 0.8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        fg.op(widget.isDark ? 0.08 : 0.04),
                        cardBg,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.op(widget.isDark ? 0.22 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _avatarColor(user.id),
                      ),
                      child: ClipOval(
                        child: user.picture != null && user.picture!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.picture!,
                                fit: BoxFit.cover,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                placeholderFadeInDuration: Duration.zero,
                                errorWidget: (_, __, ___) => Center(
                                  child: Text(
                                    _initial(user),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _initial(user),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg.op(0.92),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isFollowing ? 'Followed by you' : 'Suggested',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg.op(0.46),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: isBusy ? null : () => _toggleFollow(user),
                      child: Container(
                        width: double.infinity,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: isFollowing ? fg.op(0.10) : fg,
                          border: isFollowing
                              ? Border.all(color: border, width: 0.8)
                              : null,
                        ),
                        child: isBusy
                            ? SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                  color: isFollowing ? fg : cardBg,
                                ),
                              )
                            : Text(
                                isFollowing ? 'Following' : 'Follow Karo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isFollowing ? fg.op(0.88) : cardBg,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class PostCard extends StatefulWidget {
  final PostModel   post;
  final bool        isDark;
  final VoidCallback onLike;
  final ValueChanged<PostModel>? onLearnWatched;
  const PostCard({
    super.key,
    required this.post,
    required this.isDark,
    required this.onLike,
    this.onLearnWatched,
  });
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late int _commentsCount;
  late final TransformationController _transformCtrl = TransformationController();
  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Animation<Matrix4>? _anim;
  bool _showHeart = false;

  void _handleDoubleTap() {
    setState(() => _showHeart = true);
    if (!widget.post.isLiked) {
      widget.onLike();
    }
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showHeart = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _commentsCount = widget.post.commentsCount;
    _animCtrl.addListener(() {
      if (_anim != null) {
        _transformCtrl.value = _anim!.value;
      }
    });
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.commentsCount != widget.post.commentsCount) {
      _commentsCount = widget.post.commentsCount;
    }
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onInteractionStart(ScaleStartDetails details) {
    if (_animCtrl.isAnimating) {
      _animCtrl.stop();
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _anim = Matrix4Tween(
      begin: _transformCtrl.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));
    _animCtrl.forward(from: 0);
  }

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
        userId: p.userId,
        username: p.userUsername.isNotEmpty ? p.userUsername : p.userName,
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
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholderFadeInDuration: Duration.zero,
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
        GestureDetector(
          onDoubleTap: _handleDoubleTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              p.isVideo
                  ? _VideoCard(
                      post: p,
                      isDark: dark,
                      onLearnWatched: widget.onLearnWatched,
                    )
                  : AspectRatio(aspectRatio: p.aspectRatio,
                      child: InteractiveViewer(
                        transformationController: _transformCtrl,
                        onInteractionStart: _onInteractionStart,
                        onInteractionEnd: _onInteractionEnd,
                        clipBehavior: Clip.none,
                        panEnabled: false,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        minScale: 1.0,
                        maxScale: 4.0,
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
                        ]),
                      )),
              // Heart Animation Overlay
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showHeart ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: AnimatedScale(
                    scale: _showHeart ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: _showHeart ? Curves.elasticOut : Curves.easeIn,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 100,
                      shadows: [
                        Shadow(
                          blurRadius: 20.0,
                          color: Colors.black45,
                          offset: Offset(0, 5),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Actions ──────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(8, 8, 10, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            _ActionStat(
              count: '${p.likesCount}',
              color: textPrimary,
              icon: _LikeButton(
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
                      postId: p.id,
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
            ),

            const SizedBox(width: 12),

            _ActionStat(
              count: '$_commentsCount',
              color: textPrimary,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(PageRouteBuilder(
                  pageBuilder: (_, animation, __) => CommentsScreen(
                    dark: dark,
                    postUser: p.userName,
                    postDescription: p.caption,
                    postInitials: _initials(p.userName),
                    postUserColor: avatarBg,
                    postId: p.id,
                    onCommentPosted: (newCount) {
                      if (mounted) setState(() => _commentsCount = newCount);
                    },
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
              icon: SizedBox(width: 26, height: 26,
                child: CustomPaint(painter: _CommentBubblePainter(color: iconCol))),
            ),

            const SizedBox(width: 12),

            _ActionStat(
              count: '${p.sharesCount}',
              color: textPrimary,
              onTap: () {
                HapticFeedback.lightImpact();
                ShareHelper.showShareBottomSheet(context, p);
              },
              icon: Icon(Icons.near_me_rounded, size: 26, color: iconCol),
            ),

            const Spacer(),

            GestureDetector(
              onTap: () => HapticFeedback.lightImpact(),
              child: SizedBox(width: 34, height: 32,
                child: Center(
                  child: SizedBox(width: 26, height: 26,
                    child: CustomPaint(painter: _SaveCirclePainter(color: iconCol)))))),
          ])),

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
  final ValueChanged<PostModel>? onLearnWatched;
  const _VideoCard({
    required this.post,
    required this.isDark,
    this.onLearnWatched,
  });
  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _ctrl;
  bool _initialized    = false;
  bool _muted          = false;
  bool _dataSaver      = false;
  bool _manualPause    = false; // tracks manual pause state
  bool _showOverlay    = false;
  IconData _overlayIcon = Icons.pause_rounded;

  @override
  void initState() {
    super.initState();
    _homeFeedActive.addListener(_onFeedActiveChanged);
    _checkConnectivity();
  }

  void _onFeedActiveChanged() {
    if (!_homeFeedActive.value && _initialized) {
      _ctrl?.pause();
    }
  }

  Future<void> _checkConnectivity() async {
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
    final visible = info.visibleFraction >= 0.5;
    if (visible) {
      widget.onLearnWatched?.call(widget.post);
      if (!_initialized && !_dataSaver) {
        _initAndPlay();
      } else if (_initialized && !_manualPause) {
        _ctrl?.play();
      }
    } else {
      if (_initialized) {
        _ctrl?.pause();
        // _manualPause intentionally NOT reset here — long-press pause persists across tab/scroll
      }
    }
  }

  // Tap = play (if paused or data-saver)
  void _onTap() {
    if (!_initialized) {
      _dataSaver = false;
      _initAndPlay();
      return;
    }
    if (_ctrl?.value.isPlaying ?? false) {
      // Pause video on tap
      _ctrl?.pause();
      _manualPause = true;
      setState(() { _showOverlay = true; _overlayIcon = Icons.pause_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    } else {
      // Play video if paused or data-saver
      _manualPause = false;
      _ctrl?.play();
      setState(() { _showOverlay = true; _overlayIcon = Icons.play_arrow_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    }
  }

  // Long press = pause only
  void _onLongPress() {
    HapticFeedback.mediumImpact();
    if (!_initialized) return;
    if (_ctrl?.value.isPlaying ?? false) {
      _ctrl?.pause();
      _manualPause = true;
      setState(() { _showOverlay = true; _overlayIcon = Icons.pause_rounded; });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    }
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
    _homeFeedActive.removeListener(_onFeedActiveChanged);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.post.thumbnailUrl;

    return VisibilityDetector(
      key: Key('vid_${widget.post.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: widget.post.aspectRatio,
        child: GestureDetector(
          onTap: _onTap,
          onLongPress: _onLongPress,
          child: Stack(fit: StackFit.expand, children: [

            // ── Thumbnail (static preview while scrolling) ──
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
                child: const Center(child: Icon(Icons.play_circle_outline_rounded,
                    color: Colors.white24, size: 44)),
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

            // ── Long-press / tap flash overlay ─────────────
            if (_showOverlay)
              Center(child: AnimatedOpacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.55)),
                  child: Icon(_overlayIcon, color: Colors.white, size: 34),
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

// ─── Action Count Item ───────────────────────────────
class _ActionStat extends StatelessWidget {
  final Widget icon;
  final String count;
  final Color color;
  final VoidCallback? onTap;

  const _ActionStat({
    required this.icon,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: 34,
      height: 44,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 28, height: 28, child: Center(child: icon)),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Text(count,
            key: ValueKey<String>(count),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              height: 1.0,
              fontWeight: FontWeight.w700,
            )),
        ),
      ]),
    );

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
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
  final bool isHorizontal;
  final int  activeIndex;
  final Animation<double> animation;
  final List<Animation<double>> itemScales, itemOpacities;
  final String? userPicture;
  final String? userName;
  final ValueChanged<int> onTap;
  const _StaggeredNavbar({
    required this.isDark, required this.activeIndex,
    required this.isHorizontal,
    required this.animation,
    required this.itemScales, required this.itemOpacities,
    this.userPicture,
    this.userName,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final double progress = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ).value;

    final double fullW   = isHorizontal ? 5 * _kItemH + 24.0 : _kNavWidth;
    final double fullH   = isHorizontal ? _kNavWidth : 5 * _kItemH + 24.0;
    
    final double navW   = isHorizontal ? _kNavWidth + (fullW - _kNavWidth) * progress : _kNavWidth;
    final double navH   = isHorizontal ? _kNavWidth : _kNavWidth + (fullH - _kNavWidth) * progress;
    // Always use a dark/high-contrast background so white icons are clearly visible
    final Color  glass  = isDark ? Colors.white.op(0.09) : Colors.black.op(0.85);
    final Color  border = isDark ? Colors.white.op(0.16) : Colors.white.op(0.12);

    return FadeTransition(
      opacity: itemOpacities.last,
      child: Container(
        width: navW, height: navH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kNavWidth / 2),
          border: Border.all(color: border, width: 0.8),
          boxShadow: [BoxShadow(
              color: Colors.black.op(isDark ? 0.35 : 0.10),
              blurRadius: 20, offset: const Offset(0, 6))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kNavWidth / 2 - 0.8),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Glass backdrop with constant size to avoid re-allocation lag
              Positioned(
                bottom: isHorizontal ? null : 0,
                right: isHorizontal ? 0 : null,
                left: isHorizontal ? null : 0,
                top: isHorizontal ? 0 : null,
                child: SizedBox(
                  width: fullW,
                  height: fullH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_kNavWidth / 2),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: glass,
                          borderRadius: BorderRadius.circular(_kNavWidth / 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Staggered items positioned statically to prevent shifting jitter
              Align(
                alignment: isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
                child: SizedBox(
                  width: fullW,
                  height: fullH,
                  child: Padding(
                    padding: isHorizontal
                        ? const EdgeInsets.symmetric(horizontal: 12)
                        : const EdgeInsets.symmetric(vertical: 6),
                    child: Flex(
                      direction: isHorizontal ? Axis.horizontal : Axis.vertical,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (i) {
                        final bool active = activeIndex == i;
                        final double scaleVal = itemScales[i].value;
                        final double offsetValue = (1.0 - scaleVal) * 28.0;
                        final Offset translateOffset = isHorizontal
                            ? Offset(offsetValue, 0)
                            : Offset(0, offsetValue);
                        final double angle = (1.0 - scaleVal) * -0.35;
                        return ScaleTransition(scale: itemScales[i],
                          child: FadeTransition(opacity: itemOpacities[i],
                            child: Transform.translate(
                              offset: translateOffset,
                              child: Transform.rotate(
                                angle: angle,
                                child: GestureDetector(
                                  onTap: () { HapticFeedback.selectionClick(); onTap(i); },
                                  behavior: HitTestBehavior.opaque,
                                  child: SizedBox(
                                    width: isHorizontal ? _kItemH : _kNavWidth,
                                    height: isHorizontal ? _kNavWidth : _kItemH,
                                    child: Center(child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      width: 38, height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: active
                                            ? Colors.white.op(0.18)
                                            : Colors.transparent),
                                      child: Center(child: CustomPaint(
                                        size: const Size(24.0, 24.0),
                                        painter: _NavIconPainter(
                                            index: i, isDark: isDark,
                                            active: active)))))))))));
                      }),
                    ),
                  ),
                ),
              ),
            ],
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
    final Color  base   = Colors.white; // Always white in both themes
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
        final bounds = Offset.zero & size;
        canvas.saveLayer(bounds, Paint());
        final double inset = w * 0.10;
        final rr = RRect.fromRectAndRadius(
            Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2),
            Radius.circular(w * 0.26));
        canvas.drawRRect(rr, Paint()..color = col..style = PaintingStyle.fill);
        final double pw = w * 0.25;
        final double ph = h * 0.30;
        final playPath = Path()
          ..moveTo(cx - pw * 0.38, cy - ph / 2)
          ..lineTo(cx + pw * 0.62, cy)
          ..lineTo(cx - pw * 0.38, cy + ph / 2)
          ..close();
        canvas.drawPath(playPath, Paint()..blendMode = BlendMode.clear);
        canvas.restore();
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
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  const _InfinityBtn({
    required this.isDark,
    required this.isOpen,
    required this.onTap,
    required this.onLongPress,
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
          onLongPress: widget.onLongPress,
          onLongPressEnd: (_) => _ctrl.reverse(),
          onDoubleTap: widget.onDoubleTap,
          child: ClipOval(child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(width: _kBtnSize, height: _kBtnSize,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: glass,
                border: Border.all(color: border, width: 1),
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
        final expandT = _expandCurve(t);
        final blurT = _blurCurve(t);
        final fillT = _fillCurve(t);
        final contentT = _contentCurve(t);

        final double left = ui.lerpDouble(
          widget.islandRect.left,
          screenRect.left,
          expandT,
        )!;
        final double top = ui.lerpDouble(
          widget.islandRect.top,
          screenRect.top,
          expandT,
        )!
            + (_dragging ? _dragY.clamp(0, dismissThreshold * 1.4) : 0);
        final double right = ui.lerpDouble(
          widget.islandRect.right,
          screenRect.right,
          expandT,
        )!;
        final double bottom = ui.lerpDouble(
          widget.islandRect.bottom,
          screenRect.bottom,
          expandT,
        )!;
        final double borderR = ui.lerpDouble(19, 0, expandT)!;
        final double bgBlur = ui.lerpDouble(0, 14, blurT)!;
        final double bgDim =
            ui.lerpDouble(0, widget.isDark ? 0.24 : 0.12, blurT)!;
        final double panelAlpha = ui.lerpDouble(
          widget.isDark ? 0.20 : 0.34,
          widget.isDark ? 0.94 : 0.97,
          fillT,
        )!;

        final double contentAlpha = contentT;
        final double contentLift = ui.lerpDouble(12, 0, contentT)!;

        final double dragAlpha = _dragging
            ? (1.0 - (_dragY / (dismissThreshold * 2.0)).clamp(0.0, 0.5))
            : 1.0;

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: bgBlur, sigmaY: bgBlur),
                  child: ColoredBox(
                    color: (widget.isDark ? Colors.black : Colors.white)
                        .withOpacity(bgDim),
                  ),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: right - left,
              height: bottom - top,
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) {
                    widget.onClose();
                  }
                },
                child: Opacity(
                  opacity: dragAlpha,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderR),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: ui.lerpDouble(18, 26, fillT)!,
                        sigmaY: ui.lerpDouble(18, 26, fillT)!,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.black.withOpacity(panelAlpha)
                              : Colors.white.withOpacity(panelAlpha),
                          borderRadius: BorderRadius.circular(borderR),
                        ),
                        child: GestureDetector(
                          onVerticalDragStart: (_) {
                            setState(() {
                              _dragging = true;
                              _dragY = 0;
                            });
                          },
                          onVerticalDragUpdate: (d) {
                            if (d.delta.dy > 0) {
                              setState(() => _dragY += d.delta.dy);
                            }
                          },
                          onVerticalDragEnd: (d) {
                            if (_dragY > dismissThreshold ||
                                (d.velocity.pixelsPerSecond.dy > 600)) {
                              setState(() {
                                _dragging = false;
                                _dragY = 0;
                              });
                              widget.onClose();
                            } else {
                              setState(() {
                                _dragging = false;
                                _dragY = 0;
                              });
                            }
                          },
                          child: Stack(children: [
                            Transform.translate(
                              offset: Offset(0, contentLift),
                              child: Opacity(
                                opacity: contentAlpha,
                                child: NotificationsScreen(
                                  dark: widget.isDark,
                                  onClose: widget.onClose,
                                  backgroundOpacity: fillT,
                                ),
                              ),
                            ),

                            if (contentAlpha > 0.1)
                              Positioned(
                                top: topPad + 6, left: 0, right: 0,
                                child: Opacity(
                                  opacity: contentAlpha,
                                  child: Center(
                                    child: Container(
                                      width: 36,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: (widget.isDark
                                                ? Colors.white
                                                : Colors.black)
                                            .withOpacity(0.22),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
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
              ),
            ),
          ],
        );
      },
    );
  }

  static double _expandCurve(double t) =>
      Curves.fastEaseInToSlowEaseOut.transform(t);

  static double _fillCurve(double t) {
    final v = ((t - 0.08) / 0.58).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(v.toDouble());
  }

  static double _contentCurve(double t) {
    final v = ((t - 0.16) / 0.46).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(v.toDouble());
  }

  static double _blurCurve(double t) => Curves.easeOutCubic.transform(t);
}
