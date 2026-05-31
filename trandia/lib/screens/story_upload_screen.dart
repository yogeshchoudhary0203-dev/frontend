import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'glass_common.dart';
import '../services/api_service.dart';
import '../services/media_upload_service.dart';
import '../services/story_service.dart';

class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  File?   _image;
  int     _durationHours = 24;
  bool    _uploading     = false;
  double  _progress      = 0;
  String? _error;
  // Tracks if a picker source was selected — prevents premature screen pop
  bool    _pickerOpened  = false;

  bool get _isDark =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  @override
  void initState() {
    super.initState();
    // Auto-open picker selection on first load
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPhotoPickerOptions());
  }

  Future<void> _showPhotoPickerOptions() async {
    HapticFeedback.lightImpact();
    final dark = _isDark;
    _pickerOpened = false;

    await showModalBottomSheet<void>(
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
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Add to Story',
                style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: GlassTokens.fg(dark),
                ),
              ),
              const SizedBox(height: 20),
              _optionTile(
                dark: dark,
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo (Camera)',
                onTap: () {
                  _pickerOpened = true;
                  Navigator.pop(ctx);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _optionTile(
                dark: dark,
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                onTap: () {
                  _pickerOpened = true;
                  Navigator.pop(ctx);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    // Pop screen only if user dismissed the sheet WITHOUT selecting a source
    if (!_pickerOpened && _image == null && mounted) {
      Navigator.maybePop(context);
    }
  }

  Widget _optionTile({
    required bool dark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: dark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: GlassTokens.fg(dark)),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: GlassTokens.fg(dark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    HapticFeedback.lightImpact();
    try {
      final picked = await ImagePicker().pickImage(
        source:       source,
        maxWidth:     1080,
        maxHeight:    1920,
        imageQuality: 92,
      );
      if (picked == null) {
        // User cancelled the picker — pop only if no image was already selected
        if (_image == null && mounted) Navigator.maybePop(context);
        return;
      }
      if (!mounted) return;
      setState(() {
        _image = File(picked.path);
        _error = null;
      });
      await _showDurationPicker();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not access camera/gallery.');
    }
  }

  Future<void> _showDurationPicker() async {
    await showModalBottomSheet<void>(
      context:             context,
      backgroundColor:     Colors.transparent,
      isScrollControlled:  true,
      builder: (ctx) => _DurationSheet(
        selected: _durationHours,
        isDark:   _isDark,
        onSelect: (h) {
          setState(() => _durationHours = h);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _upload() async {
    if (_image == null || _uploading) return;
    HapticFeedback.mediumImpact();
    setState(() { _uploading = true; _error = null; _progress = 0; });

    try {
      final result = await MediaUploadService.instance.uploadImage(
        _image!,
        folder:     MediaFolder.stories,
        onProgress: (p) { if (mounted) setState(() => _progress = p); },
      );

      await StoryService.instance.create(
        mediaUrl:       result.url,
        publicId:       result.publicId,
        expiresInHours: _durationHours,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _uploading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _uploading = false; _error = 'Upload failed. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ───────────────────────────────────────────────────────
          if (_image != null)
            Image.file(_image!, fit: BoxFit.cover)
          else
            _EmptyState(onPick: _showPhotoPickerOptions),

          // ── Gradient overlays ─────────────────────────────────────────────
          if (_image != null) ...[
            _gradient(
              begin: Alignment.topCenter,
              end:   const Alignment(0, -0.4),
              color: Colors.black.withOpacity(0.60),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _gradient(
                begin: Alignment.bottomCenter,
                end:   Alignment.topCenter,
                color: Colors.black.withOpacity(0.72),
                height: 220,
              ),
            ),
          ],

          // ── Top bar ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                _IconBtn(
                  icon:  Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (_image != null)
                  GestureDetector(
                    onTap: _showDurationPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color:  Colors.black.withOpacity(0.40),
                        border: Border.all(color: Colors.white.withOpacity(0.30)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.access_time_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                            _durationHours < 24
                                ? '${_durationHours}h'
                                : '24h',
                            style: GoogleFonts.manrope(
                              color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),

          // ── Bottom actions ────────────────────────────────────────────────
          if (_image != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_error != null) ...[
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: Colors.redAccent, fontSize: 13)),
                      const SizedBox(height: 12),
                    ],
                    if (_uploading) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:      _progress,
                          minHeight:  3,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Sharing your story...',
                          style: GoogleFonts.manrope(
                            color: Colors.white70, fontSize: 13)),
                    ] else
                      Row(children: [
                        _OutlineBtn(label: 'Change', onTap: _showPhotoPickerOptions),
                        const SizedBox(width: 12),
                        _SolidBtn(label: 'Share Story', onTap: _upload),
                      ]),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradient({
    required Alignment begin,
    required Alignment end,
    required Color color,
    double? height,
  }) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin, end: end,
          colors: [color, Colors.transparent],
        ),
      ),
    );
    if (height != null) {
      return SizedBox(height: height, child: box);
    }
    return Positioned.fill(child: box);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptyState({required this.onPick});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black,
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:  Colors.white.withOpacity(0.07),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(Icons.add_photo_alternate_rounded,
                color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text('Add to your story',
            style: GoogleFonts.manrope(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Share a photo with your followers',
            style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.white,
            ),
            child: Text('Choose from Gallery',
                style: GoogleFonts.manrope(
                  color: Colors.black, fontSize: 15,
                  fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.42),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color:  Colors.white.withOpacity(0.12),
          border: Border.all(color: Colors.white.withOpacity(0.28)),
        ),
        child: Text(label,
            style: GoogleFonts.manrope(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

class _SolidBtn extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _SolidBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: 2,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.white,
        ),
        child: Text(label,
            style: GoogleFonts.manrope(
              color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Duration picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _DurationSheet extends StatelessWidget {
  final int               selected;
  final bool              isDark;
  final ValueChanged<int> onSelect;
  const _DurationSheet({
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  static const _options = [3, 6, 9, 12, 15, 18, 21, 24];

  static String _label(int h) => '${h}h';
  static String _sub(int h) {
    if (h <= 3)  return 'Quick';
    if (h <= 6)  return 'Short';
    if (h <= 9)  return 'Half day';
    if (h <= 12) return 'Half day';
    if (h <= 15) return '⅔ day';
    if (h <= 18) return '¾ day';
    if (h <= 21) return 'Almost';
    return 'Full day';
  }

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(isDark);
    final sub = GlassTokens.sub(isDark);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20,
          20 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : const Color(0xFFF4F4F6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.15),
          ),
        ),
        const SizedBox(height: 24),
        Text('Story Duration',
            style: GoogleFonts.manrope(
              color: fg, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('How long should your story stay visible?',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: sub, fontSize: 13)),
        const SizedBox(height: 24),
        // 4 × 2 grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: _options.map((h) => _DurationTile(
            hours:    h,
            label:    _label(h),
            sub:      _sub(h),
            selected: selected == h,
            isDark:   isDark,
            onTap:    () => onSelect(h),
          )).toList(),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _DurationTile extends StatelessWidget {
  final int          hours;
  final String       label;
  final String       sub;
  final bool         selected;
  final bool         isDark;
  final VoidCallback onTap;
  const _DurationTile({
    required this.hours,  required this.label,
    required this.sub,    required this.selected,
    required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05));
    final borderColor = selected
        ? Colors.transparent
        : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.09));
    final mainColor = selected
        ? (isDark ? Colors.black : Colors.white)
        : GlassTokens.fg(isDark);
    final subColor = selected
        ? (isDark ? Colors.black54 : Colors.white70)
        : GlassTokens.sub(isDark);

    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color:  bgColor,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.manrope(
                  color: mainColor, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(color: subColor, fontSize: 9.5)),
          ],
        ),
      ),
    );
  }
}
