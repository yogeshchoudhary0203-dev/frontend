import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_common.dart';
import '../models/chat_model.dart';
import '../services/user_service.dart';
import '../services/follow_state.dart';

class LikedByScreen extends StatefulWidget {
  final bool dark;
  final String postUser;
  final int likeCount;
  final String postId;

  const LikedByScreen({
    super.key,
    required this.dark,
    required this.postUser,
    required this.likeCount,
    required this.postId,
  });

  @override
  State<LikedByScreen> createState() => _LikedByScreenState();
}

class _LikedByScreenState extends State<LikedByScreen> {
  String _query = '';
  List<UserProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    FollowState.notifier.addListener(_onGlobalFollowChanged);
  }

  @override
  void dispose() {
    FollowState.notifier.removeListener(_onGlobalFollowChanged);
    super.dispose();
  }

  void _onGlobalFollowChanged() {
    if (!mounted) return;
    bool changed = false;
    final updated = _users.map((u) {
      final v = FollowState.get(u.id);
      if (v != null && v != u.isFollowing) {
        changed = true;
        return UserProfile(
          id: u.id, name: u.name, username: u.username,
          picture: u.picture, publicKey: u.publicKey,
          isFollowing: v,
          followersCount: u.followersCount, followingCount: u.followingCount,
        );
      }
      return u;
    }).toList();
    if (changed) setState(() => _users = updated);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await UserService.getPostLikers(widget.postId);
      if (mounted) {
        // Seed FollowState with current values
        FollowState.seed(users.map((u) => MapEntry(u.id, u.isFollowing)));
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(UserProfile user) async {
    final originalState = user.isFollowing;
    final targetId = user.id;

    HapticFeedback.mediumImpact();

    // Optimistically update local state
    setState(() {
      _users = _users.map((u) {
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
        _users = _users.map((u) {
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

  List<UserProfile> _filteredList() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final headerTop = MediaQuery.paddingOf(context).top + 8;
    final list = _filteredList();

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          // Theme-matching blur backdrop
          GlassBackdrop(dark: dark),

          // Scrollable List
          Positioned.fill(
            top: headerTop + 114,
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
                              ? 'No likes yet.'
                              : 'No matches found for "${_query.trim()}".',
                          style: manrope(
                            size: 13.5,
                            weight: FontWeight.w500,
                            color: sub,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final u = list[index];
                          return _UserRowCard(
                            u: u,
                            i: index,
                            dark: dark,
                            onToggle: () => _toggleFollow(u),
                          );
                        },
                      ),
          ),

          // Top Header Bar
          Positioned(
            top: headerTop,
            left: 12,
            right: 12,
            child: GlassHeader(
              dark: dark,
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: fg, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Liked by',
                    style: manrope(
                      size: 17,
                      weight: FontWeight.w800,
                      color: fg,
                      letterSpacing: -0.34,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${widget.likeCount} likes',
                      style: manrope(
                        size: 11,
                        weight: FontWeight.w600,
                        color: sub,
                        letterSpacing: -0.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),

          // Search Bar
          Positioned(
            top: headerTop + 60,
            left: 12,
            right: 12,
            child: _SearchPill(
              dark: dark,
              hint: 'Search members',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Search Pill Widget (Frosted Glass Search Input)
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
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.55),
            border: Border.all(color: GlassTokens.glassBorder(dark)),
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
                  style: manrope(
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: fg,
                    letterSpacing: -0.135,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: manrope(
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
// User Card row (Reused from followers_screen design tokens)
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
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final following = u.isFollowing;

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
              colors: GlassTokens.glassBg(dark),
            ),
            border: Border.all(color: GlassTokens.glassBorder(dark)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [GlassTokens.cardShadow(dark)],
          ),
          child: Stack(
            children: [
              // top sheen line
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
                              Colors.white.withOpacity(0.14),
                              Colors.transparent,
                            ]
                          : [
                              Colors.transparent,
                              Colors.white.withOpacity(0.95),
                              Colors.transparent,
                            ],
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  UserAvatar(
                    pictureUrl: u.picture,
                    name: u.name,
                    size: 44,
                    dark: dark,
                    index: i,
                  ),
                  const SizedBox(width: 12),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: manrope(
                            size: 14,
                            weight: FontWeight.w700,
                            color: fg,
                            letterSpacing: -0.21,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '@${u.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: manrope(
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

                  // CTA Follow Button
                  _FollowButton(following: following, dark: dark, onTap: onToggle),
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
// Follow Button component
// ───────────────────────────────────────────────────────────────
class _FollowButton extends StatelessWidget {
  final bool following;
  final bool dark;
  final VoidCallback onTap;

  const _FollowButton({
    required this.following,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);

    if (!following) {
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
            'Follow',
            style: manrope(
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
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.6),
              border: Border.all(
                color: dark
                  ? Colors.white.withOpacity(0.18)
                  : Colors.black.withOpacity(0.10),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Following',
              style: manrope(
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
