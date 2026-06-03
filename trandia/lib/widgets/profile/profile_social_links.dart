// lib/widgets/profile/profile_social_links.dart
// Social platform link buttons row (reorderable externally).

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../screens/glass_common.dart';
import '../../services/user_service.dart';
import '../../models/chat_model.dart';

Future<void> openSocialLink(String url, String platform) async {
  if (url.trim().isEmpty) return;
  String finalUrl = url.trim();
  if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
    if (platform.toLowerCase() == 'whatsapp') {
      if (finalUrl.startsWith('+') || RegExp(r'^\d+$').hasMatch(finalUrl)) {
        finalUrl = 'https://wa.me/$finalUrl';
      } else {
        finalUrl = 'https://$finalUrl';
      }
    } else {
      finalUrl = 'https://$finalUrl';
    }
  }
  final uri = Uri.parse(finalUrl);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class ProfileSocialLinksRow extends StatelessWidget {
  final bool dark;
  final Color fg;
  final UserProfile? profile;
  final List<String> platformOrder;

  const ProfileSocialLinksRow({
    super.key,
    required this.dark,
    required this.fg,
    required this.platformOrder,
    this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    for (int i = 0; i < platformOrder.length; i++) {
      final platform = platformOrder[i];
      if (platform == 'snapchat') {
        buttons.add(
          ProfileSocialButton(
            dark: dark,
            icon: FontAwesomeIcons.snapchat,
            color: const Color(0xFFFFFC00),
            label: 'Snapchat',
            url: profile?.snapchatLink?.isNotEmpty == true
                ? profile!.snapchatLink!
                : 'https://www.snapchat.com/add/sarah.d',
            platform: 'snapchat',
          ),
        );
      } else if (platform == 'instagram') {
        buttons.add(
          ProfileSocialButton(
            dark: dark,
            icon: FontAwesomeIcons.instagram,
            color: const Color(0xFFE4405F),
            label: 'Instagram',
            url: profile?.instagramLink?.isNotEmpty == true
                ? profile!.instagramLink!
                : 'https://www.instagram.com/sarah.d',
            platform: 'instagram',
          ),
        );
      } else if (platform == 'whatsapp') {
        buttons.add(
          ProfileSocialButton(
            dark: dark,
            icon: FontAwesomeIcons.whatsapp,
            color: const Color(0xFF25D366),
            label: 'WhatsApp',
            url: profile?.whatsappLink?.isNotEmpty == true
                ? profile!.whatsappLink!
                : 'https://wa.me/15551234567',
            platform: 'whatsapp',
          ),
        );
      } else if (platform == 'facebook') {
        buttons.add(
          ProfileSocialButton(
            dark: dark,
            icon: FontAwesomeIcons.facebookF,
            color: const Color(0xFF1877F2),
            label: 'Facebook',
            url: profile?.facebookLink?.isNotEmpty == true
                ? profile!.facebookLink!
                : 'https://www.facebook.com/sarah.d',
            platform: 'facebook',
          ),
        );
      } else if (platform == 'twitter') {
        buttons.add(
          ProfileSocialButton(
            dark: dark,
            icon: FontAwesomeIcons.xTwitter,
            color: dark ? Colors.white : const Color(0xFF000000),
            label: 'Twitter',
            url: profile?.twitterLink?.isNotEmpty == true
                ? profile!.twitterLink!
                : 'https://twitter.com/sarah_d',
            platform: 'twitter',
          ),
        );
      } else if (platform == 'youtube') {
        buttons.add(
          ProfileSocialButton(
            dark: dark,
            icon: FontAwesomeIcons.youtube,
            color: const Color(0xFFFF0000),
            label: 'YouTube',
            url: profile?.youtubeLink?.isNotEmpty == true
                ? profile!.youtubeLink!
                : 'https://www.youtube.com',
            platform: 'youtube',
          ),
        );
      }

      if (i < platformOrder.length - 1) {
        buttons.add(const SizedBox(width: 10));
      }
    }

    return Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }
}

class ProfileSocialButton extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final Color color;
  final String label;
  final String url;
  final String platform;

  const ProfileSocialButton({
    super.key,
    required this.dark,
    required this.icon,
    required this.color,
    required this.label,
    required this.url,
    required this.platform,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => openSocialLink(url, platform),
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.8),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.28 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -10,
              ),
            ],
          ),
          child: FaIcon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
