import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home/home_screen.dart';

class InterestGateScreen extends StatefulWidget {
  const InterestGateScreen({super.key});

  @override
  State<InterestGateScreen> createState() => _InterestGateScreenState();
}

class _InterestGateScreenState extends State<InterestGateScreen> {
  static const _lastShownKey = 'interest_screen_last_shown_at';
  static const _selectedKey = 'interest_screen_selected';
  static const _cooldown = Duration(hours: 24);

  final Set<String> _selected = <String>{};
  bool _checking = true;
  bool _saving = false;

  static const List<_InterestOption> _options = [
    _InterestOption('Fashion', Icons.checkroom_outlined),
    _InterestOption('Music', Icons.music_note_rounded),
    _InterestOption('Sports', Icons.sports_soccer_rounded),
    _InterestOption('Movies', Icons.movie_creation_outlined),
    _InterestOption('Gaming', Icons.sports_esports_outlined),
    _InterestOption('Travel', Icons.flight_takeoff_rounded),
    _InterestOption('Food', Icons.restaurant_menu_rounded),
    _InterestOption('Fitness', Icons.fitness_center_rounded),
    _InterestOption('Tech', Icons.memory_rounded),
    _InterestOption('Learning', Icons.school_outlined),
    _InterestOption('Art', Icons.palette_outlined),
    _InterestOption('News', Icons.newspaper_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGate());
  }

  Future<void> _checkGate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt(_lastShownKey);
    final shouldShow = lastShown == null ||
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(lastShown),
            ) >=
            _cooldown;

    if (!mounted) return;
    if (!shouldShow) {
      _openHome();
      return;
    }

    setState(() => _checking = false);
  }

  void _toggle(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
  }

  Future<void> _continue() async {
    if (_saving || _selected.isEmpty) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedKey, _selected.toList()..sort());
    await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);

    if (!mounted) return;
    _openHome();
  }

  Future<void> _skip() async {
    if (_saving) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);

    if (!mounted) return;
    _openHome();
  }

  void _openHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const HomeScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _InterestTheme.of(isDark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: t.bgEnd,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    if (_checking) {
      return Scaffold(
        backgroundColor: t.bgEnd,
        body: Center(
          child: CircularProgressIndicator(
            color: t.fg,
            strokeWidth: 1.6,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bgEnd,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.35,
                colors: t.bgStops,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 560,
                        minHeight: constraints.maxHeight - 36,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: _TextAction(
                                label: 'Skip',
                                color: t.muted,
                                onTap: _skip,
                              ),
                            ),
                            const Spacer(),
                            _GlassPanel(
                              t: t,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 22, 20, 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      _AppMark(t: t),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Choose your interests',
                                              style: GoogleFonts.manrope(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: t.fg,
                                                height: 1.08,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Select topics you want to see more on Trandia.',
                                              style: GoogleFonts.manrope(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: t.muted,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final option in _options)
                                        _InterestChip(
                                          t: t,
                                          option: option,
                                          selected:
                                              _selected.contains(option.label),
                                          onTap: () => _toggle(option.label),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  _PrimaryButton(
                                    t: t,
                                    enabled: _selected.isNotEmpty && !_saving,
                                    label: _saving
                                        ? 'Saving...'
                                        : _selected.isEmpty
                                            ? 'Select at least one'
                                            : 'Continue',
                                    onTap: _continue,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestOption {
  const _InterestOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _InterestTheme {
  const _InterestTheme({
    required this.dark,
    required this.fg,
    required this.muted,
    required this.bgEnd,
    required this.bgStops,
    required this.panelFill,
    required this.panelBorder,
    required this.buttonFill,
    required this.buttonFg,
  });

  final bool dark;
  final Color fg;
  final Color muted;
  final Color bgEnd;
  final List<Color> bgStops;
  final List<Color> panelFill;
  final Color panelBorder;
  final List<Color> buttonFill;
  final Color buttonFg;

  static _InterestTheme of(bool dark) => dark ? _dark : _light;

  static const _light = _InterestTheme(
    dark: false,
    fg: Color(0xFF101114),
    muted: Color(0x99101114),
    bgEnd: Color(0xFFE2E2E8),
    bgStops: [Color(0xFFF8F8FA), Color(0xFFECECF1), Color(0xFFE2E2E8)],
    panelFill: [Color(0xCCFFFFFF), Color(0x80FFFFFF)],
    panelBorder: Color(0xE6FFFFFF),
    buttonFill: [Color(0xFF55555C), Color(0xFF303035)],
    buttonFg: Color(0xFFFFFFFF),
  );

  static const _dark = _InterestTheme(
    dark: true,
    fg: Color(0xFFF6F6FA),
    muted: Color(0x99F6F6FA),
    bgEnd: Color(0xFF050506),
    bgStops: [Color(0xFF1C1C1F), Color(0xFF0D0D0F), Color(0xFF050506)],
    panelFill: [Color(0x24FFFFFF), Color(0x0DFFFFFF)],
    panelBorder: Color(0x2EFFFFFF),
    buttonFill: [Color(0xFFF2F2F7), Color(0xFFE3E3EA)],
    buttonFg: Color(0xFF101114),
  );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.t,
    required this.child,
    required this.padding,
  });

  final _InterestTheme t;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: t.panelBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.panelFill,
            ),
            boxShadow: [
              BoxShadow(
                color: t.dark
                    ? const Color(0x99000000)
                    : const Color(0x33202035),
                blurRadius: 48,
                offset: const Offset(0, 20),
                spreadRadius: -18,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.t});

  final _InterestTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.panelBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Image.asset(
          'assets/icons/app_icon.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.t,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _InterestTheme t;
  final _InterestOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? t.buttonFg : t.fg;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : t.panelBorder,
              width: 1,
            ),
            gradient: selected
                ? LinearGradient(colors: t.buttonFill)
                : LinearGradient(colors: t.panelFill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.t,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final _InterestTheme t;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: t.buttonFill,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.buttonFg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
