import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'glass_common.dart';

enum _AnalyticsPeriod { weekly, monthly }

enum _RiskLevel { low, medium, high }

class _CategoryUsage {
  final String name;
  final IconData icon;
  final int weeklyMinutes;
  final int monthlyMinutes;
  final double weeklyTrend;
  final double monthlyTrend;
  final _RiskLevel risk;
  final Color color;

  const _CategoryUsage({
    required this.name,
    required this.icon,
    required this.weeklyMinutes,
    required this.monthlyMinutes,
    required this.weeklyTrend,
    required this.monthlyTrend,
    required this.risk,
    required this.color,
  });

  int minutes(_AnalyticsPeriod period) =>
      period == _AnalyticsPeriod.weekly ? weeklyMinutes : monthlyMinutes;

  double trend(_AnalyticsPeriod period) =>
      period == _AnalyticsPeriod.weekly ? weeklyTrend : monthlyTrend;
}

class ParentalControlScreen extends StatefulWidget {
  final bool dark;
  const ParentalControlScreen({super.key, required this.dark});

  @override
  State<ParentalControlScreen> createState() => _ParentalControlScreenState();
}

class _ParentalControlScreenState extends State<ParentalControlScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  _AnalyticsPeriod _period = _AnalyticsPeriod.weekly;

  static const List<_CategoryUsage> _usage = [
    _CategoryUsage(
      name: 'General',
      icon: Icons.auto_awesome_rounded,
      weeklyMinutes: 154,
      monthlyMinutes: 642,
      weeklyTrend: 6,
      monthlyTrend: 11,
      risk: _RiskLevel.low,
      color: Color(0xFF5B8DEF),
    ),
    _CategoryUsage(
      name: 'Abusive',
      icon: Icons.report_gmailerrorred_rounded,
      weeklyMinutes: 18,
      monthlyMinutes: 74,
      weeklyTrend: -14,
      monthlyTrend: -7,
      risk: _RiskLevel.high,
      color: Color(0xFFFF5C7A),
    ),
    _CategoryUsage(
      name: 'Vulgar',
      icon: Icons.warning_amber_rounded,
      weeklyMinutes: 24,
      monthlyMinutes: 93,
      weeklyTrend: 9,
      monthlyTrend: 13,
      risk: _RiskLevel.high,
      color: Color(0xFFFF8A4C),
    ),
    _CategoryUsage(
      name: 'Aggressive',
      icon: Icons.bolt_rounded,
      weeklyMinutes: 31,
      monthlyMinutes: 118,
      weeklyTrend: 18,
      monthlyTrend: 21,
      risk: _RiskLevel.high,
      color: Color(0xFFFFC247),
    ),
    _CategoryUsage(
      name: 'Comedy',
      icon: Icons.sentiment_very_satisfied_rounded,
      weeklyMinutes: 132,
      monthlyMinutes: 538,
      weeklyTrend: 12,
      monthlyTrend: 8,
      risk: _RiskLevel.low,
      color: Color(0xFF35CFA3),
    ),
    _CategoryUsage(
      name: 'Poetry',
      icon: Icons.edit_note_rounded,
      weeklyMinutes: 72,
      monthlyMinutes: 286,
      weeklyTrend: 4,
      monthlyTrend: 6,
      risk: _RiskLevel.low,
      color: Color(0xFFB678FF),
    ),
    _CategoryUsage(
      name: 'Singing',
      icon: Icons.mic_rounded,
      weeklyMinutes: 96,
      monthlyMinutes: 392,
      weeklyTrend: 15,
      monthlyTrend: 10,
      risk: _RiskLevel.low,
      color: Color(0xFFFF6FB1),
    ),
    _CategoryUsage(
      name: 'Dancing',
      icon: Icons.music_note_rounded,
      weeklyMinutes: 84,
      monthlyMinutes: 318,
      weeklyTrend: -3,
      monthlyTrend: 2,
      risk: _RiskLevel.low,
      color: Color(0xFF24B7FF),
    ),
    _CategoryUsage(
      name: 'Instrumental',
      icon: Icons.piano_rounded,
      weeklyMinutes: 49,
      monthlyMinutes: 196,
      weeklyTrend: 7,
      monthlyTrend: 5,
      risk: _RiskLevel.low,
      color: Color(0xFF9CD84A),
    ),
    _CategoryUsage(
      name: 'Gaming',
      icon: Icons.sports_esports_rounded,
      weeklyMinutes: 188,
      monthlyMinutes: 804,
      weeklyTrend: 22,
      monthlyTrend: 17,
      risk: _RiskLevel.medium,
      color: Color(0xFF7C5CFF),
    ),
    _CategoryUsage(
      name: 'Sports',
      icon: Icons.sports_soccer_rounded,
      weeklyMinutes: 67,
      monthlyMinutes: 244,
      weeklyTrend: -8,
      monthlyTrend: -4,
      risk: _RiskLevel.low,
      color: Color(0xFF00B8A9),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  int get _totalMinutes =>
      _usage.fold(0, (sum, item) => sum + item.minutes(_period));

  int get _safeMinutes => _usage
      .where((item) => item.risk == _RiskLevel.low)
      .fold(0, (sum, item) => sum + item.minutes(_period));

  int get _flaggedMinutes => _usage
      .where((item) => item.risk != _RiskLevel.low)
      .fold(0, (sum, item) => sum + item.minutes(_period));

  int get _safetyScore {
    final high = _usage
        .where((item) => item.risk == _RiskLevel.high)
        .fold(0, (sum, item) => sum + item.minutes(_period));
    final medium = _usage
        .where((item) => item.risk == _RiskLevel.medium)
        .fold(0, (sum, item) => sum + item.minutes(_period));
    final penalty = ((high * 1.7 + medium * 0.55) / _totalMinutes * 100);
    return (100 - penalty).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          GlassBackdrop(dark: dark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: GlassHeader(
                    dark: dark,
                    padding: const EdgeInsets.only(left: 7, right: 8),
                    child: Row(
                      children: [
                        GlassCircleButton(
                          dark: dark,
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 16,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Parental Control'.tr(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: manrope(
                              size: 17,
                              weight: FontWeight.w800,
                              color: fg,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        _PeriodToggle(
                          dark: dark,
                          value: _period,
                          onChanged: (period) => setState(() {
                            _period = period;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 760;
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                        children: [
                          _HeroAnalyticsCard(
                            dark: dark,
                            pulse: _pulse,
                            score: _safetyScore,
                            totalMinutes: _totalMinutes,
                            safeMinutes: _safeMinutes,
                            flaggedMinutes: _flaggedMinutes,
                            period: _period,
                          ),
                          const SizedBox(height: 12),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _UsageChartCard(
                                    dark: dark,
                                    usage: _usage,
                                    period: _period,
                                    totalMinutes: _totalMinutes,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 5,
                                  child: _InsightsCard(
                                    dark: dark,
                                    score: _safetyScore,
                                    flaggedMinutes: _flaggedMinutes,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _UsageChartCard(
                              dark: dark,
                              usage: _usage,
                              period: _period,
                              totalMinutes: _totalMinutes,
                            ),
                            const SizedBox(height: 12),
                            _InsightsCard(
                              dark: dark,
                              score: _safetyScore,
                              flaggedMinutes: _flaggedMinutes,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _CategoryGrid(
                            dark: dark,
                            usage: _usage,
                            period: _period,
                            totalMinutes: _totalMinutes,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAnalyticsCard extends StatelessWidget {
  final bool dark;
  final Animation<double> pulse;
  final int score;
  final int totalMinutes;
  final int safeMinutes;
  final int flaggedMinutes;
  final _AnalyticsPeriod period;

  const _HeroAnalyticsCard({
    required this.dark,
    required this.pulse,
    required this.score,
    required this.totalMinutes,
    required this.safeMinutes,
    required this.flaggedMinutes,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final periodLabel = period == _AnalyticsPeriod.weekly
        ? 'this week'
        : 'this month';

    return GlassSurface(
      dark: dark,
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 580;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusPill(
                dark: dark,
                icon: Icons.verified_user_rounded,
                label: score >= 82
                    ? 'Healthy watch pattern'
                    : 'Needs attention',
                color: score >= 82
                    ? const Color(0xFF35CFA3)
                    : const Color(0xFFFFC247),
              ),
              const SizedBox(height: 14),
              Text(
                'Child activity intelligence',
                style: manrope(
                  size: compact ? 25 : 31,
                  weight: FontWeight.w900,
                  color: fg,
                  height: 1.05,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Total app usage is ${_formatDuration(totalMinutes)} $periodLabel with ${_formatDuration(flaggedMinutes)} in elevated-risk content.',
                style: manrope(
                  size: 13,
                  weight: FontWeight.w600,
                  color: sub,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(
                    dark: dark,
                    label: 'Total time',
                    value: _formatDuration(totalMinutes),
                    icon: Icons.schedule_rounded,
                  ),
                  _MetricChip(
                    dark: dark,
                    label: 'Safe fun',
                    value: _formatDuration(safeMinutes),
                    icon: Icons.favorite_rounded,
                  ),
                  _MetricChip(
                    dark: dark,
                    label: 'Risk watch',
                    value: _formatDuration(flaggedMinutes),
                    icon: Icons.radar_rounded,
                  ),
                ],
              ),
            ],
          );

          final scoreRing = _SafetyScoreRing(
            dark: dark,
            pulse: pulse,
            score: score,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: scoreRing),
                const SizedBox(height: 16),
                summary,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 18),
              scoreRing,
            ],
          );
        },
      ),
    );
  }
}

class _UsageChartCard extends StatelessWidget {
  final bool dark;
  final List<_CategoryUsage> usage;
  final _AnalyticsPeriod period;
  final int totalMinutes;

  const _UsageChartCard({
    required this.dark,
    required this.usage,
    required this.period,
    required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final maxMinutes = usage
        .map((item) => item.minutes(period))
        .reduce(math.max);

    return GlassSurface(
      dark: dark,
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(dark: dark, icon: Icons.bar_chart_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fun category breakdown',
                      style: manrope(
                        size: 16,
                        weight: FontWeight.w900,
                        color: fg,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      'Time, percentage, trend and risk by content type',
                      style: manrope(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: sub,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...usage.map(
            (item) => _CategoryBar(
              dark: dark,
              item: item,
              period: period,
              maxMinutes: maxMinutes,
              totalMinutes: totalMinutes,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final bool dark;
  final _CategoryUsage item;
  final _AnalyticsPeriod period;
  final int maxMinutes;
  final int totalMinutes;

  const _CategoryBar({
    required this.dark,
    required this.item,
    required this.period,
    required this.maxMinutes,
    required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final minutes = item.minutes(period);
    final pct = minutes / totalMinutes * 100;
    final trend = item.trend(period);
    final widthFactor = minutes / maxMinutes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        children: [
          Row(
            children: [
              Icon(item.icon, color: item.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: manrope(
                    size: 13,
                    weight: FontWeight.w800,
                    color: fg,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                '${_formatDuration(minutes)}  ${pct.toStringAsFixed(1)}%',
                style: manrope(
                  size: 12,
                  weight: FontWeight.w800,
                  color: fg,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              _TrendLabel(dark: dark, trend: trend),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    key: ValueKey('${item.name}-$period'),
                    tween: Tween(begin: 0, end: widthFactor),
                    duration: const Duration(milliseconds: 850),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Container(
                        height: 10,
                        width: constraints.maxWidth * value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              item.color,
                              Color.lerp(
                                item.color,
                                Colors.white,
                                dark ? 0.20 : 0.05,
                              )!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _riskLabel(item.risk),
                style: manrope(
                  size: 10.5,
                  weight: FontWeight.w800,
                  color: _riskColor(item.risk),
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Text(
                'recommended review ${item.risk == _RiskLevel.low ? 'normal' : 'on'}',
                style: manrope(
                  size: 10.5,
                  weight: FontWeight.w600,
                  color: sub,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final bool dark;
  final int score;
  final int flaggedMinutes;

  const _InsightsCard({
    required this.dark,
    required this.score,
    required this.flaggedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return GlassSurface(
      dark: dark,
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(dark: dark, icon: Icons.psychology_alt_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI insights',
                  style: manrope(
                    size: 16,
                    weight: FontWeight.w900,
                    color: fg,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _StatusPill(
                dark: dark,
                icon: Icons.shield_moon_rounded,
                label: '$score score',
                color: _scoreColor(score),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InsightRow(
            dark: dark,
            icon: Icons.check_circle_rounded,
            title: 'Positive engagement is dominant',
            body:
                'Comedy, singing, dancing and sports are the main safe-fun clusters.',
            color: const Color(0xFF35CFA3),
          ),
          _InsightRow(
            dark: dark,
            icon: Icons.warning_rounded,
            title: 'Aggressive content is rising',
            body:
                'Aggressive category is up versus the previous period. Review recent clips.',
            color: const Color(0xFFFFC247),
          ),
          _InsightRow(
            dark: dark,
            icon: Icons.lock_clock_rounded,
            title: 'Suggested action',
            body:
                'Set a soft limit after ${_formatDuration(flaggedMinutes)} flagged minutes and enable bedtime reminders.',
            color: const Color(0xFF5B8DEF),
          ),
          const SizedBox(height: 8),
          Text(
            'Content Safety Score blends safe time, risk intensity, and trend movement into a parent-friendly health signal.',
            style: manrope(
              size: 11.5,
              weight: FontWeight.w600,
              color: sub,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final bool dark;
  final List<_CategoryUsage> usage;
  final _AnalyticsPeriod period;
  final int totalMinutes;

  const _CategoryGrid({
    required this.dark,
    required this.usage,
    required this.period,
    required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 980
        ? 4
        : width >= 680
        ? 3
        : 2;
    final spacing = 10.0;
    final itemWidth = (width - 24 - spacing * (columns - 1)) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: usage.map((item) {
        final minutes = item.minutes(period);
        final pct = minutes / totalMinutes * 100;
        return SizedBox(
          width: itemWidth,
          child: _MiniCategoryCard(
            dark: dark,
            item: item,
            minutes: minutes,
            percentage: pct,
          ),
        );
      }).toList(),
    );
  }
}

class _MiniCategoryCard extends StatelessWidget {
  final bool dark;
  final _CategoryUsage item;
  final int minutes;
  final double percentage;

  const _MiniCategoryCard({
    required this.dark,
    required this.item,
    required this.minutes,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return GlassSurface(
      dark: dark,
      radius: 20,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: dark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _riskColor(item.risk),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: manrope(
              size: 13,
              weight: FontWeight.w900,
              color: fg,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDuration(minutes)} | ${percentage.toStringAsFixed(1)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: manrope(
              size: 11,
              weight: FontWeight.w700,
              color: sub,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyScoreRing extends StatelessWidget {
  final bool dark;
  final Animation<double> pulse;
  final int score;

  const _SafetyScoreRing({
    required this.dark,
    required this.pulse,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return SizedBox(
          width: 178,
          height: 178,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1 + pulse.value * 0.045,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _scoreColor(score).withValues(alpha: 0.28),
                        blurRadius: 38,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return CustomPaint(
                    size: const Size(158, 158),
                    painter: _RingPainter(
                      dark: dark,
                      value: value,
                      color: _scoreColor(score),
                    ),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: manrope(
                      size: 40,
                      weight: FontWeight.w900,
                      color: fg,
                      height: 0.95,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Safety Score',
                    style: manrope(
                      size: 12,
                      weight: FontWeight.w800,
                      color: sub,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final bool dark;
  final double value;
  final Color color;

  const _RingPainter({
    required this.dark,
    required this.value,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 9;
    final background = Paint()
      ..color = dark
          ? Colors.white.withValues(alpha: 0.09)
          : Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.35),
          color,
          color.withValues(alpha: 0.72),
        ],
        stops: const [0, 0.62, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.dark != dark ||
      oldDelegate.color != color;
}

class _PeriodToggle extends StatelessWidget {
  final bool dark;
  final _AnalyticsPeriod value;
  final ValueChanged<_AnalyticsPeriod> onChanged;

  const _PeriodToggle({
    required this.dark,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
            dark: dark,
            label: 'Week',
            selected: value == _AnalyticsPeriod.weekly,
            onTap: () => onChanged(_AnalyticsPeriod.weekly),
          ),
          _ToggleOption(
            dark: dark,
            label: 'Month',
            selected: value == _AnalyticsPeriod.monthly,
            onTap: () => onChanged(_AnalyticsPeriod.monthly),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final bool dark;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.dark,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = GlassTokens.sub(dark);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected
              ? (dark ? Colors.white : const Color(0xFF0A0A0A))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: manrope(
            size: 11.5,
            weight: FontWeight.w900,
            color: selected ? (dark ? Colors.black : Colors.white) : sub,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final bool dark;
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.dark,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: manrope(
                  size: 13,
                  weight: FontWeight.w900,
                  color: fg,
                  letterSpacing: 0,
                ),
              ),
              Text(
                label,
                style: manrope(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: sub,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _InsightRow({
    required this.dark,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: manrope(
                    size: 13,
                    weight: FontWeight.w900,
                    color: fg,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: manrope(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: sub,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.dark,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.17 : 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: manrope(
              size: 11,
              weight: FontWeight.w900,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendLabel extends StatelessWidget {
  final bool dark;
  final double trend;

  const _TrendLabel({required this.dark, required this.trend});

  @override
  Widget build(BuildContext context) {
    final up = trend >= 0;
    final color = up ? const Color(0xFFFF8A4C) : const Color(0xFF35CFA3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${trend.abs().toStringAsFixed(0)}%',
            style: manrope(
              size: 10.5,
              weight: FontWeight.w900,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final bool dark;
  final IconData icon;

  const _IconBubble({required this.dark, required this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '${mins}m';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}

String _riskLabel(_RiskLevel risk) {
  switch (risk) {
    case _RiskLevel.low:
      return 'LOW RISK';
    case _RiskLevel.medium:
      return 'MEDIUM RISK';
    case _RiskLevel.high:
      return 'HIGH RISK';
  }
}

Color _riskColor(_RiskLevel risk) {
  switch (risk) {
    case _RiskLevel.low:
      return const Color(0xFF35CFA3);
    case _RiskLevel.medium:
      return const Color(0xFFFFC247);
    case _RiskLevel.high:
      return const Color(0xFFFF5C7A);
  }
}

Color _scoreColor(int score) {
  if (score >= 82) return const Color(0xFF35CFA3);
  if (score >= 68) return const Color(0xFFFFC247);
  return const Color(0xFFFF5C7A);
}
