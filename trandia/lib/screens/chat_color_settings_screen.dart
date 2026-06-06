import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../services/user_service.dart';
import '../l10n/app_localizations.dart';
import 'glass_common.dart';

class ColorPreset {
  final String name;
  final Color senderColor;
  final Color receiverColor;
  const ColorPreset(this.name, this.senderColor, this.receiverColor);
}

class ChatColorSettingsScreen extends StatefulWidget {
  final bool dark;
  const ChatColorSettingsScreen({super.key, required this.dark});

  @override
  State<ChatColorSettingsScreen> createState() => _ChatColorSettingsScreenState();
}

class _ChatColorSettingsScreenState extends State<ChatColorSettingsScreen> {
  late Color _senderColor;
  late Color _receiverColor;
  late Color _bgColor;
  String? _bgImagePath;
  String _bgType = 'default'; // 'default', 'color', 'image'
  int _selectedTargetIndex = 0; // 0 for Sender, 1 for Receiver, 2 for Chat BG Color

  bool _isLoading = true;
  bool _isSaving = false;

  // Curated premium preset themes
  late final List<ColorPreset> _presets;

  @override
  void initState() {
    super.initState();
    _presets = [
      ColorPreset(
        'Sunset Glow',
        const Color(0xFFFF5F6D),
        const Color(0xFFFFC371),
      ),
      ColorPreset(
        'Ocean Blue',
        const Color(0xFF00c6ff),
        const Color(0xFF0072ff),
      ),
      ColorPreset(
        'Emerald Breeze',
        const Color(0xFF11998e),
        const Color(0xFF38ef7d),
      ),
      ColorPreset(
        'Lavender Dream',
        const Color(0xFFa18cd1),
        const Color(0xFFfbc2eb),
      ),
      ColorPreset(
        'Neon Pink',
        const Color(0xFFec008c),
        const Color(0xFFfc6767),
      ),
      ColorPreset(
        'Rose Gold',
        const Color(0xFFe55d87),
        const Color(0xFF5fc3e4),
      ),
      ColorPreset(
        'Classic Mono',
        widget.dark ? Colors.white : const Color(0xFF0A0A0A),
        widget.dark ? const Color(0xFF242424) : Colors.white,
      ),
      ColorPreset(
        'Midnight Forest',
        const Color(0xFF1D2671),
        const Color(0xFFC33764),
      ),
      ColorPreset(
        'Soft Peach',
        const Color(0xFFff9a9e),
        const Color(0xFFfecfef),
      ),
    ];

    _loadColors();
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    final senderHex = prefs.getString('chat_sender_bubble_color');
    final receiverHex = prefs.getString('chat_receiver_bubble_color');
    final bgType = prefs.getString('chat_background_type') ?? 'default';
    final bgHex = prefs.getString('chat_background_color');
    final bgImagePath = prefs.getString('chat_background_image_path');

    // Default colors matching chat_screen.dart
    final defaultSender = widget.dark ? Colors.white : const Color(0xFF0A0A0A);
    final defaultReceiver = widget.dark
        ? const Color(0xFF242424).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    final defaultBg = widget.dark ? const Color(0xFF000000) : const Color(0xFFFAFAFA);

    setState(() {
      _senderColor = senderHex != null ? _parseHex(senderHex, defaultSender) : defaultSender;
      _receiverColor = receiverHex != null ? _parseHex(receiverHex, defaultReceiver) : defaultReceiver;
      _bgColor = bgHex != null ? _parseHex(bgHex, defaultBg) : defaultBg;
      _bgImagePath = bgImagePath;
      _bgType = bgType;
      _isLoading = false;
    });
  }

