import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../glass_common.dart';

/// Parental-consent gate for users aged 13–17.
///
/// Verifies a parent/guardian's phone number via Firebase Phone Auth (OTP).
/// On success it pops the verified phone number (String); the signup flow then
/// continues. To keep the email/Google signup session completely untouched, the
/// phone credential is only used to PROVE ownership — we sign in with it, delete
/// that throwaway phone user, and sign out again before returning.
class ParentConsentScreen extends StatefulWidget {
  const ParentConsentScreen({super.key});

  @override
  State<ParentConsentScreen> createState() => _ParentConsentScreenState();
}

enum _Phase { phone, otp }

class _ParentConsentScreenState extends State<ParentConsentScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  _Phase _phase = _Phase.phone;
  bool _loading = false;
  String? _error;
  String _verificationId = '';
  String _fullPhone = '';

  static const _accent = Color(0xFF6C63FF);

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── Step 1: confirm the number, then send the OTP ──────────────────────────
  Future<void> _onContinuePhone() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    final full = '+91$digits';
    final confirmed = await _confirmNumber(full);
    if (confirmed != true) return;
    await _sendOtp(full);
  }

  Future<bool?> _confirmNumber(String full) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final fg = GlassTokens.fg(isDark);
    final sub = GlassTokens.sub(isDark);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Check this number is correct',
            style: manrope(size: 17, weight: FontWeight.w800, color: fg)),
        content: Text(
          "We'll send a one-time verification code to:\n\n$full\n\n"
          "Make sure this is a parent or guardian's number.",
          style: manrope(size: 14, weight: FontWeight.w500, color: sub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Edit', style: manrope(size: 14, weight: FontWeight.w700, color: sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Done', style: manrope(size: 14, weight: FontWeight.w700, color: _accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOtp(String full) async {
    setState(() {
      _loading = true;
      _error = null;
      _fullPhone = full;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: full,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          await _completeWithCredential(cred);
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            if (e.code == 'quota-exceeded' || e.code == 'too-many-requests') {
              _error = 'Currently unavailable. Please try again later.';
            } else if (e.code == 'invalid-phone-number') {
              _error = 'That phone number looks invalid. Please check and retry.';
            } else {
              _error = 'Could not send the code (${e.code}). Please try again.';
            }
          });
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _verificationId = verificationId;
            _phase = _Phase.otp;
            _error = null;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not send the code. Please try again.';
        });
      }
    }
  }

  // ── Step 2: verify the entered OTP ─────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code you received');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await _completeWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = (e.code == 'invalid-verification-code')
            ? 'Incorrect code. Please check and try again.'
            : 'Verification failed. Please try again.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Verification failed. Please try again.';
        });
      }
    }
  }

  /// Use the phone credential ONLY to prove the parent controls the number, then
  /// delete the throwaway phone user + sign out so the real signup session is
  /// never affected. Returns the verified number to the signup flow.
  Future<void> _completeWithCredential(PhoneAuthCredential cred) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = (e.code == 'invalid-verification-code')
            ? 'Incorrect code. Please check and try again.'
            : 'Verification failed. Please try again.';
      });
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Verification failed. Please try again.';
        });
      }
      return;
    }
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (mounted) Navigator.pop(context, _fullPhone);
  }

  // ── UI (glass theme) ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final fg = GlassTokens.fg(isDark);
    final sub = GlassTokens.sub(isDark);
    final bgStops = isDark
        ? const [Color(0xFF16161B), Color(0xFF0A0A0C), Color(0xFF000000)]
        : const [Color(0xFFFFFFFF), Color(0xFFF2F2F5), Color(0xFFE8E8EC)];
    final isPhone = _phase == _Phase.phone;

    return Scaffold(
      backgroundColor: isDark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: bgStops,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: PressableScale(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back_rounded, color: fg, size: 24),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 12, 26, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassSurface(
                        dark: isDark,
                        radius: 20,
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          isPhone
                              ? Icons.family_restroom_rounded
                              : Icons.sms_outlined,
                          color: _accent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        isPhone ? "Parent's phone number" : 'Verification code',
                        style: manrope(
                            size: 26,
                            weight: FontWeight.w800,
                            color: fg,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isPhone
                            ? "Because you're under 18, we need a parent or "
                                "guardian's phone number to give consent before "
                                "you can continue."
                            : 'Enter the 6-digit code we sent to $_fullPhone.',
                        style: manrope(
                            size: 14,
                            weight: FontWeight.w500,
                            color: sub,
                            height: 1.6),
                      ),
                      const SizedBox(height: 30),

                      // Input — glass surface
                      GlassSurface(
                        dark: isDark,
                        radius: 16,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                        child: isPhone
                            ? Row(
                                children: [
                                  Text('+91',
                                      style: manrope(
                                          size: 16,
                                          weight: FontWeight.w800,
                                          color: fg)),
                                  const SizedBox(width: 12),
                                  Container(
                                      width: 1,
                                      height: 22,
                                      color: sub.withValues(alpha: 0.35)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      cursorColor: _accent,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: manrope(
                                          size: 16,
                                          weight: FontWeight.w700,
                                          color: fg),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        border: InputBorder.none,
                                        hintText: 'Phone number',
                                        hintStyle: manrope(
                                            size: 15,
                                            weight: FontWeight.w500,
                                            color: sub),
                                        contentPadding:
                                            const EdgeInsets.symmetric(vertical: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                cursorColor: _accent,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style: manrope(
                                    size: 22,
                                    weight: FontWeight.w800,
                                    color: fg,
                                    letterSpacing: 10),
                                decoration: InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  hintText: '••••••',
                                  hintStyle: manrope(
                                      size: 22,
                                      weight: FontWeight.w700,
                                      color: sub,
                                      letterSpacing: 10),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                ),
                              ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFE5484D), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_error!,
                                  style: manrope(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFFE5484D))),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Primary button — solid pill (matches signup)
                      PressableScale(
                        onTap: _loading
                            ? null
                            : (isPhone ? _onContinuePhone : _verifyOtp),
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _loading ? fg.withValues(alpha: 0.45) : fg,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [GlassTokens.cardShadow(isDark)],
                          ),
                          child: _loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: isDark ? Colors.black : Colors.white),
                                )
                              : Text(isPhone ? 'Continue' : 'Verify',
                                  style: manrope(
                                      size: 15,
                                      weight: FontWeight.w800,
                                      color:
                                          isDark ? Colors.black : Colors.white)),
                        ),
                      ),

                      if (!isPhone) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: PressableScale(
                            onTap: _loading
                                ? null
                                : () => setState(() {
                                      _phase = _Phase.phone;
                                      _otpController.clear();
                                      _error = null;
                                    }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 12),
                              child: Text('Change number',
                                  style: manrope(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: sub)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
