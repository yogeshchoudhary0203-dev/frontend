import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_common.dart';
import '../l10n/app_localizations.dart';

class SavedPostsScreen extends StatelessWidget {
  final bool dark;
  const SavedPostsScreen({super.key, required this.dark});

  @override
  Widget build(BuildContext context) {
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
                          'Saved'.tr(context),
                          style: manrope(
                            size: 17,
                            weight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            border: Border.all(
                              color: dark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.1),
                            ),
                          ),
                          child: Icon(
                            Icons.bookmark_border_rounded,
                            size: 48,
                            color: fg.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Saved Posts Yet'.tr(context),
                          style: manrope(
                            size: 20,
                            weight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'When you save a post, it will appear here. Only you can see what you\'ve saved.'.tr(context),
                            textAlign: TextAlign.center,
                            style: manrope(
                              size: 14,
                              weight: FontWeight.w500,
                              color: sub,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
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
