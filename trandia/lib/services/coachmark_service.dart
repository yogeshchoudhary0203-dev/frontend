import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// Re-export the enums screens need so they only have to import this service.
export 'package:tutorial_coach_mark/tutorial_coach_mark.dart'
    show ContentAlign, ShapeLightFocus;

/// One step in a guided tour: a spotlight on an existing widget (via its
/// [GlobalKey]) plus a titled explanation card with a directional arrow.
class CoachStep {
  final GlobalKey key;
  final String title;
  final String body;

  /// Where the explanation card sits relative to the highlighted widget.
  final ContentAlign align;

  /// Circle for round buttons (e.g. the infinity button), RRect for cards/bars.
  final ShapeLightFocus shape;
  final double radius;

  const CoachStep({
    required this.key,
    required this.title,
    required this.body,
    this.align = ContentAlign.bottom,
    this.shape = ShapeLightFocus.RRect,
    this.radius = 14,
  });
}

/// First-run guided tours ("click here / yeh karta hai") rendered as an
/// OVERLAY on top of the existing UI.
///
/// Design rules (intentional, to satisfy the product constraints):
///  * Pure overlay — it only reads existing widgets' positions through their
///    [GlobalKey]s. It never changes any layout, widget tree, or work flow.
///  * Every tour shows AT MOST ONCE per user (persisted in SharedPreferences),
///    keyed by [tourId].
///  * Fully crash-safe: any failure (prefs error, un-mounted target) results in
///    the tour being silently skipped — it can never break a screen.
///  * If any target isn't laid out yet, the whole tour is skipped for this
///    launch and naturally retries on the next visit (still "first time").
class CoachmarkService {
  CoachmarkService._();

  static const String _prefix = 'coach_seen_';
  static bool _activeTour = false; // guards against overlapping tours

  static Future<bool> hasSeen(String tourId) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool('$_prefix$tourId') ?? false;
    } catch (_) {
      return true; // fail safe: on error, do NOT show
    }
  }

  static Future<void> _markSeen(String tourId) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('$_prefix$tourId', true);
    } catch (_) {}
  }

  /// Clears all "seen" flags — wire this to a future "Replay tutorials"
  /// setting if desired. Unused for now but kept as the single source of truth.
  static Future<void> resetAll() async {
    try {
      final p = await SharedPreferences.getInstance();
      final keys = p.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final k in keys) {
        await p.remove(k);
      }
    } catch (_) {}
  }

  /// Show a one-time guided tour. No-op if: already seen, another tour is
  /// running, the list is empty, or any target widget isn't currently mounted.
  /// Returns `true` if the tour was actually shown. Callers can use this to
  /// undo any temporary UI prep (e.g. an auto-expanded nav) when it wasn't.
  /// [onDone] fires when the tour finishes OR is skipped.
  static Future<bool> showTour(
    BuildContext context, {
    required String tourId,
    required List<CoachStep> steps,
    required bool isDark,
    VoidCallback? onDone,
  }) async {
    if (_activeTour || steps.isEmpty) return false;
    if (await hasSeen(tourId)) return false;

    // Every target must be laid out — otherwise we'd spotlight empty space.
    for (final s in steps) {
      if (s.key.currentContext == null) return false;
    }

    _activeTour = true;
    // Mark up-front so a crash / backgrounding mid-tour never re-triggers it.
    await _markSeen(tourId);
    if (!context.mounted) {
      _activeTour = false;
      return false;
    }

    final targets = <TargetFocus>[];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      targets.add(
        TargetFocus(
          identify: '$tourId-$i',
          keyTarget: s.key,
          shape: s.shape,
          radius: s.radius,
          enableOverlayTab: true, // tapping outside advances — feels natural
          contents: [
            TargetContent(
              align: s.align,
              builder: (ctx, controller) => _Card(
                isDark: isDark,
                step: s,
                index: i,
                total: steps.length,
                onNext: controller.next,
                onSkip: controller.skip,
              ),
            ),
          ],
        ),
      );
    }

    try {
      TutorialCoachMark(
        targets: targets,
        colorShadow: const Color(0xFF0A0A12),
        opacityShadow: 0.86,
        paddingFocus: 9,
        hideSkip: true, // we render our own Skip inside the card
        pulseEnable: true,
        pulseAnimationDuration: const Duration(milliseconds: 900),
        focusAnimationDuration: const Duration(milliseconds: 480),
        unFocusAnimationDuration: const Duration(milliseconds: 480),
        onFinish: () {
          _activeTour = false;
          onDone?.call();
        },
        onSkip: () {
          _activeTour = false;
          onDone?.call();
          return true;
        },
      ).show(context: context, rootOverlay: true);
      return true;
    } catch (_) {
      _activeTour = false; // never let a tour failure surface to the user
      return false;
    }
  }
}

