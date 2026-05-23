// create_post_screens.dart
// Full Create-Post flow — Hub (Photos/Videos · Fun/Learn) → Edit → Details
// → Uploading → Success. Glass / matte-mono theme, both light & dark.
//
// Drop in `lib/` alongside the other screens. Depends on glass_common.dart
// for theme tokens + Manrope + monoAvatar.
//
//   ┌──────────────┐    ┌────────┐    ┌──────────┐    ┌────────────┐    ┌──────────┐
//   │ Hub (picker) │ -> │ Edit   │ -> │ Details  │ -> │ Uploading  │ -> │ Success  │
//   └──────────────┘    └────────┘    └──────────┘    └────────────┘    └──────────┘

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'glass_common.dart';

// ───────────────────────────────────────────────────────────────
// Local helpers
// ───────────────────────────────────────────────────────────────

/// Mono *tile* gradient (different palette family from `monoAvatar`).
/// Used for media thumbnails, filter chips, preview canvas.
LinearGradient monoTile(bool dark, int i) {
  double a, b;
  if (dark) {
    a = 22 - (i % 5) * 3.0;
    b = (a - 12).clamp(4.0, 100.0);
  } else {
    a = 92 - (i % 5) * 4.0;
    b = (a - 18).clamp(56.0, 100.0);
  }
  final angle = (135 + (i * 29) % 90) * math.pi / 180.0;
  return LinearGradient(
    begin: Alignment(math.cos(angle + math.pi), math.sin(angle + math.pi)),
    end:   Alignment(math.cos(angle),            math.sin(angle)),
    colors: [
      HSLColor.fromAHSL(1, 0, 0, a / 100).toColor(),
      HSLColor.fromAHSL(1, 0, 0, b / 100).toColor(),
    ],
  );
}

class CpColors {
  final bool dark;
  CpColors(this.dark);

  Color get bg       => dark ? const Color(0xFF0A0A0C) : const Color(0xFFF4F2ED);
  Color get text     => dark ? const Color(0xFFF3F3F4) : const Color(0xFF161618);
  Color get accentOn => dark ? const Color(0xFF0A0A0C) : Colors.white;
  Color get sub      => (dark ? const Color(0xFFF3F3F4) : const Color(0xFF161618)).withOpacity(0.58);
  Color get fade     => (dark ? const Color(0xFFF3F3F4) : const Color(0xFF161618)).withOpacity(0.35);
  Color get border   => dark
      ? Colors.white.withOpacity(0.08)
      : const Color(0xFF161618).withOpacity(0.07);
  Color get pillBg   => dark
      ? Colors.white.withOpacity(0.05)
      : const Color(0xFF161618).withOpacity(0.05);
  Color get surface  => dark
      ? Colors.white.withOpacity(0.04)
      : Colors.white.withOpacity(0.6);
  Color get nextAction => dark ? const Color(0xFF9ED7C5) : const Color(0xFF1F6A5A);
}

// ───────────────────────────────────────────────────────────────
// Top bar — shared across the flow
// ───────────────────────────────────────────────────────────────
class _CpTopBar extends StatelessWidget {
  final bool dark;
  final Widget? left;
  final String title;
  final String rightLabel;
  final bool rightActive;
  final VoidCallback? onRight;

