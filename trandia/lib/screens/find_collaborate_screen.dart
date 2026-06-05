// find_collaborate_screen.dart
//
// Trandia · Find & Collaborate — creator collab discovery screen.
// Single self-contained file, BOTH themes inside (light + dark) with a
// real LIQUID-GLASS effect (BackdropFilter blur on frosted cards + a soft
// gradient backdrop with blurred blobs).
//
//   • Theme is driven by the `dark` flag.
//   • The runnable demo (main + _FcDemo) has a Light/Dark toggle pill.
//     Remove those if you embed FindCollaborateScreen in your own app.
//   • No bottom navigation bar (by design).
//
// Card anatomy (compact):
//   [AV]  Name ✓                       📍 City, India
//         Short bio line …
//         [Niche] [125K Followers] [2.3M Views]
//   [ View Profile ]  [ Send Collab Request ]

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_model.dart';
import '../services/user_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RUNNABLE DEMO — light + dark in one file. Tap the pill to switch themes.
// ─────────────────────────────────────────────────────────────────────────────
void main() => runApp(const _FcDemo());

class _FcDemo extends StatefulWidget {
  const _FcDemo();
  @override
  State<_FcDemo> createState() => _FcDemoState();
}

class _FcDemoState extends State<_FcDemo> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Stack(children: [
        FindCollaborateScreen(dark: _dark),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: dark ? Colors.white.withValues(alpha: 0.10)
                            : Colors.white.withValues(alpha: 0.6),
                border: Border.all(
                    color: dark ? Colors.white.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.95)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(dark ? 'Dark' : 'Light',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.1)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME — paired light & dark (glass tokens).
// ─────────────────────────────────────────────────────────────────────────────
class FcTheme {
  final bool dark;
  final Color fg, sub, muted;
  final List<Color> cardBg;       // vertical gradient for glass surface
  final Color cardBorder;
  final Color pillBg, pillBorder;
  final Color ctaBg, ctaFg;
  final List<Color> bgGradient;   // page backdrop gradient (top → bottom)
  final List<_Blob> blobs;

  const FcTheme({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.muted,
    required this.cardBg,
    required this.cardBorder,
    required this.pillBg,
    required this.pillBorder,
    required this.ctaBg,
    required this.ctaFg,
    required this.bgGradient,
    required this.blobs,
  });

  List<BoxShadow> get cardShadow => dark
      ? [const BoxShadow(color: Color(0xD9000000), blurRadius: 40, spreadRadius: -22, offset: Offset(0, 18))]
      : [BoxShadow(color: const Color(0xFF14161E).withValues(alpha: 0.22), blurRadius: 40, spreadRadius: -22, offset: const Offset(0, 18))];

  Color avatarTop(int i) => dark
      ? HSLColor.fromAHSL(1, 0, 0, ((60 - (i % 6) * 6) / 100).clamp(0, 1)).toColor()
      : HSLColor.fromAHSL(1, 0, 0, ((90 - (i % 6) * 4) / 100).clamp(0, 1)).toColor();
  Color avatarBot(int i) => dark
      ? HSLColor.fromAHSL(1, 0, 0, (((60 - (i % 6) * 6) - 28).clamp(10, 100)) / 100).toColor()
      : HSLColor.fromAHSL(1, 0, 0, (((90 - (i % 6) * 4) - 30).clamp(34, 100)) / 100).toColor();

  static FcTheme of(bool dark) => dark ? _darkT : _lightT;

  static final _darkT = FcTheme(
    dark: true,
    fg: const Color(0xFFFFFFFF),
    sub: Colors.white.withValues(alpha: 0.55),
    muted: Colors.white.withValues(alpha: 0.72),
    cardBg: [Colors.white.withValues(alpha: 0.075), Colors.white.withValues(alpha: 0.03)],
    cardBorder: Colors.white.withValues(alpha: 0.10),
    pillBg: Colors.white.withValues(alpha: 0.08),
    pillBorder: Colors.white.withValues(alpha: 0.12),
    ctaBg: const Color(0xFFFFFFFF),
    ctaFg: const Color(0xFF0A0A0A),
    bgGradient: const [Color(0xFF161617), Color(0xFF08080A), Color(0xFF000000)],
    blobs: [
      _Blob(Colors.white.withValues(alpha: 0.10), const Alignment(0.6, -0.9), 320),
      _Blob(Colors.white.withValues(alpha: 0.05), const Alignment(-0.8, 0.1), 300),
      _Blob(Colors.white.withValues(alpha: 0.05), const Alignment(0.8, 0.95), 320),
    ],
  );

  static final _lightT = FcTheme(
    dark: false,
    fg: const Color(0xFF0A0A0A),
    sub: Colors.black.withValues(alpha: 0.52),
    muted: Colors.black.withValues(alpha: 0.68),
    cardBg: [Colors.white.withValues(alpha: 0.74), Colors.white.withValues(alpha: 0.56)],
    cardBorder: Colors.white.withValues(alpha: 0.95),
    pillBg: Colors.white.withValues(alpha: 0.62),
    pillBorder: Colors.black.withValues(alpha: 0.07),
    ctaBg: const Color(0xFF0A0A0A),
    ctaFg: const Color(0xFFFFFFFF),
    bgGradient: const [Color(0xFFFAFAFA), Color(0xFFECECEE), Color(0xFFDCDCE0)],
    blobs: [
      _Blob(Colors.white.withValues(alpha: 0.95), const Alignment(-1, -0.9), 320),
      _Blob(const Color(0xFF14161E).withValues(alpha: 0.10), const Alignment(0.9, -0.3), 300),
      _Blob(const Color(0xFF14161E).withValues(alpha: 0.07), const Alignment(-0.6, 0.95), 320),
    ],
  );
}

class _Blob {
  final Color color;
  final Alignment align;
  final double size;
  const _Blob(this.color, this.align, this.size);
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────────────────────
class FcCreator {
  final String id, name, niche, language, city, bio, followers, following;
  final bool verified;
  final bool isFollowing;
  const FcCreator({
    this.id = '',
    required this.name,
    required this.niche,
    required this.language,
    required this.city,
    required this.bio,
    required this.followers,
    required this.following,
    this.verified = false,
    this.isFollowing = false,
  });

  /// Builds a display card model from a real backend [UserProfile].
  factory FcCreator.fromProfile(UserProfile u) {
    return FcCreator(
      id: u.id,
      name: u.name.isNotEmpty ? u.name : '@${u.username}',
      niche: _accountTypeLabel(u.accountType),
      language: '',
      city: (u.locationCity ?? '').trim(),
      bio: (u.bio ?? '').trim().isNotEmpty
          ? u.bio!.trim()
          : 'Open to collaborations',
      followers: _compactCount(u.followersCount),
      following: _compactCount(u.followingCount),
      verified: u.followersCount >= 50000,
      isFollowing: u.isFollowing,
    );
  }
}

/// Human label for an account_type value.
String _accountTypeLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'business':
      return 'Business';
    case 'professional':
      return 'Professional';
    case 'creator':
    default:
      return 'Creator';
  }
}

/// 1500 → "1.5K", 1_200_000 → "1.2M".
String _compactCount(int n) {
  if (n >= 1000000) {
    final v = (n / 1000000);
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
  }
  if (n >= 1000) {
    final v = (n / 1000);
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
  }
  return '$n';
}

const _filters = ['All Niches', 'Followers', 'Following', 'Verified', 'Sort'];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class FindCollaborateScreen extends StatefulWidget {
  const FindCollaborateScreen({super.key, this.dark = true});

  /// Theme: true = dark, false = light.
  final bool dark;

  @override
  State<FindCollaborateScreen> createState() => _FindCollaborateScreenState();
}

class _FindCollaborateScreenState extends State<FindCollaborateScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<FcCreator> _results = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetch(value);
    });
  }

  Future<void> _fetch(String query) async {
    if (mounted) setState(() => _loading = true);
    final profiles = await UserService.searchCollaborators(query);
    if (!mounted) return;
    setState(() {
      _results = profiles.map(FcCreator.fromProfile).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final t = FcTheme.of(dark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      body: Stack(
        children: [
          // backdrop: gradient + blurred blobs
          Positioned.fill(child: _Backdrop(t: t)),

          // content
          SafeArea(
            bottom: false,
            child: DefaultTextStyle(
              style: TextStyle(color: t.fg, fontFamily: 'Manrope', decoration: TextDecoration.none),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 6, bottom: 28),
                children: [
                  _UrlBar(t: t, onBack: () => Navigator.maybePop(context)),
                  _Header(t: t),
                  _SearchRow(
                    t: t,
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 14),
                  _FilterChips(t: t),
                  const SizedBox(height: 16),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Center(
                        child: SizedBox(
                          width: 26, height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(t.fg),
                          ),
                        ),
                      ),
                    )
                  else if (_results.isEmpty)
                    _EmptyState(t: t, query: _query)
                  else
                    for (int i = 0; i < _results.length; i++)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _CreatorCard(c: _results[i], i: i, t: t),
                      ),
                  if (!_loading) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: _CollabBanner(t: t),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t, required this.query});
  final FcTheme t;
  final String query;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 40, color: t.sub),
          const SizedBox(height: 14),
          Text(
            query.trim().isEmpty
                ? 'No collaborators yet'
                : 'No creators found for “${query.trim()}”',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.fg, letterSpacing: -0.2),
          ),
          const SizedBox(height: 6),
          Text(
            'Only creator, business & professional accounts appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.sub, letterSpacing: -0.05),
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
  final FcTheme t;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: t.bgGradient,
        ),
      ),
      child: Stack(
        children: [
          for (final b in t.blobs)
            Align(
              alignment: b.align,
              child: Container(
                width: b.size, height: b.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [b.color, b.color.withValues(alpha: 0)],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
          // soften the blobs
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────
class _Glass extends StatelessWidget {
  const _Glass({
    required this.t,
    required this.child,
    this.radius = 18,
    this.padding = EdgeInsets.zero,
    this.sigma = 30,
    this.gradientFill = true,
    this.fill,
    this.shadow = true,
    this.sheen = false,
  });
  final FcTheme t;
  final Widget child;
  final double radius, sigma;
  final EdgeInsets padding;
  final bool gradientFill, shadow, sheen;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? t.cardShadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: gradientFill ? null : (fill ?? t.pillBg),
              gradient: gradientFill
                  ? LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: t.cardBg,
                    )
                  : null,
              border: Border.all(color: t.cardBorder, width: 1),
            ),
            child: Stack(
              children: [
                if (sheen)
                  Positioned(
                    top: 0, left: 18, right: 18,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          t.dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.95),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCircleBtn extends StatelessWidget {
  const _GlassCircleBtn({required this.t, required this.icon, this.size = 38});
  final FcTheme t;
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: t.cardShadow),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.pillBg,
              border: Border.all(color: t.cardBorder, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: size * 0.46, color: t.fg),
          ),
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.t, required this.child});
  final FcTheme t;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: t.pillBg,
            border: Border.all(color: t.pillBorder, width: 1),
          ),
          child: DefaultTextStyle(
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.muted,
                fontFamily: 'Manrope', letterSpacing: -0.05, decoration: TextDecoration.none),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTIONS
// ─────────────────────────────────────────────────────────────────────────────
class _UrlBar extends StatelessWidget {
  const _UrlBar({required this.t, this.onBack});
  final FcTheme t;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: _GlassCircleBtn(t: t, icon: Icons.arrow_back_ios_new_rounded),
          ),
          Expanded(
            child: Center(
              child: Text('trandia.in/marketplace/collab',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.muted,
                      fontFamily: 'monospace', letterSpacing: -0.1)),
            ),
          ),
          _GlassCircleBtn(t: t, icon: Icons.ios_share_rounded),
          const SizedBox(width: 10),
          _GlassCircleBtn(t: t, icon: Icons.more_vert_rounded),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.t});
  final FcTheme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find & Collaborate',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.75, height: 1.05)),
          const SizedBox(height: 6),
          Text('Discover creators and send collab requests',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: t.sub, letterSpacing: -0.1)),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.t, this.controller, this.onChanged});
  final FcTheme t;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _Glass(
              t: t,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 50,
                child: Row(children: [
                  Icon(Icons.search_rounded, size: 19, color: t.sub),
                  const SizedBox(width: 11),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      cursorColor: t.fg,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500, color: t.fg,
                          fontFamily: 'Manrope', letterSpacing: -0.1),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search creators, niches or keywords…',
                        hintStyle: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: t.sub,
                            fontFamily: 'Manrope', letterSpacing: -0.1),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Glass(
            t: t,
            radius: 16,
            child: SizedBox(
              width: 50, height: 50,
              child: Icon(Icons.tune_rounded, size: 20, color: t.fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.t});
  final FcTheme t;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) => _Glass(
          t: t,
          radius: 999,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_filters[i],
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.1)),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: t.sub),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATOR CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.c, required this.i, required this.t});
  final FcCreator c;
  final int i;
  final FcTheme t;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      t: t,
      radius: 18,
      sheen: true,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // avatar
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [t.avatarTop(i), t.avatarBot(i)],
                  ),
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.0))],
                ),
                alignment: Alignment.center,
                child: Text(c.name[0],
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
              ),
              const SizedBox(width: 11),
              // middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // name + location
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(c.name,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: t.fg, letterSpacing: -0.3)),
                              ),
                              if (c.verified) ...[
                                const SizedBox(width: 5),
                                Icon(Icons.verified_rounded, size: 14, color: t.fg),
                              ],
                            ],
                          ),
                        ),
                        if (c.city.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.place_outlined, size: 12, color: t.sub),
                            const SizedBox(width: 3),
                            Text(c.city,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.sub, letterSpacing: -0.05)),
                          ]),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // bio
                    Text(c.bio,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.muted, height: 1.4, letterSpacing: -0.05)),
                    const SizedBox(height: 8),
                    // niche + stats
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: [
                        _TinyPill(t: t, child: Text(c.niche)),
                        _TinyPill(t: t, child: _statText('${c.followers} ', 'Followers')),
                        _TinyPill(t: t, child: _statText('${c.following} ', 'Following')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          // buttons
          Row(children: [
            Expanded(
              flex: 10,
              child: _Glass(
                t: t,
                radius: 999,
                shadow: false,
                sigma: 16,
                child: const SizedBox(
                  height: 36,
                  child: Center(child: _BtnLabel('View Profile')),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 14,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: t.ctaBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text('Send Collab Request',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ctaFg, letterSpacing: -0.1)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _statText(String strong, String rest) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.muted, fontFamily: 'Manrope', letterSpacing: -0.05),
        children: [
          TextSpan(text: strong, style: TextStyle(color: t.fg, fontWeight: FontWeight.w700)),
          TextSpan(text: rest),
        ],
      ),
    );
  }
}

class _BtnLabel extends StatelessWidget {
  const _BtnLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Text(text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.1));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLLAB BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _CollabBanner extends StatelessWidget {
  const _CollabBanner({required this.t});
  final FcTheme t;
  @override
  Widget build(BuildContext context) {
    return _Glass(
      t: t,
      radius: 18,
      sheen: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: t.pillBg,
              border: Border.all(color: t.cardBorder, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.groups_outlined, size: 22, color: t.fg),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Looking to collaborate?',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: t.fg, letterSpacing: -0.15)),
                const SizedBox(height: 2),
                Text('Create a collab post and let creators approach you.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.sub, letterSpacing: -0.05)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: t.ctaBg, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.center,
            child: Text('Create Collab Post',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.ctaFg, letterSpacing: -0.1)),
          ),
        ],
      ),
    );
  }
}
