// lib/screens/auth/login_screen.dart
//
// Glass login — single file. Same auth logic as before.
// • Auto theme: follows the device system brightness (light/dark)
// • Pixel-clean: backdrop fills the entire screen incl. behind the
//   system gesture bar — no white strip at the bottom
// • Black/white shades only (Google glyph keeps its brand colors)

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'signup_screen.dart';
import '../interest_screen.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/error_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword     = true;
  bool _isLoading           = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    showErrorDialog(context, message: message);
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields'.tr(context));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.login(email, password);
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const InterestGateScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not connect to server. Check your network.'.tr(context));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.loginWithGoogle();
      if (result == null) return;
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const InterestGateScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Google sign-in failed. Try again.'.tr(context));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Follow the app-level Theme which listens to system brightness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _GlassTheme.of(isDark);

    // Tint the system bars so the status bar icons stay readable.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: t.bgStops.last,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    final media = MediaQuery.of(context);

    return Scaffold(
      // Critical: background colour matches backdrop base so there is no
      // light strip behind the nav bar / when keyboard opens.
      backgroundColor: t.bgStops.last,
      resizeToAvoidBottomInset: true,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Backdrop: full screen including behind status & nav ────
            Positioned.fill(child: _Backdrop(t: t)),

            // ── Decorative glass chips ─────────────────────────────────
            Positioned(
              top: 60 + media.padding.top,
              right: -30,
              child: Transform.rotate(
                angle: 0.31,
                child: _GlassChip(t: t, size: 130, radius: 36),
              ),
            ),
            Positioned(
              top: 210 + media.padding.top,
              left: -40,
              child: Transform.rotate(
                angle: -0.24,
                child: _GlassChip(t: t, size: 90, radius: 26),
              ),
            ),

            // ── Card ───────────────────────────────────────────────────
            SafeArea(
              minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _GlassCard(
                      t: t,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(22, 28, 22, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: _GlassMark(t: t)),
                            const SizedBox(height: 18),
                            Center(
                              child: Text(
                                'Welcome back'.tr(context),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: t.fg,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Sign in to continue'.tr(context),
                                style: TextStyle(
                                    fontSize: 14, color: t.muted),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _FieldLabel(label: 'Email'.tr(context), color: t.muted),
                            const SizedBox(height: 8),
                            _GlassField(
                              t: t,
                              controller: _emailController,
                              hint: 'you@example.com',
                              prefixIcon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            _FieldLabel(label: 'Password'.tr(context), color: t.muted),
                            const SizedBox(height: 8),
                            _GlassField(
                              t: t,
                              controller: _passwordController,
                              hint: 'Enter your password'.tr(context),
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              suffixIcon: _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              onSuffixTap: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {/* TODO: forgot password */},
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4),
                                  child: Text(
                                    'Forgot password?'.tr(context),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: t.fg,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _PrimaryPillButton(
                              t: t,
                              label:
                                  _isLoading ? 'Signing in...'.tr(context) : 'Sign in'.tr(context),
                              onTap:
                                  _isLoading ? null : _handleSignIn,
                            ),
                            const SizedBox(height: 18),
                            _OrDivider(t: t),
                            const SizedBox(height: 18),
                            _GooglePillButton(
                              t: t,
                              onTap: _isLoading
                                  ? null
                                  : _handleGoogleSignIn,
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SignUpScreen(),
                                          ),
                                        ),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                          fontSize: 13, color: t.muted),
                                      children: [
                                        TextSpan(
                                            text:
                                                "Don't have an account?  ".tr(context)),
                                        TextSpan(
                                          text: 'Sign up'.tr(context),
                                          style: TextStyle(
                                            color: t.fg,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────
class _GlassTheme {
  final bool dark;
  final Color fg;
  final Color muted;
  final Color placeholder;
  final List<Color> bgStops;
  final List<Color> orbColors;
  final List<Color> cardFill;
  final Color cardBorder;
  final List<BoxShadow> cardShadow;
  final List<Color> fieldFill;
  final Color fieldBorder;
  final List<BoxShadow> fieldShadow;
  final List<Color> btnFill;
  final Color btnFg;
  final Color btnBorder;
  final List<BoxShadow> btnShadow;
  final Color innerHi;

  const _GlassTheme({
    required this.dark,
    required this.fg,
    required this.muted,
    required this.placeholder,
    required this.bgStops,
    required this.orbColors,
    required this.cardFill,
    required this.cardBorder,
    required this.cardShadow,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldShadow,
    required this.btnFill,
    required this.btnFg,
    required this.btnBorder,
    required this.btnShadow,
    required this.innerHi,
  });

  static _GlassTheme of(bool dark) => dark ? _dark : _light;

  static final _light = _GlassTheme(
    dark: false,
    fg: const Color(0xFF0E1124),
    muted: const Color(0x8C141628),
    placeholder: const Color(0x6B141628),
    bgStops: const [Color(0xFFF4F4F6), Color(0xFFE4E4E8), Color(0xFFD6D6DC)],
    orbColors: const [
      Color(0x52141416),
      Color(0x42141416),
      Color(0xF2FFFFFF),
      Color(0x38141416),
      Color(0x3D141416),
    ],
    cardFill: const [Color(0x61FFFFFF), Color(0x2EFFFFFF)],
    cardBorder: const Color(0xD9FFFFFF),
    cardShadow: const [
      BoxShadow(
          color: Color(0x40282050),
          blurRadius: 60,
          offset: Offset(0, 30),
          spreadRadius: -20),
    ],
    fieldFill: const [Color(0x73FFFFFF), Color(0x33FFFFFF)],
    fieldBorder: const Color(0xD9FFFFFF),
    fieldShadow: const [
      BoxShadow(
          color: Color(0x2E282050),
          blurRadius: 18,
          offset: Offset(0, 6),
          spreadRadius: -8),
    ],
    btnFill: const [Color(0xFF5A5A60), Color(0xFF3D3D42)],
    btnFg: const Color(0xFFFFFFFF),
    btnBorder: const Color(0x33FFFFFF),
    btnShadow: const [
      BoxShadow(
          color: Color(0x59282026),
          blurRadius: 30,
          offset: Offset(0, 14),
          spreadRadius: -10),
    ],
    innerHi: const Color(0xF2FFFFFF),
  );

  static final _dark = _GlassTheme(
    dark: true,
    fg: const Color(0xFFF5F4FF),
    muted: const Color(0x99F5F4FF),
    placeholder: const Color(0x6BF5F4FF),
    bgStops: const [Color(0xFF1C1C1F), Color(0xFF0D0D0F), Color(0xFF050506)],
    orbColors: const [
      Color(0x8CFFFFFF),
      Color(0x59FFFFFF),
      Color(0x66FFFFFF),
      Color(0x47FFFFFF),
      Color(0x52FFFFFF),
    ],
    cardFill: const [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
    cardBorder: const Color(0x2EFFFFFF),
    cardShadow: const [
      BoxShadow(
          color: Color(0xB3000000),
          blurRadius: 60,
          offset: Offset(0, 30),
          spreadRadius: -20),
    ],
    fieldFill: const [Color(0x1AFFFFFF), Color(0x08FFFFFF)],
    fieldBorder: const Color(0x29FFFFFF),
    fieldShadow: const [
      BoxShadow(
          color: Color(0x80000000),
          blurRadius: 18,
          offset: Offset(0, 6),
          spreadRadius: -8),
    ],
    btnFill: const [Color(0xFFF2F2F7), Color(0xFFE6E6F5)],
    btnFg: const Color(0xFF0B0A18),
    btnBorder: const Color(0x66FFFFFF),
    btnShadow: const [
      BoxShadow(
          color: Color(0x99000000),
          blurRadius: 30,
          offset: Offset(0, 14),
          spreadRadius: -10),
    ],
    innerHi: const Color(0x59FFFFFF),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BACKDROP
// ─────────────────────────────────────────────────────────────────────────────
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.t});
  final _GlassTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: t.bgStops,
        ),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Orb(color: t.orbColors[0], size: 320, left: -60, top: -40),
            _Orb(color: t.orbColors[1], size: 300, right: -60, top: 40),
            _Orb(color: t.orbColors[2], size: 360, left: 30, top: 320),
            _Orb(color: t.orbColors[3], size: 260, right: -50, bottom: 80),
            _Orb(color: t.orbColors[4], size: 300, left: -40, bottom: -30),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.color,
    required this.size,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });
  final Color color;
  final double size;
  final double? left, right, top, bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS SURFACES
// ─────────────────────────────────────────────────────────────────────────────
class _Frosted extends StatelessWidget {
  const _Frosted({
    required this.child,
    required this.radius,
    this.sigma = 24,
  });
  final Widget child;
  final double radius;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.t, required this.child});
  final _GlassTheme t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: t.cardShadow,
      ),
      child: _Frosted(
        radius: 32,
        sigma: 40,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: t.cardBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.cardFill,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(
      {required this.t, required this.size, required this.radius});
  final _GlassTheme t;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: t.fieldShadow,
        ),
        child: _Frosted(
          radius: radius,
          sigma: 28,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: t.fieldBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: t.dark
                    ? const [Color(0x24FFFFFF), Color(0x0AFFFFFF)]
                    : const [Color(0x59FFFFFF), Color(0x1AFFFFFF)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMark extends StatelessWidget {
  const _GlassMark({required this.t});
  final _GlassTheme t;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: t.fieldShadow,
      ),
      child: _Frosted(
        radius: 20,
        sigma: 20,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.dark
                  ? const [Color(0x2EFFFFFF), Color(0x0FFFFFFF)]
                  : const [Color(0x80FFFFFF), Color(0x33FFFFFF)],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icons/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.t,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
    this.textInputAction,
  });

  final _GlassTheme t;
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.fieldShadow,
      ),
      child: _Frosted(
        radius: 999,
        sigma: 24,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.fieldFill,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: TextStyle(fontSize: 15, color: t.fg),
            cursorColor: t.fg,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.only(top: 15, bottom: 15, right: 16),
              hintText: hint,
              hintStyle: TextStyle(fontSize: 15, color: t.placeholder),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 18, right: 12),
                child: Icon(prefixIcon, color: t.muted, size: 20),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: suffixIcon != null
                  ? GestureDetector(
                      onTap: onSuffixTap,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 18, left: 8),
                        child: Icon(suffixIcon,
                            color: t.muted, size: 20),
                      ),
                    )
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUTTONS
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({
    required this.t,
    required this.label,
    required this.onTap,
  });
  final _GlassTheme t;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.btnShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: t.btnBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: t.btnFill,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: t.btnFg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.t});
  final _GlassTheme t;
  @override
  Widget build(BuildContext context) {
    final lineColor =
        t.dark ? const Color(0x38FFFFFF) : const Color(0x2E141628);
    return Row(children: [
      Expanded(child: Divider(color: lineColor, thickness: 1, height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'OR'.tr(context),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: t.muted,
            letterSpacing: 2.0,
          ),
        ),
      ),
      Expanded(child: Divider(color: lineColor, thickness: 1, height: 1)),
    ]);
  }
}

