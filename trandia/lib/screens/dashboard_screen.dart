// lib/screens/dashboard/dashboard_screen.dart
//
// Creator Insights — single-file, matte-glass monochrome system (matches
// profile_screen.dart / login_screen.dart).
// • Auto theme: follows device system brightness (light / dark)
// • Layout: top bar → period segmented → hero Reach (area chart) →
//           KPI pair → Followers growth (bar chart) → Top posts
// • Pure black/white tones; the only colour is the up/down delta accent.
//
// Open it from the profile's "Creator dashboard" card, e.g.:
//   Navigator.of(context).push(MaterialPageRoute(
//     builder: (_) => const DashboardScreen()));

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SAMPLE DATA (swap for your analytics source)
// ─────────────────────────────────────────────────────────────────────────────
class InsightsData {
  const InsightsData();

  String get reach => '48.2K';
  String get reachDelta => '18.4';
  String get profileViews => '3,920';
  String get profileViewsDelta => '12.0';
  String get engagement => '6.8%';
  String get engagementDelta => '2.1';
  String get followersNet => '+1,510';

  // 12-point trend used by the hero area chart.
  List<double> get reachTrend =>
      const [3.1, 3.6, 3.2, 4.4, 4.0, 5.2, 4.8, 5.9, 6.3, 5.8, 7.0, 7.6];

  // Weekly follower adds — bar chart.
  List<double> get weeklyBars => const [22, 31, 27, 38, 34, 44, 52];
  List<String> get weeklyLabels => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  List<TopPost> get topPosts => const [
        TopPost(rank: 1, seed: 2, views: '48.2K', likes: '4,910', reel: true),
        TopPost(rank: 2, seed: 0, views: '31.7K', likes: '3,204', reel: false),
        TopPost(rank: 3, seed: 4, views: '22.9K', likes: '2,118', reel: true),
        TopPost(rank: 4, seed: 1, views: '18.4K', likes: '1,640', reel: false),
      ];
}

class TopPost {
  final int rank;
  final int seed;
  final String views;
  final String likes;
  final bool reel;
  const TopPost({
    required this.rank,
    required this.seed,
    required this.views,
    required this.likes,
    required this.reel,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.handle = '@yogesh01',
    this.data = const InsightsData(),
  });

