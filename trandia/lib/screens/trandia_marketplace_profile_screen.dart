// trandia_profile_screen.dart
//
// Trandia · Creators Marketplace — Profile screen.
// Single self-contained file, BOTH themes inside (light + dark).
// Pure monochrome system — no gradients, no colour accents.
//   • Theme is driven by the `dark` flag.
//   • The runnable demo (main + _TrpDemo) has a Light/Dark toggle pill.
//     Remove those two if you embed TrandiaProfileScreen in your own app
//     and drive `dark` yourself.
//
// Layout: top bar (back · url chip · share · more) → stats card →
//         hero (dashed-ring avatar, name ✓, category pill, bio,
//         eligibility pills) → Book / Message → Pricing list →
//         Creator Stats grid → Recent Work grid.

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RUNNABLE DEMO — light + dark in one file. Tap the pill to switch themes.
// ─────────────────────────────────────────────────────────────────────────────
void main() => runApp(const _TrpDemo());

class _TrpDemo extends StatefulWidget {
  const _TrpDemo();
  @override
  State<_TrpDemo> createState() => _TrpDemoState();
}

class _TrpDemoState extends State<_TrpDemo> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Stack(children: [
        TrandiaProfileScreen(dark: _dark),
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
// THEME — paired light & dark.
// ─────────────────────────────────────────────────────────────────────────────
class TrpTheme {
  final bool dark;
  final Color bg, surf, surf2, line, fg, sub, tag, dim;
  final Color ctaBg, ctaFg, badgeBg, badgeFg;
  const TrpTheme({
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

  static const _darkT = TrpTheme(
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

  static const _lightT = TrpTheme(
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

  static TrpTheme of(bool dark) => dark ? _darkT : _lightT;

  /// Overlay used on thumbnail badges (matches the JSX rgba logic).
  Color get thumbOverlay =>
      dark ? const Color(0x8C000000) : const Color(0xB3FFFFFF);

  // ── Glass tokens ──────────────────────────────────────────────────────────
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
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class TrandiaProfileScreen extends StatelessWidget {
  const TrandiaProfileScreen({super.key, this.dark = true});

  /// Theme: true = dark, false = light.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = TrpTheme.of(dark);

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
                padding: const EdgeInsets.only(top: 12, bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(t: t),
                    _StatsCard(t: t),
                    _Hero(t: t),
                    _ActionRow(t: t),
                    _PricingCard(t: t),
                    _StatsGrid(t: t),
                    _RecentWork(t: t),
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
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.t});
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.maybePop(context),
            child: _IconBtn(t: t, child: Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: t.fg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
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
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text('trandia.in/marketplace',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: t.fg,
                          fontFamily: 'monospace', letterSpacing: -0.12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _IconBtn(t: t, child: Icon(Icons.ios_share_rounded, size: 17, color: t.fg)),
          const SizedBox(width: 10),
          _IconBtn(t: t, child: Icon(Icons.more_horiz_rounded, size: 18, color: t.fg)),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.t, required this.child, this.size = 40});
  final TrpTheme t;
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
// STATS CARD (3 cols)
// ─────────────────────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.t});
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    const items = [
      ['1,240', 'CREATORS'],
      ['₹5K–5L', 'PRICE RANGE'],
      ['1M+', 'MIN VIEWS'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.glassFillStrong, t.glassFill],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: t.glassShadow,
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Container(width: 1, color: t.glassBorderSoft, margin: const EdgeInsets.symmetric(vertical: 4)),
                    Expanded(child: _statCol(items[i][0], items[i][1])),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCol(String v, String l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(v,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.7, height: 1)),
          const SizedBox(height: 8),
          Text(l,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: t.sub, letterSpacing: 1.33)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero({required this.t});
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.glassFillStrong, t.glassFill],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: t.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: t.glassShadow,
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                // avatar with dashed ring
                _DashedRing(
                  size: 92,
                  color: t.glassBorder,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [t.glassHighlight, t.glassFill],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: t.glassBorder, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text('AS',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.44)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Aryan Sharma',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.6, height: 1)),
                    const SizedBox(width: 8),
                    _Verified(s: 17, t: t),
                  ],
                ),
                const SizedBox(height: 14),
                _Pill(t: t, dot: true, child: Text('Comedy Creator    ·    Hindi',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.fg, letterSpacing: -0.05))),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 290),
                  child: Text(
                    'Verified Trandia creator. 5+ years making content that converts. Available for brand collabs — DM for custom packages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, height: 1.55, color: t.sub, fontWeight: FontWeight.w500, letterSpacing: -0.05),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _EligibilityPill(label: '5K+ Followers', t: t),
                    _EligibilityPill(label: '1M+ Views', t: t),
                  ],
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
// ACTION ROW
// ─────────────────────────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.t});
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Row(
        children: [
          Expanded(
            flex: 62,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.ctaBg,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: t.glassShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text('Book Creator',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: t.ctaFg, letterSpacing: -0.14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 38,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [t.glassFillStrong, t.glassFill],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.glassBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 16, color: t.fg),
                      const SizedBox(width: 8),
                      Text('Message',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.14)),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// PRICING CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.t});
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    const rows = [
      ['Promo Video (60s)', '₹15,000'],
      ['Story Mention', '₹3,500'],
      ['Reel Integration', '₹25,000'],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.glassFillStrong, t.glassFill],
              ),
              borderRadius: BorderRadius.circular(24),
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Pricing',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.14)),
                      Text('3 packages',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: t.sub, letterSpacing: -0.05)),
                    ],
                  ),
                ),
                for (final r in rows)
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: t.glassBorderSoft, width: 1))),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(r[0],
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.05)),
                        Text(r[1],
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.14)),
                      ],
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
// CREATOR STATS GRID
// ─────────────────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.t});
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text('Creator Stats',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.14)),
          ),
          Row(children: [
            Expanded(child: _StatTile(value: '125K', label: 'FOLLOWERS', t: t)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(value: '2.3M', label: 'BEST VIEWS', t: t)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatTile(value: '4.9★', label: 'RATING', t: t)),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(value: '48', label: 'BRAND DEALS', t: t)),
          ]),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, required this.t});
  final String value, label;
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.glassFillStrong, t.glassFill],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: t.glassShadow,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.7, height: 1)),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: t.sub, letterSpacing: 1.33)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT WORK GRID
// ─────────────────────────────────────────────────────────────────────────────
class _RecentWork extends StatelessWidget {
  const _RecentWork({required this.t});
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    // [topRight, bottomLeft] per tile
    final tiles = <Map<String, dynamic>>[
      {'topRight': '12.4K'}, {}, {},
      {'bottomLeft': true}, {}, {},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Recent Work',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.14)),
                Text('12',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: t.sub, letterSpacing: -0.05)),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (_, i) => _Thumb(
              t: t,
              topRight: tiles[i]['topRight'] as String?,
              bottomLeft: tiles[i]['bottomLeft'] == true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.t, this.topRight, this.bottomLeft = false});
  final TrpTheme t;
  final String? topRight;
  final bool bottomLeft;
  @override
  Widget build(BuildContext context) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: 0.45,
              child: Icon(Icons.play_arrow_rounded, size: 24, color: t.fg),
            ),
          ),
          if (topRight != null)
            Positioned(
              top: 7, right: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.thumbOverlay,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: t.glassBorderSoft, width: 1),
                ),
                child: Text(topRight!,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.05)),
              ),
            ),
          if (bottomLeft)
            Positioned(
              bottom: 7, left: 7,
              child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: t.thumbOverlay,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.glassBorderSoft, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.play_arrow_rounded, size: 12, color: t.fg),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL BITS
