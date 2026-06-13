import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/fcm_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/app_badge_service.dart';
import '../../services/user_service.dart';
import '../../models/chat_model.dart';
import '../call_screens.dart';
import '../../services/post_service.dart';
import '../../services/local_db.dart';
import '../search_screen.dart';
import '../shots_screen.dart';
import '../profile_screen.dart';
import '../chat_list_screen.dart';
import '../create_post_screens.dart';
import '../../services/block_service.dart';
import '../../services/cryptography_service.dart';
import '../../utils/route_observer.dart';
import '../../widgets/shared/home_shared.dart';
import '../../widgets/feed/feed_post_card.dart';
import '../../widgets/feed/video_card.dart' show FeedVideoPool;
import '../../widgets/stories/story_bar.dart';
import '../../widgets/home/home_nav_bar.dart';
import '../../widgets/home/suggested_users.dart';
import '../../l10n/app_localizations.dart';
import 'skill_score.dart';
import 'infinity_btn.dart';
import 'trandia_island.dart';

// -----------------------------------------------------
//  HOME SCREEN
// -----------------------------------------------------
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

  // -- Island expand / collapse ----------------------
  late AnimationController _islandCtrl;
  bool _islandOpen = false;

  // Island pill geometry (populated after first layout)
  Rect   _islandRect   = Rect.zero;
  final  GlobalKey _islandKey = GlobalKey();

  // -- Real-time notification listeners -------------
  StreamSubscription? _fcmNotifSub;
  StreamSubscription? _wsNotifSub;
  StreamSubscription? _callSub;
  String? _myUserId;
  bool _incomingCallOpen = false;
  String? _myProfilePic;
  String? _myProfileName;

  // -- Feed state ------------------------------------
  final List<PostModel> _posts       = [];
  String?               _nextCursor;
  bool                  _loadingFeed    = false;
  bool                  _feedError      = false;
  // true only when API confirms no more pages (nextCursor == null after a
  // successful fetch). Prevents the stuck-cache bug where _nextCursor == null
  // after a cache-only load blocks all future feed fetches.
  bool                  _feedFullyLoaded = false;
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
      BlockService.instance.load();
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

  @override
  void didPushNext() => homeFeedActive.value = false;

  @override
  void didPopNext() => homeFeedActive.value = true;

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
      // Fresh, randomized real users from the backend (MongoDB $sample) — a
      // different set every load, and it works even for brand-new users who
      // don't have any followers yet (the old friends-of-friends logic returned
      // the same fixed people, and nothing at all for new accounts).
      final suggestions = await UserService.getSuggestedUsers(limit: 10);
      if (!mounted) return;
      setState(() {
        _suggestedUsers
          ..clear()
          ..addAll(suggestions.where((u) => u.username.isNotEmpty));
      });
    } catch (_) {
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

  Future<void> _loadFeed({bool refresh = false}) async {
    if (_loadingFeed) return;
    // Only block pagination when we have CONFIRMED from the API that there
    // are no more pages.  Never block when running from stale local cache
    // (_feedFullyLoaded stays false until a real API response arrives).
    if (!refresh && _feedFullyLoaded && _posts.isNotEmpty) return;

    // Pull-to-refresh also rotates the "Suggested for you" tab to a fresh
    // random set of real users (runs in parallel, doesn't block the feed).
    if (refresh) unawaited(_loadFollowerSuggestions());

    // -- Stale-while-revalidate for first page (not pagination, not pull-refresh) --
    final isFirstPage = !refresh && _nextCursor == null && _posts.isEmpty;
    if (isFirstPage) {
      final cached = await LocalDb.instance.loadFeedPosts();
      if (cached.isNotEmpty && mounted) {
        // Render cached posts instantly � no spinner shown to user
        setState(() {
          _posts.addAll(cached);
          _feedError = false;
        });
        // Then silently fetch fresh data in background
        _silentlyRefreshFeed();
        return;
      }
    }

    // Standard blocking fetch (refresh, pagination, or no local cache)
    setState(() { _loadingFeed = true; _feedError = false; });
    try {
      final result = await PostService.instance.getFeed(
        cursor:  refresh ? null : _nextCursor,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _posts.clear();
          FeedVideoPool.reset();
        }
        _posts.addAll(result.posts);
        _nextCursor = result.nextCursor;
        _feedFullyLoaded = result.nextCursor == null; // confirmed no more pages
        _feedError = false;
        FeedVideoPool.grow(_posts);
      });
      // Save first page to local DB for next cold open
      if ((refresh || isFirstPage) && result.posts.isNotEmpty) {
        unawaited(LocalDb.instance.saveFeedPosts(result.posts));
      }
    } catch (_) {
      if (mounted) setState(() => _feedError = true);
    } finally {
      if (mounted) setState(() => _loadingFeed = false);
    }
  }

  /// Fetch fresh feed from API without showing a loading spinner.
  /// Updates the UI only if new posts differ from what's already shown.
  Future<void> _silentlyRefreshFeed() async {
    try {
      final result = await PostService.instance.getFeed(refresh: true);
      if (!mounted) return;
      if (result.posts.isNotEmpty) {
        setState(() {
          _posts
            ..clear()
            ..addAll(result.posts);
          _nextCursor      = result.nextCursor;
          _feedFullyLoaded = result.nextCursor == null;
          _feedError       = false;
        });
        unawaited(LocalDb.instance.saveFeedPosts(result.posts));
      }
    } catch (_) {
      // Silently ignore � user is already seeing stale data, which is fine
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

  void _toggleSave(int index) async {
    final post = _posts[index];
    final wasSaved = post.isSaved;
    setState(() {
      _posts[index] = post.copyWith(
        isSaved: !wasSaved,
      );
    });
    try {
      if (wasSaved) {
        await PostService.instance.unsavePost(post.id);
      } else {
        await PostService.instance.savePost(post.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts[index] = post.copyWith(
          isSaved: wasSaved,
        );
      });
    }
  }

  Future<void> _loadUnreadNotifCount() async {}

  void _listenForNewNotifications() {
    _fcmNotifSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final msgType = msg.data['type'] as String?;
      if (msgType == 'follow') {
        if (mounted && !_islandOpen) {
          setState(() => _unreadNotifs++);
        }
      }
    });

    _wsNotifSub = ChatService().notificationStream.listen((data) {
      final type = data['type'] as String?;
      if (type == 'follow' || type == 'notification') {
        if (mounted && !_islandOpen) {
          setState(() => _unreadNotifs++);
        }
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    // Keep the launcher-icon badge in sync whenever we recompute unread counts
    // (app open, returning from chat). Server is authoritative (msgs + notifs).
    unawaited(AppBadgeService.refresh());
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
            SkillScoreScreen(
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
    homeFeedActive.value = false;
    setState(() {
      _islandOpen = true;
      _unreadNotifs = 0;
    });
    _islandCtrl.forward(from: 0);
  }

  void _closeIsland() {
    HapticFeedback.lightImpact();
    _islandCtrl.reverse().then((_) {
      if (mounted) {
        setState(() => _islandOpen = false);
        homeFeedActive.value = true;
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
        HomeOrb(color: (isDark ? Colors.white : Colors.black).op(0.05),
            size: 300, top: 100, left: -50),
        HomeOrb(color: (isDark ? Colors.white : Colors.black).op(0.03),
            size: 250, bottom: 150, right: -30),
        Positioned.fill(child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1)),
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
              padding: EdgeInsets.only(top: topPad + 56, bottom: _navOpen ? kNavBtnSize + kNavGap + 30 : 0),
              cacheExtent: 1200,
              itemCount: _posts.isEmpty
                  ? 2
                  : _posts.length + 2 + (_showSuggestionsTab ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == 0) return StorySection(isDark: isDark, myProfilePic: _myProfilePic, myName: _myProfileName);
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
                      height: 240,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 40,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.20),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Could not load feed',
                              style: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.65),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () => _loadFeed(refresh: true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.07),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : Colors.black.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.85),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height: 200,
                    child: Center(child: Text('No posts yet'.tr(ctx),
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.38),
                        fontSize: 14,
                    ))),
                  );
                }
                if (_showSuggestionsTab && i == 4) {
                  return FollowerSuggestionsTab(
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
                                  .withValues(alpha: 0.35),
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
                  onSave: () => _toggleSave(postIdx),
                  onLearnWatched: _markLearnContentWatched,
                  postIndex: postIdx,
                  allPosts: _posts,
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

          Align(alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: _islandOpen ? null : _openIsland,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TrandiaIsland(key: _islandKey, isDark: isDark),
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
                        size: const Size(kIconSize, kIconSize),
                        painter: EnvelopeIconPainter(isDark: isDark)))),
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
            bottom: _navHorizontal ? 30 : 30 + kNavBtnSize + kNavGap,
            right: _navHorizontal ? 20 + kNavBtnSize + kNavGap : 20,
            child: AnimatedBuilder(animation: _navCtrl,
              builder: (_, __) => IgnorePointer(ignoring: !_navOpen,
                child: StaggeredNavbar(
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
            child: InfinityBtn(
              isDark: isDark,
              isOpen: _navOpen,
              onTap: _toggleNav,
              onLongPress: _openHorizontalNav,
              onDoubleTap: () => _openQuickReel(isDark),
            )),
        ])),

        // -- Dynamic Island expand overlay ------------------
        if (_islandOpen)
          Positioned.fill(
            child: IslandNotificationOverlay(
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
