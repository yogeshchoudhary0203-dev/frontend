// trandia_marketplace_screen.dart
//
// Trandia · Creators Marketplace — listing screen.
// Single self-contained file, BOTH themes inside (light + dark).
// Pure monochrome system — no gradients, no colour accents.
//   • Theme is driven by the `dark` flag.
//   • The runnable demo (main + _TrmDemo) has a Light/Dark toggle pill.
//     Remove those two if you embed TrandiaMarketplaceScreen in your own app
//     and drive `dark` yourself.
//
// Card anatomy (rectangular, 16r, hairline border):
//   [AV]  Name  ✓  [tag]                       [chevron]
//         Category · Language
//         125K Followers · 4.9★ (48) · Replies in 2h
//         WORKED WITH  [brand] [brand] [brand]
//   ───────────────────────────────────────────────────
//   Starts at  ₹15,000  ₹18,750         [20% OFF]  [Book]

import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import 'package:flutter/services.dart';
import 'trandia_marketplace_profile_screen.dart';
import '../services/marketplace_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RUNNABLE DEMO — light + dark in one file. Tap the pill to switch themes.
// ─────────────────────────────────────────────────────────────────────────────
void main() => runApp(const _TrmDemo());

class _TrmDemo extends StatefulWidget {
  const _TrmDemo();
  @override
  State<_TrmDemo> createState() => _TrmDemoState();
}

class _TrmDemoState extends State<_TrmDemo> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Stack(children: [
        TrandiaMarketplaceScreen(dark: _dark),
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
    final bg = dark ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.05);
    final br = dark ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.12);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: bg,
            border: Border.all(color: br),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 16, color: fg),
            const SizedBox(width: 8),
            Text(dark ? 'Dark' : 'Light',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: fg,
                    letterSpacing: -0.1)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME — paired light & dark. Same structural roles, inverted surface.
// ─────────────────────────────────────────────────────────────────────────────
class TrmTheme {
  final bool dark;
  final Color bg, surf, surf2, line, fg, sub, tag, dim;
  final Color ctaBg, ctaFg, badgeBg, badgeFg;
  const TrmTheme({
    required this.dark,
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.line,
    required this.fg,
    required this.sub,
    required this.tag,
    required this.dim,
    required this.ctaBg,
    required this.ctaFg,
    required this.badgeBg,
    required this.badgeFg,
  });

  static const _darkT = TrmTheme(
    dark: true,
    bg: Color(0xFF000000),
    surf: Color(0xFF0E0E0E),
    surf2: Color(0xFF141414),
    line: Color(0xFF2A2A2A),
    fg: Color(0xFFFFFFFF),
    sub: Color(0xFF8A8A8A),
    tag: Color(0xFF1F1F1F),
    dim: Color(0xFF1A1A1A),
    ctaBg: Color(0xFFFFFFFF), ctaFg: Color(0xFF000000),
    badgeBg: Color(0xFFFFFFFF), badgeFg: Color(0xFF000000),
  );

  static const _lightT = TrmTheme(
    dark: false,
    bg: Color(0xFFFFFFFF),
    surf: Color(0xFFFAFAFA),
    surf2: Color(0xFFF2F2F2),
    line: Color(0xFFE5E5E5),
    fg: Color(0xFF0A0A0A),
    sub: Color(0xFF8A8A8A),
    tag: Color(0xFFF2F2F2),
    dim: Color(0xFFF0F0F0),
    ctaBg: Color(0xFF0A0A0A), ctaFg: Color(0xFFFFFFFF),
    badgeBg: Color(0xFF0A0A0A), badgeFg: Color(0xFFFFFFFF),
  );

  static TrmTheme of(bool dark) => dark ? _darkT : _lightT;

  // ── Glass tokens (translucent overlays on top of the aurora bg) ───────────
  Color get glassFill =>
      dark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.55);
  Color get glassFillStrong =>
      dark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.72);
  Color get glassBorder =>
      dark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.90);
  Color get glassBorderSoft =>
      dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06);
  Color get glassHighlight =>
      dark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.55);
  Color get glassShadow =>
      dark ? Colors.black.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.08);
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────────────────────
enum TrmTagKind { offer, neu, hot } // 'new' is reserved in Dart → neu

