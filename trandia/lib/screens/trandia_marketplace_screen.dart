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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'trandia_marketplace_profile_screen.dart';

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
  final Color bg, surf, surf2, line, fg, sub, tag, dim;
  final Color ctaBg, ctaFg, badgeBg, badgeFg;
  const TrmTheme({
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

  static const dark = TrmTheme(
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

  static const light = TrmTheme(
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

  static TrmTheme of(bool dark) => dark ? TrmTheme.dark : TrmTheme.light;
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
  final String initials, name, category, language, followers, rating;
  final int reviews;
  final String reply, price;
  final String? priceWas, offer;
  final bool verified;
  final List<String>? brands;
  final TrmTag? tag;
  const TrmCreator({
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
}

const _creators = <TrmCreator>[
  TrmCreator(
    initials: 'AS', name: 'Aryan Sharma', verified: true,
    category: 'Comedy', language: 'Hindi',
    followers: '125K', rating: '4.9', reviews: 48, reply: '2h',
    price: '₹15,000', priceWas: '₹18,750', offer: '20% OFF',
    brands: ['Boat', 'Zomato', 'CRED'],
    tag: TrmTag(TrmTagKind.hot, 'TRENDING'),
  ),
  TrmCreator(
    initials: 'PM', name: 'Priya Mehta', verified: true,
    category: 'Fashion', language: 'English · Hindi',
    followers: '480K', rating: '5.0', reviews: 112, reply: '1h',
    price: '₹35,000',
    brands: ['Myntra', 'Nykaa', 'H&M'],
    tag: TrmTag(TrmTagKind.neu, 'TOP RATED'),
  ),
  TrmCreator(
    initials: 'RK', name: 'Rohan Kapoor', verified: false,
    category: 'Tech', language: 'Hindi',
    followers: '92K', rating: '4.7', reviews: 24, reply: '4h',
    price: '₹8,000',
    brands: ['OnePlus', 'Realme'],
  ),
  TrmCreator(
    initials: 'SI', name: 'Sneha Iyer', verified: true,
    category: 'Lifestyle', language: 'English',
    followers: '1.2M', rating: '4.9', reviews: 207, reply: '3h',
    price: '₹85,000', priceWas: '₹1,00,000', offer: '15% OFF',
    brands: ['Mamaearth', 'Plum', 'Wow'],
  ),
  TrmCreator(
    initials: 'KS', name: 'Karan Singh', verified: true,
    category: 'Gaming', language: 'Hindi',
    followers: '340K', rating: '4.8', reviews: 76, reply: '6h',
    price: '₹22,000',
    brands: ['Logitech', 'BGMI'],
    tag: TrmTag(TrmTagKind.hot, 'TRENDING'),
  ),
  TrmCreator(
    initials: 'AR', name: 'Anika Roy', verified: false,
    category: 'Food', language: 'Hindi · English',
    followers: '210K', rating: '4.8', reviews: 51, reply: '5h',
    price: '₹18,000', offer: 'NEW',
    brands: ['Swiggy', 'Licious'],
  ),
];

const _cats = ['All', 'Comedy', 'Fashion', 'Tech', 'Lifestyle', 'Gaming', 'Food', 'Travel'];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class TrandiaMarketplaceScreen extends StatelessWidget {
  const TrandiaMarketplaceScreen({super.key, this.dark = true});

  /// Theme: true = dark, false = light.
  final bool dark;

  void _openCreatorProfile(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, animation, __) => TrandiaProfileScreen(dark: dark),
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
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(t: t),
                _SearchBar(t: t),
                _Filters(t: t),
                _SortRow(t: t),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final c in _creators) ...[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openCreatorProfile(context),
                          child: _CreatorCard(c: c, t: t),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '— END OF RESULTS —',
                    style: TextStyle(
                      fontSize: 11, color: t.sub, fontWeight: FontWeight.w500,
                      letterSpacing: 0.9,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.t});
  final TrmTheme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
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
                        fontSize: 15, fontWeight: FontWeight.w600, color: t.fg,
                        letterSpacing: -0.2, height: 1)),
                const SizedBox(height: 5),
                Text('247 creators available',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500, color: t.sub,
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
  const _IconBtn({required this.t, required this.child, this.size = 36});
  final TrmTheme t;
  final Widget child;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.line, width: 1),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.t});
  final TrmTheme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: t.surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.line, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: t.sub),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Search by name, category, niche…',
                  style: TextStyle(fontSize: 13.5, color: t.sub, letterSpacing: -0.05)),
            ),
            Container(width: 1, height: 18, color: t.line, margin: const EdgeInsets.only(right: 8)),
            Container(
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.tag,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('⌘K',
                  style: TextStyle(
                      fontSize: 10, color: t.sub, fontWeight: FontWeight.w600,
                      letterSpacing: 0.4, fontFamily: 'monospace')),
            ),
          ],
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
      padding: const EdgeInsets.only(top: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? t.ctaBg : t.tag,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: t.line, width: 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w500,
                color: active ? t.ctaFg : t.fg, letterSpacing: -0.06)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SORT ROW
