import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'glass_common.dart';
import '../models/chat_model.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final bool dark;
  const EditProfileScreen({super.key, required this.dark});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _linkController = TextEditingController();
  final _snapchatController = TextEditingController();
  final _instagramController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _twitterController = TextEditingController();
  final _youtubeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _profile;
  List<String> _platformOrder = ['snapchat', 'instagram', 'whatsapp', 'facebook', 'twitter', 'youtube'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _linkController.dispose();
    _snapchatController.dispose();
    _instagramController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('social_platform_order');
      if (savedOrder != null && savedOrder.isNotEmpty) {
        final validPlatforms = {'snapchat', 'instagram', 'whatsapp', 'facebook', 'twitter', 'youtube'};
        final loadedOrder = savedOrder.where((e) => validPlatforms.contains(e)).toList();
        for (final p in validPlatforms) {
          if (!loadedOrder.contains(p)) {
            loadedOrder.add(p);
          }
        }
        _platformOrder = loadedOrder;
      }
      final profile = await UserService.getMyProfile();
      if (profile != null && mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.name;
          _usernameController.text = profile.username;
          _bioController.text = profile.bio ?? '';
          _linkController.text = profile.link ?? '';
          _snapchatController.text = profile.snapchatLink ?? '';
          _instagramController.text = profile.instagramLink ?? '';
          _whatsappController.text = profile.whatsappLink ?? '';
          _facebookController.text = profile.facebookLink ?? '';
          _twitterController.text = profile.twitterLink ?? '';
          _youtubeController.text = profile.youtubeLink ?? '';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('social_platform_order', _platformOrder);

      await ApiService.put(
        '/users/me',
        {
          'name': _nameController.text.trim(),
          'username': _usernameController.text.trim(),
          'bio': _bioController.text.trim(),
          'link': _linkController.text.trim(),
          'snapchat_link': _snapchatController.text.trim(),
          'instagram_link': _instagramController.text.trim(),
          'whatsapp_link': _whatsappController.text.trim(),
          'facebook_link': _facebookController.text.trim(),
          'twitter_link': _twitterController.text.trim(),
          'youtube_link': _youtubeController.text.trim(),
        },
        requiresAuth: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated',
              style: manrope(size: 14, weight: FontWeight.w600, color: Colors.white),
            ),
            backgroundColor: widget.dark ? const Color(0xFF1C1C1F) : const Color(0xFF333333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('ApiException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.isNotEmpty ? msg : 'Failed to update profile',
              style: manrope(size: 14, weight: FontWeight.w600, color: Colors.white),
            ),
            backgroundColor: Colors.redAccent.withOpacity(0.85),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                // ── Top bar ──
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
                          'Edit Profile',
                          style: manrope(size: 17, weight: FontWeight.w800, color: fg),
                        ),
                        const Spacer(),
                        _SaveButton(
                          dark: dark,
                          isSaving: _isSaving,
                          onTap: _saveProfile,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Content ──
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(fg),
                            strokeWidth: 2,
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                          children: [
                            // ── Avatar section ──
                            _AvatarSection(
                              dark: dark,
                              fg: fg,
                              sub: sub,
                              initial: _profile?.name.isNotEmpty == true
                                  ? _profile!.name[0].toUpperCase()
                                  : '?',
                            ),
                            const SizedBox(height: 24),

                            // ── Name field ──
                            _FieldLabel(dark: dark, label: 'NAME'),
                            const SizedBox(height: 8),
                            _GlassTextField(
                              dark: dark,
                              controller: _nameController,
                              placeholder: 'Your full name',
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 20),

                            // ── Username field ──
                            _FieldLabel(dark: dark, label: 'USERNAME'),
                            const SizedBox(height: 8),
                            _GlassTextField(
                              dark: dark,
                              controller: _usernameController,
                              placeholder: '@username',
                              icon: Icons.alternate_email_rounded,
                            ),
                            const SizedBox(height: 20),

                            // ── Bio field ──
                            _FieldLabel(dark: dark, label: 'BIO'),
                            const SizedBox(height: 8),
                            _GlassTextField(
                              dark: dark,
                              controller: _bioController,
                              placeholder: 'Tell people about yourself',
                              icon: Icons.edit_note_rounded,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 20),

                            // ── Link field ──
                            _FieldLabel(dark: dark, label: 'WEBSITE'),
                            const SizedBox(height: 8),
                            _GlassTextField(
                              dark: dark,
                              controller: _linkController,
                              placeholder: 'https://yourwebsite.com',
                              icon: Icons.link_rounded,
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 28),

                            // ── Social Links section ──
                            _FieldLabel(dark: dark, label: 'SOCIAL LINKS'),
                            const SizedBox(height: 8),
                            _SocialLinksCard(
                              dark: dark,
                              snapchatController: _snapchatController,
                              instagramController: _instagramController,
                              whatsappController: _whatsappController,
                              facebookController: _facebookController,
                              twitterController: _twitterController,
                              youtubeController: _youtubeController,
                              platformOrder: _platformOrder,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  final String item = _platformOrder.removeAt(oldIndex);
                                  _platformOrder.insert(newIndex, item);
                                });
                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setStringList('social_platform_order', _platformOrder);
                                });
                              },
                            ),
                            const SizedBox(height: 32),

                            // ── Info note ──
                            _InfoNote(dark: dark, sub: sub),
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

