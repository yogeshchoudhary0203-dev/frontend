import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_common.dart';
import '../services/app_lock_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP LOCK SETUP SCREEN
// ─────────────────────────────────────────────────────────────────────────────

enum _SetupStep { chooseLength, enterPin, confirmPin, done, manage }

class AppLockSetupScreen extends StatefulWidget {
  final bool dark;
  const AppLockSetupScreen({super.key, required this.dark});

  @override
  State<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends State<AppLockSetupScreen>
    with TickerProviderStateMixin {
  _SetupStep _step = _SetupStep.chooseLength;
  int _pinLength = 4;
  String _enteredPin = '';
  String _firstPin = '';
  bool _initDone = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;
  late final AnimationController _doneCtrl;
  late final Animation<double> _doneScale;
  late final Animation<double> _doneFade;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _doneCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _doneScale = CurvedAnimation(parent: _doneCtrl, curve: Curves.elasticOut);
    _doneFade = CurvedAnimation(parent: _doneCtrl, curve: const Interval(0.1, 0.5, curve: Curves.easeIn));

    _loadState();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _doneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final enabled = await AppLockService.isEnabled();
    final len = await AppLockService.getPinLength();
    if (!mounted) return;
    setState(() {
      _pinLength = len;
      _step = enabled ? _SetupStep.manage : _SetupStep.chooseLength;
      _initDone = true;
    });
  }