  const _CpTopBar({
    required this.dark,
    this.left,
    required this.title,
    this.rightLabel = 'Next',
    this.rightActive = true,
    this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 64, child: Align(alignment: Alignment.centerLeft, child: left ?? const SizedBox.shrink())),
          Expanded(
            child: Center(
              child: Text(
                title.tr(context),
                style: manrope(size: 16, weight: FontWeight.w700, color: c.text, letterSpacing: -0.16),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: rightLabel.isEmpty
                  ? const SizedBox.shrink()
                  : InkWell(
                      onTap: rightActive ? onRight : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Text(
                          rightLabel.tr(context),
                          style: manrope(
                            size: 14,
                            weight: FontWeight.w800,
                            color: rightActive ? c.nextAction : c.fade,
                            letterSpacing: -0.07,
                          ),
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

Widget _cpIconBtn({required bool dark, required IconData icon, VoidCallback? onTap}) {
  final c = CpColors(dark);
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 22, color: c.text)),
    ),
  );
}

// ───────────────────────────────────────────────────────────────
// Recent-media model (deterministic, matches the JSX)
// ───────────────────────────────────────────────────────────────
enum CpMediaType { image, video }

class CpMediaItem {
  final int i;
  final CpMediaType type;
  final String? duration;
  const CpMediaItem(this.i, this.type, [this.duration]);
}

const List<CpMediaItem> _kRecentMedia = [
  CpMediaItem(0,  CpMediaType.image),
  CpMediaItem(1,  CpMediaType.image),
  CpMediaItem(2,  CpMediaType.image),
  CpMediaItem(3,  CpMediaType.video, '0:22'),
  CpMediaItem(4,  CpMediaType.image),
  CpMediaItem(5,  CpMediaType.image),
  CpMediaItem(6,  CpMediaType.image),
  CpMediaItem(7,  CpMediaType.video, '0:14'),
  CpMediaItem(8,  CpMediaType.image),
  CpMediaItem(9,  CpMediaType.image),
  CpMediaItem(10, CpMediaType.video, '1:08'),
  CpMediaItem(11, CpMediaType.image),
  CpMediaItem(12, CpMediaType.image),
  CpMediaItem(13, CpMediaType.image),
  CpMediaItem(14, CpMediaType.video, '0:36'),
  CpMediaItem(15, CpMediaType.image),
  CpMediaItem(16, CpMediaType.image),
  CpMediaItem(17, CpMediaType.image),
];

// ═══════════════════════════════════════════════════════════════
// 1. HUB — picker (Photos / Videos · Fun / Learn)
// ═══════════════════════════════════════════════════════════════
enum CpTab { photo, video }
enum CpVideoSection { fun, learn }

class CreatePostHubScreen extends StatefulWidget {
  final bool dark;
  final CpTab initialTab;
  const CreatePostHubScreen({super.key, this.dark = false, this.initialTab = CpTab.photo});

  @override
  State<CreatePostHubScreen> createState() => _CreatePostHubScreenState();
}

class _CreatePostHubScreenState extends State<CreatePostHubScreen> {
  late CpTab _tab = widget.initialTab;
  CpVideoSection _section = CpVideoSection.fun;
  List<int> _sel = [0];
  bool _multi = false;

  List<CpMediaItem> get _list {
    if (_tab == CpTab.photo) {
      return _kRecentMedia.where((m) => m.type == CpMediaType.image).toList();
    }
    final vids = _kRecentMedia.where((m) => m.type == CpMediaType.video).toList();
    return vids
        .where((m) => _section == CpVideoSection.fun ? m.i.isOdd : m.i.isEven)
        .toList();
  }

  void _setTab(CpTab t) {
    setState(() {
      _tab = t;
      final l = _list;
      _sel = l.isEmpty ? [] : [l.first.i];
    });
  }

  void _setSection(CpVideoSection s) {
    setState(() {
      _section = s;
      final l = _list;
      _sel = l.isEmpty ? [] : [l.first.i];
    });
  }

  void _toggle(int i) {
    setState(() {
      if (!_multi) {
        _sel = [i];
      } else {
        if (_sel.contains(i)) {
          _sel.remove(i);
        } else if (_sel.length < 10) {
          _sel.add(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    final list = _list;
    final primary = list.firstWhere(
      (m) => _sel.isNotEmpty && m.i == _sel.first,
      orElse: () => list.isNotEmpty ? list.first : const CpMediaItem(0, CpMediaType.image),
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CpTopBar(
              dark: widget.dark,
              left: _cpIconBtn(dark: widget.dark, icon: Icons.close, onTap: () => Navigator.maybePop(context)),
              title: 'New post',
              rightLabel: 'Next',
              rightActive: _sel.isNotEmpty,
              onRight: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CreatePostEditScreen(dark: widget.dark)),
              ),
            ),

            // ── PREVIEW ────────────────────────────────────
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              child: _PickerPreview(
                dark: widget.dark,
                item: primary,
                section: _section,
              ),
            ),

            // ── CONTROL ROW ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  _RecentPill(dark: widget.dark),
                  const Spacer(),
                  _IconPill(
                    dark: widget.dark,
                    icon: Icons.collections_outlined,
                    active: _multi,
                    onTap: () {
                      setState(() {
                        _multi = !_multi;
                        if (!_multi && _sel.length > 1) _sel = _sel.take(1).toList();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _IconPill(
                    dark: widget.dark,
                    icon: Icons.photo_camera_outlined,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // ── TAB Photos / Videos ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  _TabBtn(dark: widget.dark, label: 'Photos', active: _tab == CpTab.photo,
                      onTap: () => _setTab(CpTab.photo)),
                  const SizedBox(width: 24),
                  _TabBtn(dark: widget.dark, label: 'Videos', active: _tab == CpTab.video,
                      onTap: () => _setTab(CpTab.video)),
                ],
              ),
            ),

            // ── VIDEO sub-segment: Fun / Learn ───────────────────
            if (_tab == CpTab.video)
              Container(
                color: c.bg,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Column(
                  children: [
                    _FunLearnSegment(
                      dark: widget.dark,
                      section: _section,
                      onChange: _setSection,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _section == CpVideoSection.fun
                          ? 'Casual, playful clips · max 60s'
                          : 'Tutorials & how-tos · max 5 min',
                      style: manrope(size: 11.5, weight: FontWeight.w500, color: c.sub, letterSpacing: -0.06),
                    ),
                  ],
                ),
              ),

            // ── GRID ─────────────────────────────────────────────
            Expanded(
              child: Container(
                color: c.bg,
                padding: const EdgeInsets.all(2),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, idx) {
                    final m = list[idx];
                    final selIdx = _sel.indexOf(m.i);
                    final isSel = selIdx != -1;
                    return _GridCell(
                      dark: widget.dark,
                      item: m,
                      selected: isSel,
                      selIndex: selIdx,
                      multi: _multi,
                      onTap: () => _toggle(m.i),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerPreview extends StatelessWidget {
  final bool dark;
  final CpMediaItem item;
  final CpVideoSection section;
  const _PickerPreview({required this.dark, required this.item, required this.section});

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == CpMediaType.video;
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(decoration: BoxDecoration(gradient: monoTile(dark, item.i))),
      if (isVideo)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.0,
              colors: [Color(0x00000000), Color(0x6B000000)],
            ),
          ),
        ),
      if (isVideo)
        Positioned(
          top: 12, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              section == CpVideoSection.fun ? 'FUN' : 'LEARN',
              style: manrope(
                size: 10.5, weight: FontWeight.w800,
                color: Colors.white, letterSpacing: 0.7,
              ),
            ),
          ),
        ),
      if (isVideo && item.duration != null)
        Positioned(
          right: 12, bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.duration!,
              style: manrope(size: 11, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.05),
            ),
          ),
        ),
      Positioned(
        left: 12, bottom: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.42),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '1 : 1',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _RecentPill extends StatelessWidget {
  final bool dark;
  const _RecentPill({required this.dark});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Recent'.tr(context),
              style: manrope(size: 13.5, weight: FontWeight.w700, color: c.text, letterSpacing: -0.07)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: c.text),
        ]),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _IconPill({required this.dark, required this.icon, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36, height: 32,
        decoration: BoxDecoration(
          color: active
              ? c.text
              : (dark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.7)),
          border: Border.all(color: active ? Colors.transparent : c.border),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: active ? c.accentOn : c.text),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final bool dark;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.dark, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 12, bottom: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: active ? c.text : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          label,
          style: manrope(
            size: 13.5,
            weight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? c.text : c.sub,
            letterSpacing: -0.07,
          ),
        ),
      ),
    );
  }
}

