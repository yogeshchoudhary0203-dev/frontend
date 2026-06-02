// creator_profile_screen.dart
//
// Glass Creator Profile — single self-contained file, BOTH themes in one.
// Matches the matte-glass monochrome system from login_screen.dart.
// • Theme: driven by the `dark` flag — runnable demo has a Light/Dark toggle
// • Layout: top bar → stats card (overlapping avatar = photo) → name →
//           title chip → bio → Edit-profile / Share → Creator-dashboard card →
//           posts section → 3-col grid
// • Pure black/white tones; the only colour lives on the photo itself

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../services/post_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RUNNABLE DEMO — light + dark in one file. Tap the pill to switch themes.
// (Remove main() + CreatorProfileDemo + _ThemeToggle if you embed the screen
//  in your own app and drive `dark` yourself.)
// ─────────────────────────────────────────────────────────────────────────────
void main() => runApp(const CreatorProfileDemo());

class CreatorProfileDemo extends StatefulWidget {
  const CreatorProfileDemo({super.key});
  @override
  State<CreatorProfileDemo> createState() => _CreatorProfileDemoState();
}

class _CreatorProfileDemoState extends State<CreatorProfileDemo> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Stack(children: [
        CreatorProfileScreen(
          dark: _dark,
          displayName: 'Yogesh Choudhary',
          handle: 'yogesh01',
          title: 'Designer · Studio Atelier',
          bio: 'hi i am app developer',
          followers: '10',
          following: '29',
          posts: '12',
          postCount: 12,
          // avatarUrl: 'https://your-cdn/photo.jpg',  // apni photo yahan daalo
        ),
        // Demo-only theme switch.
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ThemeToggle(
                dark: _dark,
                onTap: () => setState(() => _dark = !_dark),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.dark, required this.onTap});
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : const Color(0xFF0A0A0A);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: dark ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.06),
            border: Border.all(
              color: dark ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.10),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              dark ? 'Dark' : 'Light',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: -0.1,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class CreatorProfileScreen extends StatefulWidget {
  const CreatorProfileScreen({
    super.key,
    this.displayName = '',
    this.handle = '',
    this.title = '',
    this.bio = '',
    this.followers = '0',
    this.following = '0',
    this.posts = '0',
    this.postCount = 0,
    this.verified = true,
    this.initialFollowing = false,
    this.dark = false,
    this.owner = true,
    this.avatarUrl = '',
    this.reach = '',
    this.profileViews = '',
    this.engagement = '',
    this.onOpenDashboard,
    this.onOpenSettings,
    this.userPosts = const [],
    this.postsLoading = false,
    this.myUserId,
    this.onPostDeleted,
  });

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

  /// Theme: true = dark, false = light.
  final bool dark;

  /// Owner view = your own profile: Edit-profile / Share CTAs, settings gear,
  /// and the Creator-dashboard entry card. Set false to view another user.
  final bool owner;

  /// Profile photo. Empty string falls back to the monogram avatar.
  final String avatarUrl;

  /// Analytics stats — pass empty string '' if not yet available (shows '--').
  final String reach;
  final String profileViews;
  final String engagement;

  /// Tapped when the Creator-dashboard card is pressed.
  final VoidCallback? onOpenDashboard;

  /// Tapped when the settings gear is pressed.
  final VoidCallback? onOpenSettings;

  /// Real posts from API.
  final List<PostModel> userPosts;
  final bool postsLoading;
  final String? myUserId;
  final void Function(String postId)? onPostDeleted;

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialFollowing;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.dark;
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
                      followers: widget.followers,
                      following: widget.following,
                      posts: widget.posts,
                      avatarUrl: widget.avatarUrl,
                      initial: widget.displayName.isNotEmpty
                          ? widget.displayName[0].toUpperCase()
                          : 'U',
                    ),
                    const SizedBox(height: 68),
                    _NameRow(
                      t: t,
                      name: widget.displayName,
                      verified: widget.verified,
                    ),
                    const SizedBox(height: 10),
                    Center(child: _TitleChip(t: t, label: widget.title)),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        widget.bio,
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
                    const SizedBox(height: 18),
                    // CTAs — owner: Edit profile / Share · else: Follow / Message
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: widget.owner
                          ? Row(children: [
                              Expanded(
                                child: _PrimaryActionButton(
                                  t: t,
                                  label: 'Edit profile',
                                  icon: Icons.edit_outlined,
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MessageButton(
                                  t: t,
                                  onTap: () {},
                                  label: 'Share profile',
                                  leading:
                                      Icon(Icons.ios_share_rounded, color: t.fg, size: 16),
                                ),
                              ),
                            ])
                          : Row(children: [
                              Expanded(
                                child: _FollowButton(
                                  t: t,
                                  following: _isFollowing,
                                  onTap: () => setState(
                                      () => _isFollowing = !_isFollowing),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MessageButton(t: t, onTap: () {}),
                              ),
                            ]),
                    ),

                    // CREATOR DASHBOARD ENTRY — owner only
                    if (widget.owner) ...[
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _DashboardEntryCard(
                          t: t,
                          reach: widget.reach,
                          views: widget.profileViews,
                          engagement: widget.engagement,
                          onTap: widget.onOpenDashboard ?? () {},
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _PostsSection(
                        t: t,
                        count: widget.userPosts.length,
                        posts: widget.userPosts,
                        isLoading: widget.postsLoading,
                        myUserId: widget.myUserId,
                        onPostDeleted: widget.onPostDeleted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TOP BAR — back · handle · share · more
            SafeArea(
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
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.handle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: t.fg,
                                letterSpacing: -0.1,
                              ),
                            ),
                            if (widget.verified) ...[
                              const SizedBox(width: 4),
                              _Verified(color: t.fg, size: 14),
                            ],
                          ],
                        ),
                      ),
                      _CircleIconButton(
                        t: t,
                        icon: Icons.ios_share_rounded,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _CircleIconButton(
                        t: t,
                        icon: widget.owner
                            ? Icons.settings_outlined
                            : Icons.more_vert_rounded,
                        onTap: widget.onOpenSettings ?? () {},
                      ),
                    ],
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
    this.avatarUrl = '',
  });
  final _GlassTheme t;
  final String followers, following, posts, initial;
  final String avatarUrl;

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
                  Positioned(
                    top: 0,
                    left: 32,
                    right: 32,
                    child: Container(
                      height: 1,
                      color: t.innerHi.withValues(alpha: 0.7),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _StripesPainter(
                          color: Colors.white.withValues(
                              alpha: t.dark ? 0.05 : 0.18),
                          spacing: 18,
                        ),
                      ),
                    ),
                  ),
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
                child: ClipOval(
                  child: _AvatarImage(t: t, url: avatarUrl, initial: initial),
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
// AVATAR IMAGE — real photo with graceful monogram fallback
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.t, required this.url, required this.initial});
  final _GlassTheme t;
  final String url;
  final String initial;

  Widget _fallback() => Container(
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
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            color: Colors.white,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback();
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // Use Image.asset(url) instead if the photo ships with the app bundle.
      loadingBuilder: (ctx, child, progress) =>
          progress == null ? child : _fallback(),
      errorBuilder: (ctx, _, __) => _fallback(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATOR DASHBOARD ENTRY CARD (owner only)
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardEntryCard extends StatelessWidget {
  const _DashboardEntryCard({
    required this.t,
    required this.reach,
    required this.views,
    required this.engagement,
    required this.onTap,
  });
  final _GlassTheme t;
  final String reach, views, engagement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mini = [
      ['Reach', reach.isNotEmpty ? reach : '--'],
      ['Views', views.isNotEmpty ? views : '--'],
      ['Eng.', engagement.isNotEmpty ? engagement : '--'],
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: t.cardShadow,
      ),
      child: _Frosted(
        radius: 22,
        sigma: 24,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: t.cardBorder, width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: t.cardFill,
                ),
              ),
              child: Stack(children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _StripesPainter(
                        color: Colors.white
                            .withValues(alpha: t.dark ? 0.05 : 0.16),
                        spacing: 18,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(Icons.insights_rounded, color: t.fg, size: 17),
                      const SizedBox(width: 9),
                      Text(
                        'Creator dashboard',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: t.fg,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Insights',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: t.muted,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: t.muted, size: 18),
                    ]),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < mini.length; i++) ...[
                          if (i > 0)
                            Container(
                              width: 1,
                              color: t.dark
                                  ? const Color(0x14FFFFFF)
                                  : const Color(0x14000000),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                            ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  mini[i][1],
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: t.fg,
                                    letterSpacing: -0.6,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mini[i][0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.muted,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIMARY ACTION BUTTON (filled — Edit profile)
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.t,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final _GlassTheme t;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: t.btnFg, size: 16),
                  const SizedBox(width: 7),
                  Text(
                    label,
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
          ),
        ),
      ),
    );
  }
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
// POSTS SECTION — real posts from API
// ─────────────────────────────────────────────────────────────────────────────
class _PostsSection extends StatelessWidget {
  const _PostsSection({
    required this.t,
    required this.count,
    required this.posts,
    required this.isLoading,
    this.myUserId,
    this.onPostDeleted,
  });
  final _GlassTheme t;
  final int count;
  final List<PostModel> posts;
  final bool isLoading;
  final String? myUserId;
  final void Function(String postId)? onPostDeleted;

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
                      '$count',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.muted,
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
                      color: t.fg,
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.muted,
                      ),
                    ),
                  ),
                )
              else
                _RealPostsGrid(
                  t: t,
                  posts: posts,
                  myUserId: myUserId,
                  onPostDeleted: onPostDeleted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RealPostsGrid extends StatelessWidget {
  const _RealPostsGrid({
    required this.t,
    required this.posts,
    this.myUserId,
    this.onPostDeleted,
  });
  final _GlassTheme t;
  final List<PostModel> posts;
  final String? myUserId;
  final void Function(String postId)? onPostDeleted;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) => _RealPostTile(
        t: t,
        post: posts[i],
        i: i,
        myUserId: myUserId,
        onDeleted: () => onPostDeleted?.call(posts[i].id),
      ),
    );
  }
}

