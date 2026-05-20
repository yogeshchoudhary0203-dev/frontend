// profile_screen.dart
// Classy, professional profile screen — matte glass monochrome.
// Layout: top bar → cover band → overlapping avatar → name/handle →
// title chip → bio → website → stats card → CTAs → highlights → tabs → grid.
//
// Drop in `lib/` alongside glass_common.dart.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'glass_common.dart';
import 'setting_screen.dart';

// ───────────────────────────────────────────────────────────────
// Models
// ───────────────────────────────────────────────────────────────

class HighlightItem {
  final String label;
  final int seed;
  const HighlightItem(this.label, this.seed);
}

enum ProfileTileKind { photo, reel, carousel }

class ProfileTile {
  final ProfileTileKind kind;
  final int? count;
  const ProfileTile({required this.kind, this.count});
}

const _highlights = <HighlightItem>[
  HighlightItem('Work', 1),
  HighlightItem('Studio', 2),
  HighlightItem('Travel', 3),
  HighlightItem('Reads', 4),
  HighlightItem('Type', 5),
];

List<ProfileTile> _buildProfileTiles() => List.generate(12, (i) {
  final kind = (i == 1 || i == 7)
      ? ProfileTileKind.carousel
      : (i == 4 || i == 10)
          ? ProfileTileKind.reel
          : ProfileTileKind.photo;
  final count = i == 1 ? 4 : i == 7 ? 3 : null;
  return ProfileTile(kind: kind, count: count);
});

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
  final _tiles = _buildProfileTiles();

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final muted = dark ? Colors.white.withOpacity(0.72) : Colors.black.withOpacity(0.72);
    final hairline = dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Center(
        child: SingleChildScrollView(
          child: DefaultTextStyle(
            style: const TextStyle(
              decoration: TextDecoration.none,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      const Spacer(),
                      GlassCircleButton(
                        dark: dark,
                        icon: Icons.settings_outlined,
                        iconSize: 19,
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (_, animation, __) => SettingsScreen(dark: dark),
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
                          );
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
                        ),
                        Positioned(
                          top: 96,
                          child: Container(
                            width: 116,
                            height: 116,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA),
                              boxShadow: [
                                BoxShadow(
                                  color: dark
                                      ? Colors.black.withOpacity(0.8)
                                      : const Color(0xFF14161E).withOpacity(0.25),
                                  blurRadius: 36,
                                  offset: const Offset(0, 18),
                                  spreadRadius: -16,
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: monoAvatar(dark, 0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.22),
                                    blurRadius: 0,
                                    offset: const Offset(0, 1),
                                    spreadRadius: -1,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'S',
                                style: manrope(
                                  size: 42,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -1.26,
                                ),
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
                _NameBlock(dark: dark, fg: fg, sub: sub),

                const SizedBox(height: 12),

                // TITLE CHIP
                Center(child: _TitleChip(dark: dark, muted: muted, fg: fg)),

                // BIO
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
                  child: Text(
                    'Designer & art director.\n'
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
                  ),
                ),

                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _PostsBox(
                    dark: dark,
                    fg: fg,
                    sub: sub,
                    tiles: _tiles,
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

Future<void> _openSocialLink(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _SocialLinksRow extends StatelessWidget {
  final bool dark;
  final Color fg;
  const _SocialLinksRow({required this.dark, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.snapchat,
            color: const Color(0xFFFFFC00),
            label: 'Snapchat',
            url: 'https://www.snapchat.com/add/sarah.d',
          ),
          const SizedBox(width: 10),
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.instagram,
            color: const Color(0xFFE4405F),
            label: 'Instagram',
            url: 'https://www.instagram.com/sarah.d',
          ),
          const SizedBox(width: 10),
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.whatsapp,
            color: const Color(0xFF25D366),
            label: 'WhatsApp',
            url: 'https://wa.me/15551234567',
          ),
          const SizedBox(width: 10),
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.facebookF,
            color: const Color(0xFF1877F2),
            label: 'Facebook',
            url: 'https://www.facebook.com/sarah.d',
          ),
          const SizedBox(width: 10),
          _SocialButton(
            dark: dark,
            icon: FontAwesomeIcons.xTwitter,
            color: dark ? Colors.white : const Color(0xFF000000),
            label: 'Twitter',
            url: 'https://twitter.com/sarah_d',
          ),
        ],
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
  const _SocialButton({
    required this.dark,
    required this.icon,
    required this.color,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => _openSocialLink(url),
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.8),
            border: Border.all(
              color: dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
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
  final List<ProfileTile> tiles;
  const _PostsBox({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      dark: dark,
      radius: 28,
      padding: const EdgeInsets.all(10),
      blurSigma: 28,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
          child: Row(children: [
            Icon(Icons.grid_on_rounded, size: 15, color: fg),
            const SizedBox(width: 7),
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
              '${tiles.length}',
              style: manrope(
                size: 12,
                weight: FontWeight.w700,
                color: sub,
                letterSpacing: -0.12,
              ),
            ),
          ]),
        ),
        _ProfileGrid(dark: dark, tiles: tiles),
      ]),
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
  const _CoverBand({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.hairline,
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
          color: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.95),
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withOpacity(0.7) : const Color(0xFF14161E).withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          // top sheen
          Positioned(
            top: 0, left: 24, right: 24, height: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: dark
                    ? [Colors.transparent, Colors.white.withOpacity(0.18), Colors.transparent]
                    : [Colors.transparent, Colors.white, Colors.transparent]),
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
            ),
          ),
        ]),
      ),
    );
  }
}

