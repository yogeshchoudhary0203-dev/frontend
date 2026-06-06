// trandia_marketplace_apply_screen.dart
//
// "Apply for Trandia Marketplace" — Creator account onboarding form.
// Frontend-only: persists submission state via SharedPreferences so the
// settings tab routes to the Dashboard on subsequent opens.
// Theme: shared glass system from glass_common.dart.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'glass_common.dart';
import 'trandia_marketplace_dashboard_screen.dart';
import '../services/marketplace_service.dart';

// SharedPreferences keys (also read by setting_screen.dart routing).
class TmApplyKeys {
  static const applied = 'tm_marketplace_applied';
  static const phone = 'tm_apply_phone';
  static const contentType = 'tm_apply_content_type';
  static const followers = 'tm_apply_followers';
  static const languages = 'tm_apply_languages';
  static const bio = 'tm_apply_bio';
  static const appliedAt = 'tm_apply_applied_at';
}

class TrandiaMarketplaceApplyScreen extends StatefulWidget {
  final bool dark;
  const TrandiaMarketplaceApplyScreen({super.key, required this.dark});

  @override
  State<TrandiaMarketplaceApplyScreen> createState() =>
      _TrandiaMarketplaceApplyScreenState();
}

class _TrandiaMarketplaceApplyScreenState
    extends State<TrandiaMarketplaceApplyScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _followersCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  static const _contentTypes = [
    'Comedy', 'Fashion', 'Tech', 'Lifestyle',
    'Gaming', 'Food', 'Travel', 'Music',
  ];
  static const _langs = ['Hindi', 'English', 'Hinglish', 'Tamil', 'Telugu'];

  String? _selectedContent;
  final Set<String> _selectedLangs = {};

  bool _submitting = false;
  bool _showSuccess = false;

  late final AnimationController _successCtrl;
  late final Animation<double> _successAnim;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _successAnim = CurvedAnimation(parent: _successCtrl, curve: kIOSSpring);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _followersCtrl.dispose();
    _bioCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _phoneCtrl.text.trim().length >= 10 &&
      _selectedContent != null &&
      _selectedLangs.isNotEmpty &&
      _followersCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);

    // Parse the declared follower count (strip anything non-numeric).
    final followers = int.tryParse(
            _followersCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;

    // Persist to the backend FIRST — this is what makes the creator discoverable
    // in everyone else's marketplace search.
    final ok = await MarketplaceService.apply(
      phone: _phoneCtrl.text.trim(),
      contentType: _selectedContent ?? '',
      followers: followers,
      languages: _selectedLangs.toList(),
      bio: _bioCtrl.text.trim(),
    );

    if (!mounted) return;

    if (!ok) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit. Check your connection and try again.',
              style: manrope(size: 13.5, weight: FontWeight.w600)),
        ),
      );
      return;
    }

    // Mirror to SharedPreferences so the settings tab + dashboard route instantly
    // (and offline) without a round-trip.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TmApplyKeys.applied, true);
    await prefs.setString(TmApplyKeys.phone, _phoneCtrl.text.trim());
    await prefs.setString(TmApplyKeys.contentType, _selectedContent ?? '');
    await prefs.setString(TmApplyKeys.followers, _followersCtrl.text.trim());
    await prefs.setStringList(TmApplyKeys.languages, _selectedLangs.toList());
    await prefs.setString(TmApplyKeys.bio, _bioCtrl.text.trim());
    await prefs.setString(
        TmApplyKeys.appliedAt, DateTime.now().toIso8601String());
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _showSuccess = true;
    });
    _successCtrl.forward();
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, __, ___) =>
          TrandiaMarketplaceDashboardScreen(dark: widget.dark),
      transitionsBuilder: (_, anim, __, child) {
        final c = CurvedAnimation(parent: anim, curve: kIOSEase);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(c),
            child: child,
          ),
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      resizeToAvoidBottomInset: true,
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
                    padding: const EdgeInsets.only(left: 7, right: 14),
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
                            'Apply for Marketplace',
                            style: manrope(
                                size: 16, weight: FontWeight.w800, color: fg),
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
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                    children: [
                      _HeroIntro(dark: dark),
                      const SizedBox(height: 16),
                      _SectionLabel(text: 'CONTACT', color: sub),
                      _GlassField(
                        dark: dark,
                        icon: Icons.phone_rounded,
                        hint: 'Phone number',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(text: 'CONTENT TYPE', color: sub),
                      _ContentTypeGrid(
                        dark: dark,
                        types: _contentTypes,
                        selected: _selectedContent,
                        onSelect: (t) => setState(() => _selectedContent = t),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(text: 'LANGUAGES', color: sub),
                      _LanguageChips(
                        dark: dark,
                        all: _langs,
                        selected: _selectedLangs,
                        onToggle: (l) {
                          setState(() {
                            if (_selectedLangs.contains(l)) {
                              _selectedLangs.remove(l);
                            } else {
                              _selectedLangs.add(l);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(text: 'AUDIENCE', color: sub),
                      _GlassField(
                        dark: dark,
                        icon: Icons.people_alt_rounded,
                        hint: 'Total followers (e.g. 125000)',
                        controller: _followersCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel(text: 'ABOUT YOU', color: sub),
                      _GlassField(
                        dark: dark,
                        icon: Icons.edit_note_rounded,
                        hint: 'Tell brands about your niche, vibe, past work…',
                        controller: _bioCtrl,
                        maxLines: 5,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 24),
                      _SubmitButton(
                        dark: dark,
                        enabled: _isValid,
                        loading: _submitting,
                        onTap: _submit,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'By applying you agree to Trandia’s creator terms.',
                          style: manrope(
                              size: 11, weight: FontWeight.w500, color: sub),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showSuccess)
            _SuccessOverlay(
              dark: dark,
              anim: _successAnim,
              onContinue: _goToDashboard,
            ),
        ],
      ),
    );
  }
}

// ── Hero intro card ─────────────────────────────────────────────────────────
class _HeroIntro extends StatelessWidget {
  final bool dark;
  const _HeroIntro({required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return GlassSurface(
      dark: dark,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.storefront_rounded, color: fg, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join Trandia Marketplace',
                  style: manrope(
                      size: 16, weight: FontWeight.w800, color: fg),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get discovered by brands. Set your rates. Earn from collabs.',
                  style: manrope(
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: sub,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        text,
        style: manrope(
            size: 11,
            weight: FontWeight.w800,
            color: color,
            letterSpacing: 0.9),
      ),
    );
  }
}

// ── Glass text field ────────────────────────────────────────────────────────
class _GlassField extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _GlassField({
    required this.dark,
    required this.icon,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final multiline = maxLines > 1;
    return GlassSurface(
      dark: dark,
      radius: multiline ? 22 : 999,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: multiline ? 14 : 4,
      ),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: multiline ? 4 : 0),
            child: Icon(icon, color: sub, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              onChanged: onChanged,
              style:
                  manrope(size: 14, weight: FontWeight.w600, color: fg),
              cursorColor: fg,
              cursorHeight: 18,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    manrope(size: 14, weight: FontWeight.w500, color: sub),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: multiline ? 4 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Content type grid ───────────────────────────────────────────────────────
class _ContentTypeGrid extends StatelessWidget {
  final bool dark;
  final List<String> types;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ContentTypeGrid({
    required this.dark,
    required this.types,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final isSel = selected == t;
        return PressableScale(
          onTap: () => onSelect(t),
          child: _PillTag(
            dark: dark,
            label: t,
            selected: isSel,
            icon: _iconFor(t),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'Comedy':
        return Icons.theater_comedy_rounded;
      case 'Fashion':
        return Icons.checkroom_rounded;
      case 'Tech':
        return Icons.memory_rounded;
      case 'Lifestyle':
        return Icons.spa_rounded;
      case 'Gaming':
        return Icons.sports_esports_rounded;
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Travel':
        return Icons.flight_takeoff_rounded;
      case 'Music':
        return Icons.music_note_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}

// ── Language chips ──────────────────────────────────────────────────────────
class _LanguageChips extends StatelessWidget {
  final bool dark;
  final List<String> all;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _LanguageChips({
    required this.dark,
    required this.all,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: all.map((l) {
        final isSel = selected.contains(l);
        return PressableScale(
          onTap: () => onToggle(l),
          child: _PillTag(
            dark: dark,
            label: l,
            selected: isSel,
          ),
        );
      }).toList(),
    );
  }
}

// ── Reusable pill tag (used in grid + chips) ────────────────────────────────
class _PillTag extends StatelessWidget {
  final bool dark;
  final String label;
  final bool selected;
  final IconData? icon;
  const _PillTag({
    required this.dark,
    required this.label,
    required this.selected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final selBg = dark ? Colors.white : const Color(0xFF0A0A0A);
    final selFg = dark ? const Color(0xFF0A0A0A) : Colors.white;
    final inactiveBg = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.70);
    final border = GlassTokens.glassBorder(dark);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: kIOSEase,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? selBg : inactiveBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? selBg : border,
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: selected ? selFg : fg),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: manrope(
                size: 13,
                weight: FontWeight.w800,
                color: selected ? selFg : fg),
          ),
        ],
      ),
    );
  }
}

// ── Submit button ───────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final bool dark;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const _SubmitButton({
    required this.dark,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? Colors.white : const Color(0xFF0A0A0A);
    final fgCol = dark ? const Color(0xFF0A0A0A) : Colors.white;
    final disabledBg = dark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.18);
    return PressableScale(
      onTap: enabled && !loading ? onTap : null,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: kIOSEase,
        height: 54,
        decoration: BoxDecoration(
          color: enabled ? bg : disabledBg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: dark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                    spreadRadius: -8,
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(fgCol),
                ),
              )
            : Text(
                'Submit Application',
                style: manrope(
                    size: 15, weight: FontWeight.w800, color: fgCol),
              ),
      ),
    );
  }
}

// ── Success overlay ─────────────────────────────────────────────────────────
class _SuccessOverlay extends StatelessWidget {
  final bool dark;
  final Animation<double> anim;
  final VoidCallback onContinue;
  const _SuccessOverlay({
    required this.dark,
    required this.anim,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, child) {
          return Stack(
            children: [
              Opacity(
                opacity: anim.value.clamp(0.0, 1.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    color: dark
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Center(
                child: Transform.scale(
                  scale: 0.85 + 0.15 * anim.value.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: anim.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: GlassSurface(
            dark: dark,
            radius: 28,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark ? Colors.white : const Color(0xFF0A0A0A),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.check_rounded,
                    size: 38,
                    color: dark ? const Color(0xFF0A0A0A) : Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Thank You!',
                  style: manrope(
                      size: 22, weight: FontWeight.w800, color: fg),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your application has been received. We’ll review your profile and get back within 48 hours.',
                  textAlign: TextAlign.center,
                  style: manrope(
                      size: 13.5,
                      weight: FontWeight.w500,
                      color: sub,
                      height: 1.5),
                ),
                const SizedBox(height: 22),
                PressableScale(
                  onTap: onContinue,
                  pressedScale: 0.97,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dark ? Colors.white : const Color(0xFF0A0A0A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Continue to Dashboard',
                      style: manrope(
                          size: 14.5,
                          weight: FontWeight.w800,
                          color:
                              dark ? const Color(0xFF0A0A0A) : Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