// ─────────────────────────────────────────────────────────────────────────────
class _SortRow extends StatelessWidget {
  const _SortRow({required this.t});
  final TrmTheme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text('247',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.05)),
            const SizedBox(width: 5),
            Text('results',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.sub, letterSpacing: -0.05)),
          ]),
          Row(children: [
            Text('Sort: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.fg, letterSpacing: -0.05)),
            Text('Trending',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.05)),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: t.fg),
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
    return Container(
      decoration: BoxDecoration(
        color: t.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
                                          fontSize: 15, fontWeight: FontWeight.w600,
                                          color: t.fg, letterSpacing: -0.22, height: 1.1)),
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
                              Text(c.category,
                                  style: TextStyle(fontSize: 12, color: t.sub, fontWeight: FontWeight.w500, letterSpacing: -0.05)),
                              _Dot(t: t),
                              Text(c.language,
                                  style: TextStyle(fontSize: 12, color: t.sub, fontWeight: FontWeight.w500, letterSpacing: -0.05)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: t.line, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_right_rounded, size: 16, color: t.fg),
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
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, size: 11, color: t.fg),
                      const SizedBox(width: 3),
                      Text(c.rating, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.fg)),
                      const SizedBox(width: 3),
                      Text('(${c.reviews})', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.sub)),
                    ]),
                    _Dot(t: t),
                    Text('Replies in ${c.reply}',
                        style: TextStyle(fontSize: 11.5, color: t.sub, fontWeight: FontWeight.w500, letterSpacing: -0.05)),
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
                              fontSize: 10, color: t.sub, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                      for (final b in c.brands!)
                        Container(
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.tag,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(b,
                              style: TextStyle(fontSize: 11, color: t.fg, fontWeight: FontWeight.w500, letterSpacing: -0.05)),
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
              border: Border(top: BorderSide(color: t.line, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STARTS AT',
                        style: TextStyle(fontSize: 10, color: t.sub, fontWeight: FontWeight.w600, letterSpacing: 1.0, height: 1)),
                    const SizedBox(height: 5),
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      Text(c.price,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.42, height: 1)),
                      if (c.priceWas != null) ...[
                        const SizedBox(width: 6),
                        Text(c.priceWas!,
                            style: TextStyle(
                                fontSize: 12, color: t.sub, fontWeight: FontWeight.w500,
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
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.ctaBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Book',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: t.ctaFg, letterSpacing: -0.12)),
                  ),
                ]),
              ],
            ),
          ),
        ],
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
  const _Avatar({required this.initials, required this.t, this.size = 52});
  final String initials;
  final TrmTheme t;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.surf2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.34)),
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
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.badgeBg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(fontSize: 10, color: t.badgeFg, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );
    }
    if (kind == TrmTagKind.hot) {
      return Container(
        height: 22,
        padding: const EdgeInsets.fromLTRB(7, 0, 9, 0),
        decoration: BoxDecoration(
          color: t.tag,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.line, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt_rounded, size: 11, color: t.fg),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: t.fg, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        ]),
      );
    }
    // offer (outline)
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.fg, width: 1),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10.5, color: t.fg, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    );
  }
}