class _RealPostTile extends StatelessWidget {
  const _RealPostTile({
    required this.t,
    required this.post,
    required this.i,
    this.myUserId,
    this.onDeleted,
  });
  final _GlassTheme t;
  final PostModel post;
  final int i;
  final String? myUserId;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final isVideo = post.mediaType == 'video';
    final imageUrl = isVideo && post.thumbnailUrl != null
        ? post.thumbnailUrl!
        : post.mediaUrl;

    final aPct = t.dark ? (22 - (i % 5) * 3) : (92 - (i % 5) * 4);
    final bPct = (aPct - (t.dark ? 12 : 18)).clamp(t.dark ? 4 : 56, 100).toDouble();
    final g1 = HSLColor.fromAHSL(1, 0, 0, aPct / 100).toColor();
    final g2 = HSLColor.fromAHSL(1, 0, 0, bPct / 100).toColor();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPostModal(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [g1, g2],
            ),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPostModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'post_card',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => _CreatorPostModal(
        t: t,
        post: post,
        myUserId: myUserId,
        onDeleted: onDeleted,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST MODAL for creator profile
// ─────────────────────────────────────────────────────────────────────────────
class _CreatorPostModal extends StatefulWidget {
  const _CreatorPostModal({
    required this.t,
    required this.post,
    this.myUserId,
    this.onDeleted,
  });
  final _GlassTheme t;
  final PostModel post;
  final String? myUserId;
  final VoidCallback? onDeleted;

  @override
  State<_CreatorPostModal> createState() => _CreatorPostModalState();
}

class _CreatorPostModalState extends State<_CreatorPostModal> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _liked = false;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    if (widget.post.mediaType == 'video') {
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

  bool get _isOwner =>
      widget.myUserId != null && widget.post.userId == widget.myUserId;

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

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n > 0 ? '$n' : '';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardW = size.width * 0.88;
    final isVideo = widget.post.mediaType == 'video';
    final thumbUrl = isVideo && widget.post.thumbnailUrl != null
        ? widget.post.thumbnailUrl!
        : widget.post.mediaUrl;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: cardW,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.07),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 42,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: widget.post.userPicture != null
                                      ? Image.network(widget.post.userPicture!, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _avatarFallback())
                                      : _avatarFallback(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.post.userName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                                    Text('@${widget.post.userUsername}',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              Text(widget.post.timeAgo,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                              if (_isOwner) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _confirmDelete(context),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.more_vert_rounded,
                                        color: Colors.white.withValues(alpha: 0.75), size: 20),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Media
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: cardW - 24,
                            height: cardW - 24,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(thumbUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: Colors.black26)),
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
                                  const Center(
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Actions
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _toggleLike,
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    Icon(
                                      _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: _liked ? const Color(0xFFFF4D6D) : Colors.white,
                                      size: 22,
                                    ),
                                    if (_likesCount > 0) ...[
                                      const SizedBox(width: 5),
                                      Text(_fmt(_likesCount),
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Row(
                                children: [
                                  const Icon(Icons.mode_comment_outlined, color: Colors.white, size: 22),
                                  if (widget.post.commentsCount > 0) ...[
                                    const SizedBox(width: 5),
                                    Text(_fmt(widget.post.commentsCount),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (widget.post.caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                            child: Text(
                              widget.post.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
    color: Colors.white24,
    alignment: Alignment.center,
    child: Text(
      widget.post.userName.isNotEmpty ? widget.post.userName[0].toUpperCase() : '?',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
    ),
  );

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.t.dark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Post?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This will permanently delete the post. This cannot be undone.',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
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
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BACKDROP
// ─────────────────────────────────────────────────────────────────────────────
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
