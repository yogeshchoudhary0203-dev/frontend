import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'glass_common.dart';
import '../services/api_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final bool dark;
  const NotificationSettingsScreen({super.key, required this.dark});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool master = true;
  bool notifFollows = true;
  bool notifLikes = true;
  bool notifComments = true;
  bool notifMessages = true;
  bool notifStories = true;
  bool notifMentions = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      master = prefs.getBool('settings_notifications') ?? true;
      notifFollows = prefs.getBool('settings_notif_follows') ?? true;
      notifLikes = prefs.getBool('settings_notif_likes') ?? true;
      notifComments = prefs.getBool('settings_notif_comments') ?? true;
      notifMessages = prefs.getBool('settings_notif_messages') ?? true;
      notifStories = prefs.getBool('settings_notif_stories') ?? true;
      notifMentions = prefs.getBool('settings_notif_mentions') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    _syncToBackend();
  }

  void _syncToBackend() {
    ApiService.put(
      '/users/me/notification-settings',
      {
        'master':   master,
        'follows':  notifFollows,
        'likes':    notifLikes,
        'comments': notifComments,
        'messages': notifMessages,
        'stories':  notifStories,
        'mentions': notifMentions,
      },
      requiresAuth: true,
    ).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

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
                          'Notifications',
                          style: manrope(
                              size: 17,
                              weight: FontWeight.w800,
                              color: fg),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                    children: [
                      _NSectionCard(
                        dark: dark,
                        children: [
                          _NSwitchRow(
                            dark: dark,
                            icon: Icons.notifications_none_rounded,
                            title: 'Push notifications',
                            subtitle: 'Turn off all notifications',
                            value: master,
                            onChanged: (v) {
                              setState(() => master = v);
                              _save('settings_notifications', v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _NSectionTitle('PEOPLE', color: sub),
                      _NSectionCard(
                        dark: dark,
                        children: [
                          _NSwitchRow(
                            dark: dark,
                            icon: Icons.person_add_alt_1_outlined,
                            title: 'New followers',
                            subtitle: 'When someone follows you',
                            value: notifFollows,
                            enabled: master,
                            onChanged: (v) {
                              setState(() => notifFollows = v);
                              _save('settings_notif_follows', v);
                            },
                          ),
                          _NSwitchRow(
                            dark: dark,
                            icon: Icons.alternate_email_rounded,
                            title: 'Mentions',
                            subtitle: 'When someone mentions you',
                            value: notifMentions,
                            enabled: master,
                            onChanged: (v) {
                              setState(() => notifMentions = v);
                              _save('settings_notif_mentions', v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _NSectionTitle('POSTS', color: sub),
                      _NSectionCard(
                        dark: dark,
                        children: [
                          _NSwitchRow(
                            dark: dark,
                            icon: Icons.favorite_border_rounded,
                            title: 'Likes',
                            subtitle: 'When someone likes your post',
                            value: notifLikes,
                            enabled: master,
                            onChanged: (v) {
                              setState(() => notifLikes = v);
                              _save('settings_notif_likes', v);
                            },
                          ),
                          _NSwitchRow(
                            dark: dark,
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Comments',
                            subtitle: 'On your posts',
                            value: notifComments,
                            enabled: master,
                            onChanged: (v) {
                              setState(() => notifComments = v);
                              _save('settings_notif_comments', v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _NSectionTitle('MESSAGES & STORIES', color: sub),
                      _NSectionCard(
                        dark: dark,
                        children: [
                          _NSwitchRow(
                            dark: dark,
                            icon: Icons.send_outlined,
                            title: 'Messages',
                            subtitle: 'When someone sends you a message',
                            value: notifMessages,
                            enabled: master,
                            onChanged: (v) {
                              setState(() => notifMessages = v);
                              _save('settings_notif_messages', v);
                            },
                          ),
                          _NSwitchRow(
                            dark: dark,
                            icon: Icons.auto_stories_outlined,
                            title: 'Stories',
                            subtitle: 'Views and reactions on your story',
                            value: notifStories,
                            enabled: master,
                            onChanged: (v) {
                              setState(() => notifStories = v);
                              _save('settings_notif_stories', v);
                            },
                          ),
                        ],
                      ),
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

// ── Private widgets (scoped to this file) ────────────────────────────────────

class _NSectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _NSectionTitle(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 9),
      child: Text(
        text,
        style: manrope(
            size: 11,
            weight: FontWeight.w800,
            color: color,
            letterSpacing: 0.9),
      ),
    );
  }
}

class _NSectionCard extends StatelessWidget {
  final bool dark;
  final List<Widget> children;
  const _NSectionCard({required this.dark, required this.children});

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

class _NSwitchRow extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NSwitchRow({
    required this.dark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark
                    ? Colors.white.withOpacity(0.09)
                    : Colors.black.withOpacity(0.06),
              ),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: manrope(
                          size: 14.5,
                          weight: FontWeight.w800,
                          color: fg)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: manrope(
                          size: 12,
                          weight: FontWeight.w500,
                          color: sub)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor:
                  dark ? const Color(0xFF0A0A0A) : Colors.white,
              activeTrackColor:
                  dark ? Colors.white : const Color(0xFF0A0A0A),
              inactiveThumbColor:
                  dark ? Colors.white70 : Colors.black54,
              inactiveTrackColor:
                  dark ? Colors.white12 : Colors.black12,
            ),
          ],
        ),
      ),
    );
  }
}
