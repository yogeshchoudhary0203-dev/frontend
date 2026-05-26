// lib/screens/profile/profile_screen.dart
//
// Glass User Profile — single file. Matches the matte-glass monochrome system
// from login_screen.dart.
// • Auto theme: follows the device system brightness (light/dark)
// • Layout: top bar → stats card (overlapping avatar) → name → title chip →
//           bio → social row → Follow / Message → posts section → 3-col grid
// • Pure black/white tones for content; brand colors only on social glyphs

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/post_service.dart';
import '../models/chat_model.dart';
import '../utils/error_dialog.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.userId = '',
    this.username = '',
    this.displayName = 'Sarah Dietrich',
    this.handle = 'sarah.d',
    this.title = 'Designer · Studio Atelier',
    this.bio =
        'Designer & art director.\nCurrently leading visual identity at Studio Atelier — type, motion & quiet things.',
    this.followers = '24.3K',
    this.following = '482',
    this.posts = '168',
    this.postCount = 168,
    this.verified = true,
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
  UserProfile? _profile;
  List<PostModel> _userPosts = [];
  bool _postsLoading = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialFollowing;
    if (widget.userId.isNotEmpty) {
      _loadProfile();
      _loadPosts(widget.userId);
    }
  }

  Future<void> _loadProfile() async {
    final p = await UserService.getUserProfile(widget.userId);
    if (mounted && p != null) {
      setState(() {
        _profile = p;
        _isFollowing = p.isFollowing;
      });
    }
  }

  Future<void> _loadPosts(String userId) async {
    if (!mounted) return;
    setState(() => _postsLoading = true);
    try {
      final result = await PostService.instance.getUserPosts(userId);
      if (mounted) {
        setState(() {
          _userPosts = result.posts;
          _postsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _postsLoading = false);
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
    final t = _GlassTheme.of(isDark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: t.bgStops.last,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: t.bgStops.last,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop ─────────────────────────────────────────────────
            Positioned.fill(child: _Backdrop(t: t)),

            // Scrollable content ───────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(top: 56, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatsHeader(
                      t: t,
                      followers: _profile != null
                          ? _formatCount(_profile!.followersCount)
                          : widget.followers,
                      following: _profile != null
                          ? _formatCount(_profile!.followingCount)
                          : widget.following,
                      posts: _formatCount(_userPosts.length),
                      initial: (_profile?.name ?? widget.displayName).isNotEmpty
                          ? (_profile?.name ?? widget.displayName)[0].toUpperCase()
                          : 'U',
                    ),
                    const SizedBox(height: 68),
                    _NameRow(
                      t: t,
                      name: _profile?.name ?? widget.displayName,
                      verified: widget.verified,
                    ),
                    const SizedBox(height: 10),
                    Center(child: _TitleChip(t: t, label: '@${_profile?.username ?? widget.username}')),
                    if ((_profile?.locationCity?.isNotEmpty == true)) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: _LocationBadge(
                          t: t,
                          city: _profile!.locationCity!,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if ((_profile?.bio ?? widget.bio).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          _profile?.bio ?? widget.bio,
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
                      _WebsiteChip(t: t, url: _profile!.link!),
                    ],
                    const SizedBox(height: 16),
                    _SocialRow(t: t, profile: _profile),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Expanded(
                          child: _FollowButton(
                            t: t,
                            following: _isFollowing,
                            onTap: _handleFollow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MessageButton(t: t, onTap: _handleMessage),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _PostsSection(
                        t: t,
                        posts: _userPosts,
                        isLoading: _postsLoading,
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
                        _CircleIconButton(
                          t: t,
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.maybePop(context),
                        ),
                        const Spacer(),
                        _CircleIconButton(
                          t: t,
                          icon: Icons.ios_share_rounded,
                          onTap: () {},
                        ),
                        const SizedBox(width: 8),
                        _CircleIconButton(
                          t: t,
                          icon: Icons.more_vert_rounded,
                          onTap: () {},
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

// ─────────────────────────────────────────────────────────────────────────────
// STATS HEADER (card + overlapping avatar)
// ─────────────────────────────────────────────────────────────────────────────
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.t,
    required this.followers,
    required this.following,
    required this.posts,
    required this.initial,
  });
  final _GlassTheme t;
  final String followers, following, posts, initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass card with diagonal stripes
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: t.cardShadow,
            ),
            child: _Frosted(
              radius: 28,
              sigma: 28,
              child: Container(
                height: 150,
                padding: const EdgeInsets.only(top: 22, left: 8, right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: t.cardBorder, width: 1),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: t.cardFill,
                  ),
                ),
                child: Stack(children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _Stat(
                              t: t, value: followers, label: 'FOLLOWERS')),
                      _StatDivider(t: t),
                      Expanded(
                          child: _Stat(
                              t: t, value: following, label: 'FOLLOWING')),
                      _StatDivider(t: t),
                      Expanded(
                          child: _Stat(t: t, value: posts, label: 'POSTS')),
                    ],
                  ),
                ]),
              ),
            ),
          ),

          // Avatar — overlapping bottom-center
          Positioned(
            bottom: -58,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 124,
                height: 124,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.dark
                      ? const Color(0xFF070709)
                      : const Color(0xFFFAFAFA),
                  boxShadow: [
                    BoxShadow(
                      color: t.dark
                          ? const Color(0xD9000000)
                          : const Color(0x47282050),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                      spreadRadius: -18,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: t.dark
                          ? const [Color(0xFF8E8E92), Color(0xFF3A3A3D)]
                          : const [Color(0xFFEDEDEF), Color(0xFFA8A8AC)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.t, required this.value, required this.label});
  final _GlassTheme t;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: t.fg,
            letterSpacing: -0.8,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: t.muted,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.t});
  final _GlassTheme t;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.only(top: 6),
      color: t.dark ? const Color(0x14FFFFFF) : const Color(0x14000000),
    );
  }
}

