import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_model.dart';
import '../../screens/user_profile_screen.dart' as user_profile;
import '../../services/user_service.dart';
import '../../l10n/app_localizations.dart';
import '../shared/home_shared.dart';

// ═════════════════════════════════════════════════════
//  FOLLOWER SUGGESTIONS
// ═════════════════════════════════════════════════════

class FollowerSuggestionsTab extends StatefulWidget {
  final bool isDark;
  final List<UserProfile> users;
  const FollowerSuggestionsTab({super.key, required this.isDark, required this.users});

  @override
  State<FollowerSuggestionsTab> createState() => _FollowerSuggestionsTabState();
}

class _FollowerSuggestionsTabState extends State<FollowerSuggestionsTab> {
  final Set<String> _followingIds = <String>{};
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _syncFollowing();
  }

  @override
  void didUpdateWidget(covariant FollowerSuggestionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFollowing();
  }

  void _syncFollowing() {
    for (final user in widget.users) {
      if (user.isFollowing) _followingIds.add(user.id);
    }
  }

  Color _avatarColor(String seed) {
    const colors = [Color(0xFF646464), Color(0xFF744A40), Color(0xFF2D3561), Color(0xFF1B4332), Color(0xFF4A3F6B)];
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
        userId: user.id, username: user.username,
        displayName: user.name.isNotEmpty ? user.name : user.username,
        handle: user.username, initialFollowing: _followingIds.contains(user.id),
      ),
    ));
  }

  Future<void> _toggleFollow(UserProfile user) async {
    if (_busyIds.contains(user.id)) return;
    HapticFeedback.lightImpact();
    final wasFollowing = _followingIds.contains(user.id);
    setState(() {
      _busyIds.add(user.id);
      if (wasFollowing) _followingIds.remove(user.id); else _followingIds.add(user.id);
    });
    final ok = wasFollowing ? await UserService.unfollowUser(user.id) : await UserService.followUser(user.id);
    if (!mounted) return;
    setState(() {
      _busyIds.remove(user.id);
      if (!ok) {
        if (wasFollowing) _followingIds.add(user.id); else _followingIds.remove(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg     = widget.isDark ? Colors.white : Colors.black;
    final border = fg.op(0.10);
    final cardBg = widget.isDark ? const Color(0xFF121214) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 0, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(right: 14),
          child: Row(children: [
            Text('Suggested for you'.tr(context).toUpperCase(),
              style: TextStyle(color: fg.op(0.50), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const Spacer(),
            Text('See all'.tr(context), style: TextStyle(color: fg.op(0.92), fontSize: 13, fontWeight: FontWeight.w800)),
          ])),
        const SizedBox(height: 10),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final user        = widget.users[index];
              final isFollowing = _followingIds.contains(user.id);
              final isBusy      = _busyIds.contains(user.id);
              return GestureDetector(
                onTap: () => _openProfile(user),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border, width: 0.8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [fg.op(widget.isDark ? 0.08 : 0.04), cardBg],
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.op(widget.isDark ? 0.22 : 0.08), blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  child: Column(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _avatarColor(user.id)),
                      child: ClipOval(
                        child: user.picture != null && user.picture!.isNotEmpty
                            ? CachedNetworkImage(imageUrl: user.picture!, fit: BoxFit.cover,
                                fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                                placeholderFadeInDuration: Duration.zero,
                                errorWidget: (_, __, ___) => Center(child: Text(_initial(user), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))))
                            : Center(child: Text(_initial(user), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(user.username, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg.op(0.92), fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(isFollowing ? 'Followed by you'.tr(context) : 'Suggested'.tr(context), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg.op(0.46), fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: isBusy ? null : () => _toggleFollow(user),
                      child: Container(
                        width: double.infinity, height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: isFollowing ? fg.op(0.10) : fg,
                          border: isFollowing ? Border.all(color: border, width: 0.8) : null,
                        ),
                        child: isBusy
                            ? SizedBox(width: 15, height: 15,
                                child: CircularProgressIndicator(strokeWidth: 1.6, color: isFollowing ? fg : cardBg))
                            : Text(isFollowing ? 'Following'.tr(context) : 'Follow'.tr(context), maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isFollowing ? fg.op(0.88) : cardBg, fontSize: 13, fontWeight: FontWeight.w800)),
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