  final String handle;
  final InsightsData data;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _period = '30D';

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final t = _DashTheme.of(isDark);
    final d = widget.data;

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
        child: Stack(fit: StackFit.expand, children: [
          Positioned.fill(child: _Backdrop(t: t)),

          // Scroll content
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(top: 56, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Period row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LAST 30 DAYS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.sub,
                            letterSpacing: 0.6,
                          ),
                        ),
                        _Segmented(
                          t: t,
                          options: const ['7D', '30D', '90D'],
                          value: _period,
                          onChange: (v) => setState(() => _period = v),
                        ),
                      ],
                    ),
                  ),

                  // HERO — Reach
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _HeroReach(t: t, data: d),
                  ),

                  // KPI pair
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(children: [
                      Expanded(
                        child: _KpiTile(
                          t: t,
                          icon: Icons.visibility_outlined,
                          label: 'Profile views',
                          value: d.profileViews,
                          delta: d.profileViewsDelta,
                          up: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiTile(
                          t: t,
                          icon: Icons.show_chart_rounded,
                          label: 'Engagement',
                          value: d.engagement,
                          delta: d.engagementDelta,
                          up: true,
                        ),
                      ),
                    ]),
                  ),

                  // Followers growth
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _GlassCard(
                      t: t,
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CardHeading(
                            t: t,
                            icon: Icons.group_outlined,
                            title: 'Followers growth',
                            action: '${d.followersNet} net',
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 118,
                            child: CustomPaint(
                              painter: _BarChartPainter(
                                t: t,
                                values: d.weeklyBars,
                                labels: d.weeklyLabels,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top posts
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _GlassCard(
                      t: t,
                      padding: const EdgeInsets.fromLTRB(14, 15, 14, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CardHeading(
                            t: t,
                            icon: Icons.travel_explore_rounded,
                            title: 'Top posts',
                            action: 'By reach',
                          ),
                          const SizedBox(height: 4),
                          for (var i = 0; i < d.topPosts.length; i++) ...[
                            if (i > 0)
                              Container(
                                height: 1,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                color: t.hair,
                              ),
                            _PostRow(t: t, post: d.topPosts[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // TOP BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SizedBox(
                height: 44,
                child: Row(children: [
                  _CircleIconButton(
                    t: t,
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Creator Studio',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: t.fg,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.handle,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: t.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CircleIconButton(
                    t: t,
                    icon: Icons.ios_share_rounded,
                    onTap: () {},
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO REACH
// ─────────────────────────────────────────────────────────────────────────────
class _HeroReach extends StatelessWidget {
  const _HeroReach({required this.t, required this.data});
  final _DashTheme t;
  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      t: t,
      radius: 26,
      stripes: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.wifi_tethering_rounded, color: t.fg, size: 18),
            const SizedBox(width: 9),
            Text(
              'Accounts reached',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.sub,
                letterSpacing: 0.2,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              data.reach,
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w800,
                color: t.fg,
                letterSpacing: -1.8,
                height: 0.9,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _DeltaPill(t: t, value: data.reachDelta, up: true),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: CustomPaint(
              painter: _AreaChartPainter(t: t, values: data.reachTrend),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI TILE
// ─────────────────────────────────────────────────────────────────────────────
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.t,
    required this.icon,
    required this.label,
    required this.value,
    required this.delta,
    required this.up,
  });
  final _DashTheme t;
  final IconData icon;
  final String label, value, delta;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      t: t,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: t.dark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.05),
                border: Border.all(color: t.hair, width: 1),
              ),
              child: Icon(icon, size: 16, color: t.fg),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.sub,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: t.fg,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _DeltaText(t: t, value: delta, up: up),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP POST ROW
// ─────────────────────────────────────────────────────────────────────────────
class _PostRow extends StatelessWidget {
  const _PostRow({required this.t, required this.post});
  final _DashTheme t;
  final TopPost post;

  @override
  Widget build(BuildContext context) {
    final i = post.seed;
    final aPct = t.dark ? (26 - (i % 5) * 3) : (90 - (i % 5) * 4);
    final bPct =
        (aPct - (t.dark ? 12 : 16)).clamp(t.dark ? 6 : 58, 100).toDouble();
    final g1 = HSLColor.fromAHSL(1, 0, 0, aPct / 100).toColor();
    final g2 = HSLColor.fromAHSL(1, 0, 0, bPct / 100).toColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(children: [
        SizedBox(
          width: 16,
          child: Text(
            '${post.rank}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: t.faint,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [g1, g2],
            ),
          ),
          child: post.reel
              ? const Align(
                  alignment: Alignment(0.6, -0.6),
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 14),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.visibility_outlined, size: 14, color: t.muted),
                const SizedBox(width: 6),
                Text(
                  post.views,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: t.fg,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'views',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: t.faint,
                  ),
                ),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.favorite_border_rounded, size: 12, color: t.faint),
                const SizedBox(width: 5),
                Text(
                  post.likes,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.sub,
                  ),
                ),
              ]),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: t.faint),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD HEADING
// ─────────────────────────────────────────────────────────────────────────────
class _CardHeading extends StatelessWidget {
  const _CardHeading({
    required this.t,
    required this.icon,
    required this.title,
    this.action,
  });
  final _DashTheme t;
  final IconData icon;
  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 4, 8),
      child: Row(children: [
        Icon(icon, color: t.fg, size: 17),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: t.fg,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (action != null)
          Text(
            action!,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: t.sub,
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEGMENTED PERIOD CONTROL
// ─────────────────────────────────────────────────────────────────────────────
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.t,
    required this.options,
    required this.value,
    required this.onChange,
  });
  final _DashTheme t;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: t.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        border: Border.all(color: t.hair, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final on = o == value;
          return GestureDetector(
            onTap: () => onChange(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: on
                    ? (t.dark ? Colors.white : const Color(0xFF0A0A0A))
                    : Colors.transparent,
              ),
              child: Text(
                o,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: on
                      ? (t.dark ? const Color(0xFF0A0A0A) : Colors.white)
                      : t.sub,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELTA PILL / TEXT
// ─────────────────────────────────────────────────────────────────────────────
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.t, required this.value, required this.up});
  final _DashTheme t;
  final String value;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final c = up ? t.up : t.down;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: c.withValues(alpha: t.dark ? 0.16 : 0.14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12, color: c),
        const SizedBox(width: 2),
        Text(
          '$value%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: -0.1,
          ),
        ),
      ]),
    );
  }
}

class _DeltaText extends StatelessWidget {
  const _DeltaText({required this.t, required this.value, required this.up});
  final _DashTheme t;
  final String value;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final c = up ? t.up : t.down;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 11, color: c),
      const SizedBox(width: 2),
      Text(
        '$value%',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AREA CHART PAINTER (smooth line + gradient fill + end dot)
// ─────────────────────────────────────────────────────────────────────────────
class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.t, required this.values});
  final _DashTheme t;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const pad = 6.0;
    final innerW = size.width - pad * 2;
    final innerH = size.height - pad * 2 - 6;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : (hi - lo);

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = pad + innerW * i / (values.length - 1);
      final y = pad + 4 + innerH - ((values[i] - lo) / span) * innerH;
      pts.add(Offset(x, y));
    }

    final line = _smoothPath(pts);

    // Area fill
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height - pad)
      ..lineTo(pts.first.dx, size.height - pad)
      ..close();
    final fill = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, pad),
        Offset(0, size.height),
        [
          t.fg.withValues(alpha: t.dark ? 0.28 : 0.18),
          t.fg.withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(area, fill);

    // Line
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = t.fg
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // End dot
    canvas.drawCircle(pts.last, 3.6, Paint()..color = t.cardCore);
    canvas.drawCircle(
      pts.last,
      3.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = t.fg
        ..strokeWidth = 2.2,
    );
  }

  Path _smoothPath(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = i == 0 ? p[i] : p[i - 1];
      final p1 = p[i];
      final p2 = p[i + 1];
      final p3 = i + 2 < p.length ? p[i + 2] : p2;
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) =>
      old.values != values || old.t.dark != t.dark;
}