class TrmTag {
  final TrmTagKind kind;
  final String label;
  const TrmTag(this.kind, this.label);
}

class TrmCreator {
  final String userId;
  final String initials, name, category, language, followers, rating;
  final int reviews;
  final String reply, price;
  final String? priceWas, offer;
  final bool verified;
  final List<String>? brands;
  final TrmTag? tag;
  const TrmCreator({
    this.userId = '',
    required this.initials,
    required this.name,
    required this.category,
    required this.language,
    required this.followers,
    required this.rating,
    required this.reviews,
    required this.reply,
    required this.price,
    this.priceWas,
    this.offer,
    this.verified = false,
    this.brands,
    this.tag,
  });

  /// Builds a listing card model from a real applied creator. Fields the apply
  /// form doesn't collect (rating, reply time, price, brands) stay empty and the
  /// card renders honest "New" / "On request" states instead of fake numbers.
  factory TrmCreator.fromMarketplace(MarketplaceCreator c) => TrmCreator(
        userId: c.userId,
        initials: c.initials,
        name: c.name,
        category: c.category,
        language: c.languageLabel,
        followers: MarketplaceService.compactCount(c.followers),
        rating: '',
        reviews: 0,
        reply: '',
        price: '',
        verified: c.verified,
      );
}

const _cats = ['All', 'Comedy', 'Fashion', 'Tech', 'Lifestyle', 'Gaming', 'Food', 'Travel'];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class TrandiaMarketplaceScreen extends StatefulWidget {
  const TrandiaMarketplaceScreen({super.key, this.dark = true});

  /// Theme: true = dark, false = light.
  final bool dark;

  @override
  State<TrandiaMarketplaceScreen> createState() => _TrandiaMarketplaceScreenState();
}

