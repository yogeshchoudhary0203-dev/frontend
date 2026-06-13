// lib/screens/profile/profile_screen.dart
//
// Glass User Profile — single file. Matches the matte-glass monochrome system
// from login_screen.dart.
// • Auto theme: follows the device system brightness (light/dark)
// • Layout: top bar → stats card (overlapping avatar) → name → title chip →
//           bio → social row → Follow / Message → posts section → 3-col grid
// • Pure black/white tones for content; brand colors only on social glyphs

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';
import '../services/follow_state.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/post_service.dart';
import '../services/block_service.dart';
import '../services/report_service.dart';
import '../widgets/report_sheet.dart';
import '../models/chat_model.dart';
import '../utils/error_dialog.dart';
import 'chat_screen.dart';

import '../widgets/profile/user_profile_backdrop.dart';
import '../widgets/profile/user_profile_stats_header.dart';
import '../widgets/profile/user_profile_header_info.dart';
import '../widgets/profile/user_profile_social_links.dart';
import '../widgets/profile/user_profile_buttons.dart';
import '../widgets/profile/user_profile_posts_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.userId = '',
    this.username = '',
    this.displayName = '',
    this.handle = '',
    this.title = '',
    this.bio = '',
    this.followers = '—',
    this.following = '—',
    this.posts = '0',
    this.postCount = 0,
    this.verified = false,
    this.initialFollowing = false,
  });

  final String userId;
  final String username;
  final String displayName;
  final String handle;
  final String title;
  final String bio;
  final String followers;
  final String following;
  final String posts;
  final int postCount;
  final bool verified;
  final bool initialFollowing;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late bool _isFollowing;
  bool _isFollowLoading = false;
  bool _isBlocked = false;
  bool _isBlockLoading = false;
  bool _blockedByThem = false; // they blocked us — profile inaccessible
  UserProfile? _profile;
  bool _profileLoading = true;
  List<PostModel> _userPosts = [];
  bool _postsLoading = false;

  // Post grid pagination
  final _scrollCtrl = ScrollController();
  String? _nextPostCursor;
  bool _isLoadingMorePosts = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = FollowState.get(widget.userId) ?? widget.initialFollowing;
    _scrollCtrl.addListener(_onScroll);
    FollowState.notifier.addListener(_onGlobalFollowChanged);
    if (widget.userId.isNotEmpty) {
      _loadProfile();
      _loadPosts(widget.userId);
    }
  }

  @override
  void dispose() {
    FollowState.notifier.removeListener(_onGlobalFollowChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onGlobalFollowChanged() {
    final v = FollowState.get(widget.userId);
    if (v != null && mounted && v != _isFollowing) setState(() => _isFollowing = v);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMorePosts();
    }
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() => _profileLoading = true);
    try {
      final p = await UserService.getUserProfile(widget.userId);
      developer.log('_loadProfile: picture=${p?.picture}, name=${p?.name}');
      if (mounted && p != null) {
        FollowState.set(widget.userId, p.isFollowing);
        setState(() {
          _profile = p;
          _isFollowing = p.isFollowing;
          _isBlocked = BlockService.instance.isBlocked(widget.userId);
          _profileLoading = false;
        });
      } else if (mounted) {
        setState(() => _profileLoading = false);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('blocked_by_user') || msg.contains('403')) {
        if (mounted) setState(() { _blockedByThem = true; _profileLoading = false; });
      } else {
        if (mounted) setState(() => _profileLoading = false);
      }
    }
  }

  Future<void> _loadPosts(String userId) async {
    if (!mounted) return;
    setState(() { _postsLoading = true; _nextPostCursor = null; });
    try {
      final result = await PostService.instance.getUserPosts(userId);
      if (mounted) {
        setState(() {
          _userPosts = result.posts;
          _nextPostCursor = result.nextCursor;
          _postsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMorePosts || _nextPostCursor == null || widget.userId.isEmpty) return;
    setState(() => _isLoadingMorePosts = true);
    try {
      final result = await PostService.instance.getUserPosts(
        widget.userId,
        cursor: _nextPostCursor,
      );
      if (mounted) {
        setState(() {
          _userPosts.addAll(result.posts);
          _nextPostCursor = result.nextCursor;
          _isLoadingMorePosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMorePosts = false);
    }
  }

  void _showMoreMenu() {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              _isBlocked ? Icons.check_circle_outline : Icons.block_rounded,
              color: _isBlocked ? Colors.green : Colors.redAccent,
            ),
            title: Text(
              _isBlocked ? 'Unblock User' : 'Block User',
              style: TextStyle(
                color: _isBlocked ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _handleBlock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.outlined_flag_rounded, color: Colors.redAccent),
            title: const Text(
              'Report User',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(ctx);
              showReportSheet(
                context,
                targetType: ReportService.targetUser,
                targetId: widget.userId,
              );
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _handleBlock() async {
    if (widget.userId.isEmpty || _isBlockLoading) return;
    final wasBlocked = _isBlocked;

    // Confirm before blocking
    if (!wasBlocked) {
      final t = Theme.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Block user?'),
          content: Text('${widget.displayName.isNotEmpty ? widget.displayName : widget.username} '
              'will not be able to see your profile, send you messages, or find you in search.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Block', style: TextStyle(color: t.colorScheme.error)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() { _isBlocked = !wasBlocked; _isBlockLoading = true; });
    try {
      if (wasBlocked) {
        await BlockService.instance.unblockUser(widget.userId);
      } else {
        await BlockService.instance.blockUser(widget.userId);
        if (mounted) Navigator.maybePop(context); // close profile after block
      }
    } catch (_) {
      if (mounted) setState(() => _isBlocked = wasBlocked);
    } finally {
      if (mounted) setState(() => _isBlockLoading = false);
    }
  }

  Future<void> _handleFollow() async {
    if (widget.userId.isEmpty || _isFollowLoading) return;
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !wasFollowing;
      _isFollowLoading = true;
    });
    final success = wasFollowing
        ? await UserService.unfollowUser(widget.userId)
        : await UserService.followUser(widget.userId);
    if (!mounted) return;
    if (!success) {
      setState(() => _isFollowing = wasFollowing);
      showErrorDialog(context, message: wasFollowing ? 'Failed to unfollow' : 'Failed to follow');
    }
    setState(() => _isFollowLoading = false);
  }

  Future<void> _handleMessage() async {
    if (widget.username.isEmpty) return;
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    try {
      final myUserId = await AuthService.getCurrentUserId();
      if (!mounted) return;
      bool dialogOpen = false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      dialogOpen = true;
      final convId = await ChatService().startConversation(widget.username);
      if (mounted && dialogOpen) {
        Navigator.of(context).pop();
        dialogOpen = false;
      }
      if (!mounted) return;
      final conversation = ChatConversation(
        id: convId,
        participants: [
          UserProfile(id: myUserId ?? '', name: 'Me', username: 'me'),
          UserProfile(
            id: widget.userId,
            name: widget.displayName,
            username: widget.username,
          ),
        ],
        lastMessage: null,
        lastMessageTime: null,
        unreadCounts: {},
        isGroup: false,
      );
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => ChatScreen(
            dark: isDark,
            conversation: conversation,
            myUserId: myUserId ?? '',
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
                begin: const Offset(1.0, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        ),
      );
    } catch (e) {
      developer.log('_handleMessage error: $e');
      if (mounted) {
        try { Navigator.of(context).pop(); } catch (_) {}
        showErrorDialog(context, message: 'Could not start chat: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final t = UserProfileGlassTheme.of(isDark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: t.bgStops.last,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    // They blocked us — show minimal screen
    if (_blockedByThem) {
      return Scaffold(
        backgroundColor: t.bgStops.last,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.fg),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            const Spacer(),
            Icon(Icons.block_rounded, size: 52, color: t.fg.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'User not available',
              style: TextStyle(color: t.fg, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'This account is not available.',
              style: TextStyle(color: t.fg.withValues(alpha: 0.5), fontSize: 14),
            ),
            const Spacer(flex: 2),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bgStops.last,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop ─────────────────────────────────────────────────
            Positioned.fill(child: UserProfileBackdrop(t: t)),

            // Scrollable content ───────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(top: 56, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UserProfileStatsHeader(
                      t: t,
                      followers: _profile != null
                          ? _formatCount(_profile!.followersCount)
                          : (_profileLoading ? '—' : widget.followers),
                      following: _profile != null
                          ? _formatCount(_profile!.followingCount)
                          : (_profileLoading ? '—' : widget.following),
                      posts: _formatCount(_userPosts.length),
                      initial: (_profile?.name ?? widget.displayName).isNotEmpty
                          ? (_profile?.name ?? widget.displayName)[0].toUpperCase()
                          : '?',
                      pictureUrl: _profile?.picture,
                    ),
                    const SizedBox(height: 68),
                    if (_profileLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.muted,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      UserProfileNameRow(
                        t: t,
                        name: _profile?.name ?? widget.displayName,
                        verified: _profile != null ? false : widget.verified,
                      ),
                      const SizedBox(height: 10),
                      Center(child: UserProfileTitleChip(t: t, label: '@${_profile?.username ?? widget.username}')),
                      if ((_profile?.locationCity?.isNotEmpty == true)) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: UserProfileLocationBadge(
                            t: t,
                            city: _profile!.locationCity!,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if ((_profile?.bio ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            _profile!.bio!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              fontWeight: FontWeight.w500,
                              color: t.muted,
                              letterSpacing: -0.05,
                            ),
                          ),
                        ),
                      if ((_profile?.link ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        UserProfileWebsiteChip(t: t, url: _profile!.link!),
                      ],
                      const SizedBox(height: 16),
                      UserProfileSocialRow(t: t, profile: _profile),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          if (widget.userId.isNotEmpty) ...[
                            Expanded(
                              child: UserProfileFollowButton(
                                t: t,
                                following: _isFollowing,
                                onTap: _handleFollow,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: UserProfileMessageButton(t: t, onTap: _handleMessage),
                            ),
                          ],
                        ]),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: UserProfilePostsSection(
                        t: t,
                        posts: _userPosts,
                        isLoading: _postsLoading,
                        isLoadingMore: _isLoadingMorePosts,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        UserProfileCircleIconButton(
                          t: t,
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.maybePop(context),
                        ),
                        const Spacer(),
                        UserProfileCircleIconButton(
                          t: t,
                          icon: Icons.ios_share_rounded,
                          onTap: () {},
                        ),
                        const SizedBox(width: 8),
                        UserProfileCircleIconButton(
                          t: t,
                          icon: Icons.more_vert_rounded,
                          onTap: widget.userId.isNotEmpty ? () => _showMoreMenu() : () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
