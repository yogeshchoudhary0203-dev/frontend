import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../screens/story_upload_screen.dart';
import '../../screens/story_view_screen.dart';
import '../../services/story_service.dart';
import '../shared/home_shared.dart';

// ═════════════════════════════════════════════════════
//  STORY SECTION
// ═════════════════════════════════════════════════════

class StorySection extends StatefulWidget {
  final bool isDark;
  final String? myProfilePic;
  final String? myName;
  const StorySection({super.key, required this.isDark, this.myProfilePic, this.myName});
  @override
  State<StorySection> createState() => _StorySectionState();
}

class _StorySectionState extends State<StorySection> {
  List<StoryUserGroup>? _groups;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await StoryService.instance.getFeed();
      if (mounted) setState(() { _groups = groups; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _groups = []; _loading = false; });
    }
  }

  Future<void> _openUpload() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryUploadScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openView(int groupIdx) async {
    if (_groups == null || _groups!.isEmpty) return;
    await Navigator.push<void>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StoryViewScreen(groups: _groups!, initialGroupIndex: groupIdx),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    _load();
  }

  void _showOwnStoryOptions(BuildContext context, StoryUserGroup ownGroup) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OwnStoryOptionsSheet(
        isDark: widget.isDark,
        onView: () { Navigator.pop(ctx); _openView(_groups!.indexOf(ownGroup)); },
        onAdd:  () { Navigator.pop(ctx); _openUpload(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups   = _groups ?? [];
    final ownGroup = groups.firstWhere(
      (g) => g.isOwn,
      orElse: () => const StoryUserGroup(userId: '', userName: '', userUsername: '', isOwn: true, allSeen: false, stories: []),
    );
    final hasOwn = groups.any((g) => g.isOwn);
    final others = groups.where((g) => !g.isOwn).toList();
    final total  = _loading ? 6 : 1 + others.length;

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        itemCount: total,
        itemBuilder: (_, i) {
          if (_loading) {
            return Padding(padding: const EdgeInsets.only(right: 14), child: _ShimmerBubble(isDark: widget.isDark));
          }
          if (i == 0) {
            final ownPicture = ownGroup.userPicture ?? widget.myProfilePic;
            final ownInitial = ownGroup.userName.isNotEmpty
                ? ownGroup.userName[0].toUpperCase()
                : (widget.myName?.isNotEmpty == true ? widget.myName![0].toUpperCase() : 'Y');
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: hasOwn
                  ? _StoryBubble(name: 'Your Story', picture: ownPicture, initials: ownInitial, isOwn: true, hasStory: true, seen: false, isDark: widget.isDark,
                      onTap: () => _openView(groups.indexOf(ownGroup)), onAddTap: _openUpload, onLongPress: () => _showOwnStoryOptions(context, ownGroup))
                  : _StoryBubble(name: 'Your Story', picture: widget.myProfilePic, initials: ownInitial, isOwn: true, hasStory: false, seen: false, isDark: widget.isDark,
                      onTap: _openUpload),
            );
          }
          final g    = others[i - 1];
          final seen = g.allSeen || (g.hasStories && g.stories.every((story) => story.viewed));
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _StoryBubble(
              name: g.userName,
              picture: g.userPicture,
              initials: g.userName.isNotEmpty ? g.userName[0].toUpperCase() : '?',
              isOwn: false,
              hasStory: g.hasStories,
              seen: seen,
              isDark: widget.isDark,
              onTap: () => _openView(groups.indexOf(g)),
            ),
          );
        },
      ),
    );
  }
}

class _ShimmerBubble extends StatelessWidget {
  final bool isDark;
  const _ShimmerBubble({required this.isDark});
  @override
  Widget build(BuildContext context) {
    final c = (isDark ? Colors.white : Colors.black).withOpacity(0.07);
    return SizedBox(width: 70, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
      const SizedBox(height: 6),
      Container(width: 44, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: c)),
    ]));
  }
}

