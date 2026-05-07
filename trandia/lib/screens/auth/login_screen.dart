import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword     = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Color Tokens ─────────────────────────────────────────────
    final bgColors = isDark
        ? [const Color(0xFF1F1F22), const Color(0xFF0E0E10), const Color(0xFF050506)]
        : [const Color(0xFFFFFFFF), const Color(0xFFF4F4F5), const Color(0xFFECECEE)];

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
                const SizedBox(height: 36),

                // ── Logo + Heading ────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: logoBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            '✦',
                            style: TextStyle(
                              color: logoMark,
                              fontSize: 26,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 42),

                // ── Email ─────────────────────────────────────────
                _FieldLabel(label: 'Email', color: labelColor),
                const SizedBox(height: 8),
                _PillTextField(
                  controller: _emailController,
                  hint: 'you@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  inputBg: inputBg,
                  inputBorder: inputBorder,
                  iconColor: iconColor,
                  hintColor: hintColor,
                  textColor: textPrimary,
                ),
                const SizedBox(height: 18),

                // ── Password ──────────────────────────────────────
                _FieldLabel(label: 'Password', color: labelColor),
                const SizedBox(height: 8),
                _PillTextField(
                  controller: _passwordController,
                  hint: 'Enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  inputBg: inputBg,
                  inputBorder: inputBorder,
                  iconColor: iconColor,
                  hintColor: hintColor,
                  textColor: textPrimary,
                ),
                const SizedBox(height: 12),

                // ── Forgot Password ───────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      // TODO: navigate to forgot password
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // ── Sign In Button ────────────────────────────────
                _PillButton(
                  label: 'Sign in',
                  bgColor: btnBg,
                  textColor: btnText,
                  onTap: () {
                    // TODO: handle sign in logic
                  },
                ),
                const SizedBox(height: 26),

                // ── OR Divider ────────────────────────────────────
                _OrDivider(lineColor: dividerColor, textColor: hintColor),
                const SizedBox(height: 22),

                // ── Continue with Google ──────────────────────────
                _GoogleButton(
                  borderColor: inputBorder,
                  bgColor: inputBg,
                  textColor: textPrimary,
                  iconColor: iconColor,
                  onTap: () {
                    // TODO: handle Google sign in
                  },
                ),
                const SizedBox(height: 52),

                // ── Sign Up Link ──────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // TODO: navigate to SignUpScreen
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                          children: [
                            const TextSpan(text: "Don't have an account?  "),
                            TextSpan(
                              text: 'Sign up',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Private Helper Widgets
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
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _PillTextField extends StatelessWidget {
  const _PillTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.inputBg,
    required this.inputBorder,
    required this.iconColor,
    required this.hintColor,
    required this.textColor,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Color inputBg;
  final Color inputBorder;
  final Color iconColor;
  final Color hintColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        style: TextStyle(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          filled: true,
          fillColor: inputBg,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: hintColor),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 20,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 18, right: 10),
            child: Icon(prefixIcon, color: iconColor, size: 19),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: suffixIcon != null
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Icon(suffixIcon, color: iconColor, size: 19),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(color: inputBorder, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(color: inputBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(
              color: inputBorder.withOpacity(0.7),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.lineColor, required this.textColor});

  final Color lineColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: lineColor, thickness: 1, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: lineColor, thickness: 1, height: 1),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.borderColor,
    required this.bgColor,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
  });

  final Color borderColor;
  final Color bgColor;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'G',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