// ─────────────────────────────────────────────────────────────────────────────
class _Verified extends StatelessWidget {
  const _Verified({required this.s, required this.t});
  final double s;
  final TrpTheme t;
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

class _Pill extends StatelessWidget {
  const _Pill({required this.t, required this.child, this.dot = false});
  final TrpTheme t;
  final Widget child;
  final bool dot;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.glassFillStrong, t.glassFill],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 5, height: 5, decoration: BoxDecoration(color: t.fg, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class _EligibilityPill extends StatelessWidget {
  const _EligibilityPill({required this.label, required this.t});
  final String label;
  final TrpTheme t;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.glassFillStrong, t.glassFill],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(color: t.badgeBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.check_rounded, size: 10, color: t.badgeFg),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: t.fg, letterSpacing: -0.05)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHED RING — replicates the CSS `border: 1.5px dashed` avatar ring.
// ─────────────────────────────────────────────────────────────────────────────
class _DashedRing extends StatelessWidget {
  const _DashedRing({required this.size, required this.color, required this.child});
  final double size;
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DashedRingPainter(color),
        child: Padding(
          padding: const EdgeInsets.all(5.5),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = (size.width - 1.5) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    const dash = 4.0, gap = 4.0;
    final circ = 2 * 3.141592653589793 * r;
    final steps = (circ / (dash + gap)).floor();
    final stepAngle = (dash + gap) / r;
    final dashAngle = dash / r;
    for (int i = 0; i < steps; i++) {
      final start = i * stepAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start, dashAngle, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// AURORA BACKGROUND
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
          Positioned(top: -120, right: -90, child: _Blob(size: 320, color: c1)),
          Positioned(top: 240, left: -120, child: _Blob(size: 280, color: c2)),
          Positioned(bottom: -100, right: -70, child: _Blob(size: 300, color: c2)),
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
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