/// The explanation card: an animated, directional arrow + title + body +
/// progress + actions. Entrance is fade + scale + slide; the arrow gently
/// bobs toward the highlighted element.
class _Card extends StatefulWidget {
  final bool isDark;
  final CoachStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _Card({
    required this.isDark,
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  )..forward();
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat(reverse: true);

  late final Animation<double> _fade =
      CurvedAnimation(parent: _in, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.90, end: 1.0)
      .animate(CurvedAnimation(parent: _in, curve: Curves.easeOutBack));
  late final Animation<double> _slide = Tween<double>(begin: 16.0, end: 0.0)
      .animate(CurvedAnimation(parent: _in, curve: Curves.easeOutCubic));
  late final Animation<double> _bobT = Tween<double>(begin: 0.0, end: 6.0)
      .animate(CurvedAnimation(parent: _bob, curve: Curves.easeInOut));

  @override
  void dispose() {
    _in.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = widget.index == widget.total - 1;
    // Only top/bottom-aligned cards get a vertical arrow; for side-aligned
    // cards the pulsing spotlight is the indicator.
    final bool isVertical = widget.step.align == ContentAlign.top ||
        widget.step.align == ContentAlign.bottom;
    final bool arrowOnTop = widget.step.align == ContentAlign.bottom;

    final Color cardBg = widget.isDark ? const Color(0xFF1C1C1F) : Colors.white;
    final Color title = widget.isDark ? Colors.white : const Color(0xFF111111);
    final Color body = widget.isDark ? Colors.white70 : const Color(0xFF555555);
    final Color accent = widget.isDark ? Colors.white : const Color(0xFF111111);
    final Color onAccent = widget.isDark ? const Color(0xFF111111) : Colors.white;

    final arrow = AnimatedBuilder(
      animation: _bobT,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, arrowOnTop ? -_bobT.value : _bobT.value),
        child: Icon(
          arrowOnTop
              ? Icons.arrow_drop_up_rounded
              : Icons.arrow_drop_down_rounded,
          color: cardBg,
          size: 46,
        ),
      ),
    );

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.step.title,
              style: TextStyle(
                color: title,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.step.body,
              style: TextStyle(color: body, fontSize: 13.5, height: 1.38),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // Animated progress dots
                Row(
                  children: List.generate(widget.total, (i) {
                    final active = i == widget.index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      width: active ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: active ? accent : accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: body,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onNext,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.fromLTRB(18, 9, 14, 9),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? 'Got it' : 'Next',
                          style: TextStyle(
                            color: onAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          isLast
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          color: onAccent,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final content = Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isVertical && arrowOnTop)
            Padding(padding: const EdgeInsets.only(left: 24), child: arrow),
          card,
          if (isVertical && !arrowOnTop)
            Padding(padding: const EdgeInsets.only(left: 24), child: arrow),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _in,
      builder: (_, child) => Opacity(
        opacity: _fade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: Transform.scale(
            scale: _scale.value,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
      child: content,
    );
  }
}
