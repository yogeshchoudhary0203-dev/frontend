// create_post_screens.dart
// Real create-post flow:
//   Hub (gallery picker) → Edit (filters) → Details (caption) → Uploading → Success

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/coachmark_service.dart';
import '../services/media_upload_service.dart';
import '../services/post_service.dart';
import 'glass_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared palette helper
// ─────────────────────────────────────────────────────────────────────────────

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
    end: Alignment(math.cos(angle), math.sin(angle)),
    colors: [
      HSLColor.fromAHSL(1, 0, 0, a / 100).toColor(),
      HSLColor.fromAHSL(1, 0, 0, b / 100).toColor(),
    ],
  );
}

class CpColors {
  final bool dark;
  CpColors(this.dark);

  Color get bg => dark ? const Color(0xFF0A0A0C) : const Color(0xFFF4F2ED);
  Color get text => dark ? const Color(0xFFF3F3F4) : const Color(0xFF161618);
  Color get accentOn => dark ? const Color(0xFF0A0A0C) : Colors.white;
  Color get sub => (dark ? const Color(0xFFF3F3F4) : const Color(0xFF161618))
      .withValues(alpha: 0.58);
  Color get fade => (dark ? const Color(0xFFF3F3F4) : const Color(0xFF161618))
      .withValues(alpha: 0.35);
  Color get border => dark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF161618).withValues(alpha: 0.07);
  Color get pillBg => dark
      ? Colors.white.withValues(alpha: 0.05)
      : const Color(0xFF161618).withValues(alpha: 0.05);
  Color get surface =>
      dark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.6);
  Color get nextAction =>
      dark ? const Color(0xFF9ED7C5) : const Color(0xFF1F6A5A);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared top bar
// ─────────────────────────────────────────────────────────────────────────────

class _CpTopBar extends StatelessWidget {
  final bool dark;
  final Widget? left;
  final String title;
  final String rightLabel;
  final VoidCallback? onRight;

