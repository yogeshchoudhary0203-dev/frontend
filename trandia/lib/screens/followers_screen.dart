// followers_screen.dart
// Single-file Followers / Following screen — matte glass monochrome.
// Supports both Light and Dark themes via the `dark` flag.
//
// Requires in pubspec.yaml:
//   google_fonts: ^6.0.0
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => FollowersScreen(dark: true, initialTab: FollowersTab.followers),
//   ));

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_model.dart';
import '../services/user_service.dart';
import '../l10n/app_localizations.dart';
import 'glass_common.dart' show UserAvatar;

// ───────────────────────────────────────────────────────────────
// Public API
// ───────────────────────────────────────────────────────────────

enum FollowersTab { followers, following }

class FollowersScreen extends StatefulWidget {
  final bool dark;
  final FollowersTab initialTab;
  final String userId;
  final String userHandle;
  final int totalFollowers;
  final int totalFollowing;

  const FollowersScreen({
    super.key,
    required this.dark,
    required this.userId,
    this.initialTab = FollowersTab.followers,
    this.userHandle = '',
    this.totalFollowers = 0,
    this.totalFollowing = 0,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

// ───────────────────────────────────────────────────────────────
// Internal tokens / helpers (inlined so this file is standalone)
// ───────────────────────────────────────────────────────────────

class _Tk {
  static Color fg(bool d) => d ? Colors.white : const Color(0xFF0A0A0A);
  static Color sub(bool d) =>
      d ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.55);
  static Color muted(bool d) =>
      d ? Colors.white.withValues(alpha: 0.72) : Colors.black.withValues(alpha: 0.72);

  static List<Color> glassBg(bool d) => d
      ? [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.03)]
      : [Colors.white.withValues(alpha: 0.72), Colors.white.withValues(alpha: 0.55)];

  static Color glassBorder(bool d) =>
      d ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.95);

  static BoxShadow cardShadow(bool d) => BoxShadow(
    color: d
        ? Colors.black.withValues(alpha: 0.8)
        : const Color(0xFF14161E).withValues(alpha: 0.18),
    blurRadius: 28,
    offset: const Offset(0, 10),
    spreadRadius: -16,
  );