class _FunLearnSegment extends StatelessWidget {
  final bool dark;
  final CpVideoSection section;
  final ValueChanged<CpVideoSection> onChange;
  const _FunLearnSegment({required this.dark, required this.section, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.pillBg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(children: [
        // sliding thumb
        AnimatedAlign(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          alignment: section == CpVideoSection.fun ? Alignment.centerLeft : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            child: Container(
              decoration: BoxDecoration(
                color: c.text,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        Row(children: [
          Expanded(
            child: _SegLabel(
              dark: dark, label: 'Fun',
              active: section == CpVideoSection.fun,
              onTap: () => onChange(CpVideoSection.fun),
            ),
          ),
          Expanded(
            child: _SegLabel(
              dark: dark, label: 'Learn',
              active: section == CpVideoSection.learn,
              onTap: () => onChange(CpVideoSection.learn),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _SegLabel extends StatelessWidget {
  final bool dark;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegLabel({required this.dark, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: Text(
            label,
            style: manrope(
              size: 12.5,
              weight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? c.accentOn : c.text,
              letterSpacing: -0.06,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final bool dark;
  final CpMediaItem item;
  final bool selected;
  final int selIndex;
  final bool multi;
  final VoidCallback onTap;
  const _GridCell({
    required this.dark, required this.item, required this.selected,
    required this.selIndex, required this.multi, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    final isVideo = item.type == CpMediaType.video;
    return GestureDetector(
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(decoration: BoxDecoration(gradient: monoTile(dark, item.i))),
        if (isVideo)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x73000000)],
                stops: [0.6, 1.0],
              ),
            ),
          ),
        if (isVideo && item.duration != null)
          Positioned(
            right: 6, bottom: 5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow, size: 10, color: Colors.white),
                const SizedBox(width: 2),
                Text(item.duration!,
                    style: manrope(size: 10, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.05)),
              ],
            ),
          ),
        // selection chip
        Positioned(
          top: 6, right: 6,
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? c.text : Colors.black.withOpacity(0.28),
              border: Border.all(
                color: selected ? c.text : Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
            ),
            alignment: Alignment.center,
            child: selected
                ? (multi
                    ? Text('${selIndex + 1}',
                        style: manrope(size: 11, weight: FontWeight.w800, color: c.accentOn, letterSpacing: -0.1))
                    : Icon(Icons.check, size: 13, color: c.accentOn))
                : null,
          ),
        ),
        if (multi && !selected)
          const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: Color(0x2E000000)))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 2. EDIT screen (Crop · Filter · Adjust · Trim)
// ═══════════════════════════════════════════════════════════════
enum CpEditTool { crop, filter, adjust, trim }

const _kFilterNames = ['Original', 'Matte', 'Ivory', 'Slate', 'Noir', 'Mist', 'Sepia', 'Cool'];

class CreatePostEditScreen extends StatefulWidget {
  final bool dark;
  const CreatePostEditScreen({super.key, this.dark = false});

  @override
  State<CreatePostEditScreen> createState() => _CreatePostEditScreenState();
}

class _CreatePostEditScreenState extends State<CreatePostEditScreen> {
  CpEditTool _tool = CpEditTool.filter;
  int _filter = 1;

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _CpTopBar(
            dark: widget.dark,
            left: _cpIconBtn(dark: widget.dark, icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
            title: 'Edit',
            rightLabel: 'Next',
            rightActive: true,
            onRight: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CreatePostDetailsScreen(dark: widget.dark)),
            ),
          ),

          // ── PREVIEW with filter applied ───────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              ColorFiltered(
                colorFilter: _filterMatrix(_filter),
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: monoTile(widget.dark, 1)),
                ),
              ),
              if (_tool == CpEditTool.crop) const _CropGrid(),
            ]),
          ),

          // ── TOOL panel ────────────────────────────────────────
          Expanded(
            child: Container(
              color: c.bg,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
              child: _toolPanel(),
            ),
          ),

          // ── BOTTOM dock ───────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: c.bg,
              border: Border(top: BorderSide(color: c.border)),
            ),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ToolBtn(dark: widget.dark, icon: Icons.crop_free,         label: 'Crop',
                    active: _tool == CpEditTool.crop,   onTap: () => setState(() => _tool = CpEditTool.crop)),
                _ToolBtn(dark: widget.dark, icon: Icons.filter_vintage,    label: 'Filter',
                    active: _tool == CpEditTool.filter, onTap: () => setState(() => _tool = CpEditTool.filter)),
                _ToolBtn(dark: widget.dark, icon: Icons.tune,              label: 'Adjust',
                    active: _tool == CpEditTool.adjust, onTap: () => setState(() => _tool = CpEditTool.adjust)),
                _ToolBtn(dark: widget.dark, icon: Icons.content_cut,       label: 'Trim',
                    active: _tool == CpEditTool.trim,   onTap: () => setState(() => _tool = CpEditTool.trim)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _toolPanel() {
    switch (_tool) {
      case CpEditTool.filter:
        return _FilterPanel(
          dark: widget.dark, selected: _filter,
          onSelect: (i) => setState(() => _filter = i),
        );
      case CpEditTool.adjust:
        return _AdjustPanel(dark: widget.dark);
      case CpEditTool.crop:
        return _CropPanel(dark: widget.dark);
      case CpEditTool.trim:
        return _TrimPanel(dark: widget.dark);
    }
  }
}

ColorFilter _filterMatrix(int idx) {
  // simple, deterministic per-filter look. Identity matrix for "Original".
  switch (idx) {
    case 1:
      return const ColorFilter.matrix([
        1.05,0,0,0,4,  0,1.05,0,0,4,  0,0,1.05,0,4,  0,0,0,1,0,
      ]);
    case 2: // sepia-ish
      return const ColorFilter.matrix([
        0.45,0.45,0.10,0,18,  0.30,0.55,0.10,0,12,  0.25,0.40,0.30,0, 8,  0,0,0,1,0,
      ]);
    case 3: // muted
      return const ColorFilter.matrix([
        0.85,0.05,0.05,0,0,  0.05,0.85,0.05,0,0,  0.05,0.05,0.85,0,0,  0,0,0,1,0,
      ]);
    case 4: // noir (b/w)
      return const ColorFilter.matrix([
        0.33,0.59,0.11,0,-10,  0.33,0.59,0.11,0,-10,  0.33,0.59,0.11,0,-10,  0,0,0,1,0,
      ]);
    case 5: // mist
      return const ColorFilter.matrix([
        0.92,0.04,0.04,0,16,  0.04,0.92,0.04,0,16,  0.04,0.04,0.92,0,16,  0,0,0,1,0,
      ]);
    case 6: // strong sepia
      return const ColorFilter.matrix([
        0.55,0.55,0.10,0,16,  0.30,0.60,0.10,0,10,  0.20,0.30,0.30,0, 4,  0,0,0,1,0,
      ]);
    case 7: // cool
      return const ColorFilter.matrix([
        0.85,0,0.10,0,-2,  0,0.95,0.10,0,4,  0.10,0.05,1.05,0,8,  0,0,0,1,0,
      ]);
    default:
      return const ColorFilter.matrix([
        1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0,
      ]);
  }
}

class _CropGrid extends StatelessWidget {
  const _CropGrid();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _CropGridPainter()),
    );
  }
}

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = Colors.white.withOpacity(0.5)..strokeWidth = 1;
    final outer = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w / 3, 0),     Offset(w / 3, h),     line);
    canvas.drawLine(Offset(2 * w / 3, 0), Offset(2 * w / 3, h), line);
    canvas.drawLine(Offset(0, h / 3),     Offset(w, h / 3),     line);
    canvas.drawLine(Offset(0, 2 * h / 3), Offset(w, 2 * h / 3), line);
    canvas.drawRect(Rect.fromLTWH(2, 2, w - 4, h - 4), outer);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilterPanel extends StatelessWidget {
  final bool dark;
  final int selected;
  final ValueChanged<int> onSelect;
  const _FilterPanel({required this.dark, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'FILTERS', color: c.sub),
      const SizedBox(height: 12),
      SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _kFilterNames.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final active = selected == i;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? c.text : Colors.transparent, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColorFiltered(
                      colorFilter: _filterMatrix(i),
                      child: DecoratedBox(decoration: BoxDecoration(gradient: monoTile(dark, i + 1))),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_kFilterNames[i],
                    style: manrope(
                      size: 11,
                      weight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? c.text : c.sub,
                      letterSpacing: -0.06,
                    )),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

class _AdjustPanel extends StatelessWidget {
  final bool dark;
  const _AdjustPanel({required this.dark});

  static const _rows = [
    ['Brightness', 12], ['Contrast', -4], ['Warmth', 8],
    ['Saturation', 0], ['Highlights', -10], ['Shadows', 6],
  ];

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel(text: 'ADJUST', color: c.sub),
        const SizedBox(height: 14),
        for (final r in _rows) _AdjustSlider(dark: dark, label: r[0] as String, value: r[1] as int),
      ]),
    );
  }
}