class _OwnStoryOptionsSheet extends StatelessWidget {
  final bool isDark;
  final VoidCallback onView;
  final VoidCallback onAdd;
  const _OwnStoryOptionsSheet({required this.isDark, required this.onView, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : Colors.black;
    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF4F4F6);
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: fg.withOpacity(0.16))),
        const SizedBox(height: 16),
        Text('Your Story Options', style: GoogleFonts.manrope(color: fg, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ListTile(leading: Icon(Icons.remove_red_eye_rounded, color: fg),
          title: Text('View Your Stories', style: GoogleFonts.manrope(color: fg, fontWeight: FontWeight.w600)), onTap: onView),
        Divider(height: 1, color: fg.withOpacity(0.06), indent: 16, endIndent: 16),
        ListTile(leading: Icon(Icons.add_photo_alternate_rounded, color: fg),
          title: Text('Add New Story', style: GoogleFonts.manrope(color: fg, fontWeight: FontWeight.w600)), onTap: onAdd),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ]),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final String name;
  final String? picture;
  final String initials;
  final bool isOwn, hasStory, seen, isDark;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onLongPress;

  const _StoryBubble({
    required this.name, this.picture, required this.initials,
    required this.isOwn, required this.hasStory, required this.seen,
    required this.isDark, required this.onTap, this.onAddTap, this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      onLongPress: onLongPress,
      child: SizedBox(
        width: 70,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            SizedBox(width: 70, height: 70,
              child: CustomPaint(
                painter: _StoryRingPainter(isDark: isDark, seen: seen && !isOwn, isOwn: isOwn && !hasStory),
                child: Padding(padding: const EdgeInsets.all(4.5),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E5EA),
                      border: Border.all(color: isDark ? Colors.black.op(0.60) : Colors.white.op(0.70), width: 2),
                    ),
                    child: ClipOval(
                      child: picture != null
                          ? CachedNetworkImage(imageUrl: picture!, fit: BoxFit.cover,
                              fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero,
                              placeholderFadeInDuration: Duration.zero,
                              errorWidget: (_, __, ___) => _AvatarContent(initials: initials, isOwnNoStory: isOwn && !hasStory, isDark: isDark))
                          : _AvatarContent(initials: initials, isOwnNoStory: isOwn && !hasStory, isDark: isDark),
                    ),
                  )),
              ),
            ),
            if (isOwn && hasStory && onAddTap != null)
              Positioned(right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: () { HapticFeedback.lightImpact(); onAddTap!(); },
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white : Colors.black,
                      border: Border.all(color: isDark ? Colors.black : Colors.white, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 1.5))],
                    ),
                    child: Icon(Icons.add, color: isDark ? Colors.black : Colors.white, size: 14),
                  ),
                )),
          ]),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: TextStyle(color: (isDark ? Colors.white : Colors.black).op(seen && !isOwn ? 0.38 : 0.80), fontSize: 10.5, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _AvatarContent extends StatelessWidget {
  final String initials;
  final bool isOwnNoStory, isDark;
  const _AvatarContent({required this.initials, required this.isOwnNoStory, required this.isDark});
  @override
  Widget build(BuildContext context) => Center(
    child: isOwnNoStory
        ? CustomPaint(size: const Size(18, 18), painter: _PlusPainter(color: isDark ? Colors.white : const Color(0xFF1A1A1A)))
        : Text(initials, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A1A), fontSize: 15, fontWeight: FontWeight.w700)),
  );
}

class _StoryRingPainter extends CustomPainter {
  final bool isDark, seen, isOwn;
  const _StoryRingPainter({required this.isDark, this.seen = false, this.isOwn = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 1.5;
    if (isOwn) { _drawDashed(canvas, Offset(cx, cy), radius); return; }
    if (seen) {
      canvas.drawCircle(Offset(cx, cy), radius, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round
        ..color = (isDark ? const Color(0xFFC8CCD2) : const Color(0xFF9CA3AF)).op(isDark ? 0.42 : 0.62));
      return;
    }
    final center = Offset(cx, cy);
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2.8..color = (isDark ? Colors.white : Colors.black).op(0.06));
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.sweep(center,
        isDark
            ? const [Color(0xFFFFC66D), Color(0xFFE86D8F), Color(0xFF8B7CFF), Color(0xFFFFC66D)]
            : const [Color(0xFFF2A24B), Color(0xFFD95778), Color(0xFF7666D9), Color(0xFFF2A24B)],
        const [0.0, 0.34, 0.68, 1.0], TileMode.clamp, -math.pi / 2, -math.pi / 2 + math.pi * 2));
  }

  void _drawDashed(Canvas canvas, Offset center, double radius) {
    const int n = 20;
    const double step = (2 * math.pi) / n;
    final Paint p = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round
      ..color = (isDark ? Colors.white : Colors.black).op(0.45);
    for (int i = 0; i < n; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), i * step - math.pi / 2, step * 0.70, false, p);
    }
  }

  @override
  bool shouldRepaint(_StoryRingPainter o) => o.isDark != isDark || o.seen != seen || o.isOwn != isOwn;
}

class _PlusPainter extends CustomPainter {
  final Color color;
  const _PlusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color.op(0.85)..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    final double cx = size.width / 2, cy = size.height / 2;
    canvas.drawLine(Offset(cx, cy - 5.5), Offset(cx, cy + 5.5), p);
    canvas.drawLine(Offset(cx - 5.5, cy), Offset(cx + 5.5, cy), p);
  }

  @override
  bool shouldRepaint(_PlusPainter o) => o.color != color;
}
