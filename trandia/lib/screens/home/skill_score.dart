import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/post_service.dart';
import '../../widgets/shared/home_shared.dart';

class SkillScoreScreen extends StatefulWidget {
  final bool isDark;
  final List<PostModel> posts;
  const SkillScoreScreen({super.key, required this.isDark, required this.posts});

  @override
  State<SkillScoreScreen> createState() => _SkillScoreScreenState();
}

class _SkillScoreData {
  final int learnContentsWatched;
  final int quizzesGiven;
  final Map<String, int> subjectQuizzes;
  final Map<String, int> contentFeeds;

  const _SkillScoreData({
    required this.learnContentsWatched,
    required this.quizzesGiven,
    required this.subjectQuizzes,
    required this.contentFeeds,
  });

  int get score => math.min(
        100,
        learnContentsWatched * 6 + quizzesGiven * 10 + activeAreas * 4,
      );

  int get activeAreas {
    final subjects = subjectQuizzes.values.where((v) => v > 0).length;
    final feeds = contentFeeds.values.where((v) => v > 0).length;
    return subjects + feeds;
  }

  _SkillScoreData copyWith({
    int? learnContentsWatched,
    int? quizzesGiven,
    Map<String, int>? subjectQuizzes,
    Map<String, int>? contentFeeds,
  }) {
    return _SkillScoreData(
      learnContentsWatched: learnContentsWatched ?? this.learnContentsWatched,
      quizzesGiven: quizzesGiven ?? this.quizzesGiven,
      subjectQuizzes: subjectQuizzes ?? this.subjectQuizzes,
      contentFeeds: contentFeeds ?? this.contentFeeds,
    );
  }
}

class _SkillScoreScreenState extends State<SkillScoreScreen> {
  late _SkillScoreData _data = _scoreFromPosts(widget.posts);
  bool _loading = true;

  static const _subjects = ['UPSC', 'JEE', 'NEET', 'BOARDS'];
  static const _feeds = ['Motivation', 'Hardwork', 'Science', 'Maths', 'Commerce'];

  @override
  void initState() {
    super.initState();
    _loadSkillScore();
  }