class _StripesPainter extends CustomPainter {
  _StripesPainter({required this.color, required this.spacing});
  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    final diag = size.width + size.height;
    for (double x = -size.height; x < diag; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter old) =>
      old.color != color || old.spacing != spacing;
}

// ─────────────────────────────────────────────────────────────────────────────
// NAME + VERIFIED BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _NameRow extends StatelessWidget {
  const _NameRow({required this.t, required this.name, required this.verified});
  final _GlassTheme t;
  final String name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: t.fg,
                letterSpacing: -0.7,
              ),
            ),
          ),
          if (verified) ...[
            const SizedBox(width: 8),
            _Verified(color: t.fg, size: 20),
          ],
        ],
      ),
    );
  }
}

class _Verified extends StatelessWidget {
  const _Verified({required this.color, this.size = 16});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _VerifiedPainter(color)),
    );
  }
}

class _VerifiedPainter extends CustomPainter {
  _VerifiedPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1.6 * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 16-point starburst (alternating outer/inner radius)
    const cx = 12.0, cy = 12.0;
    const outer = 9.5, inner = 7.8;
    final path = Path();
    for (int i = 0; i < 16; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * (2 * math.pi / 16);
      final px = (cx + r * math.cos(a)) * s;
      final py = (cy + r * math.sin(a)) * s;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, stroke);