  static TextStyle manrope({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = Colors.white,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing ?? size * -0.01,
    height: height,
  );

  /// Monochrome avatar gradient (varied by index).
  static LinearGradient monoAvatar(bool dark, int i) {
    double top, bot;
    if (dark) {
      top = 62 - (i % 7) * 5.0;
      bot = (top - 30).clamp(10.0, 100.0);
    } else {
      top = 92 - (i % 7) * 3.0;
      bot = (top - 32).clamp(32.0, 100.0);
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(1, 0, 0, top / 100).toColor(),
        HSLColor.fromAHSL(1, 0, 0, bot / 100).toColor(),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Models
// ───────────────────────────────────────────────────────────────

enum _FollowState { follow, followBack, following }

class _UserRow {
  final String name;
  final String handle;
  final String bio;
  final String mutual;
  final bool verified;
  final bool isNew;
  final _FollowState state;

  const _UserRow({
    required this.name,
    required this.handle,
    required this.bio,
    this.mutual = '',
    this.verified = false,
    this.isNew = false,
    required this.state,
  });

  _UserRow copyWith({_FollowState? state}) => _UserRow(
    name: name,
    handle: handle,
    bio: bio,
    mutual: mutual,
    verified: verified,
    isNew: isNew,
    state: state ?? this.state,
  );
}

const _seedFollowers = <_UserRow>[];

const _seedFollowing = <_UserRow>[];

// ── DynamicIsland scroll animation constants ──────────────────────────────────
const double _kUserCardHeight       = 68.0;   // approximate _UserRowCard height
const double _kUserCardGap          = 8.0;    // separatorBuilder gap
const double _kUserCollapseRange    = 80.0;   // px before bottom where collapse starts
const double _kUserIslandPinLift    = 64.0;   // keeps stack above bottom safe area
const double _kUserEntryRange       = 150.0;  // px from bottom for entry animation

// ───────────────────────────────────────────────────────────────
// State
// ───────────────────────────────────────────────────────────────

class _FollowersScreenState extends State<FollowersScreen> {
  late FollowersTab _tab = widget.initialTab;
  String _query = '';

  List<UserProfile> _followers = [];
  List<UserProfile> _following = [];
  bool _isLoading = true;

  // Pagination state
  static const _pageSize = 20;
  final _scrollCtrl = ScrollController();
  bool _isLoadingMoreFollowers = false;
  bool _isLoadingMoreFollowing = false;
  bool _hasMoreFollowers = true;
  bool _hasMoreFollowing = true;
  int _followersSkip = 0;
  int _followingSkip = 0;

  bool get _activeIsLoadingMore =>
      _tab == FollowersTab.followers ? _isLoadingMoreFollowers : _isLoadingMoreFollowing;
  bool get _activeHasMore =>
      _tab == FollowersTab.followers ? _hasMoreFollowers : _hasMoreFollowing;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _followers = [];
      _following = [];
      _followersSkip = 0;
      _followingSkip = 0;
      _hasMoreFollowers = true;
      _hasMoreFollowing = true;
    });
    try {
      final fers = await UserService.getFollowers(widget.userId, skip: 0, limit: _pageSize);
      final fing = await UserService.getFollowing(widget.userId, skip: 0, limit: _pageSize);
      if (mounted) {
        setState(() {
          _followers = fers;
          _following = fing;
          _followersSkip = fers.length;
          _followingSkip = fing.length;
          _hasMoreFollowers = fers.length == _pageSize;
          _hasMoreFollowing = fing.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_activeIsLoadingMore || !_activeHasMore || _query.isNotEmpty) return;
    final isFollowers = _tab == FollowersTab.followers;
    setState(() {
      if (isFollowers) _isLoadingMoreFollowers = true;
      else _isLoadingMoreFollowing = true;
    });
    try {
      final skip = isFollowers ? _followersSkip : _followingSkip;
      final newItems = isFollowers
          ? await UserService.getFollowers(widget.userId, skip: skip, limit: _pageSize)
          : await UserService.getFollowing(widget.userId, skip: skip, limit: _pageSize);
      if (mounted) {
        setState(() {
          if (isFollowers) {
            _followers.addAll(newItems);
            _followersSkip += newItems.length;
            _hasMoreFollowers = newItems.length == _pageSize;
            _isLoadingMoreFollowers = false;
          } else {
            _following.addAll(newItems);
            _followingSkip += newItems.length;
            _hasMoreFollowing = newItems.length == _pageSize;
            _isLoadingMoreFollowing = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_tab == FollowersTab.followers) _isLoadingMoreFollowers = false;
          else _isLoadingMoreFollowing = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(UserProfile user) async {
    final originalState = user.isFollowing;
    final targetId = user.id;

    // Optimistically update local state
    setState(() {
      _followers = _followers.map((u) {
        if (u.id == targetId) {
          return UserProfile(
            id: u.id,
            name: u.name,
            username: u.username,
            picture: u.picture,
            publicKey: u.publicKey,
            isFollowing: !originalState,
            followersCount: u.followersCount,
            followingCount: u.followingCount,
          );
        }
        return u;
      }).toList();

      _following = _following.map((u) {
        if (u.id == targetId) {
          return UserProfile(
            id: u.id,
            name: u.name,
            username: u.username,
            picture: u.picture,
            publicKey: u.publicKey,
            isFollowing: !originalState,
            followersCount: u.followersCount,
            followingCount: u.followingCount,
          );
        }
        return u;
      }).toList();
    });

    bool success = false;
    if (originalState) {
      success = await UserService.unfollowUser(targetId);
    } else {
      success = await UserService.followUser(targetId);
    }

    if (!success && mounted) {
      // Revert on failure
      setState(() {
        _followers = _followers.map((u) {
          if (u.id == targetId) {
            return UserProfile(
              id: u.id,
              name: u.name,
              username: u.username,
              picture: u.picture,
              publicKey: u.publicKey,
              isFollowing: originalState,
              followersCount: u.followersCount,
              followingCount: u.followingCount,
            );
          }
          return u;
        }).toList();

        _following = _following.map((u) {
          if (u.id == targetId) {
            return UserProfile(
              id: u.id,
              name: u.name,
              username: u.username,
              picture: u.picture,
              publicKey: u.publicKey,
              isFollowing: originalState,
              followersCount: u.followersCount,
              followingCount: u.followingCount,
            );
          }
          return u;
        }).toList();
      });
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  List<UserProfile> _currentList() {
    final src = _tab == FollowersTab.followers ? _followers : _following;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return src;
    return src.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final list = _currentList();

    return Scaffold(
      backgroundColor: dark ? Colors.black : const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          const _Backdrop(),
          Positioned.fill(child: _Backdrop(dark: dark)),

          // SCROLLABLE LIST
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 192, bottom: 16),
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: dark ? Colors.white : Colors.black,
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Text(
                              _query.trim().isEmpty
                                  ? (_tab == FollowersTab.followers
                                      ? 'No followers yet.'
                                      : 'Not following anyone yet.')
                                  : 'No one matches "${_query.trim()}".',
                              style: _Tk.manrope(
                                size: 13,
                                weight: FontWeight.w500,
                                color: _Tk.sub(dark),
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (lbCtx, _) {
                              final box = lbCtx.findRenderObject() as RenderBox?;
                              final listStartGlobalY =
                                  box?.localToGlobal(Offset.zero).dy ?? 0.0;
                              final screenH = MediaQuery.sizeOf(context).height;
                              final botPad  = MediaQuery.paddingOf(context).bottom;
                              return ListView.builder(
                                controller: _scrollCtrl,
                                physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics()),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                itemCount: list.length +
                                    (_activeIsLoadingMore && _query.isEmpty ? 1 : 0),
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: false,
                                cacheExtent: 300,
                                itemBuilder: (_, i) {
                                  if (i >= list.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: dark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final u = list[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: _kUserCardGap),
                                    child: _DynamicUserScrollCard(
                                      controller: _scrollCtrl,
                                      index: i,
                                      listStartGlobalY: listStartGlobalY,
                                      screenHeight: screenH,
                                      bottomPad: botPad,
                                      child: RepaintBoundary(
                                        key: ValueKey(u.id),
                                        child: _UserRowCard(
                                          u: u,
                                          i: i,
                                          dark: dark,
                                          onToggle: () => _toggleFollow(u),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ),
          ),

          // TOP BAR
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: _TopBar(
              dark: dark,
              handle: widget.userHandle.isNotEmpty ? '@${widget.userHandle}' : 'Profile',
              subtitle: _tab == FollowersTab.followers
                  ? '${_fmt(_isLoading ? widget.totalFollowers : _followers.length)} followers'
                  : '${_fmt(_isLoading ? widget.totalFollowing : _following.length)} following',
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),

          // SEGMENTED TAB
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 12,
            right: 12,
            child: _SegmentedTabs(
              dark: dark,
              active: _tab,
              followerCount: _fmt(_isLoading ? widget.totalFollowers : _followers.length),
              followingCount: _fmt(_isLoading ? widget.totalFollowing : _following.length),
              onChange: (t) => setState(() => _tab = t),
            ),
          ),

          // SEARCH
          Positioned(
            top: MediaQuery.of(context).padding.top + 116,
            left: 12,
            right: 12,
            child: _SearchPill(
              dark: dark,
              hint: _tab == FollowersTab.followers
                  ? 'Search followers'
                  : 'Search following',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // SECTION HEADER
          Positioned(
            top: MediaQuery.of(context).padding.top + 168,
            left: 18,
            right: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tab == FollowersTab.followers
                      ? 'ALL FOLLOWERS'
                      : 'YOU FOLLOW',
                  style: _Tk.manrope(
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: _Tk.sub(dark),
                    letterSpacing: 1.05,
                  ),
                ),
                Text(
                  '${list.length} SHOWN',
                  style: _Tk.manrope(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: _Tk.sub(dark),
                    letterSpacing: 0.63,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Backdrop
// ───────────────────────────────────────────────────────────────

class _Backdrop extends StatelessWidget {
  final bool dark;
  const _Backdrop({this.dark = false});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1),
                radius: 1.2,
                colors: dark
                    ? const [
                        Color(0xFF161617),
                        Color(0xFF08080A),
                        Color(0xFF000000),
                      ]
                    : const [
                        Color(0xFFFAFAFA),
                        Color(0xFFECECEE),
                        Color(0xFFDCDCE0),
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          _blob(
            dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.95),
            const Alignment(-1, -0.8),
            320,
          ),
          _blob(
            dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.10),
            const Alignment(1, -0.2),
            280,
          ),
          _blob(
            dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.08),
            const Alignment(-0.6, 0.9),
            300,
          ),
        ],
      ),
    );
  }

  Widget _blob(Color c, Alignment a, double size) => Align(
    alignment: a,
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [c, c.withValues(alpha: 0)],
            stops: const [0, 0.7],
          ),
        ),
      ),
    ),
  );
}

// ───────────────────────────────────────────────────────────────
// Top bar
// ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool dark;
  final String handle;
  final String subtitle;
  final VoidCallback onBack;
  const _TopBar({
    required this.dark,
    required this.handle,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _Tk.fg(dark);
    final sub = _Tk.sub(dark);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _CircleBtn(
            dark: dark,
            size: 38,
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 18,
            onTap: onBack,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  handle,
                  style: _Tk.manrope(
                    size: 14,
                    weight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.21,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle.toUpperCase(),
                  style: _Tk.manrope(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: sub,
                    letterSpacing: 0.84,
                  ),
                ),
              ],
            ),
          ),
          _CircleBtn(
            dark: dark,
            size: 38,
            icon: Icons.swap_vert_rounded,
            iconSize: 20,
            onTap: () {
              showModalBottomSheet(
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
                          leading: Icon(Icons.arrow_upward_rounded, color: _Tk.fg(dark)),
                          title: Text(
                            'New follower',
                            style: TextStyle(color: _Tk.fg(dark), fontWeight: FontWeight.w600),
                          ),
                          onTap: () => Navigator.pop(ctx),
                        ),
                        ListTile(
                          leading: Icon(Icons.arrow_downward_rounded, color: _Tk.fg(dark)),
                          title: Text(
                            'Old follower',
                            style: TextStyle(color: _Tk.fg(dark), fontWeight: FontWeight.w600),
                          ),
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final bool dark;
  final double size;
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;
  const _CircleBtn({
    required this.dark,
    required this.size,
    required this.icon,
    this.iconSize = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _Tk.fg(dark);
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
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.6),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.7)
                      : const Color(0xFF14161E).withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -14,
                ),
              ],
            ),
            child: Icon(icon, size: iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Segmented tab
// ───────────────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  final bool dark;
  final FollowersTab active;
  final String followerCount;
  final String followingCount;
  final ValueChanged<FollowersTab> onChange;
  const _SegmentedTabs({
    required this.dark,
    required this.active,
    required this.followerCount,
    required this.followingCount,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.6),
            border: Border.all(color: _Tk.glassBorder(dark)),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [_Tk.cardShadow(dark)],
          ),
          child: Row(
            children: [
              _SegmentBtn(
                label: 'Followers',
                count: followerCount,
                active: active == FollowersTab.followers,
                dark: dark,
                onTap: () => onChange(FollowersTab.followers),
              ),
              _SegmentBtn(
                label: 'Following',
                count: followingCount,
                active: active == FollowersTab.following,
                dark: dark,
                onTap: () => onChange(FollowersTab.following),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentBtn extends StatelessWidget {
  final String label;
  final String count;
  final bool active;
  final bool dark;
  final VoidCallback onTap;
  const _SegmentBtn({
    required this.label,
    required this.count,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = dark ? Colors.white : const Color(0xFF0A0A0A);
    final activeFg = dark ? const Color(0xFF0A0A0A) : Colors.white;
    final muted = _Tk.muted(dark);

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
              Text(
                label.tr(context),
                style: _Tk.manrope(
                  size: 13,
                  weight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? activeFg : muted,
                  letterSpacing: -0.13,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                count,
                style: _Tk.manrope(
                  size: 11,
                  weight: FontWeight.w700,
                  color: (active ? activeFg : muted).withValues(alpha: 0.7),
                  letterSpacing: -0.11,
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
// Search pill
// ───────────────────────────────────────────────────────────────

class _SearchPill extends StatelessWidget {
  final bool dark;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchPill({
    required this.dark,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _Tk.fg(dark);
    final sub = _Tk.sub(dark);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.55),
            border: Border.all(color: _Tk.glassBorder(dark)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 16, color: sub),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: onChanged,
                  cursorColor: fg,
                  style: _Tk.manrope(
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: fg,
                    letterSpacing: -0.135,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: _Tk.manrope(
                      size: 13.5,
                      weight: FontWeight.w500,
                      color: sub,
                      letterSpacing: -0.135,
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
// Row card
// ───────────────────────────────────────────────────────────────

class _UserRowCard extends StatelessWidget {
  final UserProfile u;
  final int i;
  final bool dark;
  final VoidCallback onToggle;
  const _UserRowCard({
    required this.u,
    required this.i,
    required this.dark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _Tk.fg(dark);
    final sub = _Tk.sub(dark);
    final muted = _Tk.muted(dark);
    final state = u.isFollowing ? _FollowState.following : _FollowState.follow;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _Tk.glassBg(dark),
            ),
            border: Border.all(color: _Tk.glassBorder(dark)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [_Tk.cardShadow(dark)],
          ),
          child: Stack(
            children: [
              // top sheen
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: dark
                          ? [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.14),
                              Colors.transparent,
                            ]
                          : [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.95),
                              Colors.transparent,
                            ],
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // avatar
                  UserAvatar(
                    pictureUrl: u.picture,
                    name: u.name,
                    size: 46,
                    dark: dark,
                    index: i,
                  ),
                  const SizedBox(width: 12),

                  // text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _Tk.manrope(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: fg,
                                  letterSpacing: -0.21,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '@${u.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _Tk.manrope(
                            size: 12,
                            weight: FontWeight.w500,
                            color: sub,
                            letterSpacing: -0.06,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // CTA + more
                  _FollowCta(state: state, dark: dark, onTap: onToggle),
                  const SizedBox(width: 2),
                  Icon(Icons.more_horiz_rounded, size: 18, color: sub),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// DynamicIsland scroll animation — same effect as notifications
// ───────────────────────────────────────────────────────────────

class _DynamicUserScrollCard extends StatelessWidget {
  final ScrollController controller;
  final int index;
  final double listStartGlobalY;
  final double screenHeight;
  final double bottomPad;
  final Widget child;

  const _DynamicUserScrollCard({
    required this.controller,
    required this.index,
    required this.listStartGlobalY,
    required this.screenHeight,
    required this.bottomPad,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final scrollY      = controller.hasClients ? controller.offset : 0.0;
        final itemY        = listStartGlobalY + (index * (_kUserCardHeight + _kUserCardGap)) - scrollY;
        final itemBottomY  = itemY + _kUserCardHeight;
        final bottomStackY = screenHeight - bottomPad - _kUserIslandPinLift;

        // ── Bottom collapse: card approaching bottom stack ──
        final collapseRaw = (1.0 - ((bottomStackY - itemBottomY) / _kUserCollapseRange))
            .clamp(0.0, 1.0);
        final collapseT = Curves.easeInOutCubic.transform(collapseRaw);

        // ── Entry animation: card sliding in from below ──
        final entryRaw = ((screenHeight - itemY) / _kUserEntryRange).clamp(0.0, 1.0);
        final entryT   = Curves.easeOutCubic.transform(entryRaw);

        // Fast path — no transform needed
        if (collapseT == 0 && entryT == 1.0) return child!;

        final slideUp           = _lerp(20.0, 0.0, entryT);
        final entryOpacity      = _lerp(0.0, 1.0, entryT);
        final collapseWidthFactor = _lerp(1.0, 0.62, collapseT);
        final collapseScaleY    = _lerp(1.0, 0.74, collapseT);
        final collapseDrop      = _lerp(0.0, 14.0, collapseT);
        final collapseOpacity   = _lerp(1.0, 0.12, Curves.easeInOutCubic.transform(collapseT));

        final finalOpacity = (entryOpacity * collapseOpacity).clamp(0.0, 1.0);
        final finalSlide   = slideUp + collapseDrop;

        Widget result = Transform.translate(
          offset: Offset(0, finalSlide),
          child: Transform.scale(
            alignment: Alignment.bottomCenter,
            scaleY: collapseScaleY,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: collapseWidthFactor,
                child: child,
              ),
            ),
          ),
        );
        if (finalOpacity < 0.99) {
          result = Opacity(opacity: finalOpacity, child: result);
        }
        return ClipRect(child: result);
      },
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _FollowCta extends StatelessWidget {
  final _FollowState state;
  final bool dark;
  final VoidCallback onTap;
  const _FollowCta({
    required this.state,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary =
        state == _FollowState.follow || state == _FollowState.followBack;
    final label = state == _FollowState.follow
        ? 'Follow'
        : state == _FollowState.followBack
        ? 'Follow back'
        : 'Following';
    final fg = _Tk.fg(dark);

    if (isPrimary) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? Colors.white : const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label.tr(context),
            style: _Tk.manrope(
              size: 12,
              weight: FontWeight.w700,
              color: dark ? const Color(0xFF0A0A0A) : Colors.white,
              letterSpacing: -0.12,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.6),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.10),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label.tr(context),
              style: _Tk.manrope(
                size: 12,
                weight: FontWeight.w700,
                color: fg,
                letterSpacing: -0.12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
