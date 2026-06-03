// profile_screen.dart
// Coordinator — wires together profile widgets.
// Actual UI sections are in lib/widgets/profile/.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'glass_common.dart';
import 'followers_screen(1).dart';
import 'setting_screen.dart';
import '../models/chat_model.dart';
import '../services/user_service.dart';
import '../services/location_service.dart';
import '../services/post_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/profile/profile_cover_band.dart';
import '../widgets/profile/profile_header_info.dart';
import '../widgets/profile/profile_social_links.dart';
import '../widgets/profile/profile_posts_box.dart';

class ProfileScreen extends StatefulWidget {
  final bool dark;
  const ProfileScreen({super.key, required this.dark});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _tab = 'Posts';
  List<PostModel> _userPosts = [];
  bool _postsLoading = true;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isUpdatingLocation = false;
  bool _isPrivateAccount = false;
  String _accountType = '';
  List<String> _platformOrder = [
    'snapchat',
    'instagram',
    'whatsapp',
    'facebook',
    'twitter',
    'youtube',
  ];

  final _profileScrollCtrl = ScrollController();
  String? _nextPostCursor;
  bool _isLoadingMorePosts = false;

  @override
  void initState() {
    super.initState();
    _profileScrollCtrl.addListener(_onProfileScroll);
    _loadProfile();
  }

  @override
  void dispose() {
    _profileScrollCtrl.dispose();
    super.dispose();
  }

  void _onProfileScroll() {
    if (_profileScrollCtrl.position.pixels >=
        _profileScrollCtrl.position.maxScrollExtent - 300) {
      _loadMorePosts();
    }
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedOrder = prefs.getStringList('social_platform_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      final validPlatforms = {
        'snapchat',
        'instagram',
        'whatsapp',
        'facebook',
        'twitter',
        'youtube',
      };
      final loadedOrder =
          savedOrder.where((e) => validPlatforms.contains(e)).toList();
      for (final p in validPlatforms) {
        if (!loadedOrder.contains(p)) loadedOrder.add(p);
      }
      _platformOrder = loadedOrder;
    }
    final accountType = prefs.getString('settings_account_type') ?? '';

    final cached = UserService.cachedProfile;
    if (cached != null && !forceRefresh) {
      setState(() {
        _profile = cached;
        _accountType = accountType;
        _isPrivateAccount = accountType == 'Private';
        _isLoading = false;
      });
      if (_userPosts.isEmpty) _loadPosts(cached.id);
    } else {
      setState(() {
        _isLoading = true;
        _accountType = accountType;
        _isPrivateAccount = accountType == 'Private';
      });
    }