// ─────────────────────────────────────────────────────────────────────────────
// BAR CHART PAINTER (track + bar + labels)
// ─────────────────────────────────────────────────────────────────────────────
class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.t, required this.values, required this.labels});
  final _DashTheme t;
  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    const gap = 8.0;
    const labelH = 16.0;
    final n = values.length;
    final innerW = size.width - pad * 2;
    final innerH = size.height - pad * 2 - labelH;
    final bw = (innerW - gap * (n - 1)) / n;
    final maxV = values.reduce(math.max);

    final track = Paint()
      ..color = t.dark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04);
    final peakPaint = Paint()..color = t.fg;
    final barPaint = Paint()
      ..color = t.dark
          ? Colors.white.withValues(alpha: 0.42)
          : Colors.black.withValues(alpha: 0.34);

    for (var i = 0; i < n; i++) {
      final x = pad + i * (bw + gap);
      final r = Radius.circular(math.min(6, bw / 2));

      // track
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, pad, bw, innerH), r),
        track,
      );

      // bar
      final bh = math.max(3.0, (values[i] / maxV) * innerH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, pad + innerH - bh, bw, bh), r),
        i == n - 1 ? peakPaint : barPaint,
      );

      // label
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: t.faint,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + bw / 2 - tp.width / 2, size.height - labelH + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.values != values || old.t.dark != t.dark;
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.t,
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
    this.stripes = false,
  });
  final _DashTheme t;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool stripes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: t.cardShadow,
      ),
      child: _Frosted(
        radius: radius,
        sigma: 26,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
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
              left: radius,
              right: radius,
              child: Container(
                  height: 1, color: t.innerHi.withValues(alpha: 0.7)),
            ),
            if (stripes)
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
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
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
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter old) =>
      old.color != color || old.spacing != spacing;
}