class _GooglePillButton extends StatelessWidget {
  const _GooglePillButton({required this.t, required this.onTap});
  final _GlassTheme t;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.fieldShadow,
      ),
      child: _Frosted(
        radius: 999,
        sigma: 24,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.fieldBorder, width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: t.dark
                      ? const [Color(0x1AFFFFFF), Color(0x08FFFFFF)]
                      : const [Color(0x80FFFFFF), Color(0x38FFFFFF)],
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleGlyph(size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google'.tr(context),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: t.fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(
      Path()
        ..moveTo(24 * s, 9.5 * s)
        ..cubicTo(27.5 * s, 9.5 * s, 30.6 * s, 10.7 * s, 33 * s, 13.1 * s)
        ..lineTo(39.7 * s, 6.4 * s)
        ..cubicTo(35.6 * s, 2.7 * s, 30.2 * s, 0.5 * s, 24 * s, 0.5 * s)
        ..cubicTo(14.8 * s, 0.5 * s, 6.9 * s, 5.8 * s, 3 * s, 13.6 * s)
        ..lineTo(10.8 * s, 19.6 * s)
        ..cubicTo(12.7 * s, 13.9 * s, 18 * s, 9.5 * s, 24 * s, 9.5 * s)
        ..close(),
      paint,
    );
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(
      Path()
        ..moveTo(46.5 * s, 24.5 * s)
        ..cubicTo(46.5 * s, 22.9 * s, 46.4 * s, 21.4 * s, 46.1 * s, 20 * s)
        ..lineTo(24 * s, 20 * s)
        ..lineTo(24 * s, 29 * s)
        ..lineTo(36.7 * s, 29 * s)
        ..cubicTo(36.1 * s, 32 * s, 34.4 * s, 34.6 * s, 31.8 * s, 36.3 * s)
        ..lineTo(39.4 * s, 42.2 * s)
        ..cubicTo(43.8 * s, 38.1 * s, 46.5 * s, 32.1 * s, 46.5 * s, 24.5 * s)
        ..close(),
      paint,
    );
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(
      Path()
        ..moveTo(10.8 * s, 28.4 * s)
        ..cubicTo(10.3 * s, 27 * s, 10 * s, 25.5 * s, 10 * s, 24 * s)
        ..cubicTo(10 * s, 22.5 * s, 10.3 * s, 21 * s, 10.8 * s, 19.6 * s)
        ..lineTo(3 * s, 13.6 * s)
        ..cubicTo(1.4 * s, 16.7 * s, 0.5 * s, 20.3 * s, 0.5 * s, 24 * s)
        ..cubicTo(0.5 * s, 27.7 * s, 1.4 * s, 31.3 * s, 3 * s, 34.4 * s)
        ..lineTo(10.8 * s, 28.4 * s)
        ..close(),
      paint,
    );
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(
      Path()
        ..moveTo(24 * s, 47.5 * s)
        ..cubicTo(30.2 * s, 47.5 * s, 35.4 * s, 45.5 * s, 39.2 * s, 42.1 * s)
        ..lineTo(31.6 * s, 36.2 * s)
        ..cubicTo(29.5 * s, 37.6 * s, 26.8 * s, 38.5 * s, 24 * s, 38.5 * s)
        ..cubicTo(18 * s, 38.5 * s, 12.7 * s, 34.1 * s, 10.8 * s, 28.4 * s)
        ..lineTo(3 * s, 34.4 * s)
        ..cubicTo(6.9 * s, 42.2 * s, 14.8 * s, 47.5 * s, 24 * s, 47.5 * s)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