class _AdjustSlider extends StatelessWidget {
  final bool dark;
  final String label;
  final int value;
  const _AdjustSlider({required this.dark, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label.tr(context), style: manrope(size: 12, weight: FontWeight.w600, color: c.text, letterSpacing: -0.06)),
          const Spacer(),
          Text(value > 0 ? '+$value' : '$value',
              style: manrope(size: 12, weight: FontWeight.w600, color: c.sub, letterSpacing: -0.06)),
        ]),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (_, cs) {
          final w = cs.maxWidth;
          final half = w / 2;
          final dx = (value * 2 / 100) * w; // -100..100 → full width
          final thumbX = half + dx - 7;
          final fillW = (dx.abs()).clamp(0.0, half);
          return SizedBox(
            height: 18,
            child: Stack(children: [
              Positioned(top: 8, left: 0, right: 0,
                child: Container(height: 2, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(999)))),
              // fill from center
              Positioned(
                top: 8,
                left: value < 0 ? half - fillW : half,
                width: fillW, height: 2,
                child: DecoratedBox(decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(999))),
              ),
              Positioned(
                left: thumbX, top: 2,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: c.text,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

class _CropPanel extends StatelessWidget {
  final bool dark;
  const _CropPanel({required this.dark});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    const ratios = ['1:1', '4:5', '3:4', '9:16', '16:9', 'Free'];
    const active = '1:1';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'ASPECT RATIO', color: c.sub),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final r in ratios)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: r == active ? c.text : Colors.transparent,
              border: Border.all(color: r == active ? c.text : c.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(r,
                style: manrope(
                  size: 12.5, weight: FontWeight.w700,
                  color: r == active ? c.accentOn : c.text, letterSpacing: -0.06,
                )),
          ),
      ]),
    ]);
  }
}