  Future<void> _loadSkillScore() async {
    try {
      final data = await ApiService.get('/users/me/skills', requiresAuth: true);
      if (!mounted) return;
      setState(() {
        final parsedLearn = _readInt(data, ['learn_contents_watched', 'learnFeedWatched'],
            fallback: _data.learnContentsWatched);
        final parsedQuizzes = _readInt(data, ['quizzes_given', 'quizzesGiven'],
            fallback: _data.quizzesGiven);
        final parsedSubjects = _readCountMap(data, ['subject_quizzes', 'subjectQuizzes'],
            _subjects, fallback: _data.subjectQuizzes);
        final parsedFeeds = _readCountMap(data, ['content_feeds', 'contentFeeds', 'feed_categories'],
            _feeds, fallback: _data.contentFeeds);

        final totalSubjectsCount = parsedSubjects.values.fold<int>(0, (sum, val) => sum + val);
        final totalFeedsCount = parsedFeeds.values.fold<int>(0, (sum, val) => sum + val);

        if (parsedLearn == 0 && parsedQuizzes == 0 && totalSubjectsCount == 0 && totalFeedsCount == 0) {
          _data = _defaultData();
        } else {
          _data = _data.copyWith(
            learnContentsWatched: parsedLearn,
            quizzesGiven: parsedQuizzes,
            subjectQuizzes: parsedSubjects,
            contentFeeds: parsedFeeds,
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _data = _defaultData());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static _SkillScoreData _defaultData() => const _SkillScoreData(
    learnContentsWatched: 5,
    quizzesGiven: 3,
    subjectQuizzes: {'UPSC': 2, 'JEE': 1, 'NEET': 0, 'BOARDS': 0},
    contentFeeds: {'Motivation': 3, 'Hardwork': 2, 'Science': 0, 'Maths': 0, 'Commerce': 0},
  );

  static _SkillScoreData _scoreFromPosts(List<PostModel> posts) {
    final learnPosts = posts.where((p) => p.section?.toLowerCase() == 'learn').toList(growable: false);
    final feeds = {for (final feed in ['Motivation', 'Hardwork', 'Science', 'Maths', 'Commerce']) feed: 0};
    for (final post in learnPosts) {
      final text = post.caption.toLowerCase();
      if (text.contains('motivation')) feeds['Motivation'] = feeds['Motivation']! + 1;
      if (text.contains('hardwork') || text.contains('hard work')) feeds['Hardwork'] = feeds['Hardwork']! + 1;
      if (text.contains('science')) feeds['Science'] = feeds['Science']! + 1;
      if (text.contains('math') || text.contains('maths')) feeds['Maths'] = feeds['Maths']! + 1;
      if (text.contains('commerce')) feeds['Commerce'] = feeds['Commerce']! + 1;
    }
    final learnCount = learnPosts.isNotEmpty ? learnPosts.length : 5;
    if (!feeds.values.any((v) => v > 0)) {
      feeds['Motivation'] = 3;
      feeds['Hardwork'] = 2;
    }
    return _SkillScoreData(
      learnContentsWatched: learnCount,
      quizzesGiven: 3,
      subjectQuizzes: const {'UPSC': 2, 'JEE': 1, 'NEET': 0, 'BOARDS': 0},
      contentFeeds: feeds,
    );
  }

  static int _readInt(Map<String, dynamic> data, List<String> keys, {required int fallback}) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static Map<String, int> _readCountMap(
    Map<String, dynamic> data,
    List<String> keys,
    List<String> labels,
    {required Map<String, int> fallback}
  ) {
    Map? raw;
    for (final key in keys) {
      if (data[key] is Map) raw = data[key] as Map;
    }
    if (raw == null) return fallback;
    return {for (final label in labels) label: _valueForLabel(raw, label)};
  }

  static int _valueForLabel(Map? raw, String label) {
    if (raw == null) return 0;
    final variants = {label, label.toLowerCase(), label.toUpperCase(), label.replaceAll(' ', '_').toLowerCase()};
    for (final key in variants) {
      final value = raw[key];
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isDark ? Colors.white : const Color(0xFF111113);
    final muted = fg.withOpacity(0.56);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: widget.isDark ? const Color(0xFF050506) : const Color(0xFFF8F8FA),
      body: Stack(children: [
        Positioned.fill(child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter, radius: 1.5,
              colors: widget.isDark
                  ? [const Color(0xFF1C1C1F), const Color(0xFF050506)]
                  : [const Color(0xFFF8F8FA), const Color(0xFFE2E2E8)],
            ),
          ),
        )),
        HomeOrb(color: (widget.isDark ? Colors.white : Colors.black).op(0.05), size: 300, top: 90, left: -70),
        HomeOrb(color: (widget.isDark ? Colors.white : Colors.black).op(0.035), size: 260, bottom: 110, right: -55),
        Positioned.fill(child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: (widget.isDark ? Colors.black : Colors.white).op(0.10)),
        )),
        SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _SkillGlassPanel(
                isDark: widget.isDark,
                radius: 999,
                padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: fg.op(widget.isDark ? 0.10 : 0.06)),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: fg.op(0.88)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Skill Score', style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Learning activity', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ])),
                  if (_loading)
                    SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 1.6, color: fg.op(0.68))),
                ]),
              ),
              const SizedBox(height: 14),
              _ScoreHero(data: _data, isDark: widget.isDark),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatTile(title: 'Learn feed', value: '${_data.learnContentsWatched}', unit: 'dekhe', icon: Icons.play_circle_outline_rounded, isDark: widget.isDark)),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(title: 'Quiz', value: '${_data.quizzesGiven}', unit: 'diye', icon: Icons.quiz_outlined, isDark: widget.isDark)),
              ]),
              const SizedBox(height: 12),
              _BreakdownSection(title: 'Subject quiz', values: _data.subjectQuizzes, isDark: widget.isDark),
              const SizedBox(height: 12),
              _BreakdownSection(title: 'Feed content', values: _data.contentFeeds, isDark: widget.isDark),
              const SizedBox(height: 12),
              _SkillGlassPanel(
                isDark: widget.isDark, radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: fg.op(0.62)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _data.learnContentsWatched == 0 && _data.quizzesGiven == 0
                        ? 'Abhi skill activity empty hai.'
                        : '${_data.activeAreas} active learning areas',
                    style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w700),
                  )),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SkillGlassPanel extends StatelessWidget {
  final bool isDark;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  const _SkillGlassPanel({
    required this.isDark, required this.child,
    this.padding = const EdgeInsets.all(16), this.radius = 18, this.blur = 30,
  });

  @override
  Widget build(BuildContext context) {
    final border = (isDark ? Colors.white : Colors.black).op(isDark ? 0.10 : 0.08);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: isDark
                  ? [Colors.white.op(0.082), Colors.white.op(0.030)]
                  : [Colors.white.op(0.76), Colors.white.op(0.48)],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: 0.8),
            boxShadow: [BoxShadow(
              color: isDark ? Colors.black.op(0.34) : Colors.black.op(0.08),
              blurRadius: 24, offset: const Offset(0, 10),
            )],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  final _SkillScoreData data;
  final bool isDark;
  const _ScoreHero({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111113);
    final muted = fg.withOpacity(0.54);
    return _SkillGlassPanel(
      isDark: isDark, radius: 24, blur: 34,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 108, height: 108,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(
                value: data.score / 100, strokeWidth: 7, strokeCap: StrokeCap.round,
                backgroundColor: fg.withOpacity(0.10), color: fg.withOpacity(0.88),
              )),
              Container(
                width: 78, height: 78,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: fg.op(isDark ? 0.065 : 0.055), border: Border.all(color: fg.op(0.08))),
                alignment: Alignment.center,
                child: Text('${data.score}', style: TextStyle(color: fg, fontSize: 31, fontWeight: FontWeight.w900, height: 1)),
              ),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: fg.op(isDark ? 0.10 : 0.065)),
              child: Text('SKILLS', style: TextStyle(color: fg.op(0.68), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ),
            const SizedBox(height: 10),
            Text('Overall skill score', style: TextStyle(color: fg, fontSize: 19, fontWeight: FontWeight.w900, height: 1.12)),
            const SizedBox(height: 7),
            Text('Learn, quiz aur feed activity ka clean snapshot.', style: TextStyle(color: muted, fontSize: 12.2, height: 1.35, fontWeight: FontWeight.w600)),
          ])),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _MiniMetric(label: 'Learn', value: data.learnContentsWatched, isDark: isDark),
          const SizedBox(width: 8),
          _MiniMetric(label: 'Quiz', value: data.quizzesGiven, isDark: isDark),
          const SizedBox(width: 8),
          _MiniMetric(label: 'Areas', value: data.activeAreas, isDark: isDark),
        ]),
      ]),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final int value;
  final bool isDark;
  const _MiniMetric({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111113);
    return Expanded(
      child: Container(
        height: 42, padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: fg.op(isDark ? 0.075 : 0.055), border: Border.all(color: fg.op(0.07)),
        ),
        child: Row(children: [
          Text('$value', style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg.op(0.52), fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title, value, unit;
  final IconData icon;
  final bool isDark;
  const _StatTile({required this.title, required this.value, required this.unit, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111113);
    return _SkillGlassPanel(
      isDark: isDark, padding: const EdgeInsets.all(13), radius: 17,
      child: SizedBox(height: 96,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg.op(isDark ? 0.10 : 0.06)),
              child: Icon(icon, color: fg.withOpacity(0.78), size: 19)),
            const Spacer(),
            Icon(Icons.north_east_rounded, color: fg.op(0.28), size: 15),
          ]),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: TextStyle(color: fg, fontSize: 29, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(width: 5),
            Padding(padding: const EdgeInsets.only(bottom: 3),
              child: Text(unit, style: TextStyle(color: fg.withOpacity(0.46), fontSize: 11, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 5),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg.withOpacity(0.54), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final String title;
  final Map<String, int> values;
  final bool isDark;
  const _BreakdownSection({required this.title, required this.values, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF111113);
    final maxValue = values.values.fold<int>(0, math.max);
    return _SkillGlassPanel(
      isDark: isDark, radius: 20, padding: const EdgeInsets.fromLTRB(15, 15, 15, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fg.op(isDark ? 0.09 : 0.055)),
            child: Icon(title == 'Subject quiz' ? Icons.school_outlined : Icons.auto_awesome_motion_outlined,
              size: 16, color: fg.op(0.72))),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${values.values.fold<int>(0, (sum, value) => sum + value)} total',
            style: TextStyle(color: fg.op(0.42), fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        ...values.entries.map((entry) {
          final progress = maxValue == 0 ? 0.0 : entry.value / maxValue;
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: fg.op(isDark ? 0.045 : 0.040), border: Border.all(color: fg.op(0.055)),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg.withOpacity(0.76), fontSize: 12.5, fontWeight: FontWeight.w800))),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: fg.op(isDark ? 0.09 : 0.06)),
                  child: Text('${entry.value}', textAlign: TextAlign.center,
                    style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: progress, minHeight: 6,
                  backgroundColor: fg.withOpacity(0.085), color: fg.withOpacity(0.68))),
            ]),
          );
        }),
      ]),
    );
  }
}