  Color _parseHex(String hex, Color fallback) {
    try {
      String cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  String _toHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<void> _saveColors() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();

    final senderHex = _toHex(_senderColor);
    final receiverHex = _toHex(_receiverColor);
    final bgHex = _toHex(_bgColor);

    await prefs.setString('chat_sender_bubble_color', senderHex);
    await prefs.setString('chat_receiver_bubble_color', receiverHex);
    await prefs.setString('chat_background_type', _bgType);
    await prefs.setString('chat_background_color', bgHex);

    if (_bgImagePath != null) {
      await prefs.setString('chat_background_image_path', _bgImagePath!);
    } else {
      await prefs.remove('chat_background_image_path');
    }

    // Sync bubble colors with backend
    final success = await UserService.updateChatColors(senderHex, receiverHex);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Preferences updated successfully!'.tr(context)
                : 'Preferences saved locally (sync pending)'.tr(context),
            style: manrope(size: 14, weight: FontWeight.w600),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_sender_bubble_color');
    await prefs.remove('chat_receiver_bubble_color');
    await prefs.remove('chat_background_type');
    await prefs.remove('chat_background_color');
    await prefs.remove('chat_background_image_path');

    // Sync clear to backend
    await UserService.updateChatColors(null, null);

    // Clean up local image file
    try {
      final dir = await getDatabasesPath();
      final file = File(p.join(dir, 'chat_bg_local.png'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultSender = isDark ? Colors.white : const Color(0xFF0A0A0A);
    final defaultReceiver = isDark
        ? const Color(0xFF242424).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    final defaultBg = isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA);

    setState(() {
      _senderColor = defaultSender;
      _receiverColor = defaultReceiver;
      _bgColor = defaultBg;
      _bgImagePath = null;
      _bgType = 'default';
      _selectedTargetIndex = 0;
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preferences reset to default'.tr(context),
            style: manrope(size: 14, weight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final dir = await getDatabasesPath();
      final persistentPath = p.join(dir, 'chat_bg_local.png');

      final File localFile = File(image.path);
      await localFile.copy(persistentPath);

      setState(() {
        _bgImagePath = persistentPath;
        _bgType = 'image';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _removeBackgroundImage() {
    setState(() {
      _bgImagePath = null;
      _bgType = 'default';
    });
  }

  // Update selected target color based on HSV values
  void _updateColorFromHSV(double h, double s, double v) {
    final newColor = HSVColor.fromAHSV(1.0, h, s, v).toColor();
    setState(() {
      if (_selectedTargetIndex == 0) {
        _senderColor = newColor;
      } else if (_selectedTargetIndex == 1) {
        _receiverColor = newColor;
      } else {
        _bgColor = newColor;
        _bgType = 'color'; // Automatically shift to solid background color type
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentColor = _selectedTargetIndex == 0
        ? _senderColor
        : (_selectedTargetIndex == 1 ? _receiverColor : _bgColor);
    final hsv = HSVColor.fromColor(currentColor);

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          GlassBackdrop(dark: dark),
          SafeArea(
            child: Column(
              children: [
                // Header
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
                        Text(
                          'Chat Customizer'.tr(context),
                          style: manrope(size: 17, weight: FontWeight.w800, color: fg),
                        ),
                        const Spacer(),
                        if (_isSaving)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          TextButton(
                            onPressed: _saveColors,
                            child: Text(
                              'Save'.tr(context),
                              style: manrope(
                                size: 14,
                                weight: FontWeight.w800,
                                color: dark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Chat Preview Mockup Card
                      _buildChatPreviewCard(dark),
                      const SizedBox(height: 20),

                      // Segmented Controller for target selection
                      _buildTargetSelector(dark, fg, sub),
                      const SizedBox(height: 20),

                      // Section: Presets (Only show for Bubble Target index 0 & 1)
                      if (_selectedTargetIndex < 2) ...[
                        Text(
                          'PRESETS'.tr(context),
                          style: manrope(size: 11, weight: FontWeight.w800, color: sub, letterSpacing: 0.9),
                        ),
                        const SizedBox(height: 10),
                        _buildPresetsGrid(dark),
                        const SizedBox(height: 24),
                      ],

                      // Background Wallpapers section (Only show if BG Target is selected)
                      if (_selectedTargetIndex == 2) ...[
                        Text(
                          'WALLPAPER TYPE'.tr(context),
                          style: manrope(size: 11, weight: FontWeight.w800, color: sub, letterSpacing: 0.9),
                        ),
                        const SizedBox(height: 10),
                        _buildBGTypeSelector(dark),
                        const SizedBox(height: 24),
                      ],

                      // Section: Custom HSV Picker
                      Text(
                        'CUSTOMIZER'.tr(context),
                        style: manrope(size: 11, weight: FontWeight.w800, color: sub, letterSpacing: 0.9),
                      ),
                      const SizedBox(height: 12),
                      _buildHSVPicker(dark, hsv),
                      const SizedBox(height: 28),

                      // Reset to Default button
                      GestureDetector(
                        onTap: _resetToDefault,
                        child: GlassSurface(
                          dark: dark,
                          radius: 16,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              'Reset to Default'.tr(context),
                              style: manrope(
                                size: 14,
                                weight: FontWeight.w800,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPreviewCard(bool dark) {
    final borderCol = GlassTokens.glassBorder(dark);
    final senderTextCol = _senderColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final receiverTextCol = _receiverColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    // Determine the background container style
    Widget backgroundWidget;
    if (_bgType == 'image' && _bgImagePath != null && File(_bgImagePath!).existsSync()) {
      backgroundWidget = Image.file(
        File(_bgImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_bgType == 'color') {
      backgroundWidget = Container(
        color: _bgColor,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      backgroundWidget = GlassBackdrop(dark: dark);
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: borderCol, width: 0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background
            backgroundWidget,

            // Text bubbles overlay
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Receiver bubble
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _receiverColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        'This is a receiver bubble! 👋',
                        style: manrope(size: 13.5, weight: FontWeight.w500, color: receiverTextCol),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sender bubble
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _senderColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        'This is your message bubble! 🔥',
                        style: manrope(size: 13.5, weight: FontWeight.w500, color: senderTextCol),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Live Preview Header
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LIVE PREVIEW'.tr(context),
                    style: manrope(size: 9, weight: FontWeight.w800, color: Colors.white70, letterSpacing: 1.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelector(bool dark, Color fg, Color sub) {
    return GlassSurface(
      dark: dark,
      radius: 16,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTargetItem(0, 'Sender', dark, fg),
          _buildTargetItem(1, 'Receiver', dark, fg),
          _buildTargetItem(2, 'Background', dark, fg),
        ],
      ),
    );
  }

  Widget _buildTargetItem(int index, String label, bool dark, Color fg) {
    final isSelected = _selectedTargetIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTargetIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (dark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label.tr(context),
            style: manrope(
              size: 13.5,
              weight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBGTypeSelector(bool dark) {
    final fg = GlassTokens.fg(dark);
    return GlassSurface(
      dark: dark,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTypeButton('default', 'Default Glass', dark),
              const SizedBox(width: 8),
              _buildTypeButton('color', 'Solid Color', dark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickBackgroundImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _bgType == 'image'
                          ? (dark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08))
                          : Colors.transparent,
                      border: Border.all(
                        color: dark ? Colors.white24 : Colors.black12,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, color: fg, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _bgImagePath != null ? 'Change Image' : 'Pick Gallery Image',
                          style: manrope(size: 13, weight: FontWeight.w700, color: fg),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_bgImagePath != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _removeBackgroundImage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  ),
                ),
              ],
            ],
          ),
          if (_bgImagePath != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_bgImagePath!),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Local path: .../${p.basename(_bgImagePath!)}',
                    style: manrope(size: 11, weight: FontWeight.w500, color: GlassTokens.sub(dark)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, bool dark) {
    final isSelected = _bgType == type;
    final fg = GlassTokens.fg(dark);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _bgType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (dark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08))
                : Colors.transparent,
            border: Border.all(
              color: dark ? Colors.white24 : Colors.black12,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label.tr(context),
            style: manrope(size: 13, weight: isSelected ? FontWeight.w800 : FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetsGrid(bool dark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: _presets.length,
      itemBuilder: (context, index) {
        final preset = _presets[index];
        final isSelectedPreset = preset.senderColor == _senderColor && preset.receiverColor == _receiverColor;

        return GestureDetector(
          onTap: () {
            setState(() {
              _senderColor = preset.senderColor;
              _receiverColor = preset.receiverColor;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF222224) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelectedPreset
                    ? (dark ? Colors.white : Colors.black)
                    : (dark ? Colors.white12 : Colors.black12),
                width: isSelectedPreset ? 2.0 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  preset.name.tr(context),
                  style: manrope(size: 10, weight: FontWeight.w700, color: GlassTokens.fg(dark)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: preset.receiverColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: preset.senderColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHSVPicker(bool dark, HSVColor hsv) {
    final currentColor = hsv.toColor();
    return GlassSurface(
      dark: dark,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Selected Color Hex value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Color Value'.tr(context),
                style: manrope(size: 13, weight: FontWeight.w700, color: GlassTokens.fg(dark)),
              ),
              Text(
                _toHex(currentColor),
                style: manrope(size: 13, weight: FontWeight.w800, color: GlassTokens.fg(dark)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hue Slider
          _buildHSVSliderRow(
            label: 'Hue',
            value: hsv.hue,
            min: 0.0,
            max: 360.0,
            activeTrackBar: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
              ),
            ),
            onChanged: (val) => _updateColorFromHSV(val, hsv.saturation, hsv.value),
          ),
          const SizedBox(height: 12),

          // Saturation Slider
          _buildHSVSliderRow(
            label: 'Saturation',
            value: hsv.saturation,
            min: 0.0,
            max: 1.0,
            activeTrackBar: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor(),
                  ],
                ),
              ),
            ),
            onChanged: (val) => _updateColorFromHSV(hsv.hue, val, hsv.value),
          ),
          const SizedBox(height: 12),

          // Value/Brightness Slider
          _buildHSVSliderRow(
            label: 'Brightness',
            value: hsv.value,
            min: 0.0,
            max: 1.0,
            activeTrackBar: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    HSVColor.fromAHSV(1.0, hsv.hue, hsv.saturation, 1.0).toColor(),
                  ],
                ),
              ),
            ),
            onChanged: (val) => _updateColorFromHSV(hsv.hue, hsv.saturation, val),
          ),
        ],
      ),
    );
  }

  Widget _buildHSVSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required Widget activeTrackBar,
    required ValueChanged<double> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = GlassTokens.fg(isDark);
    final sub = GlassTokens.sub(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.tr(context),
              style: manrope(size: 12, weight: FontWeight.w600, color: sub),
            ),
            Text(
              max == 1.0 ? '${(value * 100).toInt()}%' : '${value.toInt()}°',
              style: manrope(size: 12, weight: FontWeight.w700, color: fg),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            // Background bar gradient
            activeTrackBar,

            // Custom slider overlay
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