class _TrandiaMarketplaceScreenState extends State<TrandiaMarketplaceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<MarketplaceCreator> _results = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('Marketplace');
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
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(value));
  }

  Future<void> _fetch(String query) async {
    if (mounted) setState(() => _loading = true);
    final creators = await MarketplaceService.searchCreators(query);
    if (!mounted) return;
    setState(() {
      _results = creators;
      _loading = false;
    });
  }

  void _openCreatorProfile(BuildContext context, MarketplaceCreator c) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, animation, __) =>
          TrandiaProfileScreen(dark: widget.dark, creator: c),
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final t = TrmTheme.of(dark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: t.bg,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: t.bg,
      body: DefaultTextStyle(
        style: TextStyle(
          color: t.fg,
          fontFamily: 'Inter',
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _AuroraBg(dark: dark)),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(t: t, count: _results.length),
                    _SearchBar(
                      t: t,
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                    ),
                    _Filters(t: t),
                    _SortRow(t: t, count: _results.length),
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
                      _EmptyResults(t: t, query: _query)
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          children: [
                            for (final c in _results) ...[
                              _TapScale(
                                onTap: () => _openCreatorProfile(context, c),
                                child: _CreatorCard(
                                    c: TrmCreator.fromMarketplace(c), t: t),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          '— END OF RESULTS —',
                          style: TextStyle(
                            fontSize: 11, color: t.sub, fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
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
// EMPTY RESULTS
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.t, required this.query});
  final TrmTheme t;
  final String query;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined, size: 42, color: t.sub),
          const SizedBox(height: 14),
          Text(
            query.trim().isEmpty
                ? 'No creators in the marketplace yet'
                : 'No creators found for “${query.trim()}”',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.2),
          ),
          const SizedBox(height: 6),
          Text(
            'Only creators who applied to the Trandia Marketplace appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.sub, letterSpacing: -0.05),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.t, required this.count});
  final TrmTheme t;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.maybePop(context),
            child: _IconBtn(t: t, child: Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: t.fg)),
          ),
          Expanded(
            child: Column(
              children: [
                Text('Marketplace',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: t.fg,
                        letterSpacing: -0.25, height: 1)),
                const SizedBox(height: 5),
                Text('$count creator${count == 1 ? '' : 's'} available',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: t.sub,
                        letterSpacing: -0.05, height: 1)),
              ],
            ),
          ),
          _IconBtn(t: t, child: Icon(Icons.tune_rounded, size: 18, color: t.fg)),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.t, required this.child, this.size = 40});
  final TrmTheme t;
  final Widget child;
  final double size;
  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.glassFillStrong, t.glassFill],
            ),
            border: Border.all(color: t.glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: t.glassShadow,
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.t, this.controller, this.onChanged});
  final TrmTheme t;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.glassFillStrong, t.glassFill],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: t.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: t.glassShadow,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 19, color: t.fg),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    cursorColor: t.fg,
                    style: TextStyle(
                        fontSize: 13.5, color: t.fg, fontWeight: FontWeight.w600,
                        fontFamily: 'Inter', letterSpacing: -0.05),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Search by name, category, niche…',
                      hintStyle: TextStyle(
                          fontSize: 13.5, color: t.sub, fontWeight: FontWeight.w500,
                          fontFamily: 'Inter', letterSpacing: -0.05),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.glassFillStrong,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.glassBorderSoft, width: 1),
                  ),
                  child: Text('⌘K',
                      style: TextStyle(
                          fontSize: 10, color: t.fg, fontWeight: FontWeight.w800,
                          letterSpacing: 0.4, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIPS (stateful: active chip)
// ─────────────────────────────────────────────────────────────────────────────
class _Filters extends StatefulWidget {
  const _Filters({required this.t});
  final TrmTheme t;
  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  String _active = 'All';
  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < _cats.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _Chip(
                label: _cats[i],
                active: _active == _cats[i],
                t: t,
                onTap: () => setState(() => _active = _cats[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.t, required this.onTap});
  final String label;
  final bool active;
  final TrmTheme t;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: active
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.glassFillStrong, t.glassFill],
              ),
        color: active ? t.ctaBg : null,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? t.ctaBg : t.glassBorder,
          width: 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: t.glassShadow,
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: active ? t.ctaFg : t.fg, letterSpacing: -0.06)),
    );
    return GestureDetector(
      onTap: onTap,
      child: active
          ? inner
          : ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: inner,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SORT ROW
// ─────────────────────────────────────────────────────────────────────────────
class _SortRow extends StatelessWidget {
  const _SortRow({required this.t, required this.count});
  final TrmTheme t;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text('$count',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.05)),
            const SizedBox(width: 5),
            Text('result${count == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.sub, letterSpacing: -0.05)),
          ]),
          Row(children: [
            Text('Sort: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.sub, letterSpacing: -0.05)),
            Text('Trending',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.05)),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: t.fg),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATOR CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.c, required this.t});
  final TrmCreator c;
  final TrmTheme t;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.glassFillStrong, t.glassFill],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: t.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: t.glassShadow,
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // row 1 — avatar + identity + chevron
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(initials: c.initials, t: t),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w800,
                                          color: t.fg, letterSpacing: -0.25, height: 1.1)),
                                ),
                                if (c.verified) ...[
                                  const SizedBox(width: 6),
                                  _Verified(s: 13, t: t),
                                ],
                                if (c.tag != null) ...[
                                  const SizedBox(width: 6),
                                  _OfferPill(kind: c.tag!.kind, t: t, label: c.tag!.label),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              Flexible(
                                child: Text(c.category,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: t.sub, fontWeight: FontWeight.w700, letterSpacing: -0.05)),
                              ),
                              if (c.language.isNotEmpty) ...[
                                _Dot(t: t),
                                Flexible(
                                  child: Text(c.language,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: t.sub, fontWeight: FontWeight.w700, letterSpacing: -0.05)),
                                ),
                              ],
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [t.glassFillStrong, t.glassFill],
                        ),
                        border: Border.all(color: t.glassBorder, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_right_rounded, size: 17, color: t.fg),
                    ),
                  ],
                ),

                // row 2 — inline stats
                const SizedBox(height: 12),
                Wrap(
                  spacing: 9,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statBit('${c.followers} ', 'Followers', t),
                    _Dot(t: t),
                    // Rating when the creator has reviews, otherwise an honest "New".
                    if (c.rating.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_rounded, size: 12, color: t.fg),
                        const SizedBox(width: 3),
                        Text(c.rating, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: t.fg)),
                        const SizedBox(width: 3),
                        Text('(${c.reviews})', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.sub)),
                      ])
                    else
                      Text('New',
                          style: TextStyle(fontSize: 11.5, color: t.sub, fontWeight: FontWeight.w700, letterSpacing: -0.05)),
                    if (c.reply.isNotEmpty) ...[
                      _Dot(t: t),
                      Text('Replies in ${c.reply}',
                          style: TextStyle(fontSize: 11.5, color: t.sub, fontWeight: FontWeight.w600, letterSpacing: -0.05)),
                    ],
                  ],
                ),

                // row 3 — brand collabs
                if (c.brands != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('WORKED WITH',
                          style: TextStyle(
                              fontSize: 10, color: t.sub, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      for (final b in c.brands!)
                        Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.glassFillStrong,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: t.glassBorderSoft, width: 1),
                          ),
                          child: Text(b,
                              style: TextStyle(fontSize: 11, color: t.fg, fontWeight: FontWeight.w700, letterSpacing: -0.05)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
              ],
            ),
          ),

          // divider + footer
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.glassBorderSoft, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.price.isEmpty ? 'PRICING' : 'STARTS AT',
                        style: TextStyle(fontSize: 10, color: t.sub, fontWeight: FontWeight.w800, letterSpacing: 1.2, height: 1)),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      Text(c.price.isEmpty ? 'On request' : c.price,
                          style: TextStyle(fontSize: c.price.isEmpty ? 15 : 18, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.45, height: 1)),
                      if (c.priceWas != null) ...[
                        const SizedBox(width: 7),
                        Text(c.priceWas!,
                            style: TextStyle(
                                fontSize: 12, color: t.sub, fontWeight: FontWeight.w600,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: t.sub)),
                      ],
                    ]),
                  ],
                ),
                Row(children: [
                  if (c.offer != null) ...[
                    _OfferPill(kind: TrmTagKind.offer, t: t, label: c.offer!),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.ctaBg,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: t.glassShadow,
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text('Book',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.ctaFg, letterSpacing: -0.12)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _statBit(String strong, String rest, TrmTheme t) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(strong, style: TextStyle(fontSize: 11.5, color: t.fg, fontWeight: FontWeight.w600)),
      Text(rest, style: TextStyle(fontSize: 11.5, color: t.sub, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL BITS
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.t, this.size = 54});
  final String initials;
  final TrmTheme t;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.glassHighlight, t.glassFill],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: t.glassShadow,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.34)),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.t});
  final TrmTheme t;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3, height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(color: t.sub, shape: BoxShape.circle),
    );
  }
}

