// lib/screens/auth/signup_screen.dart
//
// Glass signup — single file. Same auth logic as before.
// • Auto theme: follows device system brightness
// • Backdrop fills full screen incl. behind gesture nav (no white strip)
// • Black/white shades only (Google glyph keeps brand colors)
// • Real-time username availability check with debounce (500ms)

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'email_verification_pending_screen.dart';
import '../interest_screen.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/error_dialog.dart';

// ── Username check status ─────────────────────────────────────────────────────
enum _UStatus { idle, typing, loading, available, taken, error }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController     = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword     = true;
  bool _isLoading           = false;

  // ── Username availability state ─────────────────────────────────────────────
  _UStatus _uStatus        = _UStatus.idle;
  String   _uMessage       = '';
  List<String> _uSuggestions = [];
  Timer?   _uDebounce;
  // In-memory cache: username → available bool
  final Map<String, bool> _uCache = {};

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _uDebounce?.cancel();
    super.dispose();
  }

  // ── Username input handler ──────────────────────────────────────────────────

  void _onUsernameChanged(String raw) {
    // 1. Sanitize on the fly
    final cleaned = _sanitize(raw);
    if (cleaned != raw) {
      _usernameController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }

    // 2. Immediate feedback for short/empty input
    if (cleaned.isEmpty) {
      _uDebounce?.cancel();
      setState(() { _uStatus = _UStatus.idle; _uMessage = ''; _uSuggestions = []; });
      return;
    }
    if (cleaned.length < 3) {
      _uDebounce?.cancel();
      setState(() { _uStatus = _UStatus.typing; _uMessage = 'Keep typing…'; _uSuggestions = []; });
      return;
    }

    // 3. Cache hit → instant result
    if (_uCache.containsKey(cleaned)) {
      _uDebounce?.cancel();
      final avail = _uCache[cleaned]!;
      setState(() {
        _uStatus    = avail ? _UStatus.available : _UStatus.taken;
        _uMessage   = avail ? '@$cleaned is available' : '@$cleaned is taken';
        _uSuggestions = [];
      });
      return;
    }

    // 4. Start debounce (500 ms)
    setState(() { _uStatus = _UStatus.typing; _uMessage = ''; });
    _uDebounce?.cancel();
    _uDebounce = Timer(const Duration(milliseconds: 500), () => _checkUsername(cleaned));
  }

  static String _sanitize(String raw) {
    String s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\s\-]+'), '_');
    s = s.replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    s = s.replaceAll(RegExp(r'[_.]{2,}'), '_');
    s = s.replaceAll(RegExp(r'^[_.]|[_.]$'), '');
    if (s.length > 20) s = s.substring(0, 20);
    return s;
  }

  Future<void> _checkUsername(String username) async {
    if (!mounted) return;
    // Guard: if user typed something else while we were waiting, skip
    if (_usernameController.text != username) return;

    setState(() { _uStatus = _UStatus.loading; });

    try {
      final uri = Uri.parse('$baseUrl/users/check-username').replace(
        queryParameters: {'username': username},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      // Guard: user may have typed something different while request was in flight
      if (_usernameController.text != username) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final avail = data['available'] as bool;
          final sanitized = (data['sanitized_username'] as String?) ?? username;
          final suggestions = List<String>.from(data['suggestions'] ?? []);

          // Update text field to server-sanitized version
          if (sanitized != username) {
            _usernameController.value = TextEditingValue(
              text: sanitized,
              selection: TextSelection.collapsed(offset: sanitized.length),
            );
          }

          _uCache[sanitized] = avail;
          setState(() {
            _uStatus      = avail ? _UStatus.available : _UStatus.taken;
            _uMessage     = avail ? '@$sanitized is available' : '@$sanitized is already taken';
            _uSuggestions = avail ? [] : suggestions;
          });
        } else {
          setState(() {
            _uStatus  = _UStatus.error;
            _uMessage = (data['message'] as String?) ?? 'Invalid username';
            _uSuggestions = [];
          });
        }
      } else if (res.statusCode == 429) {
        setState(() { _uStatus = _UStatus.error; _uMessage = 'Too many requests, slow down'; });
      } else {
        setState(() { _uStatus = _UStatus.error; _uMessage = 'Could not check — tap to retry'; });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() { _uStatus = _UStatus.error; _uMessage = 'Timeout — tap to retry'; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _uStatus = _UStatus.error; _uMessage = 'Network error — tap to retry'; });
    }
  }

  void _retryUsernameCheck() {
    final u = _usernameController.text;
    if (u.length < 3) return;
    _uCache.remove(u);
    _checkUsername(u);
  }

  void _selectSuggestion(String s) {
    _usernameController.value = TextEditingValue(
      text: s, selection: TextSelection.collapsed(offset: s.length),
    );
    _uCache[s] = true;
    setState(() {
      _uStatus      = _UStatus.available;
      _uMessage     = '@$s is available';
      _uSuggestions = [];
    });
  }

  // ── Auth handlers ───────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    showErrorDialog(context, message: message);
  }

  Future<DateTime?> _showDobPicker(BuildContext context, _GlassTheme t) async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 18, now.month, now.day);
    final firstDate = DateTime(now.year - 100);
    final lastDate = now;

    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'SELECT YOUR DATE OF BIRTH'.tr(context),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: t.dark
                ? ColorScheme.dark(
                    primary: t.fg,
                    onPrimary: t.bgStops.last,
                    surface: t.bgStops.first,
                    onSurface: t.fg,
                    secondary: t.muted,
                  )
                : ColorScheme.light(
                    primary: t.fg,
                    onPrimary: t.bgStops.last,
                    surface: t.bgStops.first,
                    onSurface: t.fg,
                    secondary: t.muted,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: t.bgStops.first,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: t.fg,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _handleSignUp() async {
    final name     = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields'.tr(context));
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters'.tr(context));
      return;
    }
    if (_uStatus == _UStatus.taken) {
      _showError('That username is taken. Choose another.'.tr(context));
      return;
    }
    if (_uStatus == _UStatus.loading || _uStatus == _UStatus.typing) {
      _showError('Please wait while we check your username...'.tr(context));
      return;
    }
    if (_uStatus == _UStatus.error) {
      _showError('Please fix the username before continuing.'.tr(context));
      return;
    }

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final t = _GlassTheme.of(isDark);
    final dob = await _showDobPicker(context, t);
    if (dob == null) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.initiateFirebaseSignup(email: email, password: password);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationPendingScreen(
            email: email, name: name, username: username, password: password,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _showError('This email is already registered. Please sign in.'); break;
        case 'invalid-email':
          _showError('Please enter a valid email address.'); break;
        case 'weak-password':
          _showError('Password is too weak. Use at least 6 characters.'); break;
        default:
          _showError(e.message ?? 'Something went wrong. Try again.');
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not connect. Check your network.'.tr(context));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final t = _GlassTheme.of(isDark);
    final dob = await _showDobPicker(context, t);
    if (dob == null) return;

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
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final t = _GlassTheme.of(isDark);

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
      backgroundColor: t.bgStops.last,
      resizeToAvoidBottomInset: true,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Stack(fit: StackFit.expand, children: [
          Positioned.fill(child: _Backdrop(t: t)),
          Positioned(
            top: 40 + media.padding.top, right: -30,
            child: Transform.rotate(
              angle: 0.31,
              child: _GlassChip(t: t, size: 130, radius: 36),
            ),
          ),
          Positioned(
            top: 200 + media.padding.top, left: -40,
            child: Transform.rotate(
              angle: -0.24,
              child: _GlassChip(t: t, size: 90, radius: 26),
            ),
          ),
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
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: _GlassMark(t: t, size: 56, radius: 18)),
                          const SizedBox(height: 14),
                          Center(
                            child: Text('Create account'.tr(context),
                                style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5, color: t.fg,
                                )),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Text('Join the conversation'.tr(context),
                                style: TextStyle(fontSize: 13, color: t.muted)),
                          ),
                          const SizedBox(height: 18),
                          _FieldLabel(label: 'Name'.tr(context), color: t.muted),
                          const SizedBox(height: 8),
                          _GlassField(
                            t: t, controller: _nameController,
                            hint: 'Your full name'.tr(context),
                            prefixIcon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _FieldLabel(label: 'Username'.tr(context), color: t.muted),
                          const SizedBox(height: 8),
                          // ── Username field with availability indicator ──────
                          _UsernameField(
                            t: t,
                            controller: _usernameController,
                            status: _uStatus,
                            onChanged: _onUsernameChanged,
                            onRetry: _retryUsernameCheck,
                          ),
                          // ── Status message ──────────────────────────────────
                          if (_uMessage.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _UStatusMessage(status: _uStatus, message: _uMessage, t: t),
                          ],
                          // ── Suggestions ─────────────────────────────────────
                          if (_uSuggestions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _USuggestions(
                              suggestions: _uSuggestions,
                              t: t,
                              onSelect: _selectSuggestion,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _FieldLabel(label: 'Email'.tr(context), color: t.muted),
                          const SizedBox(height: 8),
                          _GlassField(
                            t: t, controller: _emailController,
                            hint: 'you@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _FieldLabel(label: 'Password'.tr(context), color: t.muted),
                          const SizedBox(height: 8),
                          _GlassField(
                            t: t, controller: _passwordController,
                            hint: 'Create a password'.tr(context),
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            suffixIcon: _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            onSuffixTap: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          const SizedBox(height: 18),
                          _PrimaryPillButton(
                            t: t,
                            label: _isLoading ? 'Sending verification...'.tr(context) : 'Continue'.tr(context),
                            onTap: _isLoading ? null : _handleSignUp,
                          ),
                          const SizedBox(height: 18),
                          _OrDivider(t: t),
                          const SizedBox(height: 18),
                          _GooglePillButton(
                            t: t,
                            onTap: _isLoading ? null : _handleGoogleSignUp,
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              'By creating an account, you agree to our\nTerms of Service and Privacy Policy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11, color: t.muted, height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: GestureDetector(
                              onTap: _isLoading ? null : () => Navigator.pop(context),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(fontSize: 13, color: t.muted),
                                    children: [
                                      TextSpan(text: 'Already have an account?  '.tr(context)),
                                      TextSpan(
                                        text: 'Sign in'.tr(context),
                                        style: TextStyle(
                                          color: t.fg, fontWeight: FontWeight.w700,
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
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USERNAME FIELD  (with availability suffix indicator)
// ─────────────────────────────────────────────────────────────────────────────

class _UsernameField extends StatelessWidget {
  const _UsernameField({
    required this.t,
    required this.controller,
    required this.status,
    required this.onChanged,
    required this.onRetry,
  });
  final _GlassTheme t;
  final TextEditingController controller;
  final _UStatus status;
  final ValueChanged<String> onChanged;
  final VoidCallback onRetry;

  Color get _borderColor {
    return switch (status) {
      _UStatus.available => const Color(0xFF22C55E),
      _UStatus.taken     => const Color(0xFFEF4444),
      _UStatus.error     => const Color(0xFFF97316),
      _UStatus.loading   => const Color(0xFF3B82F6),
      _                  => t.fieldBorder,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.fieldShadow,
        border: Border.all(color: _borderColor, width: 1.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: t.fieldFill,
              ),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.next,
              style: TextStyle(fontSize: 15, color: t.fg),
              cursorColor: t.fg,
              textAlignVertical: TextAlignVertical.center,
              inputFormatters: [
                // Allow a-z A-Z 0-9 _ . space (sanitizer cleans rest)
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.\s]')),
              ],
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.only(top: 15, bottom: 15, right: 16),
                hintText: 'username',
                hintStyle: TextStyle(fontSize: 15, color: t.placeholder),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 18, right: 8),
                  child: Text('@',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: t.fg.withOpacity(0.7),
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _UIndicator(status: status, onRetry: onRetry, t: t),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Trailing icon / spinner
class _UIndicator extends StatelessWidget {
  const _UIndicator({required this.status, required this.onRetry, required this.t});
  final _UStatus status;
  final VoidCallback onRetry;
  final _GlassTheme t;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
      child: switch (status) {
        _UStatus.loading => const SizedBox(
            key: ValueKey('loading'), width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        _UStatus.available => const Icon(
            Icons.check_circle_rounded,
            key: ValueKey('ok'),
            color: Color(0xFF22C55E), size: 20,
          ),
        _UStatus.taken => const Icon(
            Icons.cancel_rounded,
            key: ValueKey('taken'),
            color: Color(0xFFEF4444), size: 20,
          ),
        _UStatus.error => GestureDetector(
            key: const ValueKey('err'),
            onTap: onRetry,
            child: const Icon(Icons.refresh_rounded, color: Color(0xFFF97316), size: 20),
          ),
        _ => const SizedBox.shrink(key: ValueKey('none')),
      },
    );
  }
}

// Status message below field
class _UStatusMessage extends StatelessWidget {
  const _UStatusMessage({required this.status, required this.message, required this.t});
  final _UStatus status; final String message; final _GlassTheme t;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _UStatus.available => const Color(0xFF22C55E),
      _UStatus.taken     => const Color(0xFFEF4444),
      _UStatus.error     => const Color(0xFFF97316),
      _                  => t.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(message, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// Suggestion chips
class _USuggestions extends StatelessWidget {
  const _USuggestions({required this.suggestions, required this.t, required this.onSelect});
  final List<String> suggestions;
  final _GlassTheme t;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6),
          child: Text('Try instead:'.tr(context), style: TextStyle(fontSize: 11, color: t.muted)),
        ),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: suggestions.map((s) => GestureDetector(
            onTap: () => onSelect(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.fieldBorder.withOpacity(0.6)),
                color: t.fieldFill.first.withOpacity(0.3),
              ),
              child: Text('@$s',
                style: TextStyle(fontSize: 12, color: t.fg.withOpacity(0.8), fontWeight: FontWeight.w500)),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME — identical to login_screen.dart so both screens stay in sync
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
      Color(0x52141416), Color(0x42141416), Color(0xF2FFFFFF),
      Color(0x38141416), Color(0x3D141416),
    ],
    cardFill: const [Color(0x61FFFFFF), Color(0x2EFFFFFF)],
    cardBorder: const Color(0xD9FFFFFF),
    cardShadow: const [BoxShadow(color: Color(0x40282050), blurRadius: 60, offset: Offset(0, 30), spreadRadius: -20)],
    fieldFill: const [Color(0x73FFFFFF), Color(0x33FFFFFF)],
    fieldBorder: const Color(0xD9FFFFFF),
    fieldShadow: const [BoxShadow(color: Color(0x2E282050), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -8)],
    btnFill: const [Color(0xFF5A5A60), Color(0xFF3D3D42)],
    btnFg: const Color(0xFFFFFFFF),
    btnBorder: const Color(0x33FFFFFF),
    btnShadow: const [BoxShadow(color: Color(0x59282026), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -10)],
    innerHi: const Color(0xF2FFFFFF),
  );

  static final _dark = _GlassTheme(
    dark: true,
    fg: const Color(0xFFF5F4FF),
    muted: const Color(0x99F5F4FF),
    placeholder: const Color(0x6BF5F4FF),
    bgStops: const [Color(0xFF1C1C1F), Color(0xFF0D0D0F), Color(0xFF050506)],
    orbColors: const [
      Color(0x8CFFFFFF), Color(0x59FFFFFF), Color(0x66FFFFFF),
      Color(0x47FFFFFF), Color(0x52FFFFFF),
    ],
    cardFill: const [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
    cardBorder: const Color(0x2EFFFFFF),
    cardShadow: const [BoxShadow(color: Color(0xB3000000), blurRadius: 60, offset: Offset(0, 30), spreadRadius: -20)],
    fieldFill: const [Color(0x1AFFFFFF), Color(0x08FFFFFF)],
    fieldBorder: const Color(0x29FFFFFF),
    fieldShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -8)],
    btnFill: const [Color(0xFFF2F2F7), Color(0xFFE6E6F5)],
    btnFg: const Color(0xFF0B0A18),
    btnBorder: const Color(0x66FFFFFF),
    btnShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -10)],
    innerHi: const Color(0x59FFFFFF),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.t});
  final _GlassTheme t;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter, radius: 1.4, colors: t.bgStops,
        ),
      ),
      child: ClipRect(
        child: Stack(fit: StackFit.expand, children: [
          _Orb(color: t.orbColors[0], size: 320, left: -60, top: -40),
          _Orb(color: t.orbColors[1], size: 300, right: -60, top: 40),
          _Orb(color: t.orbColors[2], size: 360, left: 30, top: 320),
          _Orb(color: t.orbColors[3], size: 260, right: -50, bottom: 80),
          _Orb(color: t.orbColors[4], size: 300, left: -40, bottom: -30),
        ]),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, this.left, this.right, this.top, this.bottom});
  final Color color;
  final double size;
  final double? left, right, top, bottom;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left, right: right, top: top, bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size, height: size,
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

class _Frosted extends StatelessWidget {
  const _Frosted({required this.child, required this.radius, this.sigma = 24});
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
        radius: 32, sigma: 40,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: t.cardBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
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
  const _GlassChip({required this.t, required this.size, required this.radius});
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
          radius: radius, sigma: 28,
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: t.fieldBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
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
  const _GlassMark({required this.t, this.size = 64, this.radius = 20});
  final _GlassTheme t;
  final double size;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: t.fieldShadow,
      ),
      child: _Frosted(
        radius: radius, sigma: 20,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: t.dark
                  ? const [Color(0x2EFFFFFF), Color(0x0FFFFFFF)]
                  : const [Color(0x80FFFFFF), Color(0x33FFFFFF)],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(label,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: color, letterSpacing: 0.1,
          )),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.t, required this.controller, required this.hint,
    required this.prefixIcon, this.obscureText = false,
    this.suffixIcon, this.onSuffixTap,
    this.keyboardType, this.textInputAction,
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
        radius: 999, sigma: 24,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                        padding: const EdgeInsets.only(right: 18, left: 8),
                        child: Icon(suffixIcon, color: t.muted, size: 20),
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

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({required this.t, required this.label, required this.onTap});
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
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: t.btnFill,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  letterSpacing: -0.2, color: t.btnFg,
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
    final lineColor = t.dark ? const Color(0x38FFFFFF) : const Color(0x2E141628);
    return Row(children: [
      Expanded(child: Divider(color: lineColor, thickness: 1, height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('OR'.tr(context),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: t.muted, letterSpacing: 2.0,
            )),
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
        radius: 999, sigma: 24,
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
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                    Text('Continue with Google'.tr(context),
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600,
                          letterSpacing: -0.2, color: t.fg,
                        )),
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
      width: size, height: size,
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
    canvas.drawPath(Path()
      ..moveTo(24 * s, 9.5 * s)
      ..cubicTo(27.5 * s, 9.5 * s, 30.6 * s, 10.7 * s, 33 * s, 13.1 * s)
      ..lineTo(39.7 * s, 6.4 * s)
      ..cubicTo(35.6 * s, 2.7 * s, 30.2 * s, 0.5 * s, 24 * s, 0.5 * s)
      ..cubicTo(14.8 * s, 0.5 * s, 6.9 * s, 5.8 * s, 3 * s, 13.6 * s)
      ..lineTo(10.8 * s, 19.6 * s)
      ..cubicTo(12.7 * s, 13.9 * s, 18 * s, 9.5 * s, 24 * s, 9.5 * s)
      ..close(), paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(Path()
      ..moveTo(46.5 * s, 24.5 * s)
      ..cubicTo(46.5 * s, 22.9 * s, 46.4 * s, 21.4 * s, 46.1 * s, 20 * s)
      ..lineTo(24 * s, 20 * s)..lineTo(24 * s, 29 * s)..lineTo(36.7 * s, 29 * s)
      ..cubicTo(36.1 * s, 32 * s, 34.4 * s, 34.6 * s, 31.8 * s, 36.3 * s)
      ..lineTo(39.4 * s, 42.2 * s)
      ..cubicTo(43.8 * s, 38.1 * s, 46.5 * s, 32.1 * s, 46.5 * s, 24.5 * s)
      ..close(), paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(Path()
      ..moveTo(10.8 * s, 28.4 * s)
      ..cubicTo(10.3 * s, 27 * s, 10 * s, 25.5 * s, 10 * s, 24 * s)
      ..cubicTo(10 * s, 22.5 * s, 10.3 * s, 21 * s, 10.8 * s, 19.6 * s)
      ..lineTo(3 * s, 13.6 * s)
      ..cubicTo(1.4 * s, 16.7 * s, 0.5 * s, 20.3 * s, 0.5 * s, 24 * s)
      ..cubicTo(0.5 * s, 27.7 * s, 1.4 * s, 31.3 * s, 3 * s, 34.4 * s)
      ..lineTo(10.8 * s, 28.4 * s)..close(), paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(Path()
      ..moveTo(24 * s, 47.5 * s)
      ..cubicTo(30.2 * s, 47.5 * s, 35.4 * s, 45.5 * s, 39.2 * s, 42.1 * s)
      ..lineTo(31.6 * s, 36.2 * s)
      ..cubicTo(29.5 * s, 37.6 * s, 26.8 * s, 38.5 * s, 24 * s, 38.5 * s)
      ..cubicTo(18 * s, 38.5 * s, 12.7 * s, 34.1 * s, 10.8 * s, 28.4 * s)
      ..lineTo(3 * s, 34.4 * s)
      ..cubicTo(6.9 * s, 42.2 * s, 14.8 * s, 47.5 * s, 24 * s, 47.5 * s)
      ..close(), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