    // Inner checkmark
    final check = Path()
      ..moveTo(8.5 * s, 12.2 * s)
      ..lineTo(10.9 * s, 14.5 * s)
      ..lineTo(15.5 * s, 9.9 * s);
    canvas.drawPath(check, stroke);
  }

  @override
  bool shouldRepaint(covariant _VerifiedPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// TITLE CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _TitleChip extends StatelessWidget {
  const _TitleChip({required this.t, required this.label});
  final _GlassTheme t;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.fieldShadow,
      ),
      child: _Frosted(
        radius: 999,
        sigma: 16,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.fieldFill,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.fg.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEBSITE CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _WebsiteChip extends StatelessWidget {
  const _WebsiteChip({required this.t, required this.url});
  final _GlassTheme t;
  final String url;

  Future<void> _open() async {
    String full = url.trim();
    if (!full.startsWith('http://') && !full.startsWith('https://')) {
      full = 'https://$full';
    }
    try {
      await launchUrl(Uri.parse(full), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final display = url.replaceFirst(RegExp(r'^https?://'), '');
    return Center(
      child: GestureDetector(
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(colors: t.fieldFill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 14, color: t.muted),
              const SizedBox(width: 4),
              Text(
                display,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOCIAL ROW
// ─────────────────────────────────────────────────────────────────────────────
class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.t, this.profile});
  final _GlassTheme t;
  final UserProfile? profile;

  Future<void> _launch(String url) async {
    String full = url.trim();
    if (full.isEmpty) return;
    if (!full.startsWith('http://') && !full.startsWith('https://')) {
      full = 'https://$full';
    }
    try {
      await launchUrl(Uri.parse(full), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const SizedBox.shrink();

    final links = <({Widget icon, String url})>[
      if ((profile!.snapchatLink ?? '').isNotEmpty)
        (icon: const _BrandSnap(), url: profile!.snapchatLink!),
      if ((profile!.instagramLink ?? '').isNotEmpty)
        (icon: const _BrandIG(), url: profile!.instagramLink!),
      if ((profile!.whatsappLink ?? '').isNotEmpty)
        (icon: const _BrandWA(), url: profile!.whatsappLink!),
      if ((profile!.facebookLink ?? '').isNotEmpty)
        (icon: const _BrandFB(), url: profile!.facebookLink!),
      if ((profile!.twitterLink ?? '').isNotEmpty)
        (icon: const _BrandX(), url: profile!.twitterLink!),
      if ((profile!.youtubeLink ?? '').isNotEmpty)
        (icon: const _BrandYT(), url: profile!.youtubeLink!),
    ];

    if (links.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: links
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => _launch(e.url),
                    child: _SocialPill(t: t, child: e.icon),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _SocialPill extends StatelessWidget {
  const _SocialPill({required this.t, required this.child});
  final _GlassTheme t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: t.fieldShadow,
      ),
      child: _Frosted(
        radius: 999,
        sigma: 16,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.fieldFill,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _BrandSnap extends StatelessWidget {
  const _BrandSnap();
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFC00),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.snapchat,
            color: Color(0xFF0A0A0A),
            size: 13,
          ),
        ),
      );
}

class _BrandIG extends StatelessWidget {
  const _BrandIG();
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFEDA77), Color(0xFFF58529), Color(0xFFDD2A7B)],
          ),
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.instagram,
            color: Colors.white,
            size: 13,
          ),
        ),
      );
}

class _BrandWA extends StatelessWidget {
  const _BrandWA();
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF25D366),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.whatsapp,
            color: Colors.white,
            size: 13,
          ),
        ),
      );
}

class _BrandFB extends StatelessWidget {
  const _BrandFB();
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF1877F2),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.facebookF,
            color: Colors.white,
            size: 13,
          ),
        ),
      );
}

class _BrandX extends StatelessWidget {
  const _BrandX();
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 0.8),
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.xTwitter,
            color: Colors.white,
            size: 11,
          ),
        ),
      );
}

class _BrandYT extends StatelessWidget {
  const _BrandYT();
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFFF0000),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.youtube,
            color: Colors.white,
            size: 12,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BUTTONS
