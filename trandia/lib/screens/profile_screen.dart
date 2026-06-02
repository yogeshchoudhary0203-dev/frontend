// profile_screen.dart
// Classy, professional profile screen — matte glass monochrome.
// Layout: top bar → cover band → overlapping avatar → name/handle →
// title chip → bio → website → stats card → CTAs → highlights → tabs → grid.
//
// Drop in `lib/` alongside glass_common.dart.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'glass_common.dart';
import 'followers_screen(1).dart';
import 'setting_screen.dart';
import 'creator_profile_screen.dart';
import '../models/chat_model.dart';
import '../services/user_service.dart';
import '../services/location_service.dart';
import '../services/post_service.dart';
import '../l10n/app_localizations.dart';

// ───────────────────────────────────────────────────────────────
// Models
// ───────────────────────────────────────────────────────────────

class HighlightItem {
  final String label;
  final int seed;
  const HighlightItem(this.label, this.seed);
}

const _highlights = <HighlightItem>[
  HighlightItem('Work', 1),
  HighlightItem('Studio', 2),
  HighlightItem('Travel', 3),
  HighlightItem('Reads', 4),
  HighlightItem('Type', 5),
];

/// Wider tonal range tile gradient.
LinearGradient _tileGradient(bool dark, int i) {
  final double a, b;
  if (dark) {
    a = (22 - (i % 5) * 3).toDouble();
    b = (a - 12).clamp(4, 100).toDouble();
  } else {
    a = (92 - (i % 5) * 4).toDouble();
    b = (a - 18).clamp(56, 100).toDouble();
  }
  final begin = (i % 4 == 0)
      ? Alignment.topLeft
      : (i % 4 == 1)
      ? Alignment.topCenter
      : (i % 4 == 2)
      ? Alignment.topRight
      : Alignment.centerLeft;
  final end = (i % 4 == 0)
      ? Alignment.bottomRight
      : (i % 4 == 1)
      ? Alignment.bottomCenter
      : (i % 4 == 2)
      ? Alignment.bottomLeft
      : Alignment.centerRight;
  return LinearGradient(
    begin: begin,
    end: end,
    colors: [
      HSLColor.fromAHSL(1, 0, 0, a / 100).toColor(),
      HSLColor.fromAHSL(1, 0, 0, b / 100).toColor(),
    ],
  );
}