class _CoverStatsRow extends StatelessWidget {
  final Color fg;
  final Color sub;
  final Color hairline;
  const _CoverStatsRow({
    required this.fg,
    required this.sub,
    required this.hairline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _Stat(value: '24.3K', label: 'Followers', fg: fg, sub: sub)),
      Container(width: 1, height: 30, color: hairline),
      Expanded(child: _Stat(value: '482', label: 'Following', fg: fg, sub: sub)),
      Container(width: 1, height: 30, color: hairline),
      Expanded(child: _Stat(value: '168', label: 'Posts', fg: fg, sub: sub)),
    ]);
  }
}

class _DiagonalStripesPainter extends CustomPainter {
  final bool dark;
  _DiagonalStripesPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withOpacity(dark ? 0.04 : 0.025)
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
  const _NameBlock({required this.dark, required this.fg, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(
              'Sarah Dietrich',
              style: manrope(
                size: 24,
                weight: FontWeight.w800,
                color: fg,
                letterSpacing: -0.6,
              ),
            )),
            const SizedBox(width: 6),
            Icon(Icons.verified_rounded, size: 18, color: fg),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '@sarah.d · she/her',
          style: manrope(
            size: 13,
            weight: FontWeight.w500,
            color: sub,
            letterSpacing: -0.065,
          ),
        ),
      ]),
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
            color: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.6),
            border: Border.all(
              color: dark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 5, height: 5,
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
          ]),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _Stat(value: '168', label: 'Posts', fg: fg, sub: sub)),
        Container(width: 1, color: hairline, margin: const EdgeInsets.symmetric(vertical: 4)),
        Expanded(child: _Stat(value: '24.3K', label: 'Followers', fg: fg, sub: sub)),
        Container(width: 1, color: hairline, margin: const EdgeInsets.symmetric(vertical: 4)),
        Expanded(child: _Stat(value: '482', label: 'Following', fg: fg, sub: sub)),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color fg;
  final Color sub;
  const _Stat({required this.value, required this.label, required this.fg, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          label.toUpperCase(),
          style: manrope(
            size: 10.5,
            weight: FontWeight.w700,
            color: sub,
            letterSpacing: 1.05,
          ),
        ),
      ],
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
        style: ElevatedButton.styleFrom(
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
          label,
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
            color: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.6),
            border: Border.all(
              color: dark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.08),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
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
    required this.dark, required this.size, required this.child, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: size, height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.6),
              border: Border.all(
                color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: dark ? Colors.black.withOpacity(0.7) : const Color(0xFF14161E).withOpacity(0.18),
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
  const _HighlightsRow({required this.dark, required this.sub, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64, height: 64,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.14),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA),
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
                ]),
              );
            },
          ),
        ),
      ]),
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
            color: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.6),
            border: Border.all(
              color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            _TabButton(label: 'Posts',  icon: Icons.grid_on_rounded,         active: active=='Posts',  dark: dark, muted: muted, onTap: () => onChange('Posts')),
            _TabButton(label: 'Reels',  icon: Icons.movie_creation_outlined,  active: active=='Reels',  dark: dark, muted: muted, onTap: () => onChange('Reels')),
            _TabButton(label: 'Tagged', icon: Icons.local_offer_outlined,     active: active=='Tagged', dark: dark, muted: muted, onTap: () => onChange('Tagged')),
          ]),
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
    required this.label, required this.icon, required this.active,
    required this.dark, required this.muted, required this.onTap,
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
                label,
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
  final List<ProfileTile> tiles;
  const _ProfileGrid({required this.dark, required this.tiles});

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
      itemCount: tiles.length,
      itemBuilder: (_, i) => _ProfileTileView(t: tiles[i], i: i, dark: dark),
    );
  }
}

class _ProfileTileView extends StatelessWidget {
  final ProfileTile t;
  final int i;
  final bool dark;
  const _ProfileTileView({required this.t, required this.i, required this.dark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: _tileGradient(dark, i),
        ),
        child: Stack(fit: StackFit.expand, children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -1),
                radius: 1.2,
                colors: dark
                    ? [Colors.white.withOpacity(0.06), Colors.transparent]
                    : [Colors.white.withOpacity(0.55), Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          if (t.kind != ProfileTileKind.photo)
            Positioned(
              top: 6, right: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: Colors.black.withOpacity(0.42),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        t.kind == ProfileTileKind.reel
                            ? Icons.play_arrow_rounded
                            : Icons.collections_outlined,
                        size: 11,
                        color: Colors.white,
                      ),
                      if (t.kind == ProfileTileKind.carousel && t.count != null) ...[
                        const SizedBox(width: 3),
                        Text(
                          '${t.count}',
                          style: manrope(
                            size: 10,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