// ─────────────────────────────────────────────────────────────────────────────
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.t,
    required this.following,
    required this.onTap,
  });
  final _GlassTheme t;
  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (following) {
      return _MessageButton(
        t: t,
        onTap: onTap,
        label: 'Following',
        leading: Icon(Icons.check_rounded, color: t.fg, size: 16),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.btnShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: t.btnBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: t.btnFill,
              ),
            ),
            child: Stack(children: [
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: Container(
                  height: 1.2,
                  color: Colors.white
                      .withValues(alpha: t.dark ? 0.85 : 0.32),
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: t.btnFg, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Follow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: t.btnFg,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MessageButton extends StatelessWidget {
  const _MessageButton({
    required this.t,
    required this.onTap,
    this.label = 'Message',
    this.leading,
  });
  final _GlassTheme t;
  final VoidCallback onTap;
  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.fieldShadow,
      ),
      child: _Frosted(
        radius: 999,
        sigma: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.fieldBorder, width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: t.fieldFill,
                ),
              ),
              child: Stack(children: [
                Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  child: Container(
                    height: 1,
                    color: t.innerHi.withValues(alpha: 0.7),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ] else ...[
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: t.fg, size: 16),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: t.fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.t,
    required this.icon,
    required this.onTap,
  });
  final _GlassTheme t;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: t.fieldShadow,
      ),
      child: _Frosted(
        radius: 999,
        sigma: 18,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.fieldBorder, width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: t.fieldFill,
                ),
              ),
              child: Icon(icon, color: t.fg, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POSTS SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _PostsSection extends StatelessWidget {
  const _PostsSection({
    required this.t,
    required this.posts,
    required this.isLoading,
  });
  final _GlassTheme t;
  final List<PostModel> posts;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: t.cardShadow,
      ),
      child: _Frosted(
        radius: 22,
        sigma: 24,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.cardBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: t.cardFill,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, color: t.fg, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Posts',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: t.fg,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${posts.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _PostsGrid(t: t, posts: posts, isLoading: isLoading),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsGrid extends StatelessWidget {
  const _PostsGrid({
    required this.t,
    required this.posts,
    required this.isLoading,
  });
  final _GlassTheme t;
  final List<PostModel> posts;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(t.fg),
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: t.muted,
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) => _PostTile(t: t, post: posts[i], i: i),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.t, required this.post, required this.i});
  final _GlassTheme t;
  final PostModel post;
  final int i;

  @override
  Widget build(BuildContext context) {
    final isVideo = post.mediaType == 'video';
    final imageUrl = isVideo && post.thumbnailUrl != null
        ? post.thumbnailUrl!
        : post.mediaUrl;

    final aPct = t.dark ? (22 - (i % 5) * 3) : (92 - (i % 5) * 4);
    final bPct = (aPct - (t.dark ? 12 : 18))
        .clamp(t.dark ? 4 : 56, 100)
        .toDouble();
    final g1 = HSLColor.fromAHSL(1, 0, 0, aPct / 100).toColor();
    final g2 = HSLColor.fromAHSL(1, 0, 0, bPct / 100).toColor();
    final angle = (135 + (i * 29) % 90) * math.pi / 180;
    final dx = math.cos(angle);
    final dy = math.sin(angle);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-dx, -dy),
            end: Alignment(dx, dy),
            colors: [g1, g2],
          ),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          if (isVideo)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x73000000),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BACKDROP
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Location badge (read-only, shown on others' profile)
// ─────────────────────────────────────────────────────────────────────────────

class _LocationBadge extends StatelessWidget {
  final _GlassTheme t;
  final String city;
  const _LocationBadge({required this.t, required this.city});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: t.cardFill,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: t.cardBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 12,
                color: Color(0xFFFF3B30),
              ),
              const SizedBox(width: 4),
              Text(
                city,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.t});
  final _GlassTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: t.bgStops,
        ),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Orb(color: t.orbColors[0], size: 320, left: -60, top: -40),
            _Orb(color: t.orbColors[1], size: 300, right: -60, top: 40),
            _Orb(color: t.orbColors[2], size: 360, left: 30, top: 320),
            _Orb(color: t.orbColors[3], size: 260, right: -50, bottom: 80),
            _Orb(color: t.orbColors[4], size: 300, left: -40, bottom: -30),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.color,
    required this.size,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });
  final Color color;
  final double size;
  final double? left, right, top, bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FROSTED GLASS WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _Frosted extends StatelessWidget {
  const _Frosted({
    required this.child,
    required this.radius,
    this.sigma = 24,
  });
  final Widget child;
  final double radius;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────
class _GlassTheme {
  final bool dark;
  final Color fg;
  final Color muted;
  final List<Color> bgStops;
  final List<Color> orbColors;
  final List<Color> cardFill;
  final Color cardBorder;
  final List<BoxShadow> cardShadow;
  final List<Color> fieldFill;
  final Color fieldBorder;
  final List<BoxShadow> fieldShadow;
  final List<Color> btnFill;
  final Color btnFg;
  final Color btnBorder;
  final List<BoxShadow> btnShadow;
  final Color innerHi;

  const _GlassTheme({
    required this.dark,
    required this.fg,
    required this.muted,
    required this.bgStops,
    required this.orbColors,
    required this.cardFill,
    required this.cardBorder,
    required this.cardShadow,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldShadow,
    required this.btnFill,
    required this.btnFg,
    required this.btnBorder,
    required this.btnShadow,
    required this.innerHi,
  });

  static _GlassTheme of(bool dark) => dark ? _dark : _light;

  Color get locationIconColor => const Color(0xFFFF3B30);

  static final _light = _GlassTheme(
    dark: false,
    fg: const Color(0xFF0E1124),
    muted: const Color(0x8C141628),
    bgStops: const [Color(0xFFF4F4F6), Color(0xFFE4E4E8), Color(0xFFD6D6DC)],
    orbColors: const [
      Color(0x52141416),
      Color(0x42141416),
      Color(0xF2FFFFFF),
      Color(0x38141416),
      Color(0x3D141416),
    ],
    cardFill: const [Color(0x61FFFFFF), Color(0x2EFFFFFF)],
    cardBorder: const Color(0xD9FFFFFF),
    cardShadow: const [
      BoxShadow(
          color: Color(0x40282050),
          blurRadius: 60,
          offset: Offset(0, 30),
          spreadRadius: -20),
    ],
    fieldFill: const [Color(0x73FFFFFF), Color(0x33FFFFFF)],
    fieldBorder: const Color(0xD9FFFFFF),
    fieldShadow: const [
      BoxShadow(
          color: Color(0x2E282050),
          blurRadius: 18,
          offset: Offset(0, 6),
          spreadRadius: -8),
    ],
    btnFill: const [Color(0xFF1A1A1D), Color(0xFF0A0A0C)],
    btnFg: const Color(0xFFFFFFFF),
    btnBorder: const Color(0x33FFFFFF),
    btnShadow: const [
      BoxShadow(
          color: Color(0x59282026),
          blurRadius: 30,
          offset: Offset(0, 14),
          spreadRadius: -10),
    ],
    innerHi: const Color(0xF2FFFFFF),
  );

  static final _dark = _GlassTheme(
    dark: true,
    fg: const Color(0xFFF5F4FF),
    muted: const Color(0x99F5F4FF),
    bgStops: const [Color(0xFF0C0C0E), Color(0xFF060608), Color(0xFF000000)],
    orbColors: const [
      Color(0x66FFFFFF),
      Color(0x47FFFFFF),
      Color(0x52FFFFFF),
      Color(0x38FFFFFF),
      Color(0x42FFFFFF),
    ],
    cardFill: const [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
    cardBorder: const Color(0x2EFFFFFF),
    cardShadow: const [
      BoxShadow(
          color: Color(0xB3000000),
          blurRadius: 60,
          offset: Offset(0, 30),
          spreadRadius: -20),
    ],
    fieldFill: const [Color(0x1AFFFFFF), Color(0x08FFFFFF)],
    fieldBorder: const Color(0x29FFFFFF),
    fieldShadow: const [
      BoxShadow(
          color: Color(0x80000000),
          blurRadius: 18,
          offset: Offset(0, 6),
          spreadRadius: -8),
    ],
    btnFill: const [Color(0xFFFFFFFF), Color(0xFFF2F2F7)],
    btnFg: const Color(0xFF0A0A0C),
    btnBorder: const Color(0x66FFFFFF),
    btnShadow: const [
      BoxShadow(
          color: Color(0x99000000),
          blurRadius: 30,
          offset: Offset(0, 14),
          spreadRadius: -10),
    ],
    innerHi: const Color(0x59FFFFFF),
  );
}