// ───────────────────────────────────────────────────────────────
// ProfileScreen
// ───────────────────────────────────────────────────────────────

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
  List<String> _platformOrder = ['snapchat', 'instagram', 'whatsapp', 'facebook', 'twitter', 'youtube'];

  // Post grid pagination
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

    // ── Step 1: Read SharedPreferences (fast, local) ──────────────────────
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedOrder = prefs.getStringList('social_platform_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      final validPlatforms = {'snapchat', 'instagram', 'whatsapp', 'facebook', 'twitter', 'youtube'};
      final loadedOrder = savedOrder.where((e) => validPlatforms.contains(e)).toList();
      for (final p in validPlatforms) {
        if (!loadedOrder.contains(p)) loadedOrder.add(p);
      }
      _platformOrder = loadedOrder;
    }
    final accountType = prefs.getString('settings_account_type') ?? '';

    // ── Step 2: Render cached profile instantly (no loader flash) ─────────
    final cached = UserService.cachedProfile;
    if (cached != null && !forceRefresh) {
      setState(() {
        _profile = cached;
        _accountType = accountType;
        _isPrivateAccount = accountType == 'Private';
        _isLoading = false;
      });
      // Load posts from ApiService cache (also fast — 90s TTL)
      if (_userPosts.isEmpty) _loadPosts(cached.id);
    } else {
      // No cache — show loader
      setState(() {
        _isLoading = true;
        _accountType = accountType;
        _isPrivateAccount = accountType == 'Private';
      });
    }

    // ── Step 3: Background refresh from network ───────────────────────────
    try {
      final profile = await UserService.getMyProfile(forceRefresh: forceRefresh);
      if (!mounted) return;
      if (profile != null) {
        setState(() {
          _profile = profile;
          _accountType = accountType;
          _isPrivateAccount = accountType == 'Private';
          _isLoading = false;
        });
        // Reload posts if we had no cache before, or on forced refresh
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
    if (_isLoadingMorePosts || _nextPostCursor == null || _profile == null) return;
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
                  isPublic ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: fg,
                ),
                title: Text(
                  isPublic ? 'Hide location from others' : 'Show location to others',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
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
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _isUpdatingLocation = true);
                  final success = await LocationService.requestAndSaveLocation(context);
                  if (success && mounted) await _loadProfile(forceRefresh: true);
                  if (mounted) setState(() => _isUpdatingLocation = false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_off_outlined, color: Color(0xFFFF3B30)),
                title: const Text(
                  'Remove location',
                  style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
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
    ).then((_) {
      _loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_profile != null && ['Business', 'Creator', 'Professional'].contains(_accountType)) {
      return CreatorProfileScreen(
        dark: widget.dark,
        displayName: _profile!.name,
        handle: _profile!.username,
        title: '$_accountType Account',
        bio: _profile!.bio ?? '',
        followers: _profile!.followersCount.toString(),
        following: _profile!.followingCount.toString(),
        posts: _userPosts.length.toString(),
        postCount: _userPosts.length,
        avatarUrl: _profile!.picture ?? '',
        owner: true,
        userPosts: _userPosts,
        postsLoading: _postsLoading,
        myUserId: _profile!.id,
        reach: '',
        profileViews: '',
        engagement: '',
        onOpenSettings: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, animation, __) => SettingsScreen(dark: widget.dark),
              transitionDuration: const Duration(milliseconds: 320),
              reverseTransitionDuration: const Duration(milliseconds: 260),
              transitionsBuilder: (_, animation, __, child) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
                  child: FadeTransition(opacity: curved, child: child),
                );
              },
            ),
          ).then((_) => _loadProfile(forceRefresh: true));
        },
        onPostDeleted: (postId) {
          setState(() => _userPosts.removeWhere((p) => p.id == postId));
        },
      );
    }

    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final muted = dark
        ? Colors.white.withOpacity(0.72)
        : Colors.black.withOpacity(0.72);
    final hairline = dark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

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
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.08),
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
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              12,
                              MediaQuery.paddingOf(context).top + 12,
                              12,
                              10,
                            ),
                            child: Row(
                              children: [
                                // Back arrow + private lock icon
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GlassCircleButton(
                                      dark: dark,
                                      icon: Icons.arrow_back_ios_new_rounded,
                                      iconSize: 16,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    if (_isPrivateAccount) ...
                                    [
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: Center(
                                          child: Icon(
                                            Icons.lock_rounded,
                                            size: 16,
                                            color: (dark ? Colors.white : const Color(0xFF1A1A1A))
                                                .withOpacity(0.55),
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
                                        transitionDuration: const Duration(
                                          milliseconds: 320,
                                        ),
                                        reverseTransitionDuration: const Duration(
                                          milliseconds: 260,
                                        ),
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
                                            child: FadeTransition(
                                              opacity: curved,
                                              child: child,
                                            ),
                                          );
                                        },
                                      ),
                                    ).then((_) => _loadProfile(forceRefresh: true));
                                  },
                                ),
                              ],
                            ),
                          ),

                          // COVER BAND + AVATAR
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              height: 218,
                              child: Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  _CoverBand(
                                    dark: dark,
                                    fg: fg,
                                    sub: sub,
                                    hairline: hairline,
                                    followersCount: _profile?.followersCount ?? 0,
                                    followingCount: _profile?.followingCount ?? 0,
                                    postCount: _userPosts.length,
                                    onFollowersTap: () =>
                                        _openFollowers(FollowersTab.followers),
                                    onFollowingTap: () =>
                                        _openFollowers(FollowersTab.following),
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
                                                ? Colors.black.withOpacity(0.8)
                                                : const Color(
                                                    0xFF14161E,
                                                  ).withOpacity(0.25),
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

                          // NAME + HANDLE
                          _NameBlock(
                            dark: dark,
                            fg: fg,
                            sub: sub,
                            name: _profile?.name ?? '',
                            username: _profile?.username ?? '',
                          ),

                          const SizedBox(height: 10),

                          // LOCATION CHIP
                          Center(
                            child: _LocationChip(
                              dark: dark,
                              city: _profile?.locationCity,
                              isPublic: _profile?.locationPublic ?? true,
                              isLoading: _isUpdatingLocation,
                              onTap: _handleLocationTap,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // TITLE CHIP
                          Center(
                            child: _TitleChip(dark: dark, muted: muted, fg: fg),
                          ),

                          // BIO
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                            child: Text(
                              _profile?.bio?.isNotEmpty == true
                                  ? _profile!.bio!
                                  : 'Designer & art director.\n'
                                      'Currently leading visual identity at Studio Atelier — '
                                      'type, motion & quiet things.',
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

                          // SOCIAL LINKS
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _SocialLinksRow(
                              dark: dark,
                              fg: fg,
                              profile: _profile,
                              platformOrder: _platformOrder,
                            ),
                          ),

                          const SizedBox(height: 18),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _PostsBox(
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

Future<void> _openSocialLink(String url, String platform) async {
  if (url.trim().isEmpty) return;
  String finalUrl = url.trim();
  if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
    if (platform.toLowerCase() == 'whatsapp') {
      if (finalUrl.startsWith('+') || RegExp(r'^\d+$').hasMatch(finalUrl)) {
        finalUrl = 'https://wa.me/$finalUrl';
      } else {
        finalUrl = 'https://$finalUrl';
      }
    } else {
      finalUrl = 'https://$finalUrl';
    }
  }
  final uri = Uri.parse(finalUrl);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class _SocialLinksRow extends StatelessWidget {
  final bool dark;
  final Color fg;
  final UserProfile? profile;
  final List<String> platformOrder;
  const _SocialLinksRow({
    required this.dark,
    required this.fg,
    required this.platformOrder,
    this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    for (int i = 0; i < platformOrder.length; i++) {
      final platform = platformOrder[i];
      if (platform == 'snapchat') {
        buttons.add(
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.snapchat,
            color: const Color(0xFFFFFC00),
            label: 'Snapchat',
            url: profile?.snapchatLink?.isNotEmpty == true
                ? profile!.snapchatLink!
                : 'https://www.snapchat.com/add/sarah.d',
            platform: 'snapchat',
          ),
        );
      } else if (platform == 'instagram') {
        buttons.add(
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.instagram,
            color: const Color(0xFFE4405F),
            label: 'Instagram',
            url: profile?.instagramLink?.isNotEmpty == true
                ? profile!.instagramLink!
                : 'https://www.instagram.com/sarah.d',
            platform: 'instagram',
          ),
        );
      } else if (platform == 'whatsapp') {
        buttons.add(
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.whatsapp,
            color: const Color(0xFF25D366),
            label: 'WhatsApp',
            url: profile?.whatsappLink?.isNotEmpty == true
                ? profile!.whatsappLink!
                : 'https://wa.me/15551234567',
            platform: 'whatsapp',
          ),
        );
      } else if (platform == 'facebook') {
        buttons.add(
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.facebookF,
            color: const Color(0xFF1877F2),
            label: 'Facebook',
            url: profile?.facebookLink?.isNotEmpty == true
                ? profile!.facebookLink!
                : 'https://www.facebook.com/sarah.d',
            platform: 'facebook',
          ),
        );
      } else if (platform == 'twitter') {
        buttons.add(
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.xTwitter,
            color: dark ? Colors.white : const Color(0xFF000000),
            label: 'Twitter',
            url: profile?.twitterLink?.isNotEmpty == true
                ? profile!.twitterLink!
                : 'https://twitter.com/sarah_d',
            platform: 'twitter',
          ),
        );
      } else if (platform == 'youtube') {
        buttons.add(
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.youtube,
            color: const Color(0xFFFF0000),
            label: 'YouTube',
            url: profile?.youtubeLink?.isNotEmpty == true
                ? profile!.youtubeLink!
                : 'https://www.youtube.com',
            platform: 'youtube',
          ),
        );
      }

      if (i < platformOrder.length - 1) {
        buttons.add(const SizedBox(width: 10));
      }
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons,
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final Color color;
  final String label;
  final String url;
  final String platform;
  const _SocialButton({
    required this.dark,
    required this.icon,
    required this.color,
    required this.label,
    required this.url,
    required this.platform,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => _openSocialLink(url, platform),
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.8),
            border: Border.all(
              color: dark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.28 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -10,
              ),
            ],
          ),
          child: FaIcon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _PostsBox extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? myUserId;
  final void Function(String postId)? onPostDeleted;

  const _PostsBox({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.posts,
    required this.isLoading,
    this.isLoadingMore = false,
    this.myUserId,
    this.onPostDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      dark: dark,
      radius: 28,
      padding: const EdgeInsets.all(10),
      blurSigma: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
            child: Row(
              children: [
                Text(
                  'Posts',
                  style: manrope(
                    size: 14,
                    weight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${posts.length}',
                  style: manrope(
                    size: 12,
                    weight: FontWeight.w700,
                    color: sub,
                    letterSpacing: -0.12,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                  strokeWidth: 2,
                ),
              ),
            )
          else if (posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No posts yet',
                  style: manrope(size: 14, weight: FontWeight.w500, color: sub),
                ),
              ),
            )
          else ...[
            _ProfileGrid(
              dark: dark,
              posts: posts,
              myUserId: myUserId,
              onPostDeleted: onPostDeleted,
            ),
            if (isLoadingMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Cover band
// ───────────────────────────────────────────────────────────────

class _CoverBand extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final Color hairline;
  final int followersCount;
  final int followingCount;
  final int postCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  const _CoverBand({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.hairline,
    required this.followersCount,
    required this.followingCount,
    required this.postCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: const Alignment(-0.2, -1),
          end: const Alignment(0.6, 1),
          colors: dark
              ? const [Color(0xFF1C1C1F), Color(0xFF0D0D10), Color(0xFF050507)]
              : const [Color(0xFFEFEFEF), Color(0xFFD6D6DA)],
          stops: dark ? const [0.0, 0.6, 1.0] : const [0.0, 1.0],
        ),
        border: Border.all(
          color: dark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.95),
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withOpacity(0.7)
                : const Color(0xFF14161E).withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // top sheen
            Positioned(
              top: 0,
              left: 24,
              right: 24,
              height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? [
                            Colors.transparent,
                            Colors.white.withOpacity(0.18),
                            Colors.transparent,
                          ]
                        : [
                            Colors.transparent,
                            Colors.white,
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
            // diagonal stripe texture
            CustomPaint(
              painter: _DiagonalStripesPainter(dark: dark),
              size: Size.infinite,
            ),
            Positioned(
              left: 18,
              right: 18,
              top: 42,
              child: _CoverStatsRow(
                fg: fg,
                sub: sub,
                hairline: hairline,
                followersCount: followersCount,
                followingCount: followingCount,
                postCount: postCount,
                onFollowersTap: onFollowersTap,
                onFollowingTap: onFollowingTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverStatsRow extends StatelessWidget {
  final Color fg;
  final Color sub;
  final Color hairline;
  final int followersCount;
  final int followingCount;
  final int postCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  const _CoverStatsRow({
    required this.fg,
    required this.sub,
    required this.hairline,
    required this.followersCount,
    required this.followingCount,
    required this.postCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            value: _fmt(followersCount),
            label: 'Followers',
            fg: fg,
            sub: sub,
            onTap: onFollowersTap,
          ),
        ),
        Container(width: 1, height: 30, color: hairline),
        Expanded(
          child: _Stat(
            value: _fmt(followingCount),
            label: 'Following',
            fg: fg,
            sub: sub,
            onTap: onFollowingTap,
          ),
        ),
        Container(width: 1, height: 30, color: hairline),
        Expanded(
          child: _Stat(value: _fmt(postCount), label: 'Posts', fg: fg, sub: sub),
        ),
      ],
    );
  }
}

class _DiagonalStripesPainter extends CustomPainter {
  final bool dark;
  _DiagonalStripesPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withOpacity(
        dark ? 0.04 : 0.025,
      )
      ..strokeWidth = 1;
    const step = 19.0;
    // diagonal at 135deg
    final diag = size.width + size.height;
    for (double x = -diag; x < diag; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalStripesPainter old) => old.dark != dark;
}

// ───────────────────────────────────────────────────────────────
// Name + handle
// ───────────────────────────────────────────────────────────────

class _NameBlock extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final String name;
  final String username;
  const _NameBlock({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.name,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: manrope(
                    size: 24,
                    weight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.verified_rounded, size: 18, color: fg),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '@$username',
            style: manrope(
              size: 13,
              weight: FontWeight.w500,
              color: sub,
              letterSpacing: -0.065,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Title chip
// ───────────────────────────────────────────────────────────────

class _TitleChip extends StatelessWidget {
  final bool dark;
  final Color muted;
  final Color fg;
  const _TitleChip({required this.dark, required this.muted, required this.fg});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.6),
            border: Border.all(
              color: dark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.black.withOpacity(0.06),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.withOpacity(0.85),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Designer · Studio Atelier',
                style: manrope(
                  size: 12,
                  weight: FontWeight.w600,
                  color: muted,
                  letterSpacing: -0.12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Location chip (own profile)
// ───────────────────────────────────────────────────────────────

class _LocationChip extends StatelessWidget {
  final bool dark;
  final String? city;
  final bool isPublic;
  final bool isLoading;
  final VoidCallback onTap;
  const _LocationChip({
    required this.dark,
    required this.isPublic,
    required this.isLoading,
    required this.onTap,
    this.city,
  });

  @override
  Widget build(BuildContext context) {
    final hasCity = city?.isNotEmpty == true;
    final sub = GlassTokens.sub(dark);

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.6),
              border: Border.all(
                color: dark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.black.withOpacity(0.06),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(sub),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasCity
                            ? (isPublic
                                ? Icons.location_on_rounded
                                : Icons.location_off_rounded)
                            : Icons.add_location_alt_outlined,
                        size: 13,
                        color: hasCity
                            ? const Color(0xFFFF3B30)
                            : sub,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hasCity
                            ? (isPublic ? city! : '${city!} (hidden)')
                            : 'Add location',
                        style: manrope(
                          size: 12,
                          weight: FontWeight.w600,
                          color: hasCity ? GlassTokens.fg(dark).withOpacity(0.8) : sub,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Stats card
// ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final Color hairline;
  const _StatsCard({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.hairline,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      dark: dark,
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      blurSigma: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(value: '168', label: 'Posts', fg: fg, sub: sub),
          ),
          Container(
            width: 1,
            color: hairline,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
          Expanded(
            child: _Stat(value: '0', label: 'Followers', fg: fg, sub: sub),
          ),
          Container(
            width: 1,
            color: hairline,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
          Expanded(
            child: _Stat(value: '0', label: 'Following', fg: fg, sub: sub),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color fg;
  final Color sub;
  final VoidCallback? onTap;
  const _Stat({
    required this.value,
    required this.label,
    required this.fg,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: manrope(
            size: 20,
            weight: FontWeight.w800,
            color: fg,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.tr(context).toUpperCase(),
          style: manrope(
            size: 10.5,
            weight: FontWeight.w700,
            color: sub,
            letterSpacing: 1.05,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

// ───────────────────────────────────────────────────────────────
// CTAs
// ───────────────────────────────────────────────────────────────

class _PrimaryCta extends StatelessWidget {
  final bool dark;
  final String label;
  const _PrimaryCta({required this.dark, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: dark ? Colors.white : const Color(0xFF0A0A0A),
              foregroundColor: dark ? const Color(0xFF0A0A0A) : Colors.white,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: const StadiumBorder(),
              shadowColor: Colors.transparent,
            ).copyWith(
              overlayColor: MaterialStateProperty.all(
                (dark ? Colors.black : Colors.white).withOpacity(0.06),
              ),
            ),
        onPressed: () {},
        child: Text(
          label.tr(context),
          style: manrope(
            size: 14,
            weight: FontWeight.w800,
            color: dark ? const Color(0xFF0A0A0A) : Colors.white,
            letterSpacing: -0.14,
          ),
        ),
      ),
    );
  }
}

class _GhostCta extends StatelessWidget {
  final bool dark;
  final String label;
  const _GhostCta({required this.dark, required this.label});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.6),
            border: Border.all(
              color: dark
                  ? Colors.white.withOpacity(0.14)
                  : Colors.black.withOpacity(0.08),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label.tr(context),
            style: manrope(
              size: 14,
              weight: FontWeight.w700,
              color: fg,
              letterSpacing: -0.14,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleGlassBtn extends StatelessWidget {
  final bool dark;
  final double size;
  final Widget child;
  final VoidCallback? onTap;
  const _CircleGlassBtn({
    required this.dark,
    required this.size,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.6),
              border: Border.all(
                color: dark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: dark
                      ? Colors.black.withOpacity(0.7)
                      : const Color(0xFF14161E).withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -14,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Highlights
// ───────────────────────────────────────────────────────────────

class _HighlightsRow extends StatelessWidget {
  final bool dark;
  final Color sub;
  final Color muted;
  const _HighlightsRow({
    required this.dark,
    required this.sub,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              'HIGHLIGHTS',
              style: manrope(
                size: 11,
                weight: FontWeight.w700,
                color: sub,
                letterSpacing: 1.1,
              ),
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _highlights.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final h = _highlights[i];
                return SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark
                              ? Colors.white.withOpacity(0.14)
                              : Colors.black.withOpacity(0.14),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dark
                                ? const Color(0xFF0A0A0C)
                                : const Color(0xFFFAFAFA),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: monoAvatar(dark, h.seed),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        h.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: manrope(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: muted,
                          letterSpacing: -0.06,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Tabs pill
// ───────────────────────────────────────────────────────────────

class _TabsPill extends StatelessWidget {
  final bool dark;
  final String active;
  final Color muted;
  final ValueChanged<String> onChange;
  const _TabsPill({
    required this.dark,
    required this.active,
    required this.muted,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.6),
            border: Border.all(
              color: dark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.white.withOpacity(0.95),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              _TabButton(
                label: 'Posts',
                icon: Icons.grid_on_rounded,
                active: active == 'Posts',
                dark: dark,
                muted: muted,
                onTap: () => onChange('Posts'),
              ),
              _TabButton(
                label: 'Reels',
                icon: Icons.movie_creation_outlined,
                active: active == 'Reels',
                dark: dark,
                muted: muted,
                onTap: () => onChange('Reels'),
              ),
              _TabButton(
                label: 'Tagged',
                icon: Icons.local_offer_outlined,
                active: active == 'Tagged',
                dark: dark,
                muted: muted,
                onTap: () => onChange('Tagged'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool dark;
  final Color muted;
  final VoidCallback onTap;
  const _TabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.dark,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = dark ? Colors.white : const Color(0xFF0A0A0A);
    final activeFg = dark ? const Color(0xFF0A0A0A) : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? activeFg : muted),
              const SizedBox(width: 6),
              Text(
                label.tr(context),
                style: manrope(
                  size: 13,
                  weight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? activeFg : muted,
                  letterSpacing: -0.13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Profile grid
// ───────────────────────────────────────────────────────────────

class _ProfileGrid extends StatelessWidget {
  final bool dark;
  final List<PostModel> posts;
  final String? myUserId;
  final void Function(String postId)? onPostDeleted;

  const _ProfileGrid({
    required this.dark,
    required this.posts,
    this.myUserId,
    this.onPostDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) => _ProfileTileView(
        post: posts[i],
        i: i,
        dark: dark,
        myUserId: myUserId,
        onDeleted: () => onPostDeleted?.call(posts[i].id),
      ),
    );
  }
}

class _ProfileTileView extends StatelessWidget {
  final PostModel post;
  final int i;
  final bool dark;
  final String? myUserId;
  final VoidCallback? onDeleted;

  const _ProfileTileView({
    required this.post,
    required this.i,
    required this.dark,
    this.myUserId,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = post.mediaType == 'video';
    final imageUrl = isVideo && post.thumbnailUrl != null
        ? post.thumbnailUrl!
        : post.mediaUrl;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'post_card',
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => _PostCardModal(
            post: post,
            myUserId: myUserId,
            onDeleted: onDeleted,
          ),
          transitionBuilder: (ctx, anim, _, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutBack,
            );
            return FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: _tileGradient(dark, i),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
              if (isVideo)
                Positioned(
                  top: 6,
                  right: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        color: Colors.black.withOpacity(0.42),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
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

// ───────────────────────────────────────────────────────────────
// 3D Glass Post Card Modal
// ───────────────────────────────────────────────────────────────

class _PostCardModal extends StatefulWidget {
  final PostModel post;
  final String? myUserId;
  final VoidCallback? onDeleted;

  const _PostCardModal({
    required this.post,
    this.myUserId,
    this.onDeleted,
  });

  @override
  State<_PostCardModal> createState() => _PostCardModalState();
}

class _PostCardModalState extends State<_PostCardModal> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _liked = false;
  late int _likesCount;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    if (widget.post.isVideo) {
      _videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.post.mediaUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      )
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _videoReady = true);
            _videoCtrl!.play();
          }
        });
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    if (_liked) {
      PostService.instance.likePost(widget.post.id);
    } else {
      PostService.instance.unlikePost(widget.post.id);
    }
  }

  void _openComments() {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/comments', arguments: widget.post.id);
  }

  bool get _isOwner =>
      widget.myUserId != null && widget.post.userId == widget.myUserId;

  void _showOptions() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (sheetCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              if (_isOwner)
                _OptionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete Post',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.of(sheetCtx).pop(); // close only the sheet
                    _confirmDelete();
                  },
                ),
              _OptionTile(
                icon: Icons.copy_outlined,
                label: 'Copy Link',
                color: dark ? Colors.white : Colors.black87,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AlertDialog(
          backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Delete Post?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'This will permanently delete the post. This cannot be undone.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx); // close dialog
                await _executeDelete();
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeDelete() async {
    try {
      await PostService.instance.deletePost(widget.post.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted?.call();
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardW = size.width * 0.88;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          // blurred backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
          ),

          // 3D glass card
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(-0.015),
                child: Container(
                  width: cardW,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.white.withOpacity(0.07),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.40),
                        blurRadius: 42,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.05),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(),
                          _buildMedia(cardW),
                          _buildActions(),
                          if (widget.post.caption.isNotEmpty) _buildCaption(),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white.withOpacity(0.30)),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.50),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: widget.post.userPicture != null
                  ? Image.network(
                      widget.post.userPicture!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarFallback(widget.post.userName),
                    )
                  : _avatarFallback(widget.post.userName),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  '@${widget.post.userUsername}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            widget.post.timeAgo,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _showOptions,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.more_vert_rounded,
                color: Colors.white.withOpacity(0.75),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: Colors.white24,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildMedia(double cardW) {
    final isVideo = widget.post.isVideo;
    final thumbUrl = isVideo && widget.post.thumbnailUrl != null
        ? widget.post.thumbnailUrl!
        : widget.post.mediaUrl;
    final mediaH = cardW - 24;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: cardW - 24,
        height: mediaH,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black26),
            ),
            if (isVideo && _videoReady && _videoCtrl != null)
              GestureDetector(
                onTap: () => setState(() {
                  _videoCtrl!.value.isPlaying
                      ? _videoCtrl!.pause()
                      : _videoCtrl!.play();
                }),
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoCtrl!.value.size.width,
                      height: _videoCtrl!.value.size.height,
                      child: VideoPlayer(_videoCtrl!),
                    ),
                  ),
                ),
              ),
            if (isVideo && !_videoReady)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
            if (isVideo && _videoReady && _videoCtrl != null)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoCtrl!,
                builder: (_, val, __) {
                  if (val.isPlaying) return const SizedBox.shrink();
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            if (isVideo && _videoReady)
              Positioned(
                bottom: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _muted = !_muted;
                    _videoCtrl!.setVolume(_muted ? 0 : 1);
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          _ActionBtn(
            icon: _liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: _liked ? const Color(0xFFFF4D6D) : Colors.white,
            label: _fmt(_likesCount),
            onTap: _toggleLike,
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.mode_comment_outlined,
            iconColor: Colors.white,
            label: _fmt(widget.post.commentsCount),
            onTap: _openComments,
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.send_rounded,
            iconColor: Colors.white,
            label: _fmt(widget.post.sharesCount),
            onTap: () => HapticFeedback.selectionClick(),
          ),
          const Spacer(),
          _ActionBtn(
            icon: Icons.bookmark_border_rounded,
            iconColor: Colors.white,
            label: '',
            onTap: () => HapticFeedback.selectionClick(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Text(
        widget.post.caption,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(0.82),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n > 0 ? '$n' : '';
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