class _Verified extends StatelessWidget {
  const _Verified({required this.s, required this.t});
  final double s;
  final TrmTheme t;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(color: t.badgeBg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(Icons.check_rounded, size: s * 0.66, color: t.badgeFg),
    );
  }
}

/// Offer / tag pill. kind:
///   offer → outline (fg border, transparent fill)
///   neu   → inverted fill (badge colours)
///   hot   → filled tag with bolt
class _OfferPill extends StatelessWidget {
  const _OfferPill({required this.kind, required this.t, required this.label});
  final TrmTagKind kind;
  final TrmTheme t;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (kind == TrmTagKind.neu) {
      return Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.badgeBg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(fontSize: 10, color: t.badgeFg, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
      );
    }
    if (kind == TrmTagKind.hot) {
      return Container(
        height: 24,
        padding: const EdgeInsets.fromLTRB(8, 0, 11, 0),
        decoration: BoxDecoration(
          color: t.glassFillStrong,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.glassBorder, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt_rounded, size: 12, color: t.fg),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: t.fg, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ]),
      );
    }
    // offer (outline)
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.fg, width: 1.2),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10.5, color: t.fg, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AURORA BACKGROUND — soft blurred blobs so the glass blur has something to read
// ─────────────────────────────────────────────────────────────────────────────
class _AuroraBg extends StatelessWidget {
  const _AuroraBg({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final c1 = dark ? const Color(0x33FFFFFF) : const Color(0x22000000);
    final c2 = dark ? const Color(0x22FFFFFF) : const Color(0x14000000);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120, right: -90,
            child: _Blob(size: 320, color: c1),
          ),
          Positioned(
            top: 220, left: -110,
            child: _Blob(size: 260, color: c2),
          ),
          Positioned(
            bottom: -90, right: -60,
            child: _Blob(size: 280, color: c2),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAP SCALE — tiny micro-interaction for premium feel
// ─────────────────────────────────────────────────────────────────────────────
class _TapScale extends StatefulWidget {
  const _TapScale({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
