// lib/widgets/profile/user_profile_social_links.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_profile_backdrop.dart';
import '../../models/chat_model.dart';

class UserProfileSocialRow extends StatelessWidget {
  const UserProfileSocialRow({super.key, required this.t, this.profile});
  final UserProfileGlassTheme t;
  final UserProfile? profile;

  Future<void> _launch(String url) async {
    String full = url.trim();
    if (full.isEmpty) return;
    if (!full.startsWith('http://') && !full.startsWith('https://')) {
      full = 'https://$full';
    }
    try {
      await launchUrl(Uri.parse(full), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const SizedBox.shrink();

    final links = <({Widget icon, String url})>[
      if ((profile!.snapchatLink ?? '').isNotEmpty)
        (icon: const UserProfileBrandSnap(), url: profile!.snapchatLink!),
      if ((profile!.instagramLink ?? '').isNotEmpty)
        (icon: const UserProfileBrandIG(), url: profile!.instagramLink!),
      if ((profile!.whatsappLink ?? '').isNotEmpty)
        (icon: const UserProfileBrandWA(), url: profile!.whatsappLink!),
      if ((profile!.facebookLink ?? '').isNotEmpty)
        (icon: const UserProfileBrandFB(), url: profile!.facebookLink!),
      if ((profile!.twitterLink ?? '').isNotEmpty)
        (icon: const UserProfileBrandX(), url: profile!.twitterLink!),
      if ((profile!.youtubeLink ?? '').isNotEmpty)
        (icon: const UserProfileBrandYT(), url: profile!.youtubeLink!),
    ];

    if (links.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: links
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => _launch(e.url),
                    child: UserProfileSocialPill(t: t, child: e.icon),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class UserProfileSocialPill extends StatelessWidget {
  const UserProfileSocialPill({super.key, required this.t, required this.child});
  final UserProfileGlassTheme t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: t.fieldShadow,
      ),
      child: UserProfileFrosted(
        radius: 999,
        sigma: 16,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.fieldBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: t.fieldFill,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class UserProfileBrandSnap extends StatelessWidget {
  const UserProfileBrandSnap({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFC00),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.snapchat,
            color: Color(0xFF0A0A0A),
            size: 13,
          ),
        ),
      );
}

class UserProfileBrandIG extends StatelessWidget {
  const UserProfileBrandIG({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFEDA77), Color(0xFFF58529), Color(0xFFDD2A7B)],
          ),
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.instagram,
            color: Colors.white,
            size: 13,
          ),
        ),
      );
}

class UserProfileBrandWA extends StatelessWidget {
  const UserProfileBrandWA({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF25D366),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.whatsapp,
            color: Colors.white,
            size: 13,
          ),
        ),
      );
}

class UserProfileBrandFB extends StatelessWidget {
  const UserProfileBrandFB({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF1877F2),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.facebookF,
            color: Colors.white,
            size: 13,
          ),
        ),
      );
}

class UserProfileBrandX extends StatelessWidget {
  const UserProfileBrandX({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 0.8),
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.xTwitter,
            color: Colors.white,
            size: 11,
          ),
        ),
      );
}

class UserProfileBrandYT extends StatelessWidget {
  const UserProfileBrandYT({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFFFF0000),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: FaIcon(
            FontAwesomeIcons.youtube,
            color: Colors.white,
            size: 12,
          ),
        ),
      );
}
