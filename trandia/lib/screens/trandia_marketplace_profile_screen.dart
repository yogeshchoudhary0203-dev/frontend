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
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
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
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.maybePop(context),
            child: _IconBtn(t: t, child: Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: t.fg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.surf,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.line, width: 1),
              ),
              child: Text('trandia.in/marketplace',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w500, color: t.sub,
                      fontFamily: 'monospace', letterSpacing: -0.12)),
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
  const _IconBtn({required this.t, required this.child, this.size = 36});
  final TrpTheme t;
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: t.surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line, width: 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Container(width: 1, color: t.line, margin: const EdgeInsets.symmetric(vertical: 4)),
                Expanded(child: _statCol(items[i][0], items[i][1])),
              ],
            ],
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
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.66, height: 1)),
          const SizedBox(height: 8),
          Text(l,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: t.sub, letterSpacing: 1.33)),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          color: t.surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line, width: 1),
        ),
        child: Column(
          children: [
            // avatar with dashed ring
            _DashedRing(
              size: 84,
              color: t.line,
              child: Container(
                decoration: BoxDecoration(
                  color: t.dim,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.line, width: 1),
                ),
                alignment: Alignment.center,
                child: Text('AS',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: t.sub, letterSpacing: -0.44)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aryan Sharma',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.55, height: 1)),
                const SizedBox(width: 8),
                _Verified(s: 16, t: t),
              ],
            ),
            const SizedBox(height: 12),
            _Pill(t: t, dot: true, child: Text('Comedy Creator    ·    Hindi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.fg, letterSpacing: -0.05))),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                'Verified Trandia creator. 5+ years making content that converts. Available for brand collabs — DM for custom packages.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.55, color: t.sub, fontWeight: FontWeight.w400, letterSpacing: -0.05),
              ),
            ),
            const SizedBox(height: 16),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            flex: 62,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.ctaBg, borderRadius: BorderRadius.circular(999)),
              child: Text('Book Creator',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ctaFg, letterSpacing: -0.14)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 38,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.line, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 15, color: t.fg),
                  const SizedBox(width: 7),
                  Text('Message',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.fg, letterSpacing: -0.14)),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: t.surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Pricing',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.14)),
                  Text('3 packages',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.sub, letterSpacing: -0.05)),
                ],
              ),
            ),
            for (final r in rows)
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line, width: 1))),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r[0],
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, color: t.fg, letterSpacing: -0.05)),
                    Text(r[1],
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.14)),
                  ],
                ),
              ),
          ],
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Text('Creator Stats',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.14)),
          ),
          Row(children: [
            Expanded(child: _StatTile(value: '125K', label: 'FOLLOWERS', t: t)),
            const SizedBox(width: 8),
            Expanded(child: _StatTile(value: '2.3M', label: 'BEST VIEWS', t: t)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatTile(value: '4.9★', label: 'RATING', t: t)),
            const SizedBox(width: 8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: t.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.66, height: 1)),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: t.sub, letterSpacing: 1.33)),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Recent Work',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.14)),
                Text('12',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.sub, letterSpacing: -0.05)),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
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
        color: t.dim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: 0.35,
              child: Icon(Icons.play_arrow_rounded, size: 22, color: t.fg),
            ),
          ),
          if (topRight != null)
            Positioned(
              top: 6, right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: t.thumbOverlay,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: t.line, width: 1),
                ),
                child: Text(topRight!,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t.fg, letterSpacing: -0.05)),
              ),
            ),
          if (bottomLeft)
            Positioned(
              bottom: 6, left: 6,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: t.thumbOverlay,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.line, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.play_arrow_rounded, size: 11, color: t.fg),
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
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: t.tag, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 4, height: 4, decoration: BoxDecoration(color: t.sub, shape: BoxShape.circle)),
            const SizedBox(width: 6),
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
      height: 30,
      padding: const EdgeInsets.fromLTRB(11, 0, 12, 0),
      decoration: BoxDecoration(
        color: t.tag,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: t.badgeBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.check_rounded, size: 9, color: t.badgeFg),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.fg, letterSpacing: -0.05)),
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