class _TrimPanel extends StatelessWidget {
  final bool dark;
  const _TrimPanel({required this.dark});

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(text: 'TRIM · 0:08 – 0:52', color: c.sub),
      const SizedBox(height: 12),
      Container(
        height: 56,
        decoration: BoxDecoration(
          color: dark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.5),
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: List.generate(24, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: monoTile(dark, i),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // selection box
            Positioned.fill(
              child: LayoutBuilder(builder: (_, cs) {
                final w = cs.maxWidth;
                return Stack(children: [
                  Positioned(
                    left: 0.12 * w, top: 0, bottom: 0, width: 4,
                    child: DecoratedBox(decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(2))),
                  ),
                  Positioned(
                    left: 0.78 * w, top: 0, bottom: 0, width: 4,
                    child: DecoratedBox(decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(2))),
                  ),
                  Positioned(
                    left: 0.12 * w + 4, right: w - (0.78 * w),
                    top: 0, bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top:    BorderSide(color: c.text, width: 2),
                            bottom: BorderSide(color: c.text, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]);
              }),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: Text('Drag the handles to trim - 44s selected'.tr(context),
            style: manrope(size: 11.5, weight: FontWeight.w500, color: c.sub, letterSpacing: -0.06)),
      ),
    ]);
  }
}

