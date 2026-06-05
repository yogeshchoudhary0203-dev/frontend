import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import 'glass_common.dart';
import 'edit_profile_screen.dart';
import 'parental_control_screen.dart';
import 'intro_slides.dart';
import 'notification_settings_screen.dart';
import 'saved_posts_screen.dart';
import 'app_lock_screen.dart';
import '../services/app_lock_service.dart';
import 'trandia_marketplace_screen.dart';
import 'trandia_marketplace_apply_screen.dart';
import 'trandia_marketplace_dashboard_screen.dart';
import 'find_collaborate_screen.dart';

// Search item model ────────────────────────────────────────────────────────────
class _SearchItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  const _SearchItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.switchValue,
    this.onSwitch,
  });

  bool matches(String q) =>
      title.toLowerCase().contains(q) ||
      subtitle.toLowerCase().contains(q);
}

// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final bool dark;
  const SettingsScreen({super.key, required this.dark});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool privateAccount = false;
  bool creatorAccount = false;
  bool activityStatus = false;
  bool notifications = true;
  String accountType = 'Personal';
  bool _appLockEnabled = false;
  int _appLockPinLength = 4;
  bool _appliedToMarketplace = false;
  UserProfile? _profile;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSettings();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await UserService.getMyProfile();
    if (mounted && p != null) {
      // Backend is the source of truth for account type — keep the local UI and
      // SharedPreferences mirror in sync with whatever the server returned.
      final backendType = _displayAccountType(p.accountType);
      setState(() {
        _profile = p;
        accountType = backendType;
        privateAccount = backendType == 'Private';
        creatorAccount = backendType == 'Creator';
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_account_type', backendType);
      await prefs.setBool('settings_private_account', backendType == 'Private');
      await prefs.setBool('settings_creator_account', backendType == 'Creator');
    }
  }

  /// Maps the backend's lowercase account_type to the display label used by the
  /// account-type selector ('creator' → 'Creator').
  String _displayAccountType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'private':
        return 'Private';
      case 'creator':
        return 'Creator';
      case 'business':
        return 'Business';
      case 'professional':
        return 'Professional';
      default:
        return 'Personal';
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final lockEnabled = await AppLockService.isEnabled();
    final lockLen = await AppLockService.getPinLength();
    setState(() {
      privateAccount = prefs.getBool('settings_private_account') ?? false;
      creatorAccount = prefs.getBool('settings_creator_account') ?? false;
      activityStatus = prefs.getBool('settings_activity_status') ?? false;
      notifications = prefs.getBool('settings_notifications') ?? true;
      _appLockEnabled = lockEnabled;
      _appLockPinLength = lockLen;
      _appliedToMarketplace =
          prefs.getBool(TmApplyKeys.applied) ?? false;
      final savedType = prefs.getString('settings_account_type');
      if (savedType != null) {
        accountType = savedType;
      } else {
        if (privateAccount) {
          accountType = 'Private';
        } else if (creatorAccount) {
          accountType = 'Creator';
        } else {
          accountType = 'Personal';
        }
      }
    });
  }

  Future<void> _refreshAppLockState() async {
    final enabled = await AppLockService.isEnabled();
    final len = await AppLockService.getPinLength();
    if (mounted) setState(() { _appLockEnabled = enabled; _appLockPinLength = len; });
  }

  void _openAppLock(BuildContext ctx) {
    _openScreenSmoothly(ctx, AppLockSetupScreen(dark: widget.dark))
        .then((_) => _refreshAppLockState());
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveSettingString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveAccountType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_account_type', type);
    bool isPrivate = type == 'Private';
    bool isCreator = type == 'Creator';
    await prefs.setBool('settings_private_account', isPrivate);
    await prefs.setBool('settings_creator_account', isCreator);
    if (mounted) {
      setState(() {
        accountType = type;
        privateAccount = isPrivate;
        creatorAccount = isCreator;
      });
    }
    // Persist on the backend so it survives reinstalls & syncs across devices.
    // Fire-and-forget: the local UI is already updated; a failed sync just means
    // the next profile refresh will reconcile.
    UserService.updateAccountType(type);
  }

  Future<void> _openScreenSmoothly(BuildContext ctx, Widget screen) {
    return Navigator.of(ctx).push(PageRouteBuilder(
      pageBuilder: (_, animation, __) => screen,
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
    ));
  }

  void _openEditProfile(BuildContext ctx) {
    _openScreenSmoothly(ctx, EditProfileScreen(dark: widget.dark))
        .then((_) => _loadProfile());
  }

  bool get _isMarketplaceEligible =>
      accountType == 'Business' || accountType == 'Professional';

  bool get _isCreatorAccount => accountType == 'Creator';

  bool get _isCollaboratorEligible =>
      accountType == 'Creator' ||
      accountType == 'Business' ||
      accountType == 'Professional';

  void _openMarketplace(BuildContext ctx) {
    _openScreenSmoothly(ctx, TrandiaMarketplaceScreen(dark: widget.dark));
  }

  void _openFindCollaborate(BuildContext ctx) {
    _openScreenSmoothly(ctx, FindCollaborateScreen(dark: widget.dark));
  }

  Future<void> _openCreatorMarketplaceFlow(BuildContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    final applied = prefs.getBool(TmApplyKeys.applied) ?? false;
    if (!ctx.mounted) return;
    if (applied) {
      _openScreenSmoothly(
          ctx, TrandiaMarketplaceDashboardScreen(dark: widget.dark));
    } else {
      _openScreenSmoothly(
          ctx, TrandiaMarketplaceApplyScreen(dark: widget.dark));
    }
  }

  void _openDummy(BuildContext ctx) {
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: GlassTokens.fg(widget.dark)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    ));
  }

  void _openSecurityScreen(BuildContext ctx) {
    final dark = widget.dark;
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: dark ? GlassTokens.bgDark : GlassTokens.bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Security'.tr(context),
            style: manrope(size: 17, weight: FontWeight.w800, color: GlassTokens.fg(dark)),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: GlassTokens.fg(dark)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _SectionCard(
              dark: dark,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openDummy(context),
                  child: _SettingRow(
                    dark: dark,
                    icon: Icons.lock_outline_rounded,
                    title: 'Reset Password',
                    subtitle: 'Change your current password',
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showForgotPasswordModal(context),
                  child: _SettingRow(
                    dark: dark,
                    icon: Icons.help_outline_rounded,
                    title: 'Forgot Password',
                    subtitle: 'Recover your account access',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  void _showForgotPasswordModal(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final emailCtrl = TextEditingController();
    bool isLoading = false;
    bool isSent = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? const Color(0xE00C0C0E) : const Color(0xF2FDFDFD),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: GlassTokens.glassBorder(dark), width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: dark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      Icon(
                        isSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
                        size: 64,
                        color: isSent ? Colors.green : fg,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSent ? 'Check Your Email' : 'Forgot Password',
                        style: manrope(size: 22, weight: FontWeight.w800, color: fg),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSent 
                            ? 'We have sent a password reset link to your email. Please check your inbox.'
                            : 'Enter your email address and we will send you a verification link to reset your password.',
                        style: manrope(size: 14, weight: FontWeight.w500, color: sub, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (!isSent) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                            border: Border.all(color: dark ? Colors.white12 : Colors.black12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: manrope(size: 15, weight: FontWeight.w600, color: fg),
                            decoration: InputDecoration(
                              hintText: 'Enter your email',
                              hintStyle: manrope(size: 15, weight: FontWeight.w500, color: sub),
                              prefixIcon: Icon(Icons.email_outlined, color: sub, size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: isLoading ? null : () async {
                            final email = emailCtrl.text.trim();
                            if (email.isEmpty) return;
                            setModalState(() => isLoading = true);
                            try {
                              await AuthService.resetPassword(email);
                              if (ctx.mounted) {
                                setModalState(() {
                                  isLoading = false;
                                  isSent = true;
                                });
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setModalState(() => isLoading = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Failed to send reset link', style: manrope(size: 14, weight: FontWeight.w600))),
                                );
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: dark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(dark ? Colors.black : Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Send Verification Link',
                                    style: manrope(
                                      size: 16,
                                      weight: FontWeight.w800,
                                      color: dark ? Colors.black : Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Close',
                              style: manrope(size: 16, weight: FontWeight.w700, color: fg),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  void _openAccountTypeSelector(BuildContext context) {
    final dark = widget.dark;
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    final types = [
      {
        'name': 'Personal',
        'desc': 'Standard private or public personal profile',
        'icon': Icons.person_rounded
      },
      {
        'name': 'Private',
        'desc': 'Only approved followers see your posts',
        'icon': Icons.lock_rounded
      },
      {
        'name': 'Creator',
        'desc': 'Best for public figures, content producers, artists',
        'icon': Icons.workspace_premium_rounded
      },
      {
        'name': 'Business',
        'desc': 'Best for retailers, local businesses, organizations',
        'icon': Icons.business_center_rounded
      },
      {
        'name': 'Professional',
        'desc': 'Best for professionals, portfolios, work search',
        'icon': Icons.work_rounded
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xE00C0C0E) : const Color(0xF2FDFDFD),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: GlassTokens.glassBorder(dark), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: dark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Select Account Type'.tr(context),
                  style: manrope(size: 18, weight: FontWeight.w800, color: fg),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the account type that suits you best'.tr(context),
                  style: manrope(size: 12, weight: FontWeight.w500, color: sub),
                ),
                const SizedBox(height: 18),
                ...types.map((t) {
                  final name = t['name'] as String;
                  final desc = t['desc'] as String;
                  final icon = t['icon'] as IconData;
                  final isSelected = accountType == name;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _saveAccountType(name);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04))
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? (dark ? Colors.white24 : Colors.black12)
                                : Colors.transparent,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dark
                                    ? Colors.white.withValues(alpha: 
                                        isSelected ? 0.12 : 0.08)
                                    : Colors.black.withValues(alpha: 
                                        isSelected ? 0.08 : 0.04),
                              ),
                              child: Icon(icon, size: 20, color: fg),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${name.tr(context)} ${'Account'.tr(context)}',
                                    style: manrope(
                                        size: 14.5,
                                        weight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                        color: fg),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc.tr(context),
                                    style: manrope(
                                        size: 11.5,
                                        weight: FontWeight.w500,
                                        color: sub),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: fg, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_SearchItem> _buildSearchItems(BuildContext ctx) {
    final dark = widget.dark;
    return [
      _SearchItem(
        icon: Icons.person_outline_rounded,
        title: 'Edit profile',
        subtitle: 'Name, bio, links and photo',
        onTap: () => _openEditProfile(ctx),
      ),
      _SearchItem(
        icon: Icons.manage_accounts_outlined,
        title: 'Account type',
        subtitle: 'Switch to personal, private, creator, business, or professional account',
        onTap: () => _openAccountTypeSelector(ctx),
      ),
      if (_isMarketplaceEligible)
        _SearchItem(
          icon: Icons.storefront_outlined,
          title: 'Trandia Marketplace',
          subtitle: 'Discover & connect with creators',
          onTap: () => _openMarketplace(ctx),
        ),
      if (_isCreatorAccount)
        _SearchItem(
          icon: _appliedToMarketplace
              ? Icons.dashboard_rounded
              : Icons.workspace_premium_outlined,
          title: _appliedToMarketplace
              ? 'Marketplace Dashboard'
              : 'Apply for Trandia Marketplace',
          subtitle: _appliedToMarketplace
              ? 'Requests, earnings & history'
              : 'Get discovered by brands & earn',
          onTap: () async {
            await _openCreatorMarketplaceFlow(ctx);
            _loadSettings();
          },
        ),
      if (_isCollaboratorEligible)
        _SearchItem(
          icon: Icons.groups_2_outlined,
          title: 'Find Collaborator',
          subtitle: 'Connect & create with other creators',
          onTap: () => _openFindCollaborate(ctx),
        ),
      _SearchItem(
        icon: Icons.lock_outline_rounded,
        title: 'Privacy',
        subtitle: 'Private account, mentions, tags',
        onTap: () => _openDummy(ctx),
      ),

      _SearchItem(
        icon: Icons.shield_outlined,
        title: 'Security',
        subtitle: 'Password and login activity',
        onTap: () => _openSecurityScreen(ctx),
      ),
      _SearchItem(
        icon: Icons.phonelink_lock_rounded,
        title: 'App Lock',
        subtitle: 'Lock app with a PIN',
        onTap: () => _openAppLock(ctx),
      ),
      _SearchItem(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: 'Likes, follows and messages',
        onTap: () => _openScreenSmoothly(
          ctx,
          NotificationSettingsScreen(dark: dark),
        ).then((_) => _loadSettings()),
      ),

      _SearchItem(
        icon: Icons.language,
        title: 'Language',
        subtitle: 'English, Hindi, Hinglish',
      ),
      _SearchItem(
        icon: Icons.supervised_user_circle,
        title: 'Parental Control',
        subtitle: 'Screen time and content filters',
        onTap: () => _openScreenSmoothly(
          ctx,
          ParentalControlScreen(dark: dark),
        ),
      ),
      _SearchItem(
        icon: Icons.bookmark_border_rounded,
        title: 'Saved',
        subtitle: 'Posts and collections',
        onTap: () => _openScreenSmoothly(ctx, SavedPostsScreen(dark: dark)),
      ),
      _SearchItem(
        icon: Icons.archive_outlined,
        title: 'Archive',
        subtitle: 'Stories and hidden posts',
        onTap: () => _openDummy(ctx),
      ),
      _SearchItem(
        icon: Icons.help_outline_rounded,
        title: 'Help',
        subtitle: 'Support and app info',
        onTap: () => _openDummy(ctx),
      ),
    ];
  }

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _SearchPill(dark: dark, controller: _searchCtrl),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _searchQuery.isNotEmpty
                      ? _buildSearchResults(context)
                      : _buildNormalList(
                          context, dark, sub, selectedLanguage, languageController),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalList(
    BuildContext context,
    bool dark,
    Color sub,
    String selectedLanguage,
    dynamic languageController,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      children: [
        _AccountCard(dark: dark, profile: _profile),
        const SizedBox(height: 16),
        _SectionTitle('ACCOUNT'.tr(context), color: sub),
        _SectionCard(
          dark: dark,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openEditProfile(context),
              child: _SettingRow(
                dark: dark,
                icon: Icons.person_outline_rounded,
                title: 'Edit profile',
                subtitle: 'Name, bio, links and photo',
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openAccountTypeSelector(context),
              child: _SettingRow(
                dark: dark,
                icon: Icons.manage_accounts_outlined,
                title: 'Account type',
                subtitle: '${accountType.tr(context)} ${'Account'.tr(context)}',
              ),
            ),
            if (_isMarketplaceEligible)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openMarketplace(context),
                child: _SettingRow(
                  dark: dark,
                  icon: Icons.storefront_outlined,
                  title: 'Trandia Marketplace',
                  subtitle: 'Discover & connect with creators',
                ),
              ),
            if (_isCreatorAccount)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await _openCreatorMarketplaceFlow(context);
                  _loadSettings();
                },
                child: _SettingRow(
                  dark: dark,
                  icon: _appliedToMarketplace
                      ? Icons.dashboard_rounded
                      : Icons.workspace_premium_outlined,
                  title: _appliedToMarketplace
                      ? 'Marketplace Dashboard'
                      : 'Apply for Trandia Marketplace',
                  subtitle: _appliedToMarketplace
                      ? 'Requests, earnings & history'
                      : 'Get discovered by brands & earn',
                ),
              ),
            if (_isCollaboratorEligible)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openFindCollaborate(context),
                child: _SettingRow(
                  dark: dark,
                  icon: Icons.groups_2_outlined,
                  title: 'Find Collaborator',
                  subtitle: 'Connect & create with other creators',
                ),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDummy(context),
              child: _SettingRow(
                dark: dark,
                icon: Icons.lock_outline_rounded,
                title: 'Privacy',
                subtitle: 'Private account, mentions, tags',
              ),
            ),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSecurityScreen(context),
              child: _SettingRow(
                dark: dark,
                icon: Icons.shield_outlined,
                title: 'Security',
                subtitle: 'Password and login activity',
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openAppLock(context),
              child: _BaseRow(
                dark: dark,
                icon: Icons.phonelink_lock_rounded,
                title: 'App Lock',
                subtitle: _appLockEnabled
                    ? 'ON • $_appLockPinLength-digit PIN'
                    : 'Protect app with a PIN',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_appLockEnabled)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('ON',
                            style: manrope(size: 11, weight: FontWeight.w800, color: Colors.green)),
                      ),
                    Icon(Icons.chevron_right_rounded, color: sub, size: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle('PREFERENCES'.tr(context), color: sub),
        _SectionCard(
          dark: dark,
          children: [
            // Notifications: master switch + chevron to sub-settings
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openScreenSmoothly(
                context,
                NotificationSettingsScreen(dark: dark),
              ).then((_) => _loadSettings()),
              child: _BaseRow(
                dark: dark,
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Likes, follows and messages',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: notifications,
                      onChanged: (v) {
                        setState(() => notifications = v);
                        _saveSetting('settings_notifications', v);
                      },
                      activeThumbColor:
                          dark ? const Color(0xFF0A0A0A) : Colors.white,
                      activeTrackColor:
                          dark ? Colors.white : const Color(0xFF0A0A0A),
                      inactiveThumbColor:
                          dark ? Colors.white70 : Colors.black54,
                      inactiveTrackColor:
                          dark ? Colors.white12 : Colors.black12,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(Icons.chevron_right_rounded,
                          color: sub, size: 24),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
        const SizedBox(height: 16),
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
                .map((lang) => DropdownMenuItem(
                    value: lang, child: Text(lang.tr(context))))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                languageController.setLanguage(AppLanguage.fromLabel(v));
              }
            },
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openScreenSmoothly(
            context,
            ParentalControlScreen(dark: dark),
          ),
          child: _BaseRow(
            dark: dark,
            icon: Icons.supervised_user_circle,
            title: 'Parental Control',
            subtitle: '',
            trailing: Icon(Icons.chevron_right_rounded,
                color: GlassTokens.sub(dark), size: 24),
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('MORE'.tr(context), color: sub),
        _SectionCard(
          dark: dark,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openScreenSmoothly(context, SavedPostsScreen(dark: dark)),
              child: _SettingRow(
                dark: dark,
                icon: Icons.bookmark_border_rounded,
                title: 'Saved',
                subtitle: 'Posts and collections',
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDummy(context),
              child: _SettingRow(
                dark: dark,
                icon: Icons.archive_outlined,
                title: 'Archive',
                subtitle: 'Stories and hidden posts',
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDummy(context),
              child: _SettingRow(
                dark: dark,
                icon: Icons.help_outline_rounded,
                title: 'Help',
                subtitle: 'Support and app info',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _LogoutButton(dark: dark),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final dark = widget.dark;
    final sub = GlassTokens.sub(dark);
    final items = _buildSearchItems(context)
        .where((i) => i.matches(_searchQuery))
        .toList();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No results found',
            style:
                manrope(size: 14, weight: FontWeight.w600, color: sub),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        final row = _BaseRow(
          dark: dark,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          trailing: item.switchValue != null
              ? Switch(
                  value: item.switchValue!,
                  onChanged: item.onSwitch,
                  activeThumbColor:
                      dark ? const Color(0xFF0A0A0A) : Colors.white,
                  activeTrackColor:
                      dark ? Colors.white : const Color(0xFF0A0A0A),
                  inactiveThumbColor:
                      dark ? Colors.white70 : Colors.black54,
                  inactiveTrackColor:
                      dark ? Colors.white12 : Colors.black12,
                )
              : Icon(Icons.chevron_right_rounded, color: sub, size: 24),
        );

        final card = Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassSurface(
              dark: dark,
              radius: 20,
              padding: EdgeInsets.zero,
              child: row),
        );

        return item.onTap != null
            ? GestureDetector(onTap: item.onTap, child: card)
            : card;
      },
    );
  }
}

// ── Search pill ───────────────────────────────────────────────────────────────

class _SearchPill extends StatelessWidget {
  final bool dark;
  final TextEditingController controller;
  const _SearchPill({required this.dark, required this.controller});

  @override
  Widget build(BuildContext context) {
    final sub = GlassTokens.sub(dark);
    final fg = GlassTokens.fg(dark);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.6),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.95),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 19, color: sub),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: manrope(
                      size: 14, weight: FontWeight.w600, color: fg),
                  decoration: InputDecoration(
                    hintText: 'Search settings'.tr(context),
                    hintStyle: manrope(
                        size: 14, weight: FontWeight.w600, color: sub),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  cursorColor: fg,
                  cursorHeight: 18,
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (controller.text.isNotEmpty)
                GestureDetector(
                  onTap: controller.clear,
                  child:
                      Icon(Icons.close_rounded, size: 18, color: sub),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared UI widgets ─────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final bool dark;
  final UserProfile? profile;
  const _AccountCard({required this.dark, this.profile});

  @override
  Widget build(BuildContext context) {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);
    final name = profile?.name ?? '';
    final username = profile?.username ?? '';

    return GlassSurface(
      dark: dark,
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          profile == null
              ? Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, gradient: monoAvatar(dark, 2)),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                )
              : UserAvatar(
                  pictureUrl: profile!.picture,
                  name: name,
                  size: 58,
                  dark: dark,
                  index: 2,
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : '...',
                  style: manrope(
                      size: 16, weight: FontWeight.w800, color: fg),
                ),
                const SizedBox(height: 3),
                Text(
                  username.isNotEmpty ? '@$username' : '',
                  style: manrope(
                      size: 12.5, weight: FontWeight.w600, color: sub),
                ),
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
        style: manrope(
            size: 11,
            weight: FontWeight.w800,
            color: color,
            letterSpacing: 0.9),
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
      trailing: Icon(Icons.chevron_right_rounded,
          color: GlassTokens.sub(dark), size: 24),
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
        activeThumbColor: dark ? const Color(0xFF0A0A0A) : Colors.white,
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
              color: dark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.tr(context),
                    style: manrope(
                        size: 14.5,
                        weight: FontWeight.w800,
                        color: fg)),
                const SizedBox(height: 3),
                Text(subtitle.tr(context),
                    style: manrope(
                        size: 12,
                        weight: FontWeight.w500,
                        color: sub)),
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

// ── Logout button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatefulWidget {
  final bool dark;
  const _LogoutButton({required this.dark});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _loading = false;

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.dark ? const Color(0xFF1C1C1F) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log out?',
          style: manrope(
              size: 17,
              weight: FontWeight.w800,
              color: GlassTokens.fg(widget.dark)),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: manrope(
              size: 14,
              weight: FontWeight.w500,
              color: GlassTokens.sub(widget.dark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: manrope(
                  size: 14,
                  weight: FontWeight.w700,
                  color: GlassTokens.sub(widget.dark)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Log out',
              style: manrope(
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IntroSlidesScreen()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _handleLogout,
      child: GlassSurface(
        dark: widget.dark,
        radius: 999,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: _loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                )
              : Text(
                  'Log out'.tr(context),
                  style: manrope(
                      size: 14,
                      weight: FontWeight.w800,
                      color: Colors.redAccent),
                ),
        ),
      ),
    );
  }
}