    try {
      final profile = await UserService.getMyProfile(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      if (profile != null) {
        setState(() {
          _profile = profile;
          _accountType = accountType;
          _isPrivateAccount = accountType == 'Private';
          _isLoading = false;
        });
        if (cached == null || forceRefresh) _loadPosts(profile.id);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPosts(String userId) async {
    if (!mounted) return;
    setState(() {
      _postsLoading = true;
      _nextPostCursor = null;
    });
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
    if (_isLoadingMorePosts ||
        _nextPostCursor == null ||
        _profile == null) return;
    setState(() => _isLoadingMorePosts = true);
    try {
      final result = await PostService.instance.getUserPosts(
        _profile!.id,
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

  Future<void> _handleLocationTap() async {
    if (!mounted) return;
    final hasLocation = _profile?.locationCity?.isNotEmpty == true;
    if (hasLocation) {
      await _showLocationOptions();
    } else {
      setState(() => _isUpdatingLocation = true);
      final success = await LocationService.requestAndSaveLocation(context);
      if (success && mounted) await _loadProfile(forceRefresh: true);
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  Future<void> _showLocationOptions() async {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final isPublic = _profile?.locationPublic ?? true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: dark ? const Color(0xFF1C1C1F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  isPublic
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: fg,
                ),
                title: Text(
                  isPublic
                      ? 'Hide location from others'
                      : 'Show location to others',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _isUpdatingLocation = true);
                  await UserService.updateLocationPrivacy(!isPublic);
                  UserService.invalidateProfileCache();
                  await _loadProfile(forceRefresh: true);
                  if (mounted) setState(() => _isUpdatingLocation = false);
                },
              ),
              ListTile(
                leading: Icon(Icons.my_location_rounded, color: fg),
                title: Text(
                  'Update location',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _isUpdatingLocation = true);
                  final success =
                      await LocationService.requestAndSaveLocation(context);
                  if (success && mounted)
                    await _loadProfile(forceRefresh: true);
                  if (mounted) setState(() => _isUpdatingLocation = false);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.location_off_outlined,
                  color: Color(0xFFFF3B30),
                ),
                title: const Text(
                  'Remove location',
                  style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _isUpdatingLocation = true);
                  await UserService.removeLocation();
                  UserService.invalidateProfileCache();
                  await _loadProfile(forceRefresh: true);
                  if (mounted) setState(() => _isUpdatingLocation = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFollowers(FollowersTab initialTab) {
    if (_profile == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FollowersScreen(
          dark: widget.dark,
          userId: _profile!.id,
          userHandle: _profile!.username,
          initialTab: initialTab,
          totalFollowers: _profile!.followersCount,
          totalFollowing: _profile!.followingCount,
        ),
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
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ).then((_) => _loadProfile());
  }

  bool get _isCreatorAccount =>
      ['Business', 'Creator', 'Professional'].contains(_accountType);

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final muted = dark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.72);
    final hairline = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: _isLoading && _profile == null
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
          : _profile == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load profile',
                    style: manrope(
                      size: 16,
                      weight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _loadProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Retry',
                        style: manrope(
                          size: 14,
                          weight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: SingleChildScrollView(
                controller: _profileScrollCtrl,
                child: DefaultTextStyle(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Top bar ──────────────────────────────────────
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          MediaQuery.paddingOf(context).top + 12,
                          12,
                          10,
                        ),
                        child: Row(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GlassCircleButton(
                                  dark: dark,
                                  icon: Icons.arrow_back_ios_new_rounded,
                                  iconSize: 16,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                                if (_isPrivateAccount) ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: Center(
                                      child: Icon(
                                        Icons.lock_rounded,
                                        size: 16,
                                        color: (dark
                                                ? Colors.white
                                                : const Color(0xFF1A1A1A))
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Spacer(),
                            GlassCircleButton(
                              dark: dark,
                              icon: Icons.settings_outlined,
                              iconSize: 19,
                              onTap: () {
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    pageBuilder: (_, animation, __) =>
                                        SettingsScreen(dark: dark),
                                    transitionDuration:
                                        const Duration(milliseconds: 320),
                                    reverseTransitionDuration:
                                        const Duration(milliseconds: 260),
                                    transitionsBuilder:
                                        (_, animation, __, child) {
                                      final curved = CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                        reverseCurve: Curves.easeInCubic,
                                      );
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.05),
                                          end: Offset.zero,
                                        ).animate(curved),
                                        child: FadeTransition(
                                          opacity: curved,
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                                ).then(
                                  (_) => _loadProfile(forceRefresh: true),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // ── Cover band + avatar ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          height: 218,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              ProfileCoverBand(
                                dark: dark,
                                fg: fg,
                                sub: sub,
                                hairline: hairline,
                                followersCount:
                                    _profile?.followersCount ?? 0,
                                followingCount:
                                    _profile?.followingCount ?? 0,
                                postCount: _userPosts.length,
                                onFollowersTap: () => _openFollowers(
                                  FollowersTab.followers,
                                ),
                                onFollowingTap: () => _openFollowers(
                                  FollowersTab.following,
                                ),
                              ),
                              Positioned(
                                top: 96,
                                child: Container(
                                  width: 116,
                                  height: 116,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dark
                                        ? const Color(0xFF0A0A0C)
                                        : const Color(0xFFFAFAFA),
                                    boxShadow: [
                                      BoxShadow(
                                        color: dark
                                            ? Colors.black.withValues(
                                                alpha: 0.8,
                                              )
                                            : const Color(
                                                0xFF14161E,
                                              ).withValues(alpha: 0.25),
                                        blurRadius: 36,
                                        offset: const Offset(0, 18),
                                        spreadRadius: -16,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: UserAvatar(
                                      pictureUrl: _profile?.picture,
                                      name: _profile?.name ?? '?',
                                      size: 108,
                                      dark: dark,
                                      index: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Name + handle ────────────────────────────────
                      ProfileNameBlock(
                        dark: dark,
                        fg: fg,
                        sub: sub,
                        name: _profile?.name ?? '',
                        username: _profile?.username ?? '',
                      ),

                      const SizedBox(height: 10),

                      // ── Location chip ────────────────────────────────
                      Center(
                        child: ProfileLocationChip(
                          dark: dark,
                          city: _profile?.locationCity,
                          isPublic: _profile?.locationPublic ?? true,
                          isLoading: _isUpdatingLocation,
                          onTap: _handleLocationTap,
                        ),
                      ),

                      // ── Account type chip ────────────────────────────
                      if (_isCreatorAccount) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: ProfileTitleChip(
                            dark: dark,
                            muted: muted,
                            fg: fg,
                            label: '$_accountType Account',
                          ),
                        ),
                      ],

                      // ── Bio ──────────────────────────────────────────
                      if (_profile?.bio?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                          child: Text(
                            _profile!.bio!,
                            textAlign: TextAlign.center,
                            style: manrope(
                              size: 13.5,
                              weight: FontWeight.w500,
                              color: muted,
                              letterSpacing: -0.07,
                              height: 1.55,
                            ),
                          ),
                        ),

                      // ── Creator dashboard card ───────────────────────
                      if (_isCreatorAccount) ...[
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ProfileCreatorDashboardCard(
                            dark: dark,
                            fg: fg,
                            sub: sub,
                            accountType: _accountType,
                          ),
                        ),
                      ],

                      // ── Social links ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ProfileSocialLinksRow(
                          dark: dark,
                          fg: fg,
                          profile: _profile,
                          platformOrder: _platformOrder,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Posts grid box ───────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ProfilePostsBox(
                          dark: dark,
                          fg: fg,
                          sub: sub,
                          posts: _userPosts,
                          isLoading: _postsLoading,
                          isLoadingMore: _isLoadingMorePosts,
                          myUserId: _profile?.id,
                          onPostDeleted: (postId) {
                            setState(() {
                              _userPosts.removeWhere((p) => p.id == postId);
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