// ─────────────────────────────────────────────────────────────────────────────
// CIRCLE ICON BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.t, required this.icon, required this.onTap});
  final _DashTheme t;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: t.fieldShadow),
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
// BACKDROP
// ─────────────────────────────────────────────────────────────────────────────
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.t});
  final _DashTheme t;

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
        child: Stack(fit: StackFit.expand, children: [
          _Orb(color: t.orbColors[0], size: 320, left: -60, top: -40),
          _Orb(color: t.orbColors[1], size: 300, right: -60, top: 60),
          _Orb(color: t.orbColors[2], size: 300, left: 30, bottom: 60),
        ]),
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
// FROSTED WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _Frosted extends StatelessWidget {
  const _Frosted({required this.child, required this.radius, this.sigma = 24});
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
class _DashTheme {
  final bool dark;
  final Color fg, sub, muted, faint, hair;
  final Color up, down;
  final Color cardCore; // solid core behind the area-chart end dot
  final List<Color> bgStops, orbColors, cardFill, fieldFill;
  final Color cardBorder, fieldBorder, innerHi;
  final List<BoxShadow> cardShadow, fieldShadow;

  const _DashTheme({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.muted,
    required this.faint,
    required this.hair,
    required this.up,
    required this.down,
    required this.cardCore,
    required this.bgStops,
    required this.orbColors,
    required this.cardFill,
    required this.fieldFill,
    required this.cardBorder,
    required this.fieldBorder,
    required this.innerHi,
    required this.cardShadow,
    required this.fieldShadow,
  });

  static _DashTheme of(bool dark) => dark ? _dark : _light;

  static const _up = Color(0xFF34C07A);
  static const _down = Color(0xFFE0594B);

  static final _light = _DashTheme(
    dark: false,
    fg: const Color(0xFF0A0A0A),
    sub: const Color(0x8C000000),
    muted: const Color(0xB8000000),
    faint: const Color(0x66000000),
    hair: const Color(0x0F000000),
    up: _up,
    down: _down,
    cardCore: const Color(0xFFFFFFFF),
    bgStops: const [Color(0xFFFAFAFA), Color(0xFFECECEE), Color(0xFFDCDCE0)],
    orbColors: const [Color(0xF2FFFFFF), Color(0x1A141416), Color(0x14141416)],
    cardFill: const [Color(0xD9FFFFFF), Color(0x8CFFFFFF)],
    fieldFill: const [Color(0x73FFFFFF), Color(0x33FFFFFF)],
    cardBorder: const Color(0xF2FFFFFF),
    fieldBorder: const Color(0xD9FFFFFF),
    innerHi: const Color(0xFFFFFFFF),
    cardShadow: const [
      BoxShadow(
          color: Color(0x33282050),
          blurRadius: 34,
          offset: Offset(0, 16),
          spreadRadius: -18),
    ],
    fieldShadow: const [
      BoxShadow(
          color: Color(0x2E282050),
          blurRadius: 24,
          offset: Offset(0, 10),
          spreadRadius: -14),
    ],
  );

  static final _dark = _DashTheme(
    dark: true,
    fg: const Color(0xFFFFFFFF),
    sub: const Color(0x8CFFFFFF),
    muted: const Color(0xB8FFFFFF),
    faint: const Color(0x66FFFFFF),
    hair: const Color(0x14FFFFFF),
    up: _up,
    down: _down,
    cardCore: const Color(0xFF0A0A0C),
    bgStops: const [Color(0xFF0C0C0E), Color(0xFF060608), Color(0xFF000000)],
    orbColors: const [Color(0x12FFFFFF), Color(0x0AFFFFFF), Color(0x0AFFFFFF)],
    cardFill: const [Color(0x12FFFFFF), Color(0x06FFFFFF)],
    fieldFill: const [Color(0x10FFFFFF), Color(0x05FFFFFF)],
    cardBorder: const Color(0x1AFFFFFF),
    fieldBorder: const Color(0x1AFFFFFF),
    innerHi: const Color(0x3DFFFFFF),
    cardShadow: const [
      BoxShadow(
          color: Color(0xCC000000),
          blurRadius: 34,
          offset: Offset(0, 16),
          spreadRadius: -18),
    ],
    fieldShadow: const [
      BoxShadow(
          color: Color(0xB3000000),
          blurRadius: 24,
          offset: Offset(0, 10),
          spreadRadius: -14),
    ],
  );
}