// ─────────────────────────────────────────────────────────────────
// Save button
// ─────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool dark;
  final bool isSaving;
  final VoidCallback onTap;
  const _SaveButton({
    required this.dark,
    required this.isSaving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSaving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: dark
              ? Colors.white.withOpacity(isSaving ? 0.06 : 0.14)
              : Colors.black.withOpacity(isSaving ? 0.04 : 0.08),
        ),
        child: isSaving
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(GlassTokens.fg(dark)),
                ),
              )
            : Text(
                'Save',
                style: manrope(
                  size: 13,
                  weight: FontWeight.w800,
                  color: GlassTokens.fg(dark),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Avatar section with change-photo overlay
// ─────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  final bool dark;
  final Color fg;
  final Color sub;
  final String initial;
  const _AvatarSection({
    required this.dark,
    required this.fg,
    required this.sub,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFFAFAFA),
                  boxShadow: [
                    BoxShadow(
                      color: dark
                          ? Colors.black.withOpacity(0.8)
                          : const Color(0xFF14161E).withOpacity(0.25),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                      spreadRadius: -16,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: monoAvatar(dark, 0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.22),
                        blurRadius: 0,
                        offset: const Offset(0, 1),
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: manrope(
                      size: 36,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1.08,
                    ),
                  ),
                ),
              ),
              // Camera badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? const Color(0xFF1C1C1F) : Colors.white,
                  border: Border.all(
                    color: dark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.black.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(dark ? 0.5 : 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 16,
                  color: fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Change photo',
            style: manrope(
              size: 13,
              weight: FontWeight.w700,
              color: sub,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Field label
// ─────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final bool dark;
  final String label;
  const _FieldLabel({required this.dark, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label,
        style: manrope(
          size: 11,
          weight: FontWeight.w800,
          color: GlassTokens.sub(dark),
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Glass text field
// ─────────────────────────────────────────────────────────────────

class _GlassTextField extends StatelessWidget {
  final bool dark;
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  const _GlassTextField({
    required this.dark,
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: GlassTokens.glassBg(dark),
            ),
            border: Border.all(color: GlassTokens.glassBorder(dark), width: 1),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [GlassTokens.cardShadow(dark)],
          ),
          child: Stack(
            children: [
              // Top sheen
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: dark
                          ? [Colors.transparent, Colors.white.withOpacity(0.14), Colors.transparent]
                          : [Colors.transparent, Colors.white.withOpacity(0.98), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  crossAxisAlignment: maxLines > 1
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
                      child: Container(
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: maxLines,
                        keyboardType: keyboardType,
                        style: manrope(
                          size: 14.5,
                          weight: FontWeight.w600,
                          color: fg,
                        ),
                        cursorColor: fg,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: placeholder,
                          hintStyle: manrope(
                            size: 14,
                            weight: FontWeight.w500,
                            color: sub,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: maxLines > 1 ? 14 : 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Info note at bottom
// ─────────────────────────────────────────────────────────────────

class _InfoNote extends StatelessWidget {
  final bool dark;
  final Color sub;
  const _InfoNote({required this.dark, required this.sub});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      dark: dark,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withOpacity(0.09)
                  : Colors.black.withOpacity(0.06),
            ),
            child: Icon(Icons.info_outline_rounded, size: 18, color: sub),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your profile info is visible to everyone who can view your profile.',
              style: manrope(
                size: 12.5,
                weight: FontWeight.w500,
                color: sub,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Social Links Card
// ─────────────────────────────────────────────────────────────────

class _PlatformData {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String placeholder;
  final TextEditingController controller;

  _PlatformData({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.placeholder,
    required this.controller,
  });
}

class _SocialLinksCard extends StatelessWidget {
  final bool dark;
  final TextEditingController snapchatController;
  final TextEditingController instagramController;
  final TextEditingController whatsappController;
  final TextEditingController facebookController;
  final TextEditingController twitterController;
  final TextEditingController youtubeController;
  final List<String> platformOrder;
  final ReorderCallback onReorder;

  const _SocialLinksCard({
    required this.dark,
    required this.snapchatController,
    required this.instagramController,
    required this.whatsappController,
    required this.facebookController,
    required this.twitterController,
    required this.youtubeController,
    required this.platformOrder,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final platforms = {
      'snapchat': _PlatformData(
        id: 'snapchat',
        icon: FontAwesomeIcons.snapchat,
        iconColor: const Color(0xFFFFFC00),
        label: 'Snapchat',
        placeholder: 'https://snapchat.com/add/username',
        controller: snapchatController,
      ),
      'instagram': _PlatformData(
        id: 'instagram',
        icon: FontAwesomeIcons.instagram,
        iconColor: const Color(0xFFE4405F),
        label: 'Instagram',
        placeholder: 'https://instagram.com/username',
        controller: instagramController,
      ),
      'whatsapp': _PlatformData(
        id: 'whatsapp',
        icon: FontAwesomeIcons.whatsapp,
        iconColor: const Color(0xFF25D366),
        label: 'WhatsApp',
        placeholder: 'https://wa.me/phonenumber',
        controller: whatsappController,
      ),
      'facebook': _PlatformData(
        id: 'facebook',
        icon: FontAwesomeIcons.facebookF,
        iconColor: const Color(0xFF1877F2),
        label: 'Facebook',
        placeholder: 'https://facebook.com/username',
        controller: facebookController,
      ),
      'twitter': _PlatformData(
        id: 'twitter',
        icon: FontAwesomeIcons.xTwitter,
        iconColor: dark ? Colors.white : const Color(0xFF000000),
        label: 'X (Twitter)',
        placeholder: 'https://x.com/username',
        controller: twitterController,
      ),
      'youtube': _PlatformData(
        id: 'youtube',
        icon: FontAwesomeIcons.youtube,
        iconColor: const Color(0xFFFF0000),
        label: 'YouTube',
        placeholder: 'https://youtube.com/@username',
        controller: youtubeController,
      ),
    };

    return GlassSurface(
      dark: dark,
      radius: 24,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: platformOrder.length,
        buildDefaultDragHandles: false,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final platformId = platformOrder[index];
          final data = platforms[platformId]!;
          return Column(
            key: ValueKey(platformId),
            children: [
              _SocialLinkField(
                index: index,
                dark: dark,
                icon: data.icon,
                iconColor: data.iconColor,
                label: data.label,
                placeholder: data.placeholder,
                controller: data.controller,
              ),
              if (index < platformOrder.length - 1)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  height: 1,
                  color: dark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SocialLinkField extends StatelessWidget {
  final int index;
  final bool dark;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String placeholder;
  final TextEditingController controller;

  const _SocialLinkField({
    required this.index,
    required this.dark,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.placeholder,
    required this.controller,
  });

  Future<void> _launchUrl() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    String url = text;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (label.toLowerCase() == 'whatsapp') {
        if (url.startsWith('+') || RegExp(r'^\d+$').hasMatch(url)) {
          url = 'https://wa.me/$url';
        } else {
          url = 'https://$url';
        }
      } else {
        url = 'https://$url';
      }
    }

    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Tooltip(
            message: 'Tap icon to open link',
            child: GestureDetector(
              onTap: _launchUrl,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.white.withOpacity(0.8),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                alignment: Alignment.center,
                child: FaIcon(icon, size: 18, color: iconColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _launchUrl,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    label,
                    style: manrope(
                      size: 12,
                      weight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  style: manrope(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: fg,
                  ),
                  cursorColor: fg,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 4, bottom: 4),
                    hintText: placeholder,
                    hintStyle: manrope(
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: sub,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Icon(
                Icons.drag_handle_rounded,
                color: sub.withOpacity(0.6),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
