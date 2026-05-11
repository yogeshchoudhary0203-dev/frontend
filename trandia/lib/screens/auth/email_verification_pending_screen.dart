import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../home/home_screen.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class EmailVerificationPendingScreen extends StatefulWidget {
  final String email;
  final String name;
  final String username;
  final String password;

  const EmailVerificationPendingScreen({
    super.key,
    required this.email,
    required this.name,
    required this.username,
    required this.password,
  });

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  bool _isLoading    = false;
  bool _isResending  = false;
  int  _resendTimer  = 60;
  Timer? _countdownTimer;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startAutoCheck();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _resendTimer = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendTimer > 0) _resendTimer--;
        else t.cancel();
      });
    });
  }

  void _startAutoCheck() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _isLoading) return;
      final verified = await AuthService.checkEmailVerified();
      if (verified && mounted && !_isLoading) {
        _autoCheckTimer?.cancel();
        await _doCompleteSignup();
      }
    });
  }

  void _showMsg(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _doCompleteSignup() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.completeSignup(
        email: widget.email,
        name: widget.name,
        username: widget.username,
        password: widget.password,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      _showMsg(e.message);
    } catch (e) {
      _showMsg('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyPressed() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final verified = await AuthService.checkEmailVerified();
    setState(() => _isLoading = false);

    if (!verified) {
      _showMsg('Email not verified yet. Please click the link in your inbox.');
      return;
    }

    await _doCompleteSignup();
  }

  Future<void> _handleResend() async {
    if (_resendTimer > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await AuthService.resendVerificationEmail();
      _showMsg('Verification email resent!', isError: false);
      _startCountdown();
    } catch (e) {
      _showMsg('Could not resend: $e');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _openEmailApp() async {
    final uri = Uri.parse('mailto:');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColors    = isDark ? [const Color(0xFF1F1F22), const Color(0xFF0E0E10), const Color(0xFF050506)] : [const Color(0xFFFFFFFF), const Color(0xFFF4F4F5), const Color(0xFFECECEE)];
    final textPrimary = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF0A0A0A);
    final textSecond  = isDark ? const Color(0xFF8B8B93) : const Color(0xFF737373);
    final cardBg      = isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
    final cardBorder  = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E5E5);
    final btnBg       = isDark ? const Color(0xFFECECEE) : const Color(0xFF2A2A2A);
    final btnText     = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF);
    final accent      = const Color(0xFF6C63FF);

    final parts   = widget.email.split('@');
    final masked  = '${parts[0].substring(0, parts[0].length.clamp(1, 2))}***@${parts.length > 1 ? parts[1] : ''}';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment.topCenter, radius: 1.5, colors: bgColors),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text('✉️', style: const TextStyle(fontSize: 56, height: 1)),
                ),
                const SizedBox(height: 24),
                Text('Check your email', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.3)),
                const SizedBox(height: 10),
                Text('We sent a verification link to\n$masked',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: textSecond, height: 1.6)),
                const SizedBox(height: 32),

                // Steps card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg, border: Border.all(color: cardBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    _Step(n: '1', text: 'Open your email inbox', accent: accent, textColor: textPrimary),
                    const SizedBox(height: 12),
                    _Step(n: '2', text: 'Click the "Verify email" link', accent: accent, textColor: textPrimary),
                    const SizedBox(height: 12),
                    _Step(n: '3', text: 'Come back and press the button below', accent: accent, textColor: textPrimary),
                  ]),
                ),
                const SizedBox(height: 28),

                // Open email app
                SizedBox(height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _openEmailApp,
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('Open Email App'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // I've Verified button
                SizedBox(height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnBg, foregroundColor: btnText,
                      shadowColor: Colors.transparent, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: _isLoading
                        ? SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: btnText))
                        : Text("I've Verified — Continue",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: btnText)),
                  ),
                ),
                const SizedBox(height: 20),

                // Resend
                Center(
                  child: GestureDetector(
                    onTap: _resendTimer == 0 && !_isResending ? _handleResend : null,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _isResending
                          ? Text('Sending…', style: TextStyle(fontSize: 13, color: accent))
                          : _resendTimer > 0
                              ? RichText(text: TextSpan(
                                  style: TextStyle(fontSize: 13, color: textSecond),
                                  children: [
                                    const TextSpan(text: 'Resend in '),
                                    TextSpan(text: '${_resendTimer}s',
                                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                                  ]))
                              : Text('Resend verification email',
                                  style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Back
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('← Go back',
                          style: TextStyle(fontSize: 13, color: textSecond)),
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

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, required this.accent, required this.textColor});
  final String n, text; final Color accent, textColor;
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 26, height: 26,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: Center(child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))),
    const SizedBox(width: 12),
    Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: textColor, height: 1.4))),
  ]);
}