class _ToolBtn extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToolBtn({
    required this.dark, required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: active ? c.text : c.sub),
          const SizedBox(height: 5),
          Text(label.tr(context),
              style: manrope(
                size: 10.5,
                weight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? c.text : c.sub, letterSpacing: -0.05,
              )),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: manrope(size: 11, weight: FontWeight.w700, color: color, letterSpacing: 1.7),
      );
}

// ═══════════════════════════════════════════════════════════════
// 3. DETAILS / caption screen
// ═══════════════════════════════════════════════════════════════
enum CpKind { photo, video }

class CreatePostDetailsScreen extends StatefulWidget {
  final bool dark;
  final CpKind kind;
  const CreatePostDetailsScreen({super.key, this.dark = false, this.kind = CpKind.video});

  @override
  State<CreatePostDetailsScreen> createState() => _CreatePostDetailsScreenState();
}

class _CreatePostDetailsScreenState extends State<CreatePostDetailsScreen> {
  late final TextEditingController _caption = TextEditingController(
    text: '60-sec breakdown on kerning — three tiny rules that fix 90% of bad type.',
  );
  CpVideoSection _section = CpVideoSection.learn;
  String _audience = 'Everyone';

  bool _toggleShareStory = false;
  bool _toggleHideCounts = false;
  bool _toggleCommentsOff = true;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _CpTopBar(
            dark: widget.dark,
            left: _cpIconBtn(dark: widget.dark, icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
            title: 'New post',
            rightLabel: 'Share',
            rightActive: true,
            onRight: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CreatePostUploadingScreen(dark: widget.dark)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── caption row ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bg,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          gradient: monoTile(widget.dark, 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      if (widget.kind == CpKind.video)
                        const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _caption,
                        maxLines: 3,
                        style: manrope(
                          size: 14, weight: FontWeight.w500, color: c.text,
                          letterSpacing: -0.07, height: 1.45,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write a caption…',
                          hintStyle: manrope(
                            size: 14, weight: FontWeight.w500, color: c.fade,
                            letterSpacing: -0.07,
                          ),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                  ]),
                ),

                // ── Post-to (Fun / Learn) cards ──────────────
                if (widget.kind == CpKind.video)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.bg,
                      border: Border(bottom: BorderSide(color: c.border)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _SectionLabel(text: 'POST TO', color: c.sub),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _SectionCard(
                            dark: widget.dark, title: 'Fun', subtitle: 'Casual & playful',
                            active: _section == CpVideoSection.fun,
                            onTap: () => setState(() => _section = CpVideoSection.fun),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SectionCard(
                            dark: widget.dark, title: 'Learn', subtitle: 'Tutorials & how-tos',
                            active: _section == CpVideoSection.learn,
                            onTap: () => setState(() => _section = CpVideoSection.learn),
                          ),
                        ),
                      ]),
                    ]),
                  ),

                // ── option rows ───────────────────────────────
                _OptionRow(dark: widget.dark, icon: Icons.person_outline,    label: 'Tag people',
                    value: '@maya, @studio.atelier'),
                _OptionRow(dark: widget.dark, icon: Icons.location_on_outlined, label: 'Add location',
                    value: 'Lisbon, PT'),
                _OptionRow(dark: widget.dark, icon: Icons.music_note_outlined, label: 'Add music',
                    value: widget.kind == CpKind.video ? 'original sound' : 'None'),
                _OptionRow(
                  dark: widget.dark, icon: Icons.public, label: 'Audience',
                  value: _audience,
                  onTap: () => setState(() => _audience = _audience == 'Everyone' ? 'Close friends' : 'Everyone'),
                ),

                // ── toggles ───────────────────────────────────
                Container(
                  color: c.bg,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  child: Column(children: [
                    _ToggleRow(dark: widget.dark, label: 'Also share to your story',  value: _toggleShareStory,
                        onChange: (v) => setState(() => _toggleShareStory = v), divider: true),
                    _ToggleRow(dark: widget.dark, label: 'Hide like and view counts', value: _toggleHideCounts,
                        onChange: (v) => setState(() => _toggleHideCounts = v), divider: true),
                    _ToggleRow(dark: widget.dark, label: 'Turn off commenting',       value: _toggleCommentsOff,
                        onChange: (v) => setState(() => _toggleCommentsOff = v), divider: false),
                  ]),
                ),

                // ── Share CTA ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  child: SizedBox(
                    height: 50,
                    child: Material(
                      color: c.text,
                      borderRadius: BorderRadius.circular(14),
                      elevation: widget.dark ? 0 : 6,
                      shadowColor: const Color(0xFF14161E).withOpacity(0.18),
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CreatePostUploadingScreen(dark: widget.dark)),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: Text('Share'.tr(context),
                              style: manrope(
                                size: 15, weight: FontWeight.w800,
                                color: c.accentOn, letterSpacing: -0.15,
                              )),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool dark;
  final String title, subtitle;
  final bool active;
  final VoidCallback onTap;
  const _SectionCard({
    required this.dark, required this.title, required this.subtitle,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? c.text
              : (dark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6)),
          border: Border.all(color: active ? c.text : c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.tr(context),
              style: manrope(
                size: 14, weight: FontWeight.w800,
                color: active ? c.accentOn : c.text, letterSpacing: -0.14,
              )),
          const SizedBox(height: 2),
          Text(subtitle.tr(context),
              style: manrope(
                size: 11.5, weight: FontWeight.w500,
                color: active ? c.accentOn.withOpacity(0.75) : c.sub,
                letterSpacing: -0.06,
              )),
        ]),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _OptionRow({
    required this.dark, required this.icon, required this.label,
    required this.value, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: dark ? Colors.white.withOpacity(0.05) : const Color(0xFF161618).withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: c.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label.tr(context),
                style: manrope(size: 14, weight: FontWeight.w700, color: c.text, letterSpacing: -0.07)),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: manrope(size: 12.5, weight: FontWeight.w500, color: c.sub, letterSpacing: -0.06)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: c.fade),
        ]),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final bool dark;
  final String label;
  final bool value;
  final ValueChanged<bool> onChange;
  final bool divider;
  const _ToggleRow({
    required this.dark, required this.label, required this.value,
    required this.onChange, required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: c.border)) : null,
      ),
      child: Row(children: [
        Expanded(
          child: Text(label.tr(context),
              style: manrope(size: 14, weight: FontWeight.w600, color: c.text, letterSpacing: -0.07)),
        ),
        GestureDetector(
          onTap: () => onChange(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40, height: 22,
            decoration: BoxDecoration(
              color: value
                  ? c.text
                  : (dark ? Colors.white.withOpacity(0.12) : const Color(0xFF161618).withOpacity(0.12)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? c.accentOn : Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 3, offset: const Offset(0, 1))],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 4. UPLOADING screen — progress ring + step list
// ═══════════════════════════════════════════════════════════════
class CreatePostUploadingScreen extends StatefulWidget {
  final bool dark;
  const CreatePostUploadingScreen({super.key, this.dark = false});

  @override
  State<CreatePostUploadingScreen> createState() => _CreatePostUploadingScreenState();
}

class _CreatePostUploadingScreenState extends State<CreatePostUploadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    // After 6s, auto-navigate to success (demo flow).
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CreatePostSuccessScreen(dark: widget.dark)),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _CpTopBar(
            dark: widget.dark,
            left: _cpIconBtn(dark: widget.dark, icon: Icons.close, onTap: () => Navigator.maybePop(context)),
            title: 'Uploading',
            rightLabel: '',
            rightActive: false,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── progress ring + thumb ────────────────────
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      // animate progress 18..96..18 in sync with controller cycle
                      final t = _ctrl.value; // 0..1
                      final p = 18 + (78 * (1 - (t * 2 - 1).abs())); // ping-pong
                      return SizedBox(
                        width: 160, height: 160,
                        child: Stack(alignment: Alignment.center, children: [
                          SizedBox.expand(
                            child: CustomPaint(
                              painter: _RingPainter(progress: p / 100, base: c.border, track: c.text),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: monoTile(widget.dark, 1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.play_arrow, size: 28, color: Colors.white.withOpacity(0.85)),
                          ),
                        ]),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Text('Posting your video...'.tr(context),
                      style: manrope(size: 22, weight: FontWeight.w800, color: c.text, letterSpacing: -0.44)),
                  const SizedBox(height: 6),
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      final t = _ctrl.value;
                      final p = (18 + (78 * (1 - (t * 2 - 1).abs()))).round();
                      return Text('$p% · about 12 seconds left',
                          style: manrope(
                            size: 13, weight: FontWeight.w500, color: c.sub, letterSpacing: -0.06,
                          ));
                    },
                  ),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(children: [
                      _StepRow(dark: widget.dark, label: 'Compressing', done: true,  active: false),
                      const SizedBox(height: 10),
                      _StepRow(dark: widget.dark, label: 'Uploading',   done: false, active: true),
                      const SizedBox(height: 10),
                      _StepRow(dark: widget.dark, label: 'Publishing',  done: false, active: false),
                    ]),
                  ),
                  const SizedBox(height: 36),
                  OutlinedButton(
                    onPressed: () => Navigator.maybePop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    ),
                    child: Text('Cancel upload'.tr(context),
                        style: manrope(size: 13, weight: FontWeight.w700, color: c.text, letterSpacing: -0.06)),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color base, track;
  _RingPainter({required this.progress, required this.base, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final basePaint = Paint()..color = base..strokeWidth = 4..style = PaintingStyle.stroke;
    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      trackPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.base != base || old.track != track;
}

class _StepRow extends StatefulWidget {
  final bool dark;
  final String label;
  final bool done;
  final bool active;
  const _StepRow({required this.dark, required this.label, required this.done, required this.active});

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    final activeOrDone = widget.done || widget.active;
    return Row(children: [
      Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.done ? c.text : Colors.transparent,
          border: Border.all(color: activeOrDone ? c.text : c.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: widget.done
            ? Icon(Icons.check, size: 11, color: c.accentOn)
            : widget.active
                ? FadeTransition(
                    opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
                    child: ScaleTransition(
                      scale: Tween(begin: 0.6, end: 1.0).animate(_pulse),
                      child: Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c.text),
                      ),
                    ),
                  )
                : null,
      ),
      const SizedBox(width: 10),
      Text(widget.label.tr(context),
          style: manrope(
            size: 13.5, weight: FontWeight.w600,
            color: activeOrDone ? c.text : c.fade, letterSpacing: -0.06,
          )),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// 5. SUCCESS screen
// ═══════════════════════════════════════════════════════════════
class CreatePostSuccessScreen extends StatefulWidget {
  final bool dark;
  const CreatePostSuccessScreen({super.key, this.dark = false});

  @override
  State<CreatePostSuccessScreen> createState() => _CreatePostSuccessScreenState();
}

class _CreatePostSuccessScreenState extends State<CreatePostSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringA = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _ringB = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ringB.repeat();
    });
  }

  @override
  void dispose() {
    _ringA.dispose();
    _ringB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _CpTopBar(
            dark: widget.dark,
            title: '',
            rightLabel: 'Done',
            rightActive: true,
            onRight: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
              child: Column(children: [
                const SizedBox(height: 24),
                SizedBox(
                  width: 132, height: 132,
                  child: Stack(alignment: Alignment.center, children: [
                    _PulseRing(ctrl: _ringA, border: c.border),
                    Padding(padding: const EdgeInsets.all(16),
                      child: _PulseRing(ctrl: _ringB, border: c.border)),
                    Container(
                      margin: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.text,
                        boxShadow: [
                          BoxShadow(
                            color: widget.dark ? Colors.white.withOpacity(0.12)
                                               : const Color(0xFF14161E).withOpacity(0.18),
                            blurRadius: widget.dark ? 32 : 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.check, size: 34, color: c.accentOn),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
                Text('Posted successfully'.tr(context),
                    style: manrope(size: 24, weight: FontWeight.w800, color: c.text, letterSpacing: -0.6)),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: manrope(
                      size: 13.5, weight: FontWeight.w500, color: c.sub,
                      letterSpacing: -0.06, height: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'Your video is now live in '.tr(context)),
                      TextSpan(
                        text: 'Learn'.tr(context),
                        style: manrope(
                          size: 13.5, weight: FontWeight.w800, color: c.text,
                          letterSpacing: -0.06, height: 1.5,
                        ),
                      ),
                      TextSpan(text: '. It may take a moment to appear in friends feeds.'.tr(context)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── preview card ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.dark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6),
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: monoTile(widget.dark, 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Icon(Icons.play_arrow, size: 18, color: Colors.white.withOpacity(0.9)),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('a 60-second crash course in kerning',
                            overflow: TextOverflow.ellipsis,
                            style: manrope(size: 13.5, weight: FontWeight.w700, color: c.text, letterSpacing: -0.06)),
                        const SizedBox(height: 2),
                        Text('Learn · 0:44 · just now',
                            style: manrope(size: 11.5, weight: FontWeight.w500, color: c.sub, letterSpacing: -0.06)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Share to story'.tr(context),
                            style: manrope(size: 13.5, weight: FontWeight.w800, color: c.text, letterSpacing: -0.06)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.text,
                          foregroundColor: c.accentOn,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('View post'.tr(context),
                            style: manrope(size: 13.5, weight: FontWeight.w800, color: c.accentOn, letterSpacing: -0.06)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Text('Create another'.tr(context),
                      style: manrope(size: 12.5, weight: FontWeight.w700, color: c.sub, letterSpacing: -0.06)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController ctrl;
  final Color border;
  const _PulseRing({required this.ctrl, required this.border});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        final scale = 0.85 + (0.4 * t);
        final opacity = (1 - t).clamp(0.0, 0.8);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}