  void _onDigit(String d) {
    if (_enteredPin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() => _enteredPin += d);
    if (_enteredPin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 120), _handleComplete);
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
  }

  Future<void> _handleComplete() async {
    if (_step == _SetupStep.enterPin) {
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = '';
        _step = _SetupStep.confirmPin;
      });
    } else if (_step == _SetupStep.confirmPin) {
      if (_enteredPin == _firstPin) {
        await AppLockService.enable(pin: _enteredPin);
        if (!mounted) return;
        setState(() { _step = _SetupStep.done; });
        HapticFeedback.heavyImpact();
        _doneCtrl.forward();
      } else {
        HapticFeedback.vibrate();
        await _shakeCtrl.forward(from: 0);
        if (!mounted) return;
        setState(() { _enteredPin = ''; _firstPin = ''; _step = _SetupStep.enterPin; });
      }
    }
  }

  void _confirmDisable() {
    final dark = widget.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF1C1C1F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Disable App Lock?',
            style: manrope(size: 17, weight: FontWeight.w800, color: GlassTokens.fg(dark))),
        content: Text('Your PIN will be removed and the app will no longer be protected.',
            style: manrope(size: 14, weight: FontWeight.w500, color: GlassTokens.sub(dark))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: manrope(size: 14, weight: FontWeight.w700, color: GlassTokens.sub(dark))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AppLockService.disable();
              if (mounted) Navigator.pop(context);
            },
            child: Text('Disable',
                style: manrope(size: 14, weight: FontWeight.w700, color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          GlassBackdrop(dark: dark),
          SafeArea(
            child: !_initDone
                ? const Center(child: CircularProgressIndicator())
                : _buildStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _SetupStep.chooseLength: return _buildChooseLength();
      case _SetupStep.enterPin:    return _buildPinEntry(isConfirm: false);
      case _SetupStep.confirmPin:  return _buildPinEntry(isConfirm: true);
      case _SetupStep.done:        return _buildDone();
      case _SetupStep.manage:      return _buildManage();
    }
  }

  // ─── Choose 4 / 6 ────────────────────────────────────────────────────────

  Widget _buildChooseLength() {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Column(
      children: [
        _TopBar(dark: dark, title: 'App Lock', onBack: () => Navigator.pop(context)),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GlowIcon(dark: dark, icon: Icons.lock_rounded, size: 80),
              const SizedBox(height: 28),
              Text('Set App Lock',
                  style: manrope(size: 26, weight: FontWeight.w900, color: fg)),
              const SizedBox(height: 10),
              Text('Choose a PIN to protect your account',
                  style: manrope(size: 14, weight: FontWeight.w500, color: sub)),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Expanded(child: _PinLengthCard(dark: dark, digits: 4,
                        selected: _pinLength == 4, onTap: () => setState(() => _pinLength = 4))),
                    const SizedBox(width: 14),
                    Expanded(child: _PinLengthCard(dark: dark, digits: 6,
                        selected: _pinLength == 6, onTap: () => setState(() => _pinLength = 6))),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _PrimaryButton(
                  dark: dark,
                  label: 'Continue',
                  onTap: () { _enteredPin = ''; setState(() => _step = _SetupStep.enterPin); },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Enter / Confirm PIN ──────────────────────────────────────────────────

  Widget _buildPinEntry({required bool isConfirm}) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Column(
      children: [
        _TopBar(
          dark: dark,
          title: isConfirm ? 'Confirm PIN' : 'Set PIN',
          onBack: () => setState(() {
            _enteredPin = '';
            _firstPin = '';
            _step = isConfirm ? _SetupStep.enterPin : _SetupStep.chooseLength;
          }),
        ),
        Expanded(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                isConfirm ? 'Re-enter your PIN' : 'Enter a $_pinLength-digit PIN',
                style: manrope(size: 22, weight: FontWeight.w800, color: fg),
              ),
              const SizedBox(height: 8),
              Text(
                isConfirm ? 'Make sure it matches your first PIN' : 'You\'ll use this to unlock the app',
                style: manrope(size: 13, weight: FontWeight.w500, color: sub),
              ),
              const SizedBox(height: 36),
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
                child: _PinDots(dark: dark, total: _pinLength, filled: _enteredPin.length),
              ),
              const Spacer(flex: 3),
              _NumPad(dark: dark, onDigit: _onDigit, onDelete: _onDelete),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Done ─────────────────────────────────────────────────────────────────

  Widget _buildDone() {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _doneScale,
          builder: (_, child) => Transform.scale(scale: _doneScale.value, child: child),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: Colors.green.withOpacity(0.45), blurRadius: 36, spreadRadius: 6),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
          ),
        ),
        const SizedBox(height: 32),
        FadeTransition(
          opacity: _doneFade,
          child: Column(
            children: [
              Text('App Lock Enabled!',
                  style: manrope(size: 26, weight: FontWeight.w900, color: fg)),
              const SizedBox(height: 10),
              Text(
                'Your app is now protected\nwith a $_pinLength-digit PIN',
                style: manrope(size: 14, weight: FontWeight.w500, color: sub, height: 1.55),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _PrimaryButton(dark: dark, label: 'Done', onTap: () => Navigator.pop(context)),
        ),
      ],
    );
  }

  // ─── Manage (already enabled) ─────────────────────────────────────────────

  Widget _buildManage() {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return Column(
      children: [
        _TopBar(dark: dark, title: 'App Lock', onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              // Status card
              GlassSurface(
                dark: dark,
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.withOpacity(0.18),
                      ),
                      child: const Icon(Icons.lock_rounded, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('App Lock is Active',
                            style: manrope(size: 15, weight: FontWeight.w800, color: fg)),
                        const SizedBox(height: 3),
                        Text('$_pinLength-digit PIN enabled',
                            style: manrope(size: 12, weight: FontWeight.w500, color: sub)),
                      ],
                    )),
                    const Icon(Icons.verified_rounded, color: Colors.green, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Change PIN
              GestureDetector(
                onTap: () => setState(() {
                  _enteredPin = '';
                  _firstPin = '';
                  _step = _SetupStep.chooseLength;
                }),
                child: GlassSurface(
                  dark: dark, radius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(children: [
                    _IconCircle(dark: dark, icon: Icons.pin_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Change PIN', style: manrope(size: 14.5, weight: FontWeight.w800, color: fg)),
                      const SizedBox(height: 2),
                      Text('Set a new PIN for app lock', style: manrope(size: 12, weight: FontWeight.w500, color: sub)),
                    ])),
                    Icon(Icons.chevron_right_rounded, color: sub, size: 24),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              // Disable
              GestureDetector(
                onTap: _confirmDisable,
                child: GlassSurface(
                  dark: dark, radius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withOpacity(0.12)),
                      child: const Icon(Icons.lock_open_rounded, size: 20, color: Colors.redAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Disable App Lock', style: manrope(size: 14.5, weight: FontWeight.w800, color: Colors.redAccent)),
                      const SizedBox(height: 2),
                      Text('Remove PIN protection', style: manrope(size: 12, weight: FontWeight.w500, color: sub)),
                    ])),
                    Icon(Icons.chevron_right_rounded, color: sub, size: 24),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP LOCK VERIFY SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AppLockVerifyScreen extends StatefulWidget {
  final bool dark;
  final VoidCallback? onVerified;
  const AppLockVerifyScreen({super.key, required this.dark, this.onVerified});

  @override
  State<AppLockVerifyScreen> createState() => _AppLockVerifyScreenState();
}

class _AppLockVerifyScreenState extends State<AppLockVerifyScreen>
    with TickerProviderStateMixin {
  int _pinLength = 4;
  String _enteredPin = '';
  bool _wrongPin = false;
  bool _pinLoaded = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    _loadPinLength();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPinLength() async {
    final len = await AppLockService.getPinLength();
    if (mounted) setState(() { _pinLength = len; _pinLoaded = true; });
  }

  void _onDigit(String d) {
    if (_enteredPin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() { _enteredPin += d; _wrongPin = false; });
    if (_enteredPin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 100), _verify);
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() { _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1); _wrongPin = false; });
  }

  Future<void> _verify() async {
    final correct = await AppLockService.verifyPin(_enteredPin);
    if (!mounted) return;
    if (correct) {
      HapticFeedback.heavyImpact();
      AppLockService.lockShown = false;
      if (widget.onVerified != null) {
        widget.onVerified!();
      } else {
        Navigator.of(context).pop();
      }
    } else {
      HapticFeedback.vibrate();
      await _shakeCtrl.forward(from: 0);
      if (!mounted) return;
      setState(() { _enteredPin = ''; _wrongPin = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
        body: Stack(
          children: [
            GlassBackdrop(dark: dark),
            SafeArea(
              child: !_pinLoaded
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        const Spacer(flex: 2),
                        _GlowIcon(dark: dark, icon: Icons.lock_rounded, size: 80),
                        const SizedBox(height: 28),
                        Text('App Locked',
                            style: manrope(size: 26, weight: FontWeight.w900, color: fg)),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _wrongPin ? 'Incorrect PIN. Try again.' : 'Enter your PIN to continue',
                            key: ValueKey(_wrongPin),
                            style: manrope(
                              size: 14,
                              weight: FontWeight.w500,
                              color: _wrongPin ? Colors.redAccent : sub,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
                          child: _PinDots(
                            dark: dark,
                            total: _pinLength,
                            filled: _enteredPin.length,
                            isError: _wrongPin,
                          ),
                        ),
                        const Spacer(flex: 3),
                        _NumPad(dark: dark, onDigit: _onDigit, onDelete: _onDelete),
                        const SizedBox(height: 28),
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
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool dark;
  final String title;
  final VoidCallback onBack;
  const _TopBar({required this.dark, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: GlassHeader(
        dark: dark,
        padding: const EdgeInsets.only(left: 7, right: 8),
        child: Row(children: [
          GlassCircleButton(dark: dark, icon: Icons.arrow_back_ios_new_rounded, iconSize: 16, onTap: onBack),
          const SizedBox(width: 10),
          Text(title, style: manrope(size: 17, weight: FontWeight.w800, color: GlassTokens.fg(dark))),
        ]),
      ),
    );
  }
}

class _GlowIcon extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final double size;
  const _GlowIcon({required this.dark, required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: dark
              ? [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.06)]
              : [Colors.black.withOpacity(0.12), Colors.black.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: dark ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
            blurRadius: 32, spreadRadius: 8,
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Icon(icon, size: size * 0.5, color: GlassTokens.fg(dark)),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final bool dark;
  final int total;
  final int filled;
  final bool isError;
  const _PinDots({required this.dark, required this.total, required this.filled, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final dotColor = isError ? Colors.redAccent : GlassTokens.fg(dark);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          margin: EdgeInsets.symmetric(horizontal: total == 4 ? 12 : 8),
          width: isFilled ? 16 : 14,
          height: isFilled ? 16 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? dotColor : Colors.transparent,
            border: Border.all(
              color: isFilled ? dotColor : dotColor.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: isFilled
                ? [BoxShadow(color: dotColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)]
                : null,
          ),
        );
      }),
    );
  }
}

class _NumPad extends StatelessWidget {
  final bool dark;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  const _NumPad({required this.dark, required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          _numRow(['1', '2', '3']),
          const SizedBox(height: 14),
          _numRow(['4', '5', '6']),
          const SizedBox(height: 14),
          _numRow(['7', '8', '9']),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 88, height: 66),
              _NumButton(dark: dark, onTap: () => onDigit('0'),
                  child: Text('0', style: manrope(size: 24, weight: FontWeight.w600, color: GlassTokens.fg(dark)))),
              _NumButton(dark: dark, onTap: onDelete,
                  child: Icon(Icons.backspace_outlined, color: GlassTokens.fg(dark), size: 22)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numRow(List<String> labels) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.map((l) => _NumButton(
        dark: dark,
        onTap: () => onDigit(l),
        child: Text(l, style: manrope(size: 24, weight: FontWeight.w600, color: GlassTokens.fg(dark))),
      )).toList(),
    );
  }
}

class _NumButton extends StatefulWidget {
  final bool dark;
  final Widget child;
  final VoidCallback onTap;
  const _NumButton({required this.dark, required this.child, required this.onTap});

  @override
  State<_NumButton> createState() => _NumButtonState();
}

class _NumButtonState extends State<_NumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: SizedBox(
          width: 88,
          height: 66,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _pressed
                        ? (dark
                            ? [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.10)]
                            : [Colors.black.withOpacity(0.14), Colors.black.withOpacity(0.07)])
                        : GlassTokens.glassBg(dark),
                  ),
                  border: Border.all(color: GlassTokens.glassBorder(dark), width: 1),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinLengthCard extends StatelessWidget {
  final bool dark;
  final int digits;
  final bool selected;
  final VoidCallback onTap;
  const _PinLengthCard({required this.dark, required this.digits, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? (dark
                        ? [Colors.white.withOpacity(0.16), Colors.white.withOpacity(0.08)]
                        : [Colors.black.withOpacity(0.10), Colors.black.withOpacity(0.04)])
                    : GlassTokens.glassBg(dark),
              ),
              border: Border.all(
                color: selected
                    ? (dark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.28))
                    : GlassTokens.glassBorder(dark),
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [GlassTokens.cardShadow(dark)],
            ),
            child: Column(
              children: [
                Text('$digits', style: manrope(size: 36, weight: FontWeight.w900, color: fg)),
                const SizedBox(height: 4),
                Text('digit PIN', style: manrope(size: 12, weight: FontWeight.w600, color: sub)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(digits, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7, height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? fg : sub),
                  )),
                ),
                if (selected) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('Selected', style: manrope(size: 10, weight: FontWeight.w800, color: fg)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final bool dark;
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.dark, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: dark ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: manrope(size: 16, weight: FontWeight.w800, color: dark ? Colors.black : Colors.white)),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final bool dark;
  final IconData icon;
  const _IconCircle({required this.dark, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? Colors.white.withOpacity(0.09) : Colors.black.withOpacity(0.06),
      ),
      child: Icon(icon, size: 20, color: GlassTokens.fg(dark)),
    );
  }
}
