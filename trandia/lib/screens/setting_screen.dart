import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'glass_common.dart';
import 'edit_profile_screen.dart';
import 'parental_control_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool dark;
  const SettingsScreen({super.key, required this.dark});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool privateAccount = true;
  bool activityStatus = false;
  bool notifications = true;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final languageController = AppLanguageScope.controllerOf(context);
    final selectedLanguage = languageController.language.label;

    return Scaffold(
      backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(
        children: [
          GlassBackdrop(dark: dark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: GlassHeader(
                    dark: dark,
                    padding: const EdgeInsets.only(left: 7, right: 8),
                    child: Row(
                      children: [
                        GlassCircleButton(
                          dark: dark,
                          icon: Icons.arrow_back_ios_new_rounded,
                          iconSize: 16,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Settings'.tr(context),
                          style: manrope(size: 17, weight: FontWeight.w800, color: fg),
                        ),
                        const Spacer(),
                        GlassCircleButton(
                          dark: dark,
                          icon: Icons.more_horiz_rounded,
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _SearchPill(dark: dark),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                    children: [
                      _AccountCard(dark: dark),
                      const SizedBox(height: 16),
                      _SectionTitle('ACCOUNT'.tr(context), color: sub),
                      _SectionCard(
                        dark: dark,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (_, animation, __) =>
                                      EditProfileScreen(dark: dark),
                                  transitionDuration: const Duration(milliseconds: 320),
                                  reverseTransitionDuration: const Duration(milliseconds: 260),
                                  transitionsBuilder: (_, animation, __, child) {
                                    final curved = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                      reverseCurve: Curves.easeInCubic,
                                    );
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.05),
                                        end: Offset.zero,
                                      ).animate(curved),
                                      child: FadeTransition(opacity: curved, child: child),
                                    );
                                  },
                                ),
                              );
                            },
                            child: _SettingRow(
                              dark: dark,
                              icon: Icons.person_outline_rounded,
                              title: 'Edit profile',
                              subtitle: 'Name, bio, links and photo',
                            ),
                          ),
                          _SettingRow(
                            dark: dark,
                            icon: Icons.lock_outline_rounded,
                            title: 'Privacy',
                            subtitle: 'Private account, mentions, tags',
                          ),
                          _SettingRow(
                            dark: dark,
                            icon: Icons.shield_outlined,
                            title: 'Security',
                            subtitle: 'Password and login activity',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle('PREFERENCES'.tr(context), color: sub),
                      _SectionCard(
                        dark: dark,
                        children: [
                          _SwitchRow(
                            dark: dark,
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            subtitle: 'Likes, follows and messages',
                            value: notifications,
                            onChanged: (v) => setState(() => notifications = v),
                          ),
                          _SwitchRow(
                            dark: dark,
                            icon: Icons.visibility_outlined,
                            title: 'Activity status',
                            subtitle: 'Show when you are active',
                            value: activityStatus,
                            onChanged: (v) => setState(() => activityStatus = v),
                          ),
                          _SwitchRow(
                            dark: dark,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Private account',
                            subtitle: 'Only followers see your posts',
                            value: privateAccount,
                            onChanged: (v) => setState(() => privateAccount = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Language selection row
                      _BaseRow(
                        dark: dark,
                        icon: Icons.language,
                        title: 'Language'.tr(context),
                        subtitle: selectedLanguage.tr(context),
                        trailing: DropdownButton<String>(
                          value: selectedLanguage,
                          underline: const SizedBox(),
                          icon: Icon(Icons.arrow_drop_down, color: GlassTokens.sub(dark)),
                          items: ['English', 'Hindi', 'Hinglish']
                              .map((lang) => DropdownMenuItem(value: lang, child: Text(lang.tr(context))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              languageController.setLanguage(AppLanguage.fromLabel(v));
                            }
                          },
                        ),
                      ),
                      // Parental Control option
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParentalControlScreen(dark: dark))),
                        child: _BaseRow(
                          dark: dark,
                          icon: Icons.supervised_user_circle,
                          title: 'Parental Control',
                          subtitle: '',
                          trailing: Icon(Icons.chevron_right_rounded, color: GlassTokens.sub(dark), size: 24),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle('MORE'.tr(context), color: sub),
                      _SectionCard(
                        dark: dark,
                        children: [
                          _SettingRow(
                            dark: dark,
                            icon: Icons.bookmark_border_rounded,
                            title: 'Saved',
                            subtitle: 'Posts and collections',
                          ),
                          _SettingRow(
                            dark: dark,
                            icon: Icons.archive_outlined,
                            title: 'Archive',
                            subtitle: 'Stories and hidden posts',
                          ),
                          _SettingRow(
                            dark: dark,
                            icon: Icons.help_outline_rounded,
                            title: 'Help',
                            subtitle: 'Support and app info',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _LogoutButton(dark: dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final bool dark;
  const _SearchPill({required this.dark});

  @override
  Widget build(BuildContext context) {
    final sub = GlassTokens.sub(dark);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.6),
            border: Border.all(
              color: dark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.95),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 19, color: sub),
              const SizedBox(width: 10),
              Text('Search settings'.tr(context), style: manrope(size: 14, weight: FontWeight.w600, color: sub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final bool dark;
  const _AccountCard({required this.dark});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return GlassSurface(
      dark: dark,
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: monoAvatar(dark, 2)),
            alignment: Alignment.center,
            child: Text('S', style: manrope(size: 22, weight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sarah Dietrich', style: manrope(size: 16, weight: FontWeight.w800, color: fg)),
                const SizedBox(height: 3),
                Text('@sarah.d', style: manrope(size: 12.5, weight: FontWeight.w600, color: sub)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: sub, size: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 9),
      child: Text(
        text,
        style: manrope(size: 11, weight: FontWeight.w800, color: color, letterSpacing: 0.9),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool dark;
  final List<Widget> children;
  const _SectionCard({required this.dark, required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      dark: dark,
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingRow({
    required this.dark,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseRow(
      dark: dark,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Icon(Icons.chevron_right_rounded, color: GlassTokens.sub(dark), size: 24),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.dark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseRow(
      dark: dark,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: dark ? const Color(0xFF0A0A0A) : Colors.white,
        activeTrackColor: dark ? Colors.white : const Color(0xFF0A0A0A),
        inactiveThumbColor: dark ? Colors.white70 : Colors.black54,
        inactiveTrackColor: dark ? Colors.white12 : Colors.black12,
      ),
    );
  }
}

class _BaseRow extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _BaseRow({
    required this.dark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white.withOpacity(0.09) : Colors.black.withOpacity(0.06),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.tr(context), style: manrope(size: 14.5, weight: FontWeight.w800, color: fg)),
                const SizedBox(height: 3),
                Text(subtitle.tr(context), style: manrope(size: 12, weight: FontWeight.w500, color: sub)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final bool dark;
  const _LogoutButton({required this.dark});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      dark: dark,
      radius: 999,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          'Log out'.tr(context),
          style: manrope(
            size: 14,
            weight: FontWeight.w800,
            color: dark ? Colors.white.withOpacity(0.88) : const Color(0xFF0A0A0A),
          ),
        ),
      ),
    );
  }
}
