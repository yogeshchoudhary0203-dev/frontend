import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_verification_pending_screen.dart';
import '../home/home_screen.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _handleSignUp() async {
    final name     = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Create Firebase user + send verification email
      await AuthService.initiateFirebaseSignup(email: email, password: password);

      if (!mounted) return;

      // Navigate to "check your email" screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationPendingScreen(
            email: email,
            name: name,
            username: username,
            password: password,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _showError('This email is already registered. Please sign in.');
          break;
        case 'invalid-email':
          _showError('Please enter a valid email address.');
          break;
        case 'weak-password':
          _showError('Password is too weak. Use at least 6 characters.');
          break;
        default:
          _showError(e.message ?? 'Something went wrong. Try again.');
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not connect. Check your network.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.loginWithGoogle();
      if (result == null) return;
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColors      = isDark ? [const Color(0xFF1F1F22), const Color(0xFF0E0E10), const Color(0xFF050506)] : [const Color(0xFFFFFFFF), const Color(0xFFF4F4F5), const Color(0xFFECECEE)];
    final inputBg       = isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
    final inputBorder   = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E5E5);
    final textPrimary   = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF0A0A0A);
    final textSecondary = isDark ? const Color(0xFF8B8B93) : const Color(0xFF737373);
    final labelColor    = isDark ? const Color(0xFFB5B5BD) : const Color(0xFF525252);
    final iconColor     = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final hintColor     = isDark ? const Color(0xFF71767B) : const Color(0xFF6B7280);
    final btnBg         = isDark ? const Color(0xFFECECEE) : const Color(0xFF2A2A2A);
    final btnText       = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF);
    final dividerColor  = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E5E5);
    final logoBg        = isDark ? const Color(0xFFFAFAFA) : const Color(0xFF1F1F1F);
    final logoMark      = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment.topCenter, radius: 1.5, colors: bgColors),
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
                      decoration: BoxDecoration(color: logoBg, borderRadius: BorderRadius.circular(13)),
                      child: Center(child: Text('✦', style: TextStyle(color: logoMark, fontSize: 24, height: 1.0))),
                    ),
                    const SizedBox(height: 18),
                    Text('Create account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: textPrimary, letterSpacing: -0.3)),
                    const SizedBox(height: 6),
                    Text('Join the conversation', style: TextStyle(fontSize: 13, color: textSecondary)),
                  ]),
                ),
                const SizedBox(height: 36),
                _FieldLabel(label: 'Name', color: labelColor),
                const SizedBox(height: 8),
                _PillTextField(controller: _nameController, hint: 'Your full name', prefixIcon: Icons.person_outline_rounded, keyboardType: TextInputType.name, textInputAction: TextInputAction.next, inputBg: inputBg, inputBorder: inputBorder, iconColor: iconColor, hintColor: hintColor, textColor: textPrimary),
                const SizedBox(height: 16),
                _FieldLabel(label: 'Username', color: labelColor),
                const SizedBox(height: 8),
                _PillTextField(controller: _usernameController, hint: 'username', prefixIcon: Icons.alternate_email_rounded, keyboardType: TextInputType.text, textInputAction: TextInputAction.next, inputBg: inputBg, inputBorder: inputBorder, iconColor: iconColor, hintColor: hintColor, textColor: textPrimary),
                const SizedBox(height: 16),
                _FieldLabel(label: 'Email', color: labelColor),
                const SizedBox(height: 8),
                _PillTextField(controller: _emailController, hint: 'you@example.com', prefixIcon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, inputBg: inputBg, inputBorder: inputBorder, iconColor: iconColor, hintColor: hintColor, textColor: textPrimary),
                const SizedBox(height: 16),
                _FieldLabel(label: 'Password', color: labelColor),
                const SizedBox(height: 8),
                _PillTextField(controller: _passwordController, hint: 'Create a password', prefixIcon: Icons.lock_outline_rounded, obscureText: _obscurePassword, textInputAction: TextInputAction.done, suffixIcon: _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword), inputBg: inputBg, inputBorder: inputBorder, iconColor: iconColor, hintColor: hintColor, textColor: textPrimary),
                const SizedBox(height: 26),
                _PillButton(label: _isLoading ? 'Sending verification…' : 'Continue', bgColor: btnBg, textColor: btnText, onTap: _isLoading ? null : _handleSignUp),
                const SizedBox(height: 26),
                _OrDivider(lineColor: dividerColor, textColor: hintColor),
                const SizedBox(height: 22),
                _GoogleButton(borderColor: inputBorder, bgColor: inputBg, textColor: textPrimary, iconColor: iconColor, onTap: _isLoading ? null : _handleGoogleSignUp),
                const SizedBox(height: 32),
                Center(child: Text('By creating an account, you agree to our\nTerms of Service and Privacy Policy.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: textSecondary, height: 1.6))),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RichText(text: TextSpan(style: TextStyle(fontSize: 13, color: textSecondary), children: [const TextSpan(text: 'Already have an account?  '), TextSpan(text: 'Sign in', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500))])),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.color});
  final String label; final Color color;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 6), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color, letterSpacing: 0.1)));
}

class _PillTextField extends StatelessWidget {
  const _PillTextField({required this.controller, required this.hint, required this.prefixIcon, required this.inputBg, required this.inputBorder, required this.iconColor, required this.hintColor, required this.textColor, this.obscureText = false, this.suffixIcon, this.onSuffixTap, this.keyboardType, this.textInputAction});
  final TextEditingController controller; final String hint; final IconData prefixIcon; final bool obscureText; final IconData? suffixIcon; final VoidCallback? onSuffixTap; final TextInputType? keyboardType; final TextInputAction? textInputAction; final Color inputBg, inputBorder, iconColor, hintColor, textColor;
  @override
  Widget build(BuildContext context) => SizedBox(height: 52, child: TextField(controller: controller, obscureText: obscureText, keyboardType: keyboardType, textInputAction: textInputAction, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(filled: true, fillColor: inputBg, hintText: hint, hintStyle: TextStyle(fontSize: 14, color: hintColor), contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20), prefixIcon: Padding(padding: const EdgeInsets.only(left: 18, right: 10), child: Icon(prefixIcon, color: iconColor, size: 19)), prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0), suffixIcon: suffixIcon != null ? GestureDetector(onTap: onSuffixTap, child: Padding(padding: const EdgeInsets.only(right: 18), child: Icon(suffixIcon, color: iconColor, size: 19))) : null, suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: inputBorder, width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: inputBorder, width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: inputBorder.withValues(alpha: 0.7), width: 1.5)))));
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.bgColor, required this.textColor, required this.onTap});
  final String label; final Color bgColor, textColor; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(height: 52, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: bgColor, foregroundColor: textColor, shadowColor: Colors.transparent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))), child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))));
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.lineColor, required this.textColor});
  final Color lineColor, textColor;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Divider(color: lineColor, thickness: 1, height: 1)), Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textColor, letterSpacing: 1.2))), Expanded(child: Divider(color: lineColor, thickness: 1, height: 1))]);
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.borderColor, required this.bgColor, required this.textColor, required this.iconColor, required this.onTap});
  final Color borderColor, bgColor, textColor, iconColor; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(height: 52, child: OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(backgroundColor: bgColor, foregroundColor: textColor, side: BorderSide(color: borderColor, width: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('G', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: iconColor)), const SizedBox(width: 10), Text('Continue with Google', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))])));
}
