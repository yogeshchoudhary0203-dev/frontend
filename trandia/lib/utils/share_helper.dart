import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/post_service.dart';
import '../services/share_service.dart';
import '../screens/glass_common.dart';
import '../l10n/app_localizations.dart';

class ShareHelper {
  ShareHelper._();

  static void showShareBottomSheet(BuildContext context, PostModel post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.4),
      isScrollControlled: true,
      builder: (context) {
        return _ShareSheetContent(post: post, isDark: isDark);
      },
    );
  }
}

class _ShareSheetContent extends StatefulWidget {
  final PostModel post;
  final bool isDark;

  const _ShareSheetContent({
    required this.post,
    required this.isDark,
  });

  @override
  State<_ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends State<_ShareSheetContent> {
  PostModel get post => widget.post;
  bool get isDark => widget.isDark;

  String _shareUrl = '';
  bool _loadingUrl = true;

  @override
  void initState() {
    super.initState();
    // Pre-populate with fallback immediately, then replace with smart URL
    _shareUrl = _buildFallbackUrl();
    _fetchSmartUrl();
  }

  String _buildFallbackUrl() {
    final path = post.isVideo ? 'video' : 'post';
    return 'https://trandia.com/$path/${post.id}';
  }

  Future<void> _fetchSmartUrl() async {
    final url = await ShareService.getShareUrl(post);
    if (mounted) {
      setState(() {
        _shareUrl = url;
        _loadingUrl = false;
      });
    }
  }

  String get _shareText => ShareService.buildShareText(post, _shareUrl);

  Future<void> _launchSocialApp(BuildContext context, String url, String fallbackText) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to system share if app is not installed/resolvable
        // ignore: deprecated_member_use
        await Share.share(fallbackText);
      }
    } catch (e) {
      // ignore: deprecated_member_use
      await Share.share(fallbackText);
    }
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    if (context.mounted) Navigator.of(context).pop();
    
    // Show glassmorphic snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.12),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Link Copied!'.tr(context),
                      style: manrope(
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColors    = GlassTokens.glassBg(isDark);
    final borderColor = GlassTokens.glassBorder(isDark);
    final textPrimary = GlassTokens.fg(isDark);

    final shareOptions = [
      _ShareOption(
        name: 'WhatsApp',
        icon: FontAwesomeIcons.whatsapp,
        color: const Color(0xFF25D366),
        onTap: () {
          final text = _shareText;
          _launchSocialApp(context, 'whatsapp://send?text=${Uri.encodeComponent(text)}', text);
          Navigator.of(context).pop();
        },
      ),
      _ShareOption(
        name: 'Telegram',
        icon: FontAwesomeIcons.telegram,
        color: const Color(0xFF0088CC),
        onTap: () {
          final text = _shareText;
          _launchSocialApp(context, 'tg://msg?text=${Uri.encodeComponent(text)}', text);
          Navigator.of(context).pop();
        },
      ),
      _ShareOption(
        name: 'Instagram',
        icon: FontAwesomeIcons.instagram,
        color: const Color(0xFFE1306C),
        onTap: () {
          // Instagram doesn't support custom scheme link sharing easily, fallback to system share
          // ignore: deprecated_member_use
          Share.share(_shareText);
          Navigator.of(context).pop();
        },
      ),
      _ShareOption(
        name: 'Messenger',
        icon: FontAwesomeIcons.facebookMessenger,
        color: const Color(0xFF006AFF),
        onTap: () {
          // Fallback to system share
          // ignore: deprecated_member_use
          Share.share(_shareText);
          Navigator.of(context).pop();
        },
      ),
      _ShareOption(
        name: 'Twitter / X',
        icon: FontAwesomeIcons.xTwitter,
        color: const Color(0xFF1DA1F2),
        onTap: () {
          final text = _shareText;
          _launchSocialApp(context, 'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}', text);
          Navigator.of(context).pop();
        },
      ),
      _ShareOption(
        name: 'Facebook',
        icon: FontAwesomeIcons.facebook,
        color: const Color(0xFF1877F2),
        onTap: () {
          final url = _shareUrl;
          _launchSocialApp(context, 'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}', _shareText);
          Navigator.of(context).pop();
        },
      ),
      _ShareOption(
        name: 'Copy Link',
        icon: Icons.link_rounded,
        color: const Color(0xFF888888),
        onTap: () => _copyToClipboard(context),
      ),
      _ShareOption(
        name: 'More',
        icon: Icons.more_horiz_rounded,
        color: const Color(0xFF555555),
        onTap: () {
          // ignore: deprecated_member_use
          Share.share(_shareText);
          Navigator.of(context).pop();
        },
      ),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bgColors,
            ),
            border: Border(
              top: BorderSide(color: borderColor, width: 1.5),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              )
            ],
          ),
          padding: const EdgeInsets.only(top: 10, bottom: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: textPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              
              // Sheet Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      post.isVideo ? 'Share Video'.tr(context) : 'Share Post'.tr(context),
                      style: manrope(
                        size: 17,
                        weight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: textPrimary.withValues(alpha: 0.07),
                        ),
                        child: Icon(Icons.close_rounded, size: 16, color: textPrimary.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Smart link loading indicator
              if (_loadingUrl)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: textPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Generating link…',
                        style: manrope(
                          size: 11,
                          weight: FontWeight.w500,
                          color: textPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 10),

              // Share Options Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: shareOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final opt = shareOptions[index];
                    return GestureDetector(
                      onTap: opt.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Icon Button
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  opt.color.withValues(alpha: isDark ? 0.25 : 0.85),
                                  opt.color.withValues(alpha: isDark ? 0.15 : 0.95),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: opt.color.withValues(alpha: isDark ? 0.35 : 0.2),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: opt.color.withValues(alpha: isDark ? 0.12 : 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                opt.icon,
                                color: isDark ? opt.color : Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // App Name
                          Text(
                            opt.name.tr(context),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: manrope(
                              size: 11,
                              weight: FontWeight.w700,
                              color: textPrimary.withValues(alpha: 0.85),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareOption {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
