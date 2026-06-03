// lib/widgets/profile/user_profile_buttons.dart
import 'package:flutter/material.dart';
import 'user_profile_backdrop.dart';

class UserProfileFollowButton extends StatelessWidget {
  const UserProfileFollowButton({
    super.key,
    required this.t,
    required this.following,
    required this.onTap,
  });
  final UserProfileGlassTheme t;
  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (following) {
      return UserProfileMessageButton(
        t: t,
        onTap: onTap,
        label: 'Following',
        leading: Icon(Icons.check_rounded, color: t.fg, size: 16),
      );
    }
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
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: t.btnBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: t.btnFill,
              ),
            ),
            child: Stack(children: [
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: Container(
                  height: 1.2,
                  color: Colors.white
                      .withValues(alpha: t.dark ? 0.85 : 0.32),
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: t.btnFg, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Follow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: t.btnFg,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class UserProfileMessageButton extends StatelessWidget {
  const UserProfileMessageButton({
    super.key,
    required this.t,
    required this.onTap,
    this.label = 'Message',
    this.leading,
  });
  final UserProfileGlassTheme t;
  final VoidCallback onTap;
  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.fieldShadow,
      ),
      child: UserProfileFrosted(
        radius: 999,
        sigma: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.fieldBorder, width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: t.fieldFill,
                ),
              ),
              child: Stack(children: [
                Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  child: Container(
                    height: 1,
                    color: t.innerHi.withValues(alpha: 0.7),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ] else ...[
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: t.fg, size: 16),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: t.fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