  const _CpTopBar({
    super.key,
    required this.dark,
    this.left,
    required this.title,
    this.rightLabel = 'Next',
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
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerLeft,
              child: left ?? const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title.tr(context),
                style: manrope(
                  size: 16,
                  weight: FontWeight.w700,
                  color: c.text,
                  letterSpacing: -0.16,
                ),
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
                      onTap: onRight,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          rightLabel.tr(context),
                          style: manrope(
                            size: 14,
                            weight: FontWeight.w800,
                            color: onRight != null ? c.nextAction : c.fade,
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

Widget _cpIconBtn({
  required bool dark,
  required IconData icon,
  VoidCallback? onTap,
}) {
  final c = CpColors(dark);
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 22, color: c.text),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. HUB — opens gallery picker immediately
// ─────────────────────────────────────────────────────────────────────────────

enum CpTab { photo, video }

class CreatePostHubScreen extends StatefulWidget {
  final bool dark;
  final CpTab initialTab;
  const CreatePostHubScreen({
    super.key,
    this.dark = false,
    this.initialTab = CpTab.photo,
  });

  @override
  State<CreatePostHubScreen> createState() => _CreatePostHubScreenState();
}

class _CreatePostHubScreenState extends State<CreatePostHubScreen> {
  String? _error;
  // True once the user taps a source option — prevents the sheet's .then
  // callback from popping the screen before the async picker finishes.
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSourceSelector());
  }

  Future<void> _showSourceSelector() async {
    _picking = false;
    final c = CpColors(widget.dark);
    final dark = widget.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: dark ? const Color(0xFF1C1C1F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Create a Post',
                style: manrope(
                  size: 16,
                  weight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 20),
              _sourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo (Camera)',
                onTap: () {
                  _picking = true;
                  Navigator.pop(ctx);
                  _pickFile(ImageSource.camera, isVideo: false);
                },
              ),
              const SizedBox(height: 10),
              _sourceTile(
                icon: Icons.videocam_rounded,
                label: 'Record Video (Camera)',
                onTap: () {
                  _picking = true;
                  Navigator.pop(ctx);
                  _pickFile(ImageSource.camera, isVideo: true);
                },
              ),
              const SizedBox(height: 10),
              _sourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                onTap: () {
                  _picking = true;
                  Navigator.pop(ctx);
                  _pickGallery();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Only auto-pop if user swiped the sheet away without selecting anything
      if (mounted && _error == null && !_picking) {
        Navigator.maybePop(context);
      }
    });
  }

  Widget _sourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final dark = widget.dark;
    final c = CpColors(dark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: dark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c.text),
            const SizedBox(width: 14),
            Text(
              label,
              style: manrope(size: 15, weight: FontWeight.w600, color: c.text),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile(ImageSource source, {required bool isVideo}) async {
    setState(() => _error = null);
    try {
      final picker = ImagePicker();
      final XFile? file = isVideo
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source, imageQuality: 85);
      if (!mounted) return;
      if (file == null) {
        _showSourceSelector();
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CreatePostEditScreen(
            dark: widget.dark,
            file: file,
            isVideo: isVideo,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Could not access camera/media. Please try again.',
      );
    }
  }

  Future<void> _pickGallery() async {
    setState(() => _error = null);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickMedia();
      if (!mounted) return;
      if (file == null) {
        _showSourceSelector();
        return;
      }
      final isVideo =
          file.mimeType?.startsWith('video') == true ||
          file.path.toLowerCase().endsWith('.mp4') ||
          file.path.toLowerCase().endsWith('.mov') ||
          file.path.toLowerCase().endsWith('.avi') ||
          file.path.toLowerCase().endsWith('.webm');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CreatePostEditScreen(
            dark: widget.dark,
            file: file,
            isVideo: isVideo,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open gallery. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _CpTopBar(
              dark: widget.dark,
              left: _cpIconBtn(
                dark: widget.dark,
                icon: Icons.close,
                onTap: () => Navigator.maybePop(context),
              ),
              title: 'New post',
              rightLabel: '',
            ),
            Expanded(
              child: Center(
                child: _error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: manrope(
                              size: 14,
                              weight: FontWeight.w500,
                              color: c.sub,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _PillBtn(
                            dark: widget.dark,
                            label: 'Try Again',
                            onTap: _showSourceSelector,
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Choose a source…',
                            style: manrope(
                              size: 14,
                              weight: FontWeight.w500,
                              color: c.sub,
                            ),
                          ),
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
// 2. EDIT — filter + crop UI, shows actual picked file
// ─────────────────────────────────────────────────────────────────────────────

enum CpEditTool { crop, filter, adjust, trim }

const _kFilterNames = [
  'Original',
  'Matte',
  'Ivory',
  'Slate',
  'Noir',
  'Mist',
  'Sepia',
  'Cool',
];

class CreatePostEditScreen extends StatefulWidget {
  final bool dark;
  final XFile file;
  final bool isVideo;
  final CpVideoSection initialSection;

  const CreatePostEditScreen({
    super.key,
    this.dark = false,
    required this.file,
    required this.isVideo,
    this.initialSection = CpVideoSection.fun,
  });

  @override
  State<CreatePostEditScreen> createState() => _CreatePostEditScreenState();
}

class _CreatePostEditScreenState extends State<CreatePostEditScreen> {
  CpEditTool _tool = CpEditTool.filter;
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CpTopBar(
              dark: widget.dark,
              left: _cpIconBtn(
                dark: widget.dark,
                icon: Icons.arrow_back,
                onTap: () => Navigator.maybePop(context),
              ),
              title: 'Edit',
              rightLabel: 'Next',
              onRight: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreatePostDetailsScreen(
                    dark: widget.dark,
                    file: widget.file,
                    isVideo: widget.isVideo,
                    selectedFilter: _filter,
                    initialSection: widget.initialSection,
                  ),
                ),
              ),
            ),

            // ── PREVIEW ────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: _filterMatrix(_filter),
                    child: widget.isVideo
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: monoTile(widget.dark, 1),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.videocam_outlined,
                                size: 60,
                                color: Colors.white54,
                              ),
                            ),
                          )
                        : Image.file(
                            File(widget.file.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: monoTile(widget.dark, 1),
                              ),
                            ),
                          ),
                  ),
                  if (_tool == CpEditTool.crop) const _CropGrid(),
                ],
              ),
            ),

            // ── TOOL PANEL ─────────────────────────────────────
            Expanded(
              flex: 3,
              child: Container(
                color: c.bg,
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                child: _toolPanel(c),
              ),
            ),

            // ── BOTTOM DOCK ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.border)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ToolBtn(
                    dark: widget.dark,
                    icon: Icons.crop_free,
                    label: 'Crop',
                    active: _tool == CpEditTool.crop,
                    onTap: () => setState(() => _tool = CpEditTool.crop),
                  ),
                  _ToolBtn(
                    dark: widget.dark,
                    icon: Icons.filter_vintage,
                    label: 'Filter',
                    active: _tool == CpEditTool.filter,
                    onTap: () => setState(() => _tool = CpEditTool.filter),
                  ),
                  _ToolBtn(
                    dark: widget.dark,
                    icon: Icons.tune,
                    label: 'Adjust',
                    active: _tool == CpEditTool.adjust,
                    onTap: () => setState(() => _tool = CpEditTool.adjust),
                  ),
                  if (widget.isVideo)
                    _ToolBtn(
                      dark: widget.dark,
                      icon: Icons.content_cut,
                      label: 'Trim',
                      active: _tool == CpEditTool.trim,
                      onTap: () => setState(() => _tool = CpEditTool.trim),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolPanel(CpColors c) {
    switch (_tool) {
      case CpEditTool.filter:
        return _FilterPanel(
          dark: widget.dark,
          selected: _filter,
          onSelect: (i) => setState(() => _filter = i),
          previewFile: widget.file,
          isVideo: widget.isVideo,
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

// ─────────────────────────────────────────────────────────────────────────────
// 3. DETAILS — caption + settings
// ─────────────────────────────────────────────────────────────────────────────

enum CpVideoSection { fun, learn }

class CreatePostDetailsScreen extends StatefulWidget {
  final bool dark;
  final XFile file;
  final bool isVideo;
  final int selectedFilter;
  final CpVideoSection initialSection;

  const CreatePostDetailsScreen({
    super.key,
    this.dark = false,
    required this.file,
    required this.isVideo,
    this.selectedFilter = 0,
    this.initialSection = CpVideoSection.fun,
  });

  @override
  State<CreatePostDetailsScreen> createState() =>
      _CreatePostDetailsScreenState();
}

class _CreatePostDetailsScreenState extends State<CreatePostDetailsScreen> {
  static const List<String> _learnTopicSuggestions = [
    'Maths',
    'Science',
    'English',
    'History',
    'Commerce',
    'Coding',
    'UPSC',
    'JEE',
    'NEET',
  ];

  late final TextEditingController _caption = TextEditingController();
  late final TextEditingController _learnTopic = TextEditingController();
  late CpVideoSection _section;
  String _audience = 'Everyone';
  final GlobalKey _coachShareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CoachmarkService.showTour(
        context,
        tourId: 'create_share_v1',
        isDark: widget.dark,
        steps: [
          CoachStep(
            key: _coachShareKey,
            title: 'Almost done',
            body: 'Add a caption (and a topic for Learn videos), then tap Share '
                'to publish your post.',
            align: ContentAlign.bottom,
            radius: 14,
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    _learnTopic.dispose();
    super.dispose();
  }

  String? get _learnTopicPayload {
    if (!widget.isVideo || _section != CpVideoSection.learn) return null;
    final value = _learnTopic.text.trim();
    return value.isEmpty ? null : value;
  }

  void _selectLearnTopic(String topic) {
    setState(() {
      _learnTopic.text = topic;
      _learnTopic.selection = TextSelection.collapsed(offset: topic.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CpTopBar(
              key: _coachShareKey,
              dark: widget.dark,
              left: _cpIconBtn(
                dark: widget.dark,
                icon: Icons.arrow_back,
                onTap: () => Navigator.maybePop(context),
              ),
              title: 'New post',
              rightLabel: 'Share',
              onRight: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreatePostUploadingScreen(
                    dark: widget.dark,
                    file: widget.file,
                    isVideo: widget.isVideo,
                    caption: _caption.text.trim(),
                    section: widget.isVideo
                        ? (_section == CpVideoSection.fun ? 'fun' : 'learn')
                        : null,
                    learnTopic: _learnTopicPayload,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Media thumbnail + caption ─────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.bg,
                      border: Border(bottom: BorderSide(color: c.border)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: widget.isVideo
                                ? Container(
                                    decoration: BoxDecoration(
                                      gradient: monoTile(widget.dark, 1),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  )
                                : Image.file(
                                    File(widget.file.path),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _caption,
                            maxLines: 4,
                            maxLength: 2000,
                            style: manrope(
                              size: 14,
                              weight: FontWeight.w500,
                              color: c.text,
                              letterSpacing: -0.07,
                              height: 1.45,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Write a caption…',
                              hintStyle: manrope(
                                size: 14,
                                weight: FontWeight.w500,
                                color: c.fade,
                                letterSpacing: -0.07,
                              ),
                              border: InputBorder.none,
                              counterStyle: manrope(
                                size: 11,
                                weight: FontWeight.w500,
                                color: c.fade,
                              ),
                              isCollapsed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Post-to section (videos only) ─────────────
                  if (widget.isVideo)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.bg,
                        border: Border(bottom: BorderSide(color: c.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(text: 'POST TO', color: c.sub),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _SectionCard(
                                  dark: widget.dark,
                                  title: 'Fun',
                                  subtitle: 'Casual & playful',
                                  active: _section == CpVideoSection.fun,
                                  onTap: () => setState(
                                    () => _section = CpVideoSection.fun,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _SectionCard(
                                  dark: widget.dark,
                                  title: 'Learn',
                                  subtitle: 'Tutorials & how-tos',
                                  active: _section == CpVideoSection.learn,
                                  onTap: () => setState(
                                    () => _section = CpVideoSection.learn,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  if (widget.isVideo && _section == CpVideoSection.learn)
                    _LearnTopicPicker(
                      dark: widget.dark,
                      controller: _learnTopic,
                      suggestions: _learnTopicSuggestions,
                      onSuggestionTap: _selectLearnTopic,
                      onChanged: (_) => setState(() {}),
                    ),

                  _OptionRow(
                    dark: widget.dark,
                    icon: Icons.public,
                    label: 'Audience',
                    value: _audience,
                    onTap: () => setState(
                      () => _audience = _audience == 'Everyone'
                          ? 'Close friends'
                          : 'Everyone',
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
                    child: SizedBox(
                      height: 50,
                      child: Material(
                        color: c.text,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CreatePostUploadingScreen(
                                dark: widget.dark,
                                file: widget.file,
                                isVideo: widget.isVideo,
                                caption: _caption.text.trim(),
                                section: widget.isVideo
                                    ? (_section == CpVideoSection.fun
                                          ? 'fun'
                                          : 'learn')
                                    : null,
                                learnTopic: _learnTopicPayload,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: Center(
                            child: Text(
                              'Share'.tr(context),
                              style: manrope(
                                size: 15,
                                weight: FontWeight.w800,
                                color: c.accentOn,
                                letterSpacing: -0.15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
// 4. UPLOADING — real upload to Cloudinary + create post in backend
// ─────────────────────────────────────────────────────────────────────────────

class CreatePostUploadingScreen extends StatefulWidget {
  final bool dark;
  final XFile file;
  final bool isVideo;
  final String caption;
  final String? section;
  final String? learnTopic;

  const CreatePostUploadingScreen({
    super.key,
    this.dark = false,
    required this.file,
    required this.isVideo,
    required this.caption,
    this.section,
    this.learnTopic,
  });

  @override
  State<CreatePostUploadingScreen> createState() =>
      _CreatePostUploadingScreenState();
}

class _CreatePostUploadingScreenState extends State<CreatePostUploadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  double _progress = 0.0;
  bool _compressDone = false;
  bool _uploadDone = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _startUpload();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    try {
      setState(() {
        _progress = 0.1;
        _compressDone = true;
      });

      final file = File(widget.file.path);
      final uploader = MediaUploadService.instance;

      MediaUploadResult result;
      if (widget.isVideo) {
        result = await uploader.uploadVideo(
          file,
          folder: MediaFolder.posts,
          onProgress: (p) {
            if (mounted) setState(() => _progress = 0.1 + p * 0.75);
          },
        );
      } else {
        result = await uploader.uploadImage(
          file,
          folder: MediaFolder.posts,
          onProgress: (p) {
            if (mounted) setState(() => _progress = 0.1 + p * 0.75);
          },
        );
      }

      if (!mounted) return;
      setState(() {
        _progress = 0.88;
        _uploadDone = true;
      });

      // Compute aspect ratio from file (default 1:1 if unavailable)
      double aspectRatio = 1.0;
      if (result.width != null && result.height != null && result.height! > 0) {
        aspectRatio = result.width! / result.height!;
      }

      await PostService.instance.createPost(
        mediaUrl: result.url,
        thumbnailUrl: result.thumbnailUrl,
        publicId: result.publicId,
        mediaType: widget.isVideo ? 'video' : 'image',
        caption: widget.caption,
        aspectRatio: aspectRatio,
        section: widget.section,
        learnTopic: widget.learnTopic,
      );

      if (!mounted) return;
      setState(() => _progress = 1.0);

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CreatePostSuccessScreen(dark: widget.dark),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMsg =
            'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CpColors(widget.dark);

    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              _CpTopBar(
                dark: widget.dark,
                title: 'Upload Failed',
                rightLabel: '',
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: c.text.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMsg!,
                        textAlign: TextAlign.center,
                        style: manrope(
                          size: 14,
                          weight: FontWeight.w500,
                          color: c.sub,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _PillBtn(
                        dark: widget.dark,
                        label: 'Go Back',
                        onTap: () => Navigator.maybePop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CpTopBar(dark: widget.dark, title: 'Uploading', rightLabel: ''),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CustomPaint(
                              painter: _RingPainter(
                                progress: _progress,
                                base: c.border,
                                track: c.text,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: monoTile(widget.dark, 1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: widget.isVideo
                                  ? const Icon(
                                      Icons.videocam,
                                      size: 40,
                                      color: Colors.white70,
                                    )
                                  : Image.file(
                                      File(widget.file.path),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      (widget.isVideo
                              ? 'Posting your video…'
                              : 'Posting your photo…')
                          .tr(context),
                      style: manrope(
                        size: 22,
                        weight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: -0.44,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(_progress * 100).round()}%',
                      style: manrope(
                        size: 13,
                        weight: FontWeight.w500,
                        color: c.sub,
                        letterSpacing: -0.06,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        children: [
                          _StepRow(
                            dark: widget.dark,
                            label: 'Compressing',
                            done: _compressDone,
                            active: !_compressDone,
                          ),
                          const SizedBox(height: 10),
                          _StepRow(
                            dark: widget.dark,
                            label: 'Uploading',
                            done: _uploadDone,
                            active: _compressDone && !_uploadDone,
                          ),
                          const SizedBox(height: 10),
                          _StepRow(
                            dark: widget.dark,
                            label: 'Publishing',
                            done: _progress >= 1.0,
                            active: _uploadDone && _progress < 1.0,
                          ),
                        ],
                      ),
                    ),
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
// 5. SUCCESS
// ─────────────────────────────────────────────────────────────────────────────

class CreatePostSuccessScreen extends StatefulWidget {
  final bool dark;
  const CreatePostSuccessScreen({super.key, this.dark = false});

  @override
  State<CreatePostSuccessScreen> createState() =>
      _CreatePostSuccessScreenState();
}

class _CreatePostSuccessScreenState extends State<CreatePostSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringA = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _ringB = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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
        child: Column(
          children: [
            _CpTopBar(
              dark: widget.dark,
              title: '',
              rightLabel: 'Done',
              onRight: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _PulseRing(ctrl: _ringA, border: c.border),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _PulseRing(ctrl: _ringB, border: c.border),
                          ),
                          Container(
                            margin: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.text,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.dark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : const Color(
                                          0xFF14161E,
                                        ).withValues(alpha: 0.18),
                                  blurRadius: widget.dark ? 32 : 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.check,
                              size: 34,
                              color: c.accentOn,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Posted successfully'.tr(context),
                      style: manrope(
                        size: 24,
                        weight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your post is now live and will appear in the feed.'.tr(
                        context,
                      ),
                      textAlign: TextAlign.center,
                      style: manrope(
                        size: 13.5,
                        weight: FontWeight.w500,
                        color: c.sub,
                        letterSpacing: -0.06,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).popUntil((r) => r.isFirst),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.text,
                                foregroundColor: c.accentOn,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'View Feed'.tr(context),
                                style: manrope(
                                  size: 13.5,
                                  weight: FontWeight.w800,
                                  color: c.accentOn,
                                  letterSpacing: -0.06,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        Future.microtask(
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreatePostHubScreen(dark: widget.dark),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Post another'.tr(context),
                        style: manrope(
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: c.sub,
                          letterSpacing: -0.06,
                        ),
                      ),
                    ),
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
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PillBtn extends StatelessWidget {
  final bool dark;
  final String label;
  final VoidCallback onTap;
  const _PillBtn({
    required this.dark,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: c.text,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: manrope(size: 14, weight: FontWeight.w700, color: c.accentOn),
        ),
      ),
    );
  }
}

class _CropGrid extends StatelessWidget {
  const _CropGrid();
  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _CropGridPainter()));
}

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final outer = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset(w / 3, 0), Offset(w / 3, h), line);
    canvas.drawLine(Offset(2 * w / 3, 0), Offset(2 * w / 3, h), line);
    canvas.drawLine(Offset(0, h / 3), Offset(w, h / 3), line);
    canvas.drawLine(Offset(0, 2 * h / 3), Offset(w, 2 * h / 3), line);
    canvas.drawRect(Rect.fromLTWH(2, 2, w - 4, h - 4), outer);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _FilterPanel extends StatelessWidget {
  final bool dark;
  final int selected;
  final ValueChanged<int> onSelect;
  final XFile previewFile;
  final bool isVideo;
  const _FilterPanel({
    required this.dark,
    required this.selected,
    required this.onSelect,
    required this.previewFile,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? c.text : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ColorFiltered(
                          colorFilter: _filterMatrix(i),
                          child: isVideo
                              ? Container(
                                  decoration: BoxDecoration(
                                    gradient: monoTile(dark, i + 1),
                                  ),
                                )
                              : Image.file(
                                  File(previewFile.path),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _kFilterNames[i],
                      style: manrope(
                        size: 11,
                        weight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? c.text : c.sub,
                        letterSpacing: -0.06,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

ColorFilter _filterMatrix(int idx) {
  switch (idx) {
    case 1:
      return const ColorFilter.matrix([
        1.05,
        0,
        0,
        0,
        4,
        0,
        1.05,
        0,
        0,
        4,
        0,
        0,
        1.05,
        0,
        4,
        0,
        0,
        0,
        1,
        0,
      ]);
    case 2:
      return const ColorFilter.matrix([
        0.45,
        0.45,
        0.10,
        0,
        18,
        0.30,
        0.55,
        0.10,
        0,
        12,
        0.25,
        0.40,
        0.30,
        0,
        8,
        0,
        0,
        0,
        1,
        0,
      ]);
    case 3:
      return const ColorFilter.matrix([
        0.85,
        0.05,
        0.05,
        0,
        0,
        0.05,
        0.85,
        0.05,
        0,
        0,
        0.05,
        0.05,
        0.85,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    case 4:
      return const ColorFilter.matrix([
        0.33,
        0.59,
        0.11,
        0,
        -10,
        0.33,
        0.59,
        0.11,
        0,
        -10,
        0.33,
        0.59,
        0.11,
        0,
        -10,
        0,
        0,
        0,
        1,
        0,
      ]);
    case 5:
      return const ColorFilter.matrix([
        0.92,
        0.04,
        0.04,
        0,
        16,
        0.04,
        0.92,
        0.04,
        0,
        16,
        0.04,
        0.04,
        0.92,
        0,
        16,
        0,
        0,
        0,
        1,
        0,
      ]);
    case 6:
      return const ColorFilter.matrix([
        0.55,
        0.55,
        0.10,
        0,
        16,
        0.30,
        0.60,
        0.10,
        0,
        10,
        0.20,
        0.30,
        0.30,
        0,
        4,
        0,
        0,
        0,
        1,
        0,
      ]);
    case 7:
      return const ColorFilter.matrix([
        0.85,
        0,
        0.10,
        0,
        -2,
        0,
        0.95,
        0.10,
        0,
        4,
        0.10,
        0.05,
        1.05,
        0,
        8,
        0,
        0,
        0,
        1,
        0,
      ]);
    default:
      return const ColorFilter.matrix([
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
  }
}

class _AdjustPanel extends StatelessWidget {
  final bool dark;
  const _AdjustPanel({required this.dark});
  static const _rows = [
    ['Brightness', 12],
    ['Contrast', -4],
    ['Warmth', 8],
    ['Saturation', 0],
    ['Highlights', -10],
    ['Shadows', 6],
  ];
  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(text: 'ADJUST', color: c.sub),
          const SizedBox(height: 14),
          for (final r in _rows)
            _AdjustSlider(
              dark: dark,
              label: r[0] as String,
              value: r[1] as int,
            ),
        ],
      ),
    );
  }
}

class _AdjustSlider extends StatelessWidget {
  final bool dark;
  final String label;
  final int value;
  const _AdjustSlider({
    required this.dark,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.tr(context),
                style: manrope(
                  size: 12,
                  weight: FontWeight.w600,
                  color: c.text,
                  letterSpacing: -0.06,
                ),
              ),
              const Spacer(),
              Text(
                value > 0 ? '+$value' : '$value',
                style: manrope(
                  size: 12,
                  weight: FontWeight.w600,
                  color: c.sub,
                  letterSpacing: -0.06,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (_, cs) {
              final w = cs.maxWidth;
              final half = w / 2;
              final dx = (value * 2 / 100) * w;
              final thumbX = half + dx - 7;
              final fillW = (dx.abs()).clamp(0.0, half);
              return SizedBox(
                height: 18,
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: value < 0 ? half - fillW : half,
                      width: fillW,
                      height: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.text,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: thumbX,
                      top: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.text,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'ASPECT RATIO', color: c.sub),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final r in ratios)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: r == active ? c.text : Colors.transparent,
                  border: Border.all(color: r == active ? c.text : c.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  r,
                  style: manrope(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: r == active ? c.accentOn : c.text,
                    letterSpacing: -0.06,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrimPanel extends StatelessWidget {
  final bool dark;
  const _TrimPanel({required this.dark});
  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'TRIM', color: c.sub),
        const SizedBox(height: 12),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white.withValues(alpha: 0.5),
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              'Trim available after upload',
              style: manrope(size: 12, weight: FontWeight.w500, color: c.sub),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToolBtn({
    required this.dark,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: active ? c.text : c.sub),
            const SizedBox(height: 5),
            Text(
              label.tr(context),
              style: manrope(
                size: 10.5,
                weight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? c.text : c.sub,
                letterSpacing: -0.05,
              ),
            ),
          ],
        ),
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
    style: manrope(
      size: 11,
      weight: FontWeight.w700,
      color: color,
      letterSpacing: 1.7,
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final bool dark;
  final String title, subtitle;
  final bool active;
  final VoidCallback onTap;
  const _SectionCard({
    required this.dark,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
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
              : (dark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.6)),
          border: Border.all(color: active ? c.text : c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.tr(context),
              style: manrope(
                size: 14,
                weight: FontWeight.w800,
                color: active ? c.accentOn : c.text,
                letterSpacing: -0.14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle.tr(context),
              style: manrope(
                size: 11.5,
                weight: FontWeight.w500,
                color: active ? c.accentOn.withValues(alpha: 0.75) : c.sub,
                letterSpacing: -0.06,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnTopicPicker extends StatelessWidget {
  final bool dark;
  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<String> onChanged;

  const _LearnTopicPicker({
    required this.dark,
    required this.controller,
    required this.suggestions,
    required this.onSuggestionTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    final selected = controller.text.trim().toLowerCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(text: 'SUBJECT / TOPIC', color: c.sub),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLength: 48,
            textInputAction: TextInputAction.done,
            style: manrope(
              size: 14,
              weight: FontWeight.w700,
              color: c.text,
              letterSpacing: -0.07,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Physics, UPSC, Coding',
              hintStyle: manrope(
                size: 13,
                weight: FontWeight.w500,
                color: c.fade,
                letterSpacing: -0.06,
              ),
              counterText: '',
              prefixIcon: Icon(Icons.school_outlined, size: 18, color: c.sub),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.text.withValues(alpha: 0.55)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((topic) {
              final active = selected == topic.toLowerCase();
              return _TopicChip(
                dark: dark,
                label: topic,
                active: active,
                onTap: () => onSuggestionTap(topic),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final bool dark;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TopicChip({
    required this.dark,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = CpColors(dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.text : c.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? c.text : c.border),
        ),
        child: Text(
          label,
          style: manrope(
            size: 12,
            weight: FontWeight.w800,
            color: active ? c.accentOn : c.text,
            letterSpacing: -0.06,
          ),
        ),
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
    required this.dark,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
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
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFF161618).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: c.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.tr(context),
                style: manrope(
                  size: 14,
                  weight: FontWeight.w700,
                  color: c.text,
                  letterSpacing: -0.07,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: manrope(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: c.sub,
                  letterSpacing: -0.06,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: c.fade),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color base, track;
  _RingPainter({
    required this.progress,
    required this.base,
    required this.track,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = base
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      Paint()
        ..color = track
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class _StepRow extends StatefulWidget {
  final bool dark, done, active;
  final String label;
  const _StepRow({
    required this.dark,
    required this.label,
    required this.done,
    required this.active,
  });
  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
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
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.done ? c.text : Colors.transparent,
            border: Border.all(
              color: activeOrDone ? c.text : c.border,
              width: 1.5,
            ),
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
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.text,
                      ),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          widget.label.tr(context),
          style: manrope(
            size: 13.5,
            weight: FontWeight.w600,
            color: activeOrDone ? c.text : c.fade,
            letterSpacing: -0.06,
          ),
        ),
      ],
    );
  }
}

class _PulseRing extends StatelessWidget {
  final AnimationController ctrl;
  final Color border;
  const _PulseRing({required this.ctrl, required this.border});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ctrl,
    builder: (_, __) => Opacity(
      opacity: (1 - ctrl.value).clamp(0.0, 0.8),
      child: Transform.scale(
        scale: 0.85 + (0.4 * ctrl.value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}
