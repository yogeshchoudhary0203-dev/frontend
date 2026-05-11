import 'dart:async';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String name;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.name,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying  = false;
  bool _isResending  = false;
  int  _resendTimer  = 60; // seconds before resend is allowed
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-verify when all 6 digits entered
    if (_otp.length == 6) {
      _handleVerify();
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _handleVerify() async {
    if (_otp.length != 6) {
      _showMessage('Please enter the complete 6-digit OTP');
      return;
    }
    if (_isVerifying) return;

    setState(() => _isVerifying = true);
    try {
      await AuthService.verifyEmailOtp(
        email: widget.email,
        otp: _otp,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      _showMessage(e.message);
      // Clear OTP fields on wrong attempt
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    } catch (_) {
      _showMessage('Could not connect to server. Check your network.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleResend() async {
    if (_resendTimer > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await AuthService.resendOtp(widget.email);
      _showMessage('New OTP sent to ${widget.email}', isError: false);
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      _startResendTimer();
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not resend OTP. Try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColors = isDark
        ? [const Color(0xFF1F1F22), const Color(0xFF0E0E10), const Color(0xFF050506)]
        : [const Color(0xFFFFFFFF), const Color(0xFFF4F4F5), const Color(0xFFECECEE)];

    final inputBg     = isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
    final inputBorder = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E5E5);
    final textPrimary = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF0A0A0A);
    final textSecond  = isDark ? const Color(0xFF8B8B93) : const Color(0xFF737373);
    final btnBg       = isDark ? const Color(0xFFECECEE) : const Color(0xFF2A2A2A);
    final btnText     = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF);
    final logoBg      = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1F1F1F);
    final logoMark    = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF);
    final accentColor = const Color(0xFF6C63FF);

    // Mask email for display: y***@gmail.com
    final emailParts  = widget.email.split('@');
    final maskedEmail = emailParts.isNotEmpty
        ? '${emailParts[0].substring(0, (emailParts[0].length).clamp(1, 2))}***@${emailParts.length > 1 ? emailParts[1] : ''}'
        : widget.email;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: bgColors,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                Center(
                  child: Column(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: logoBg, borderRadius: BorderRadius.circular(13)),
                      child: Center(
                        child: Text('✦',
                            style: TextStyle(
                                color: logoMark, fontSize: 24, height: 1.0)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Verify your email',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 6),
                    Text(
                      'We sent a 6-digit code to\n$maskedEmail',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: textSecond, height: 1.5),
                    ),
                  ]),
                ),
                const SizedBox(height: 40),

                // ── OTP Boxes ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 46, height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: inputBg,
                        border: Border.all(
                          color: _controllers[i].text.isNotEmpty
                              ? accentColor
                              : inputBorder,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textPrimary),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          setState(() {});
                          _onDigitChanged(i, v);
                        },
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                // ── Verify Button ─────────────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _handleVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnBg,
                      foregroundColor: btnText,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                    child: Text(
                      _isVerifying ? 'Verifying…' : 'Verify & Create Account',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: btnText),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Resend ────────────────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _resendTimer == 0 && !_isResending
                        ? _handleResend
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _isResending
                          ? Text('Sending…',
                              style: TextStyle(
                                  fontSize: 13, color: accentColor))
                          : _resendTimer > 0
                              ? RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 13, color: textSecond),
                                    children: [
                                      const TextSpan(
                                          text: 'Resend OTP in '),
                                      TextSpan(
                                          text: '${_resendTimer}s',
                                          style: TextStyle(
                                              color: textPrimary,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )
                              : Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: accentColor,
                                      fontWeight: FontWeight.w500),
                                ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Back ──────────────────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 13, color: textSecond),
                          children: [
                            const TextSpan(text: '← '),
                            TextSpan(
                                text: 'Go back',
                                style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
